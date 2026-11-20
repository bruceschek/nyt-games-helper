import Testing
@testable import NYTGamesHelper

// The expected values here were taken from the Python project, which has been
// played against the real games for a long time. Cross-checking against it is the
// cheapest way to know the Swift port kept the behaviour.

// MARK: - Wordle constraints

@Suite("Wordle constraints")
struct WordleConstraintTests {

    private func board(_ entries: (String, String)...) -> WordleBoard {
        let parser = WordleInputParser()
        var board = WordleBoard()
        for (word, marks) in entries {
            guard case .success(let guess) = parser.parse("\(word) \(marks)") else {
                Issue.record("couldn't parse \(word) \(marks)")
                continue
            }
            board.guesses.append(guess)
        }
        return board
    }

    @Test("a green pins the letter to its position")
    func greenPinsPosition() {
        // Only the R is marked, so C, A, N and E are ruled out too.
        let constraints = board(("crane", ".g...")).constraints
        #expect(constraints.knownLetters[1] == "r")
        #expect(constraints.allows("brisk"))
        #expect(!constraints.allows("worst"))   // has an R, but not in slot 2
    }

    @Test("a yellow requires the letter but bars that position")
    func yellowBarsPosition() {
        let constraints = board(("crane", "y....")).constraints
        #expect(constraints.allows("music"))    // has a C, and not first
        #expect(!constraints.allows("chill"))   // C is first, where it can't be
        #expect(!constraints.allows("spilt"))   // no C at all
    }

    @Test("an all-grey letter is excluded outright")
    func greyExcludes() {
        let constraints = board(("crane", ".....")).constraints
        #expect(!constraints.allows("cheat"))
        #expect(constraints.allows("moist"))
    }

    // The reason the constraint model tracks counts rather than a present/absent
    // flag. A grey copy of a letter alongside a marked copy means "exactly this
    // many", not "none".
    @Test("a grey duplicate caps the count instead of banning the letter")
    func greyDuplicateCapsCount() {
        // In `sassy` against an answer holding one s, the first s comes back green
        // and the other two grey. That means "exactly one s", not "no s".
        let constraints = board(("sassy", "g....")).constraints
        #expect(constraints.minCount["s"] == 1)
        #expect(constraints.maxCount["s"] == 1)
        #expect(constraints.allows("shirt"))            // exactly one s, in the right spot
        #expect(!constraints.allows("shots"))           // two s
    }

    @Test("two marked copies require two of that letter")
    func twoMarkedCopiesRequireTwo() {
        // `geese` with the first two e's green and the third grey: exactly two e's.
        let constraints = board(("geese", ".gg..")).constraints
        #expect(constraints.minCount["e"] == 2)
        #expect(constraints.maxCount["e"] == 2)
        #expect(constraints.allows("beefy"))
        #expect(!constraints.allows("beset"))
    }

    @Test("suggestions come from the answer list, not the Scrabble dictionary")
    func suggestionsUseAnswerList() {
        let results = WordleSolver.suggestions(for: board(("crane", "ggggg")))
        #expect(results.map(\.word) == ["crane"])
    }

    @Test("an unconstrained board offers every answer")
    func emptyBoardOffersEverything() {
        #expect(WordleSolver.suggestions(for: WordleBoard()).count == WordLists.wordleAnswers.count)
    }
}

// MARK: - Wordle input

@Suite("Wordle input")
struct WordleInputTests {
    let parser = WordleInputParser()

    @Test("reads the word and its marks")
    func readsMarks() throws {
        let guess = try #require(try? parser.parse("crane .g..y").get())
        #expect(guess.word == "crane")
        #expect(guess.marks == [.notInWord, .rightSpot, .notInWord, .notInWord, .wrongSpot])
    }

    @Test("accepts the alternative mark characters")
    func acceptsAlternativeMarks() throws {
        let plus = try #require(try? parser.parse("crane -+--?").get())
        let plain = try #require(try? parser.parse("crane .g..y").get())
        #expect(plus.marks == plain.marks)
    }

    @Test("rejects a word Wordle wouldn't accept")
    func rejectsIllegalGuess() {
        #expect(throws: (any Error).self) { try parser.parse("zzzzz .....").get() }
    }

    @Test("rejects the wrong number of marks")
    func rejectsWrongMarkCount() {
        #expect(throws: (any Error).self) { try parser.parse("crane .g.").get() }
    }

    @Test("rejects a word of the wrong length")
    func rejectsWrongLength() {
        #expect(throws: (any Error).self) { try parser.parse("cranes .g..y").get() }
    }
}

// MARK: - Spelling Bee

@Suite("Spelling Bee")
struct SpellingBeeTests {

