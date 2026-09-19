import SwiftUI

/// An accordion whose bellows are the iPhone Duo hinge.
///
/// Hold the device like an open book: left thumb on the bass buttons,
/// right thumb on the keys. Fold and unfold to push air — the faster
/// the hinge moves, the louder it plays. Without a hinge, drag the bellows.
struct AccordionView: View {
    @State private var audio = AccordionAudio()
    @State private var hinge: DeviceHinge?
    @State private var lastHingeSample: (degrees: Double, date: Date)?
    /// 0 when closed, 1 when fully stretched.
    @State private var stretch = 0.8
    @State private var trebleNotes: Set<Int> = []
    @State private var bassNotes: Set<Int> = []
    @State private var song: Song?
    @State private var step = 0
    @State private var isAirLocked = false

    private let keyboardNotes = Note.range("B3", "E5")

    var body: some View {
        GeometryReader { screen in
            // The cover display is tall and narrow: no room to play, so show the closed accordion.
            if screen.size.width < screen.size.height {
                ClosedAccordion(hint: hinge == nil ? "Turn sideways to play" : "Unfold to play")
            } else {
                instrument(screen: screen)
            }
        }
        .background(Color(white: 0.05))
        .onChange(of: trebleNotes.union(bassNotes)) { _, notes in
            audio.synth.setHeldNotes(notes)
        }
        .onChange(of: trebleNotes) { old, new in
            advanceSong(pressed: new.subtracting(old))
        }
        .onChange(of: isAirLocked) { _, isLocked in
            audio.synth.setAirLocked(isLocked)
        }
        .onChange(of: song) {
            step = 0
        }
        // 👇 The API: the hinge is the bellows.
        .onHingeChange { _, newContext in
            hinge = newContext.hinge
            guard let degrees = newContext.hinge?.angle.degrees else { return }
            let now = Date.now
            if let last = lastHingeSample {
                // Air comes from how fast the hinge moves, in either direction.
                // The interval is capped, so a sudden jump after a pause still counts as a push.
                let seconds = min(max(now.timeIntervalSince(last.date), 1.0 / 120), 0.2)
                let speed = abs(degrees - last.degrees) / seconds
                audio.synth.pump(speed / 120)
            }
            lastHingeSample = (degrees, now)
            withAnimation(.interactiveSpring) {
                stretch = degrees / 180
            }
        }
    }

    @ViewBuilder
    private func instrument(screen: GeometryProxy) -> some View {
        // Pad both sides by the larger inset so the bellows stay centered on the fold.
        let inset = max(screen.safeAreaInsets.leading, screen.safeAreaInsets.trailing) + 16
        TimelineView(.animation) { timeline in
            let pressure = audio.synth.pressure
            VStack(spacing: 0) {
                SongBar(song: $song, step: $step, isAirLocked: $isAirLocked, hint: hint, pressure: pressure)

                GeometryReader { proxy in
                    // Equal ends keep the bellows in the middle.
                    let endWidth = proxy.size.width * 0.37
                    HStack(spacing: 0) {
                        AccordionEnd {
                            BassBoard { bassNotes = $0 }
                        }
                        .frame(width: endWidth)

                        Bellows(
                            stretch: stretch,
                            pressure: pressure,
                            time: timeline.date.timeIntervalSinceReferenceDate
                        )
                        .gesture(bellowsDrag)

                        AccordionEnd {
                            TrebleKeyboard(notes: keyboardNotes, highlighted: nextNote) { trebleNotes = $0 }
                        }
                        .frame(width: endWidth)
                    }
                }
                .padding(.bottom)
            }
            .padding(.horizontal, inset)
            .padding(.top, screen.safeAreaInsets.top)
            .padding(.bottom, screen.safeAreaInsets.bottom)
        }
        .ignoresSafeArea()
    }

    private var hint: String {
        hinge == nil ? "Drag the bellows to play" : "Fold and unfold to play"
    }

    private var nextNote: Note? {
        guard let song, step < song.notes.count else { return nil }
        return song.notes[step]
    }

    /// Fallback for devices without a hinge, and handy in the simulator.
    private var bellowsDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                audio.synth.pump(abs(value.velocity.width) / 600)
                if hinge == nil {
                    stretch = min(max(stretch + value.velocity.width / 60_000, 0), 1)
                }
            }
    }

    private func advanceSong(pressed: Set<Int>) {
        guard let nextNote, pressed.contains(nextNote.midi) else { return }
        step += 1
    }
}

/// The red wooden body that holds the buttons or keys.
private struct AccordionEnd<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.62, green: 0.06, blue: 0.1).gradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                LinearGradient(colors: [.white, .gray, .white.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                                lineWidth: 3
                            )
                    }
                    .shadow(radius: 8)
            }
    }
}

/// Shown on the narrow cover display: the accordion folded shut, gently breathing.
private struct ClosedAccordion: View {
    let hint: String

    var body: some View {
        VStack(spacing: 32) {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                HStack(spacing: 0) {
                    AccordionEnd {
                        // Two columns of bass buttons, dark notes beside light chords.
                        Grid(horizontalSpacing: 10, verticalSpacing: 14) {
                            ForEach(0..<6, id: \.self) { _ in
                                GridRow {
                                    Circle().fill(Color(white: 0.12))
                                    Circle().fill(Color(white: 0.95))
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(width: 84)

                    Bellows(stretch: 0.05 + 0.05 * sin(time * 2), pressure: 0, time: time)
                        .frame(width: 30)

                    AccordionEnd {
                        VStack(spacing: 3) {
                            ForEach(0..<9, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(red: 0.97, green: 0.95, blue: 0.9))
                            }
                        }
                    }
                    .frame(width: 84)
                }
                .frame(height: 320)
            }

            Label(hint, systemImage: "arrow.left.and.right")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AccordionView()
        .preferredColorScheme(.dark)
}
