import Foundation

/// The bundled word lists.
///
/// Everything is checked into the app bundle rather than fetched, so the app works
/// offline. See `python - modified from p073/dict/SOURCES.md` for what each list is
/// and where it came from — in particular, why Wordle answers must come from
/// `wordleAnswers` and not from the Scrabble dictionary.
///
/// Lists load lazily and stay loaded: the largest is ~196k words and takes well
/// under a second to parse, but there's no reason to pay it twice.
enum WordLists {

    /// NWL2023, the NASPA tournament Scrabble list — ~196k words, all lengths.
    /// The general-purpose dictionary behind Spelling Bee and Letter Boxed.
    static let scrabble: [String] = load("nwl2023")

    /// The 2,315 words Wordle can actually choose as the answer. Curated by the NYT
    /// for words an ordinary player knows, which is why it doubles as the test of
    /// whether a suggestion is worth making.
    static let wordleAnswers: [String] = load("wordle-answers")

    /// The 10,657 words Wordle accepts as guesses but never uses as an answer.
    /// Together with `wordleAnswers` these are the 12,972 legal guesses.
    static let wordleExtraGuesses: [String] = load("wordle-allowed-guesses")

    /// Every word Wordle will accept as a guess.
    static let legalWordleGuesses: Set<String> = Set(wordleAnswers).union(wordleExtraGuesses)

    /// Word → frequency rank (1 = most common) from the Google 10k list.
    ///
    /// This lists *word forms*, not lemmas, so `tried` and `asked` have their own
    /// entries. That matters: the lemma-based list the Python project also carries
    /// scores those as if they were rare.
    static let wordFormRanks: [String: Int] = {
        var ranks: [String: Int] = [:]
        for (index, word) in load("google-10000-english").enumerated() {
            ranks[word] = index + 1
        }
        return ranks
    }()

    /// Rank used for a word with no frequency data — sorts below every ranked word.
    static let unrankedSink: Int = (wordFormRanks.values.max() ?? 0) + 1

    static func rank(of word: String) -> Int {
        wordFormRanks[word] ?? unrankedSink
    }

    // MARK: - Loading

    private static func load(_ name: String) -> [String] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            assertionFailure("Missing bundled word list: \(name).txt")
            return []
        }
        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }
}