    @Test("matches the Python solver on n / acdehl")
    func matchesPythonReference() throws {
        let puzzle = try #require(try? SpellingBeeInputParser().parse("n acdehl").get())
        let results = SpellingBeeSolver.solve(puzzle)

        // Python: 126 words, 764 points, 7 pangrams.
        #expect(results.finds.count == 126)
        #expect(results.totalScore == 764)
        #expect(results.finds.filter(\.isPangram).map(\.word).sorted()
                == ["chandelle", "chandelled", "channeled", "channelled",
                    "cleanhanded", "dancehall", "lanched"])
    }

    @Test("scores four-letter words at one point and longer words by length")
    func scoring() {
        let puzzle = SpellingBeePuzzle(centerLetter: "n", outerLetters: Array("acdehl"))
        #expect(puzzle.score(for: "lane") == 1)
        #expect(puzzle.score(for: "clean") == 5)
        #expect(puzzle.score(for: "dancehall") == 9 + 7)   // pangram
    }

    @Test("reads the letters however they're typed")
    func parsing() throws {
        let split = try #require(try? SpellingBeeInputParser().parse("n acdehl").get())
        let joined = try #require(try? SpellingBeeInputParser().parse("nacdehl").get())
        let commas = try #require(try? SpellingBeeInputParser().parse("n, a, c, d, e, h, l").get())
        #expect(split == joined)
        #expect(split == commas)
    }

    @Test("rejects the wrong number of letters")
    func rejectsWrongCount() {
        #expect(throws: (any Error).self) { try SpellingBeeInputParser().parse("n acde").get() }
    }
}

// MARK: - Letter Boxed

@Suite("Letter Boxed")
struct LetterBoxedTests {

    @Test("finds a shortest chain matching the Python solver's length")
    func matchesPythonReference() throws {
        let puzzle = try #require(try? LetterBoxedInputParser().parse("vgy hfp lta ceo").get())
        let solution = try #require(LetterBoxedSolver.solve(puzzle))

        // Python's best is `fletch hypogea ava` — 3 words, 16 letters. Ties are
        // possible, so the length is what's checked, not the exact words.
        #expect(solution.words.count == 3)
        #expect(solution.letterCount == 16)
    }

    @Test("the chain obeys the rules of the box")
    func chainIsLegal() throws {
        let puzzle = try #require(try? LetterBoxedInputParser().parse("vgy hfp lta ceo").get())
        let solution = try #require(LetterBoxedSolver.solve(puzzle))
        let sideOf = puzzle.sideOfLetter

        var covered = LetterSet()
        for (index, word) in solution.words.enumerated() {
            covered = covered.union(LetterSet(word))
            #expect(LetterSet(word).isSubset(of: puzzle.allLetters))
            let letters = Array(word)
            for position in 0..<(letters.count - 1) {
                #expect(sideOf[letters[position]] != sideOf[letters[position + 1]])
            }
            if index > 0 {
                #expect(solution.words[index - 1].last == word.first)
            }
        }
        #expect(covered.count == LetterBoxedPuzzle.letterCount)
    }

    @Test("rejects a box that isn't four sides of three")
    func rejectsMalformedBox() {
        #expect(throws: (any Error).self) { try LetterBoxedInputParser().parse("abc def ghi").get() }
        #expect(throws: (any Error).self) { try LetterBoxedInputParser().parse("abcd ef ghi jkl").get() }
    }
}

// MARK: - Supporting types

@Suite("Letter sets")
struct LetterSetTests {

    @Test("counts distinct letters")
    func counting() {
        #expect(LetterSet("hello").count == 4)
        #expect(LetterSet("").isEmpty)
    }

    @Test("subset means every letter is available")
    func subset() {
        #expect(LetterSet("cab").isSubset(of: LetterSet("abcd")))
        #expect(!LetterSet("cabs").isSubset(of: LetterSet("abcd")))
    }
}

@Suite("Bundled data")
struct WordListTests {

    @Test("the word lists are the expected size")
    func listSizes() {
        #expect(WordLists.wordleAnswers.count == 2315)
        #expect(WordLists.legalWordleGuesses.count == 12972)
        #expect(WordLists.scrabble.count == 196601)
    }

    @Test("every answer has a frequency, so suggestions never fall back to alphabetical")
    func everyAnswerIsRanked() {
        #expect(WordLists.wordFormRanks.count == 12972)
        #expect(WordLists.wordleAnswers.allSatisfy { WordLists.wordFormRanks[$0] != nil })
        // The web-crawl list this replaced knew none of these three.
        for word in ["foist", "hoist", "moist"] {
            #expect(WordLists.wordZipf[word] ?? 0 > 2)
        }
        // Ordinary English must outrank web vocabulary — the old list had this backwards.
        #expect(WordLists.rank(of: "flour") < WordLists.rank(of: "login"))
    }

    @Test("the precomputed openers loaded")
    func openersLoaded() throws {
        let reference = try #require(OpeningWords.reference)
        #expect(reference.sets.count == 25)
        #expect(reference.sets.allSatisfy { $0.words.count == 4 })
        #expect(reference.sets.allSatisfy { $0.distinctLetters >= reference.minUniqueLetters })
    }
}
