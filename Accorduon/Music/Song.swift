/// A melody the song guide walks you through, one note at a time.
struct Song: Hashable, Identifiable {
    let title: String
    let notes: [Note]

    var id: String { title }

    init(_ title: String, melody: String) {
        self.title = title
        notes = melody.split(separator: " ").map { Note(String($0)) }
    }
}

extension Song {
    /// All melodies fit the treble keyboard, B3...E5.
    static let all: [Song] = [
        Song("Ode to Joy", melody: """
            E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 E4 D4 D4 \
            E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 D4 C4 C4
            """),
        Song("Twinkle, Twinkle", melody: """
            C4 C4 G4 G4 A4 A4 G4 F4 F4 E4 E4 D4 D4 C4 \
            G4 G4 F4 F4 E4 E4 D4 G4 G4 F4 F4 E4 E4 D4 \
            C4 C4 G4 G4 A4 A4 G4 F4 F4 E4 E4 D4 D4 C4
            """),
        Song("Jingle Bells", melody: """
            E4 E4 E4 E4 E4 E4 E4 G4 C4 D4 E4 \
            F4 F4 F4 F4 F4 E4 E4 E4 E4 D4 D4 E4 D4 G4 \
            E4 E4 E4 E4 E4 E4 E4 G4 C4 D4 E4 \
            F4 F4 F4 F4 F4 E4 E4 E4 G4 G4 F4 D4 C4
            """),
        Song("Happy Birthday", melody: """
            D4 D4 E4 D4 G4 F#4 D4 D4 E4 D4 A4 G4 \
            D4 D4 D5 B4 G4 F#4 E4 C5 C5 B4 G4 A4 G4
            """),
        Song("Katyusha", melody: """
            E4 F#4 G4 E4 G4 G4 F#4 E4 F#4 B3 \
            F#4 G4 A4 F#4 A4 A4 G4 F#4 E4 \
            B4 E5 D5 E5 D5 C5 C5 B4 A4 B4 E4 \
            C5 A4 B4 G4 F#4 B3 G4 F#4 E4
            """),
    ]
}
