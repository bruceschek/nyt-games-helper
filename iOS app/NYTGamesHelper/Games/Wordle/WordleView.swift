import SwiftUI

/// The Wordle board.
///
/// The board is pinned and only the suggestions scroll, so the tiles and the
/// buttons stay reachable however many guesses are in.
///
/// Where there's width to spare — iPhone Duo unfolded, either way up — the board
/// and the suggestions sit side by side; otherwise the board goes on top. Either
/// way the tiles shrink to fit a short screen, such as the Duo's outer display
/// with the keyboard up.
struct WordleView: View {
    @State private var model = WordleModel()
    @FocusState private var keyboardFocused: Bool
    @Environment(\.horizontalSizeClass) private var widthClass

    var body: some View {
        Group {
            if widthClass == .regular {
                HStack(spacing: 0) {
                    fittedBoard
                        .frame(maxHeight: .infinity, alignment: .top)
                        .frame(width: 400)
                    Divider()
                    suggestions
                }
            } else {
                VStack(spacing: 0) {
                    // First call on the height, so the board takes its full size
                    // whenever it fits and the suggestions get what's left.
                    fittedBoard.layoutPriority(1)
                    Divider()
                    suggestions
                }
            }
        }
        // One field for the keyboard, outside the board: the board is built at
        // several sizes to find one that fits, and a field inside it would be
        // swapped for another — dropping the keyboard — whenever the size changed.
        .background(alignment: .topLeading) { hiddenField }
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button("Start over", action: model.startOver)
                    .disabled(model.board.guesses.isEmpty && model.draftText.isEmpty)
                Button { model.undoLastRow() } label: {
                    Label("Undo last row", systemImage: "arrow.uturn.backward")
                }
                .disabled(model.board.guesses.isEmpty)
            }
        }
        .onAppear { keyboardFocused = model.isAcceptingGuesses }
    }

    // MARK: - Board

    /// The board at the largest tile size that fits the height available.
    private var fittedBoard: some View {
        ViewThatFits(in: .vertical) {
            ForEach([52.0, 44, 36, 30], id: \.self) { size in
                board.environment(\.wordleTileSize, size)
            }
        }
    }

    private var board: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                ForEach(model.board.guesses) { guess in
                    LockedRow(guess: guess)
                }
                if model.isAcceptingGuesses {
                    draftRow
                }
                ForEach(0..<remainingRows, id: \.self) { _ in
                    PlaceholderRow()
                }
            }
            .padding(.top, 8)

            controls
        }
        .padding(.bottom, 12)
    }

    private var hiddenField: some View {
        // Invisible, but it's what the keyboard is actually attached to —
        // the tiles above are just a rendering of what it holds.
        TextField("", text: $model.draftText)
            .focused($keyboardFocused)
            // Never capitalise: the field is invisible, and letting it
            // upper-case the text would make every keystroke round-trip
            // through the binding as the model lower-cased it back, which
            // drops characters when typing quickly. The tiles do the
            // upper-casing for display.
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .submitLabel(.done)
            .onSubmit { model.beginColorizing() }
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
    }

    private var draftRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<WordleBoard.length, id: \.self) { index in
                WordleTile(
                    letter: model.draftLetters[index],
                    mark: model.phase == .colorizing ? model.draftMarks[index] : .notInWord,
                    isActive: true
                )
                .onTapGesture {
                    if model.phase == .colorizing {
                        model.cycleMark(at: index)
                    } else {
                        keyboardFocused = true
                    }
                }
            }
        }
    }

    /// Rows still to come, so the board doesn't jump about as guesses are added.
    private var remainingRows: Int {
        let used = model.board.guesses.count + (model.isAcceptingGuesses ? 1 : 0)
        return max(0, WordleModel.maxGuesses - used)
    }

    // MARK: - Buttons

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 6) {
            switch model.status {
            case .solved:
                Label("That's it — you've got it.", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
            case .outOfGuesses:
                Label("That's all six guesses.", systemImage: "flag.checkered")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            case .playing:
                HStack(spacing: 12) {
                    PhotoSourceButton(
                        isReading: model.isReadingPhoto,
                        onPhoto: { photo in
                            keyboardFocused = false
                            model.read(photo)
                        },
                        onProblem: model.report
                    ) {
                        Label("Read board", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(.bordered)

                    if model.phase == .typing {
                        Button("Colorize") {
                            keyboardFocused = false
                            model.beginColorizing()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.hasFullDraft)
                    } else {
                        Button("Edit letters") {
                            model.editLetters()
                            keyboardFocused = true
                        }
                        .buttonStyle(.bordered)

                        Button("Accept") {
                            model.accept()
                            keyboardFocused = model.isAcceptingGuesses
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Text(hint)
                    .font(.caption)
                    .foregroundStyle(model.problem == nil ? Color.secondary : Color.orange)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
                    .padding(.horizontal)
            }
        }
    }

    private var hint: String {
        if let problem = model.problem { return problem.message }
        switch model.phase {
        case .typing:
            return model.hasFullDraft
                ? "Now say how Wordle marked it."
                : "Type your guess — or read the whole board from a screenshot."
        case .colorizing:
            return "Tap a letter to cycle it: white → yellow → green."
        }
    }

    // MARK: - Suggestions

    private var suggestions: some View {
        List {
            Section(header) {
                if model.suggestions.isEmpty {
                    Text("No word fits all of that — check the colours above for a slip.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.suggestions.prefix(200)) { suggestion in
                    HStack {
                        Text(suggestion.word).font(.body.monospaced())
                        Spacer()
                        Text(suggestion.commonnessRank.map { "#\($0)" } ?? "uncommon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var header: String {
        switch model.suggestions.count {
        case 0:  "Still possible"
        case 1:  "That's the answer"
        default: "Still possible — \(model.suggestions.count) words, most common first"
        }
    }
}

#Preview {
    NavigationStack { WordleView().navigationTitle("Wordle") }
}
