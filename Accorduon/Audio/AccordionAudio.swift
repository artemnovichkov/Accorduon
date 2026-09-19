import AVFoundation

/// Owns the audio engine and plays `ReedSynth` through an `AVAudioSourceNode`.
final class AccordionAudio {
    let synth: ReedSynth
    private let engine = AVAudioEngine()

    init() {
        let session = AVAudioSession.sharedInstance()
        // `.playback` keeps the accordion audible with the silent switch on.
        try? session.setCategory(.playback)
        try? session.setActive(true)

        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        synth = ReedSynth(sampleRate: sampleRate)

        let source = Self.makeSourceNode(for: synth)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        engine.attach(source)
        do {
            try engine.connectNode(source, to: engine.mainMixerNode, format: format)
            try engine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    /// Builds the render block outside the main actor: it runs on the audio thread.
    private nonisolated static func makeSourceNode(for synth: ReedSynth) -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, bufferList in
            synth.render(frameCount: Int(frameCount), into: UnsafeMutableAudioBufferListPointer(bufferList))
            return noErr
        }
    }
}
