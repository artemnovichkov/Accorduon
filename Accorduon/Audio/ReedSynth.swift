import CoreAudio
import Foundation
import Synchronization

/// A small accordion model, built from the things that make a real one sound the way it does:
///
/// - **Several reeds per note.** Three reeds at the same pitch, one tuned flat and one sharp,
///   beat against each other ("wet" musette), plus a quieter reed an octave below.
/// - **A reed-shaped wave.** Reeds snap open and shut, so each one is a narrow pulse,
///   anti-aliased with PolyBLEP to avoid the harsh digital fizz of a raw sawtooth.
/// - **The reed chamber.** Two resonant peaks color every note, like the wooden body does.
/// - **Air.** Reeds speak slightly flat and settle into pitch, air hiss rides on top,
///   and the bellows pressure controls both loudness and brightness.
///
/// Like a real accordion, holding a key isn't enough to make a sound:
/// the bellows have to move. `pump(_:)` adds air, and the air leaks out
/// on its own, so the sound fades as soon as the bellows stop.
///
/// The class is `nonisolated` because `render` runs on the real-time audio thread.
/// All shared state lives behind a `Mutex`.
nonisolated final class ReedSynth: Sendable {
    /// One reed rank, like a register on a real accordion.
    private struct Reed {
        /// Pitch relative to the note.
        let ratio: Double
        let gain: Double
    }

    /// Bassoon (16') + three musette 8' reeds tuned −12, 0, +12 cents.
    private static let reeds = [
        Reed(ratio: 0.5, gain: 0.35),
        Reed(ratio: pow(2, -12.0 / 1200), gain: 0.5),
        Reed(ratio: 1, gain: 0.6),
        Reed(ratio: pow(2, 12.0 / 1200), gain: 0.5),
    ]

    private struct Voice {
        var isHeld = false
        var level = 0.0
        /// Seconds since the key went down, for the attack pitch bend.
        var age = 0.0
        /// One phase per reed. A fixed-size vector, so the audio thread never allocates.
        var phases = SIMD4<Double>()
    }

    /// A biquad band-pass filter (RBJ cookbook), used for the reed chamber resonances.
    private struct Resonance {
        let b0, b2, a1, a2: Double
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

        init(frequency: Double, q: Double, sampleRate: Double) {
            let omega = 2 * .pi * frequency / sampleRate
            let alpha = sin(omega) / (2 * q)
            let a0 = 1 + alpha
            b0 = alpha / a0
            b2 = -alpha / a0
            a1 = -2 * cos(omega) / a0
            a2 = (1 - alpha) / a0
        }

        mutating func process(_ x: Double) -> Double {
            let y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x
            y2 = y1; y1 = y
            return y
        }
    }

    private struct State {
        var voices = [Voice](repeating: Voice(), count: 128)
        /// Air pushed by the bellows, 0...1. Leaks out over time.
        var air = 0.0
        /// Keeps the bellows full without moving them.
        var isAirLocked = false
        /// `air` smoothed so pressure changes don't click.
        var pressure = 0.0
        var lowPass = 0.0
        var dcBlockInput = 0.0
        var dcBlockOutput = 0.0
        var noiseSeed: UInt32 = 22_222
        var lowChamber: Resonance
        var highChamber: Resonance
    }

    private let state: Mutex<State>
    private let sampleRate: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        state = Mutex(State(
            lowChamber: Resonance(frequency: 1_100, q: 1.4, sampleRate: sampleRate),
            highChamber: Resonance(frequency: 2_700, q: 2, sampleRate: sampleRate)
        ))
    }

    /// The current bellows pressure, 0...1.
    var pressure: Double {
        state.withLock { $0.pressure }
    }

    /// Replaces the set of held MIDI notes.
    func setHeldNotes(_ notes: Set<Int>) {
        state.withLock { state in
            for midi in state.voices.indices {
                let isHeld = notes.contains(midi)
                if isHeld && !state.voices[midi].isHeld {
                    state.voices[midi].age = 0
                }
                state.voices[midi].isHeld = isHeld
            }
        }
    }

    /// Keeps the bellows full, for playing without pumping.
    func setAirLocked(_ isLocked: Bool) {
        state.withLock { $0.isAirLocked = isLocked }
    }

    /// Pushes air into the bellows. `amount` is 0...1.
    func pump(_ amount: Double) {
        state.withLock { state in
            state.air = max(state.air, min(amount, 1))
        }
    }

    /// Fills a mono Float32 buffer. Called on the audio thread.
    func render(frameCount: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        guard let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return }
        let output = UnsafeMutableBufferPointer(start: data, count: frameCount)
        output.initialize(repeating: 0)

        let attack = smoothing(seconds: 0.025)
        let release = smoothing(seconds: 0.07)
        let airLeak = exp(-1 / (0.3 * sampleRate))
        let pressureSmoothing = smoothing(seconds: 0.03)
        let secondsPerFrame = 1 / sampleRate
        let reeds = Self.reeds

        state.withLock { state in
            // How open the valves are: air hiss only flows while keys are down.
            var openValves = 0.0

            // 1. Mix every sounding reed.
            for midi in state.voices.indices where state.voices[midi].isHeld || state.voices[midi].level > 0.0001 {
                var voice = state.voices[midi]
                let frequency = 440 * pow(2, Double(midi - 69) / 12)
                let target = voice.isHeld ? 1.0 : 0.0
                let rate = voice.isHeld ? attack : release
                // The bass side already sits low, so skip its 16' reed to keep it from getting muddy.
                let firstReed = midi < 48 ? 1 : 0

                for frame in 0..<frameCount {
                    voice.level += (target - voice.level) * rate
                    // Reeds start about 20 cents flat and settle within ~40 ms.
                    let bend = 1 - 0.0116 * exp(-voice.age / 0.04)
                    voice.age += secondsPerFrame

                    var sample = 0.0
                    for index in firstReed..<reeds.count {
                        let step = frequency * reeds[index].ratio * bend / sampleRate
                        let phase = (voice.phases[index] + step).truncatingRemainder(dividingBy: 1)
                        voice.phases[index] = phase
                        sample += reedWave(phase: phase, step: step) * reeds[index].gain
                    }
                    output[frame] += Float(sample * 0.35 * voice.level)
                }
                openValves += voice.level
                state.voices[midi] = voice
            }
            openValves = min(openValves, 1)

            // 2. Shape the mix with the bellows and the body.
            for frame in 0..<frameCount {
                state.air = state.isAirLocked ? max(state.air, 0.7) : state.air * airLeak
                state.pressure += (state.air - state.pressure) * pressureSmoothing
                let pressure = state.pressure

                state.noiseSeed = state.noiseSeed &* 1_664_525 &+ 1_013_904_223
                let noise = Double(state.noiseSeed) / Double(UInt32.max) * 2 - 1
                let reeds = Double(output[frame]) + noise * 0.04 * openValves

                // Brighter with more air.
                let cutoff = 1_200 + 4_000 * pressure
                state.lowPass += (reeds - state.lowPass) * (1 - exp(-2 * .pi * cutoff / sampleRate))
                let body = state.lowPass
                    + 0.9 * state.lowChamber.process(reeds)
                    + 0.5 * state.highChamber.process(reeds)

                // Remove any DC offset left by the asymmetric reed pulses.
                let centered = body - state.dcBlockInput + 0.995 * state.dcBlockOutput
                state.dcBlockInput = body
                state.dcBlockOutput = centered

                output[frame] = Float(tanh(centered * pow(pressure, 0.7) * 0.8))
            }
        }
    }

    /// A narrow pulse with rounded, anti-aliased edges: roughly how a reed chops the airflow.
    private func reedWave(phase: Double, step: Double) -> Double {
        let duty = 0.3
        let saw = 2 * phase - 1 - polyBLEP(phase, step)
        let shifted = (phase + duty).truncatingRemainder(dividingBy: 1)
        let shiftedSaw = 2 * shifted - 1 - polyBLEP(shifted, step)
        // Mostly pulse, with a little saw for the reed's buzzy edge.
        return 0.7 * (saw - shiftedSaw) + 0.3 * saw
    }

    /// Smooths the jump of a sawtooth to cut aliasing.
    private func polyBLEP(_ phase: Double, _ step: Double) -> Double {
        if phase < step {
            let x = phase / step
            return x + x - x * x - 1
        }
        if phase > 1 - step {
            let x = (phase - 1) / step
            return x * x + x + x + 1
        }
        return 0
    }

    /// A one-pole smoothing coefficient that reaches ~63% of the target in `seconds`.
    private func smoothing(seconds: Double) -> Double {
        1 - exp(-1 / (seconds * sampleRate))
    }
}
