import Foundation

/// Reads the four sides of the box from a typed line.
///
///     abc def ghi jkl        abc, def, ghi, jkl
struct LetterBoxedInputParser: TextPuzzleParser {
    typealias Puzzle = LetterBoxedPuzzle

    static let placeholder = "abc def ghi jkl"

    static let syntaxHelp = """
        Type the four sides of the box, three letters each, separated by spaces:

          abc def ghi jkl

        Any order of sides works — what matters is which letters share a side, \
        since a word can't step straight from one letter to another on the same one.
        """

    func parse(_ description: String) -> Result<LetterBoxedPuzzle, PuzzleInputError> {
        let sides = description
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map { Array($0.filter(\.isLetter)) }
            .filter { !$0.isEmpty }

        guard sides.count == LetterBoxedPuzzle.sideCount else {
            return .failure(PuzzleInputError("A Letter Boxed puzzle has 4 sides; I read \(sides.count). Try `abc def ghi jkl`."))
        }

        for (index, side) in sides.enumerated() where side.count != LetterBoxedPuzzle.lettersPerSide {
            return .failure(PuzzleInputError("Side \(index + 1) has \(side.count) letter\(side.count == 1 ? "" : "s") — each side of the box has 3."))
        }

        let all = sides.flatMap { $0 }
        guard Set(all).count == LetterBoxedPuzzle.letterCount else {
            return .failure(PuzzleInputError("Those letters repeat — the box has 12 different ones."))
        }

        return .success(LetterBoxedPuzzle(sides: sides))
    }
}
