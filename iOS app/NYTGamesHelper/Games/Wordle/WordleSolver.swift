import Foundation

struct WordleSuggestion: Identifiable, Equatable {
    let word: String
    /// Frequency rank, 1 = most common. `nil` when the word has no frequency data.
    let commonnessRank: Int?

    var id: String { word }
}

/// Narrows the answer list down to what's still possible.
///
/// Candidates come from the 2,315 words Wordle can actually pick, never the full
/// Scrabble dictionary — otherwise it happily suggests words the game would never
/// use as an answer.
enum WordleSolver {

    static func suggestions(for board: WordleBoard) -> [WordleSuggestion] {
        let constraints = board.constraints
        return WordLists.wordleAnswers
            .filter(constraints.allows)
            .map { WordleSuggestion(word: $0, commonnessRank: WordLists.wordFormRanks[$0]) }
            .sorted { left, right in
                let leftRank = left.commonnessRank ?? WordLists.unrankedSink
                let rightRank = right.commonnessRank ?? WordLists.unrankedSink
                return leftRank == rightRank ? left.word < right.word : leftRank < rightRank
            }
    }
}
