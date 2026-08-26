import SwiftUI

@Observable
final class WordleModel {
    var board = WordleBoard()
    var entry = ""
    var error: PuzzleInputError?
    var suggestions: [WordleSuggestion] = []

    private let parser = WordleInputParser()

    func submit() {
        switch parser.parse(entry) {
        case .failure(let problem):
            error = problem
        case .success(let guess):
            error = nil
            entry = ""
            board.guesses.append(guess)
            refresh()
        }
    }

    func remove(_ guess: Guess) {
        board.guesses.removeAll { $0 == guess }
        refresh()
    }

    func startOver() {
        board = WordleBoard()
        entry = ""
        error = nil
        suggestions = []
    }

    private func refresh() {
        suggestions = WordleSolver.suggestions(for: board)
    }
}

struct WordleView: View {
    @State private var model = WordleModel()

    var body: some View {
        VStack(spacing: 12) {
            PuzzleEntryField(
                placeholder: WordleInputParser.placeholder,
                help: WordleInputParser.syntaxHelp,
                text: $model.entry,
                error: model.error,
                onSubmit: model.submit
            )

            if model.board.guesses.isEmpty {
                Spacer()
                EmptyStateView(
                    symbol: "square.grid.3x3",
                    message: "Type a guess and how Wordle marked it, and I'll show what the answer can still be."
                )
                Spacer()
            } else {
                List {
                    Section("Your guesses") {
                        ForEach(model.board.guesses) { guess in
                            GuessRow(guess: guess)
                                .swipeActions {
                                    Button("Remove", role: .destructive) { model.remove(guess) }
                                }
                        }
                    }

                    Section(suggestionsHeader) {
                        if model.suggestions.isEmpty {
                            Text("No word fits all of that — check the marks above for a slip.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(model.suggestions.prefix(50)) { suggestion in
                            HStack {
                                Text(suggestion.word).font(.body.monospaced())
                                Spacer()
                                Text(suggestion.commonnessRank == nil ? "uncommon" : "#\(suggestion.commonnessRank!)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Start over", action: model.startOver)
                    .disabled(model.board.guesses.isEmpty)
            }
        }
    }

    private var suggestionsHeader: String {
        let count = model.suggestions.count
        switch count {
        case 0:  return "Still possible"
        case 1:  return "That's the answer"
        default: return "Still possible — \(count) words, most common first"
        }
    }
}

/// One played guess, coloured the way the game colours it.
struct GuessRow: View {
    let guess: Guess

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(guess.letters.enumerated()), id: \.offset) { index, letter in
                Text(String(letter).uppercased())
                    .font(.headline.monospaced())
                    .frame(width: 34, height: 34)
                    .background(background(for: guess.marks[index]), in: .rect(cornerRadius: 6))
                    .foregroundStyle(foreground(for: guess.marks[index]))
            }
        }
        .padding(.vertical, 2)
    }

    private func foreground(for mark: LetterMark) -> Color {
        mark == .notInWord ? .primary : .white
    }

    private func background(for mark: LetterMark) -> Color {
        switch mark {
        case .rightSpot: .green
        case .wrongSpot: .yellow
        case .notInWord: Color.secondary.opacity(0.2)
        }
    }
}

#Preview {
    NavigationStack { WordleView().navigationTitle("Wordle") }
}
