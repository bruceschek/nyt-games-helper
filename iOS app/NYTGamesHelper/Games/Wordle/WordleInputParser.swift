import Foundation

/// Reads a typed guess-and-result into a `Guess`.
///
/// Accepted shape is the word, then how the game marked it:
///
///     crane .g..y      slate ggyxx      pride g y . . .
///
/// `g` or `+` for a letter in the right spot, `y` or `?` for a letter in the word
/// but the wrong spot, and `.`, `x`, `-` or `_` for a letter that isn't in the word
/// at all. Case and spacing inside the marks are ignored.
struct WordleInputParser: TextPuzzleParser {
    typealias Puzzle = Guess

    static let placeholder = "crane .g..y"

    static let syntaxHelp = """
        Type the word you guessed, then how the game marked it — one character per letter:

          g  right spot        (green)
          y  wrong spot        (yellow)
          .  not in the word   (grey)

        For example, `crane .g..y` means the R is in the right spot, the E is in the \
        word but somewhere else, and C, A and N aren't in it.
        """

    func parse(_ description: String) -> Result<Guess, PuzzleInputError> {
        let fields = description
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard let word = fields.first?.lowercased() else {
            return .failure(PuzzleInputError("Type the word you guessed, then how it was marked — for example `crane .g..y`."))
        }

        guard word.count == WordleBoard.length else {
            return .failure(PuzzleInputError("`\(word)` has \(word.count) letters. Wordle guesses are 5."))
        }
        guard word.allSatisfy(\.isLetter) else {
            return .failure(PuzzleInputError("`\(word)` should be five plain letters."))
        }
        guard WordLists.legalWordleGuesses.contains(word) else {
            return .failure(PuzzleInputError("Wordle doesn't accept `\(word)` as a guess."))
        }

        let markText = fields.dropFirst().joined()
        guard !markText.isEmpty else {
            return .failure(PuzzleInputError("Add how the game marked `\(word)` — five characters using g, y and . — for example `\(word) .g..y`."))
        }

        var marks: [LetterMark] = []
        for character in markText {
            switch Character(character.lowercased()) {
            case "g", "+":                marks.append(.rightSpot)
            case "y", "?":                marks.append(.wrongSpot)
            case ".", "x", "-", "_":      marks.append(.notInWord)
            default:
                return .failure(PuzzleInputError("`\(character)` isn't a mark I recognise. Use g for the right spot, y for the wrong spot, and . for a letter that isn't in the word."))
            }
        }

        guard marks.count == WordleBoard.length else {
            return .failure(PuzzleInputError("You marked \(marks.count) letter\(marks.count == 1 ? "" : "s") but `\(word)` has 5."))
        }

        return .success(Guess(word: word, marks: marks))
    }
}
