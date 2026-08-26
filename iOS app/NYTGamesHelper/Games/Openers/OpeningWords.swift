import Foundation

/// A set of four opening guesses, in the order they're best played.
struct OpenerSet: Codable, Identifiable, Equatable {
    let words: [String]
    let score: Double
    let distinctLetters: Int
    /// How many possible answers typically survive after each word, in order.
    let expectedRemaining: [Double]

    var id: String { words.joined(separator: "-") }
}

struct OpenersReference: Codable, Equatable {
    let minUniqueLetters: Int
    let requiredLetters: String
    let answerPoolSize: Int
    let sets: [OpenerSet]
}

/// The precomputed best opening words.
///
/// Wordle's answer pool is a fixed list that hasn't changed since 2021, so the best
/// openers are a constant, not something to recompute. The search runs in the Python
/// project (`uv run export_openers.py`) and writes `openers.json`; the app only reads
/// it. Regenerate that file if the answer list ever changes.
enum OpeningWords {
    static let reference: OpenersReference? = {
        guard let url = Bundle.main.url(forResource: "openers", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            assertionFailure("Missing bundled openers.json")
            return nil
        }
        return try? JSONDecoder().decode(OpenersReference.self, from: data)
    }()
}
