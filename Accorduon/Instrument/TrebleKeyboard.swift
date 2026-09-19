import SwiftUI

/// The piano keyboard on the right end, laid out vertically like on a real accordion:
/// low notes at the top, black keys toward the bellows.
///
/// `SpatialEventGesture` reports every finger at once, so you can play chords
/// and glide between keys.
struct TrebleKeyboard: View {
    let notes: [Note]
    /// The next note of the song guide, if any.
    var highlighted: Note?
    /// Called with the MIDI notes under your fingers whenever they change.
    var onChange: (Set<Int>) -> Void

    @State private var pressed: Set<Int> = []

    var body: some View {
        GeometryReader { proxy in
            let layout = KeyboardLayout(notes: notes, size: proxy.size)
            ZStack(alignment: .topLeading) {
                ForEach(layout.whiteKeys, id: \.note) { key in
                    WhiteKey(note: key.note, isPressed: pressed.contains(key.note.midi), isHighlighted: key.note == highlighted)
                        .frame(width: key.frame.width, height: key.frame.height)
                        .offset(x: key.frame.minX, y: key.frame.minY)
                }
                ForEach(layout.blackKeys, id: \.note) { key in
                    BlackKey(isPressed: pressed.contains(key.note.midi), isHighlighted: key.note == highlighted)
                        .frame(width: key.frame.width, height: key.frame.height)
                        .offset(x: key.frame.minX, y: key.frame.minY)
                }
            }
            // `offset` doesn't resize the stack, so size it to the whole keyboard for hit testing.
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .contentShape(.rect)
            .gesture(
                SpatialEventGesture()
                    .onChanged { events in
                        let touched = events
                            .filter { $0.phase == .active }
                            .compactMap { layout.note(at: $0.location)?.midi }
                        update(Set(touched))
                    }
                    .onEnded { _ in
                        update([])
                    }
            )
        }
    }

    private func update(_ notes: Set<Int>) {
        guard notes != pressed else { return }
        pressed = notes
        onChange(notes)
    }
}

private struct KeyboardLayout {
    struct Key {
        let note: Note
        let frame: CGRect
    }

    let whiteKeys: [Key]
    let blackKeys: [Key]

    init(notes: [Note], size: CGSize) {
        let whites = notes.filter { !$0.isBlack }
        let keyHeight = size.height / Double(whites.count)
        whiteKeys = whites.enumerated().map { index, note in
            Key(note: note, frame: CGRect(x: 0, y: Double(index) * keyHeight, width: size.width, height: keyHeight))
        }
        // A black key sits on the border below the white key one semitone lower.
        blackKeys = notes.filter(\.isBlack).compactMap { note in
            guard let index = whites.firstIndex(where: { $0.midi == note.midi - 1 }) else { return nil }
            let border = Double(index + 1) * keyHeight
            return Key(note: note, frame: CGRect(x: 0, y: border - keyHeight * 0.3, width: size.width * 0.58, height: keyHeight * 0.6))
        }
    }

    func note(at point: CGPoint) -> Note? {
        (blackKeys + whiteKeys).first { $0.frame.contains(point) }?.note
    }
}

private struct WhiteKey: View {
    let note: Note
    let isPressed: Bool
    let isHighlighted: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isPressed ? Color(white: 0.75).gradient : Color(red: 1, green: 0.98, blue: 0.93).gradient)
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.55))
                        .phaseAnimator([0.6, 1]) { view, opacity in
                            view.opacity(opacity)
                        }
                }
            }
            .overlay(alignment: .trailing) {
                Text(note.name)
                    .font(.caption.bold())
                    .foregroundStyle(.black.opacity(0.45))
                    .padding(.trailing, 10)
            }
            .padding(1)
    }
}

private struct BlackKey: View {
    let isPressed: Bool
    let isHighlighted: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isHighlighted ? Color.accentColor.gradient : Color(white: isPressed ? 0.3 : 0.1).gradient)
            .shadow(radius: isPressed ? 0 : 2, x: -1, y: 1)
            .padding(.vertical, 1)
    }
}

#Preview {
    TrebleKeyboard(notes: Note.range("B3", "E5"), highlighted: Note("E4")) { _ in }
        .frame(width: 180, height: 600)
}
