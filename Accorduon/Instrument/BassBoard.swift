import SwiftUI

/// The left end: a simplified Stradella bass with a bass note and a chord for each key.
struct BassBoard: View {
    /// Called with the MIDI notes of the pressed buttons whenever they change.
    var onChange: (Set<Int>) -> Void

    @State private var pressed: Set<BassButton> = []

    private let rows = BassButton.rows

    var body: some View {
        GeometryReader { proxy in
            let cell = CGSize(width: proxy.size.width / 2, height: proxy.size.height / Double(rows.count))
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(rows[row]) { button in
                            BassButtonView(button: button, isPressed: pressed.contains(button))
                                .frame(width: cell.width, height: cell.height)
                        }
                    }
                }
            }
            .contentShape(.rect)
            .gesture(
                SpatialEventGesture()
                    .onChanged { events in
                        let touched = events
                            .filter { $0.phase == .active }
                            .compactMap { event -> BassButton? in
                                let row = Int(event.location.y / cell.height)
                                let column = Int(event.location.x / cell.width)
                                guard rows.indices.contains(row), (0..<2).contains(column) else { return nil }
                                return rows[row][column]
                            }
                        update(Set(touched))
                    }
                    .onEnded { _ in
                        update([])
                    }
            )
        }
    }

    private func update(_ buttons: Set<BassButton>) {
        guard buttons != pressed else { return }
        pressed = buttons
        onChange(Set(buttons.flatMap(\.notes)))
    }
}

struct BassButton: Hashable, Identifiable {
    let label: String
    /// Chord buttons are white; single bass notes are black, like on a real accordion.
    let isChord: Bool
    let notes: [Int]

    var id: String { label + (isChord ? " chord" : " bass") }

    /// Rows follow the circle of fifths, as on a real accordion.
    /// Each row: the root in the bass, then its triad.
    static let rows: [[BassButton]] = [
        ("F", 53, true), ("C", 48, true), ("G", 55, true),
        ("D", 50, false), ("A", 57, false), ("E", 52, false),
    ].map { name, root, isMajor in
        [
            BassButton(label: name, isChord: false, notes: [root - 12]),
            BassButton(label: isMajor ? name : name + "m", isChord: true, notes: [root, root + (isMajor ? 4 : 3), root + 7]),
        ]
    }
}

private struct BassButtonView: View {
    let button: BassButton
    let isPressed: Bool

    var body: some View {
        // A solid rim under the cap instead of an animated blur shadow,
        // which flickered as a black square while animating.
        ZStack {
            Circle()
                .fill(.black.opacity(0.45))
                .offset(y: 4)
            Circle()
                .fill(Color(white: brightness).gradient)
                .overlay {
                    Text(button.label)
                        .font(.title3.bold())
                        .foregroundStyle(button.isChord ? .black.opacity(0.7) : .white.opacity(0.85))
                }
                .offset(y: isPressed ? 3 : 0)
        }
        .padding(8)
        .animation(.snappy(duration: 0.08), value: isPressed)
    }

    private var brightness: Double {
        switch (button.isChord, isPressed) {
        case (true, false): 0.95
        case (true, true): 0.7
        case (false, false): 0.12
        case (false, true): 0.35
        }
    }
}

#Preview {
    BassBoard { _ in }
        .frame(width: 180, height: 600)
        .background(.red)
}
