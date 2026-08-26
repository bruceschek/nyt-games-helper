import Foundation

/// The box: four sides of three letters each.
struct LetterBoxedPuzzle: Equatable {
    static let sideCount = 4
    static let lettersPerSide = 3
    static var letterCount: Int { sideCount * lettersPerSide }

    let sides: [[Character]]

    var allLetters: LetterSet { LetterSet(sides.flatMap { $0 }) }

    /// letter → which side it sits on, for the "no two in a row from one side" rule.
    var sideOfLetter: [Character: Int] {
        var map: [Character: Int] = [:]
        for (index, side) in sides.enumerated() {
            for letter in side { map[letter] = index }
        }
        return map
    }
}

struct LetterBoxedSolution: Identifiable, Equatable {
    let words: [String]

    var id: String { words.joined(separator: "-") }
    var letterCount: Int { words.reduce(0) { $0 + $1.count } }
}

enum LetterBoxedSolver {

    /// Finds the shortest chain of words that uses all twelve letters.
    ///
    /// A word is playable if it only uses the box's letters and never steps between
    /// two letters on the same side; each word after the first has to start with the
    /// letter the previous one ended on. Fewest words wins, and among equals, fewest
    /// letters.
    ///
    /// `maxSharedLetters` caps how many already-used letters a word may repeat. The
    /// default explores everything; tightening it trades completeness for speed on
    /// puzzles where the full search drags.
    static func solve(
        _ puzzle: LetterBoxedPuzzle,
        maxWords: Int = 5,
        maxSharedLetters: Int? = nil
    ) -> LetterBoxedSolution? {
        let allowed = puzzle.allLetters
        let sideOf = puzzle.sideOfLetter
        let target = LetterBoxedPuzzle.letterCount

        let playable = WordLists.scrabble.filter { word in
            guard word.count >= 3, LetterSet(word).isSubset(of: allowed) else { return false }
            let letters = Array(word)
            for index in 0..<(letters.count - 1) where sideOf[letters[index]] == sideOf[letters[index + 1]] {
                return false
            }
            return true
        }

        var wordsStartingWith: [Character: [String]] = [:]
        for word in playable {
            wordsStartingWith[word.first!, default: []].append(word)
        }

        var best: LetterBoxedSolution?
        var bestWordCount = maxWords + 1
        var bestLetterCount = Int.max

        func extend(_ chain: [String], _ used: LetterSet) {
            // One more word can only lengthen the chain, so a chain already as long
            // as the best answer can't beat it.
            guard chain.count < bestWordCount else { return }
            guard let candidates = wordsStartingWith[chain.last!.last!] else { return }

            for word in candidates where !chain.contains(word) {
                let wordLetters = LetterSet(word)
                if let cap = maxSharedLetters, used.intersection(wordLetters).count > cap { continue }

                let nowUsed = used.union(wordLetters)
                let nextChain = chain + [word]

                if nowUsed.count == target {
                    let letters = nextChain.reduce(0) { $0 + $1.count }
                    if nextChain.count < bestWordCount
                        || (nextChain.count == bestWordCount && letters < bestLetterCount) {
                        best = LetterBoxedSolution(words: nextChain)
                        bestWordCount = nextChain.count
                        bestLetterCount = letters
                    }
                } else {
                    extend(nextChain, nowUsed)
                }
            }
        }

        for word in playable {
            let letters = LetterSet(word)
            if letters.count == target {
                if 1 < bestWordCount || (1 == bestWordCount && word.count < bestLetterCount) {
                    best = LetterBoxedSolution(words: [word])
                    bestWordCount = 1
                    bestLetterCount = word.count
                }
            } else {
                extend([word], letters)
            }
        }

        return best
    }
}
