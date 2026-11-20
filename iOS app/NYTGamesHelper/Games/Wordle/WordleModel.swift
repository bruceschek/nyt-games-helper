import Foundation

/// Drives the Wordle board: one row being built, the rows already locked in, and
/// what the answer can still be.
///
/// A row is built in two steps. First its letters are typed, then `beginColorizing`
/// switches the row over to accepting taps that cycle each tile's colour. `accept`
/// locks the finished row into the `WordleBoard` and starts a fresh one.
@Observable
final class WordleModel {

    /// What the row currently being built is accepting.
    enum Phase {
        /// Letters are being typed; the tiles are blank.
        case typing
        /// Letters are settled; tapping a tile cycles its colour.
        case colorizing
    }

    enum Status {
        case playing
        case solved
        case outOfGuesses
    }

    /// Wordle gives you six.
    static let maxGuesses = 6

    private(set) var board = WordleBoard()
    private(set) var suggestions: [WordleSuggestion] = []

    /// The letters typed into the row being built. Sanitised on the way in, so it
    /// only ever holds up to five lowercase letters.
    var draftText: String = "" {
        didSet {
            let cleaned = String(draftText.lowercased().filter(\.isLetter).prefix(WordleBoard.length))
            if cleaned != draftText {
                draftText = cleaned
                return
            }
            // Changing the letters invalidates any colours already picked.
            if cleaned != oldValue {
                draftMarks = Self.blankMarks
                problem = nil
                phase = .typing
            }
        }
    }

    private(set) var draftMarks = WordleModel.blankMarks
    private(set) var phase = Phase.typing
    private(set) var problem: PuzzleInputError?
    private(set) var isReadingPhoto = false

    private let imageReader = WordleImageReader()

    private static var blankMarks: [LetterMark] {
        Array(repeating: .notInWord, count: WordleBoard.length)
    }

    init() {
        suggestions = WordleSolver.suggestions(for: board)
    }

    // MARK: - Where the game stands

    var status: Status {
        if board.isSolved { return .solved }
        if board.guesses.count >= Self.maxGuesses { return .outOfGuesses }
        return .playing
    }

    /// Whether there's still a row to fill in.
    var isAcceptingGuesses: Bool { status == .playing }

    var hasFullDraft: Bool { draftText.count == WordleBoard.length }

    var draftLetters: [Character?] {
        let typed = Array(draftText)
        return (0..<WordleBoard.length).map { $0 < typed.count ? typed[$0] : nil }
    }

    // MARK: - Building a row

    /// Settles the letters and switches the row over to accepting colour taps.
    func beginColorizing() {
        guard hasFullDraft else { return }
        guard WordLists.legalWordleGuesses.contains(draftText) else {
            problem = PuzzleInputError("Wordle doesn't accept `\(draftText)` as a guess.")
            return
        }
        problem = nil
        phase = .colorizing
    }

    /// Back to the keyboard to fix a letter. Colours picked so far are kept unless
    /// the letters actually change.
    func editLetters() {
        phase = .typing
    }

    /// White → yellow → green → white, so a wrong pick can be corrected by carrying
    /// on round rather than starting the row again.
    func cycleMark(at index: Int) {
        guard phase == .colorizing, draftMarks.indices.contains(index) else { return }
        draftMarks[index] = switch draftMarks[index] {
        case .notInWord: .wrongSpot
        case .wrongSpot: .rightSpot
        case .rightSpot: .notInWord
        }
    }

    /// Locks the row in and starts a new one.
    func accept() {
        guard phase == .colorizing, hasFullDraft else { return }
        board.guesses.append(Guess(word: draftText, marks: draftMarks))
        resetDraft()
        refresh()
    }

    // MARK: - Going back

    /// Removes the last locked row and puts it back into the draft, so a mistake in
    /// an accepted row can be fixed without starting over.
    func undoLastRow() {
        guard let last = board.guesses.popLast() else { return }
        draftText = last.word
        draftMarks = last.marks
        phase = .colorizing
        problem = nil
        refresh()
    }

    // MARK: - From a picture

    /// Reads every row played so far from a picture of the game and puts the board
    /// in their place. Meant to be repeated after each guess: each new picture
    /// replaces the board rather than adding to it, so one taken too early, or
    /// misread, is put right by the next.
    func read(_ photo: PuzzlePhoto) {
        isReadingPhoto = true
        Task {
            defer { isReadingPhoto = false }
            do {
                show(try await imageReader.read(photo))
            } catch {
                problem = PuzzleInputError("Something went wrong reading that picture. Try again.")
            }
        }
    }

    /// The same as `read(_:)` for a screen already pulled apart — what tests drive.
    func read(_ screen: WordleScreen) {
        show(imageReader.parse(screen))
    }

    /// For a problem found before there was a picture to read, such as no access to Photos.
    func report(_ problem: PuzzleInputError) {
        self.problem = problem
    }

    private func show(_ result: Result<WordleBoard, PuzzleInputError>) {
        switch result {
        case .success(let read):
            replaceBoard(with: read)
        case .failure(let reason):
            problem = reason
        }
    }

    /// Swaps the whole board for `newBoard`, dropping any row half-built by hand.
    func replaceBoard(with newBoard: WordleBoard) {
        board = newBoard
        resetDraft()
        refresh()
    }

    func startOver() {
        board = WordleBoard()
        resetDraft()
        refresh()
    }

    // MARK: -

    private func resetDraft() {
        draftText = ""
        draftMarks = Self.blankMarks
        phase = .typing
        problem = nil
    }

    private func refresh() {
        suggestions = WordleSolver.suggestions(for: board)
    }
}
