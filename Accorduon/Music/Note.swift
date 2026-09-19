/// A note on the equal-tempered scale, identified by its MIDI number (C4 = 60).
struct Note: Hashable, Identifiable {
    let midi: Int

    var id: Int { midi }

    init(midi: Int) {
        self.midi = midi
    }

    /// Parses scientific pitch notation: `"C4"`, `"F#3"`.
    init(_ spelling: String) {
        let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        var rest = Substring(spelling)
        let semitone = letters[rest.removeFirst()]!
        let sharp = rest.first == "#" ? 1 : 0
        let octave = Int(rest.dropFirst(sharp))!
        midi = (octave + 1) * 12 + semitone + sharp
    }

    var name: String {
        ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][midi % 12]
    }

    var isBlack: Bool {
        [1, 3, 6, 8, 10].contains(midi % 12)
    }

    /// Every note from `lowest` to `highest`, inclusive.
    static func range(_ lowest: String, _ highest: String) -> [Note] {
        (Note(lowest).midi...Note(highest).midi).map(Note.init(midi:))
    }
}
