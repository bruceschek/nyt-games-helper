import Foundation

/// Reads today's hive from a typed line.
///
/// The center letter comes first, then the other six — either split off on its own
/// or just run together:
///
///     n acdehl        n, acdehl        nacdehl
struct SpellingBeeInputParser: TextPuzzleParser {
    typealias Puzzle = SpellingBeePuzzle

    static let placeholder = "n acdehl"

    static let syntaxHelp = """
        Type the center letter first, then the six letters around it:

          n acdehl

        Running all seven together works too (`nacdehl`) — the first one is always \
        taken as the center letter.
        """

    func parse(_ description: String) -> Result<SpellingBeePuzzle, PuzzleInputError> {
        let letters = description.lowercased().filter(\.isLetter)

        guard !letters.isEmpty else {
            return .failure(PuzzleInputError("Type the center letter first, then the other six — for example `n acdehl`."))
        }

        let fields = description
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map { $0.filter(\.isLetter) }
            .filter { !$0.isEmpty }

        // Either "n acdehl" (center split off) or "nacdehl" (all seven together).
        let center: Character
        let outer: [Character]
        if fields.count >= 2, fields[0].count == 1 {
            center = fields[0].first!
            outer = Array(fields.dropFirst().joined())
        } else {
            center = letters.first!
            outer = Array(letters.dropFirst())
        }

        guard outer.count == 6 else {
            let total = outer.count + 1
            return .failure(PuzzleInputError("Spelling Bee has 7 letters; I read \(total). Type the center letter first, then the other six."))
        }
        guard Set(outer + [center]).count == 7 else {
            return .failure(PuzzleInputError("Those letters repeat — a Spelling Bee puzzle has 7 different ones."))
        }

        return .success(SpellingBeePuzzle(centerLetter: center, outerLetters: outer))
    }
}
