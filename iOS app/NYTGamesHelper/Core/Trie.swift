import Foundation

/// A prefix tree over the dictionary.
///
/// Spelling Bee needs to walk every word buildable from seven letters; doing that
/// against a flat 196k-word list means testing every word, while a trie abandons a
/// whole branch the moment a prefix goes nowhere.
final class Trie {
    final class Node {
        var children: [Character: Node] = [:]
        var isWord = false
    }

    let root = Node()

    init(words: some Sequence<String>, allowedLetters: LetterSet? = nil) {
        for word in words {
            if let allowed = allowedLetters, !LetterSet(word).isSubset(of: allowed) { continue }
            insert(word)
        }
    }

    func insert(_ word: String) {
        var node = root
        for letter in word {
            if let next = node.children[letter] {
                node = next
            } else {
                let next = Node()
                node.children[letter] = next
                node = next
            }
        }
        node.isWord = true
    }

    func contains(_ word: String) -> Bool {
        var node = root
        for letter in word {
            guard let next = node.children[letter] else { return false }
            node = next
        }
        return node.isWord
    }
}
