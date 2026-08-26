import Foundation

/// What the game said about one letter of one guess.
enum LetterMark: String, CaseIterable, Codable {
    case rightSpot   = "g"   // green
    case wrongSpot   = "y"   // yellow
    case notInWord   = "."   // grey

    var label: String {
        switch self {
        case .rightSpot: "right spot"
        case .wrongSpot: "wrong spot"
        case .notInWord: "not in the word"
        }
    }
}

/// One guess and the feedback it drew.
struct Guess: Equatable, Codable, Identifiable {
    let word: String
    let marks: [LetterMark]

    var id: String { word + marks.map(\.rawValue).joined() }

    var letters: [Character] { Array(word) }
}

/// Everything known about today's puzzle: the guesses played so far, in order.
///
/// This is the whole state — nothing is accumulated incrementally, so constraints
/// are re-derived from scratch every time. That costs nothing at five guesses and
/// buys a lot: a guess can be removed or corrected, the board can be replaced
/// wholesale (which is exactly what reading it from a photo will do), and there is
/// no running state to get out of step with what's on screen.
struct WordleBoard: Equatable, Codable {
    static let length = 5

    var guesses: [Guess] = []

    var isSolved: Bool {
        guesses.last?.marks.allSatisfy { $0 == .rightSpot } ?? false
    }

    /// The constraints these guesses imply about the answer.
    ///
    /// The per-letter minimum and maximum occurrence counts are what make duplicate
    /// letters come out right, and they are the reason this is derived rather than
    /// tracked ad hoc. A letter marked grey does not mean "absent" — it means "no
    /// more of these than the ones already marked green or yellow in this guess",
    /// which is only "absent" when that count is zero.
    var constraints: WordleConstraints {
        var constraints = WordleConstraints()

        for guess in guesses {
            var markedPresent: [Character: Int] = [:]   // green or yellow, this guess
            var markedAbsent: [Character: Int] = [:]    // grey, this guess

            for (index, letter) in guess.letters.enumerated() {
                switch guess.marks[index] {
                case .rightSpot:
                    constraints.knownLetters[index] = letter
                    markedPresent[letter, default: 0] += 1
                case .wrongSpot:
                    constraints.bannedPositions[letter, default: []].insert(index)
                    markedPresent[letter, default: 0] += 1
                case .notInWord:
                    markedAbsent[letter, default: 0] += 1
                }
            }

            for letter in Set(guess.letters) {
                let present = markedPresent[letter] ?? 0
                constraints.minCount[letter] = max(constraints.minCount[letter] ?? 0, present)

                // A grey copy caps the total: the answer holds no more of this letter
                // than the copies the game just confirmed.
                if (markedAbsent[letter] ?? 0) > 0 {
                    constraints.maxCount[letter] = min(constraints.maxCount[letter] ?? Self.length, present)
                }
            }
        }
        return constraints
    }
}

/// The answer must satisfy all of these.
struct WordleConstraints: Equatable {
    /// Letters pinned to a position by a green mark; `nil` where still unknown.
    var knownLetters: [Character?] = Array(repeating: nil, count: WordleBoard.length)
    /// Positions a letter has been marked yellow in, so it cannot sit there.
    var bannedPositions: [Character: Set<Int>] = [:]
    var minCount: [Character: Int] = [:]
    var maxCount: [Character: Int] = [:]

    func allows(_ word: String) -> Bool {
        let letters = Array(word)
        guard letters.count == WordleBoard.length else { return false }

        for (index, known) in knownLetters.enumerated() where known != nil {
            if letters[index] != known { return false }
        }

        for (letter, banned) in bannedPositions {
            if !letters.contains(letter) { return false }
            for index in banned where letters[index] == letter { return false }
        }

        var counts: [Character: Int] = [:]
        for letter in letters { counts[letter, default: 0] += 1 }

        for (letter, minimum) in minCount where (counts[letter] ?? 0) < minimum { return false }
        for (letter, maximum) in maxCount where (counts[letter] ?? 0) > maximum { return false }

        return true
    }
}
