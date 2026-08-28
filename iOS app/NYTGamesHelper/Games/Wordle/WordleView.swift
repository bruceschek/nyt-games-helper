import SwiftUI

/// The Wordle board.
///
/// The board is pinned at the top and only the suggestions scroll, so the tiles and
/// the buttons stay reachable however many guesses are in.
struct WordleView: View {
    @State private var model = WordleModel()
    @FocusState private var keyboardFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            board
            Divider()
            suggestions
        }
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

    private var board: some View {
        VStack(spacing: 12) {
            ZStack {
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
            }
            .padding(.top, 8)

            controls
        }
        .padding(.bottom, 12)
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
                : "Type your guess."
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
