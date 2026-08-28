import Testing
@testable import NYTGamesHelper

/// Drives the view models the way the screens do — type, submit, read results —
/// so the wiring between entry field, parser and solver is covered without a UI.
@MainActor
@Suite("Game models")
struct GameModelTests {

    /// Builds a row the way the screen does: type, colorize, accept.
    private func play(_ model: WordleModel, _ word: String, _ marks: String) {
        model.draftText = word
        model.beginColorizing()
        for (index, character) in marks.enumerated() {
            // White is where every tile starts, so only yellow and green need taps.
            let taps = switch character {
            case "y": 1
            case "g": 2
            default:  0
            }
            for _ in 0..<taps { model.cycleMark(at: index) }
        }
        model.accept()
    }

    @Test("an accepted row narrows the suggestions and clears the draft")
    func wordleAcceptRow() {
        let model = WordleModel()
        play(model, "crane", ".g..y")

        #expect(model.board.guesses.count == 1)
        #expect(model.board.guesses[0].marks
                == [.notInWord, .rightSpot, .notInWord, .notInWord, .wrongSpot])
        #expect(model.draftText.isEmpty)
        #expect(model.phase == .typing)

        #expect(!model.suggestions.isEmpty)
        #expect(model.suggestions.count < WordLists.wordleAnswers.count)
        let constraints = model.board.constraints
        #expect(model.suggestions.allSatisfy { constraints.allows($0.word) })
    }

    @Test("tapping a tile cycles white, yellow, green and back")
    func wordleCycleWraps() {
        let model = WordleModel()
        model.draftText = "crane"
        model.beginColorizing()

        #expect(model.draftMarks[0] == .notInWord)
        model.cycleMark(at: 0)
        #expect(model.draftMarks[0] == .wrongSpot)
        model.cycleMark(at: 0)
        #expect(model.draftMarks[0] == .rightSpot)
        model.cycleMark(at: 0)
        #expect(model.draftMarks[0] == .notInWord)   // a wrong pick can be corrected
    }

    @Test("tiles only take colour once the row has been colorized")
    func wordleCycleNeedsColorizing() {
        let model = WordleModel()
        model.draftText = "crane"
        model.cycleMark(at: 0)
        #expect(model.draftMarks[0] == .notInWord)
    }

    @Test("letters are sanitised and capped at five")
    func wordleDraftSanitised() {
        let model = WordleModel()
        model.draftText = "CrAnE!!"
        #expect(model.draftText == "crane")

        model.draftText = "cranes"
        #expect(model.draftText == "crane")
    }

    @Test("a word Wordle wouldn't accept can't be colorized")
    func wordleRejectsIllegalGuess() {
        let model = WordleModel()
        model.draftText = "zzzzz"
        model.beginColorizing()

        #expect(model.phase == .typing)
        #expect(model.problem != nil)
    }

    @Test("changing the letters clears the colours already picked")
    func wordleEditClearsMarks() {
        let model = WordleModel()
        model.draftText = "crane"
        model.beginColorizing()
        model.cycleMark(at: 0)
        #expect(model.draftMarks[0] == .wrongSpot)

        model.editLetters()
        model.draftText = "crank"
        #expect(model.draftMarks.allSatisfy { $0 == .notInWord })
        #expect(model.phase == .typing)
    }

    @Test("going back to edit keeps the colours when the letters don't change")
    func wordleEditKeepsMarksWhenUnchanged() {
        let model = WordleModel()
        model.draftText = "crane"
        model.beginColorizing()
        model.cycleMark(at: 1)
        model.cycleMark(at: 1)

        model.editLetters()
        #expect(model.draftMarks[1] == .rightSpot)
    }

    @Test("the board stops after six guesses")
    func wordleStopsAtSix() {
        let model = WordleModel()
        for word in ["crane", "slime", "pudgy", "borax", "front", "witch"] {
            play(model, word, ".....")
        }
        #expect(model.board.guesses.count == 6)
        #expect(model.status == .outOfGuesses)
        #expect(!model.isAcceptingGuesses)
    }

    @Test("an all-green row ends the game early")
    func wordleStopsWhenSolved() {
        let model = WordleModel()
        play(model, "crane", "ggggg")

        #expect(model.status == .solved)
        #expect(!model.isAcceptingGuesses)
        #expect(model.suggestions.map(\.word) == ["crane"])
    }

    @Test("undo puts the last row back into the draft")
    func wordleUndo() {
        let model = WordleModel()
        play(model, "crane", ".g..y")
        let narrowed = model.suggestions.count

        model.undoLastRow()
        #expect(model.board.guesses.isEmpty)
        #expect(model.draftText == "crane")
        #expect(model.draftMarks[1] == .rightSpot)
        #expect(model.phase == .colorizing)
        #expect(model.suggestions.count > narrowed)
    }

    @Test("start over clears everything")
    func wordleStartOver() {
        let model = WordleModel()
        play(model, "crane", ".g..y")
        model.startOver()

        #expect(model.board.guesses.isEmpty)
        #expect(model.draftText.isEmpty)
        #expect(model.phase == .typing)
        #expect(model.suggestions.count == WordLists.wordleAnswers.count)
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
