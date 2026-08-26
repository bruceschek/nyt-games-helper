import Foundation

/// Today's hive: the letter every word must use, and the six around it.
struct SpellingBeePuzzle: Equatable {
    let centerLetter: Character
    let outerLetters: [Character]

    var allLetters: LetterSet { LetterSet([centerLetter] + outerLetters) }

    /// A word using every letter in the puzzle — worth a 7-point bonus.
    func isPangram(_ word: String) -> Bool {
        allLetters.isSubset(of: LetterSet(word))
    }

    /// The NYT's scoring: a four-letter word is 1 point, longer words score their
    /// length, and a pangram takes 7 more.
    func score(for word: String) -> Int {
        let base = word.count == 4 ? 1 : word.count
        return base + (isPangram(word) ? 7 : 0)
    }
}

struct SpellingBeeFind: Identifiable, Equatable {
    let word: String
    let score: Int
    let isPangram: Bool

    var id: String { word }
}

struct SpellingBeeResults: Equatable {
    let finds: [SpellingBeeFind]
    let totalScore: Int

    /// Grouped by first letter, the way the puzzle's own hints are laid out.
    var byFirstLetter: [(letter: Character, finds: [SpellingBeeFind])] {
        Dictionary(grouping: finds) { $0.word.first ?? " " }
            .sorted { $0.key < $1.key }
            .map { (letter: $0.key, finds: $0.value.sorted { $0.word < $1.word }) }
    }
}

enum SpellingBeeSolver {

    /// Every word in the dictionary buildable from the puzzle's letters that uses
    /// the center letter and runs to at least four letters.
    ///
    /// Building a trie limited to the seven allowed letters first means the walk
    /// only ever visits reachable prefixes, rather than testing all ~196k words.
    static func solve(_ puzzle: SpellingBeePuzzle) -> SpellingBeeResults {
        let allowed = puzzle.allLetters
        let trie = Trie(words: WordLists.scrabble, allowedLetters: allowed)

        var finds: [SpellingBeeFind] = []

        func walk(_ node: Trie.Node, _ prefix: String, _ usedCenter: Bool) {
            if node.isWord, usedCenter, prefix.count >= 4 {
                finds.append(
                    SpellingBeeFind(
                        word: prefix,
                        score: puzzle.score(for: prefix),
                        isPangram: puzzle.isPangram(prefix)
                    )
                )
            }
            for (letter, child) in node.children {
                walk(child, prefix + String(letter), usedCenter || letter == puzzle.centerLetter)
            }
        }
        walk(trie.root, "", false)

        finds.sort { $0.word < $1.word }
        return SpellingBeeResults(finds: finds, totalScore: finds.reduce(0) { $0 + $1.score })
    }
}
