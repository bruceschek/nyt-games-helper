import Testing
@testable import NYTGamesHelper

/// Drives the view models the way the screens do — type, submit, read results —
/// so the wiring between entry field, parser and solver is covered without a UI.
@MainActor
@Suite("Game models")
struct GameModelTests {

    @Test("a Wordle guess narrows the suggestions and clears the field")
    func wordleSubmit() {
        let model = WordleModel()
        model.entry = "crane .g..y"
        model.submit()

        #expect(model.error == nil)
        #expect(model.entry.isEmpty)
        #expect(model.board.guesses.count == 1)
        #expect(!model.suggestions.isEmpty)
        #expect(model.suggestions.count < WordLists.wordleAnswers.count)
        // Every suggestion has to satisfy what was entered.
        let constraints = model.board.constraints
        #expect(model.suggestions.allSatisfy { constraints.allows($0.word) })
    }

    @Test("a bad entry surfaces an error and keeps what was typed")
    func wordleBadEntry() {
        let model = WordleModel()
        model.entry = "crane .g."
        model.submit()

        #expect(model.error != nil)
        #expect(model.entry == "crane .g.")
        #expect(model.board.guesses.isEmpty)
    }

    @Test("removing a guess widens the suggestions again")
    func wordleRemoveGuess() {
        let model = WordleModel()
        model.entry = "crane .g..y"
        model.submit()
        let narrowed = model.suggestions.count

        model.remove(model.board.guesses[0])
        #expect(model.board.guesses.isEmpty)
        #expect(model.suggestions.count > narrowed)
    }

    @Test("start over clears everything")
    func wordleStartOver() {
        let model = WordleModel()
        model.entry = "crane .g..y"
        model.submit()
        model.startOver()

        #expect(model.board.guesses.isEmpty)
        #expect(model.suggestions.isEmpty)
        #expect(model.error == nil)
    }

    @Test("Spelling Bee runs its search off the main thread and reports back")
    func spellingBeeSubmit() async throws {
        let model = SpellingBeeModel()
        model.entry = "n acdehl"
        model.submit()

        try await waitUntil { !model.isWorking && model.results != nil }
        #expect(model.results?.finds.count == 126)
        #expect(model.puzzle?.centerLetter == "n")
    }

    @Test("Letter Boxed finds a chain and reports back")
    func letterBoxedSubmit() async throws {
        let model = LetterBoxedModel()
        model.entry = "vgy hfp lta ceo"
        model.submit()

        try await waitUntil { !model.isWorking && model.searched }
        #expect(model.solution?.words.count == 3)
    }

    /// Polls until `condition` holds, so a test doesn't hang forever if it never does.
    private func waitUntil(
        timeout: Duration = .seconds(30),
        _ condition: () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("condition never became true within \(timeout)")
    }
}
