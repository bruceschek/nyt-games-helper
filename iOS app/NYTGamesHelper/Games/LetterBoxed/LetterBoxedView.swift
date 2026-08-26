import SwiftUI

@Observable
final class LetterBoxedModel {
    var entry = ""
    var error: PuzzleInputError?
    var solution: LetterBoxedSolution?
    var searched = false
    var isWorking = false

    private let parser = LetterBoxedInputParser()

    func submit() {
        switch parser.parse(entry) {
        case .failure(let problem):
            error = problem
        case .success(let puzzle):
            error = nil
            isWorking = true
            searched = false
            Task {
                let found = await Task.detached(priority: .userInitiated) {
                    LetterBoxedSolver.solve(puzzle)
                }.value
                solution = found
                searched = true
                isWorking = false
            }
        }
    }
}

struct LetterBoxedView: View {
    @State private var model = LetterBoxedModel()

    var body: some View {
        VStack(spacing: 12) {
            PuzzleEntryField(
                placeholder: LetterBoxedInputParser.placeholder,
                help: LetterBoxedInputParser.syntaxHelp,
                text: $model.entry,
                error: model.error,
                onSubmit: model.submit
            )

            if model.isWorking {
                Spacer()
                ProgressView("Chaining words…")
                Spacer()
            } else if let solution = model.solution {
                List {
                    Section("\(solution.words.count) words, \(solution.letterCount) letters") {
                        ForEach(Array(solution.words.enumerated()), id: \.offset) { index, word in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                                Text(word).font(.body.monospaced())
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else if model.searched {
                Spacer()
                ContentUnavailableView(
                    "No chain found",
                    systemImage: "square.dashed",
                    description: Text("Nothing in the dictionary links all twelve letters. Double-check which letters share a side.")
                )
                Spacer()
            } else {
                Spacer()
                EmptyStateView(
                    symbol: "square.dashed",
                    message: "Type the four sides of the box and I'll find the shortest chain that uses every letter."
                )
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationStack { LetterBoxedView().navigationTitle("Letter Boxed") }
}
