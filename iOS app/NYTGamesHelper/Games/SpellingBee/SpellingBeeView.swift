import SwiftUI

@Observable
final class SpellingBeeModel {
    var entry = ""
    var error: PuzzleInputError?
    var puzzle: SpellingBeePuzzle?
    var results: SpellingBeeResults?
    var isWorking = false
    var isReadingPhoto = false

    private let parser = SpellingBeeInputParser()
    private let imageReader = SpellingBeeImageReader()

    /// Reads the hive from a picture, writes what it found into the entry field —
    /// so a misread letter can be fixed by typing — and solves it.
    func read(_ photo: PuzzlePhoto) {
        isReadingPhoto = true
        Task {
            defer { isReadingPhoto = false }
            do {
                show(try await imageReader.read(photo))
            } catch {
                self.error = PuzzleInputError("Something went wrong reading that picture. Try again, or type the letters in.")
            }
        }
    }

    /// The same as `read(_:)` for letters already pulled from a picture — what
    /// the tests drive.
    func read(_ glyphs: [RecognizedGlyph]) {
        show(imageReader.parse(glyphs))
    }

    private func show(_ result: Result<SpellingBeePuzzle, PuzzleInputError>) {
        switch result {
        case .failure(let problem):
            error = problem
        case .success(let puzzle):
            entry = "\(puzzle.centerLetter) \(String(puzzle.outerLetters))"
            submit()
        }
    }

    func submit() {
        switch parser.parse(entry) {
        case .failure(let problem):
            error = problem
        case .success(let parsed):
            error = nil
            puzzle = parsed
            isWorking = true
            Task {
                let found = await Task.detached(priority: .userInitiated) {
                    SpellingBeeSolver.solve(parsed)
                }.value
                results = found
                isWorking = false
            }
        }
    }
}

struct SpellingBeeView: View {
    @State private var model = SpellingBeeModel()

    var body: some View {
        VStack(spacing: 12) {
            PuzzleEntryField(
                placeholder: SpellingBeeInputParser.placeholder,
                help: SpellingBeeInputParser.syntaxHelp,
                text: $model.entry,
                error: model.error,
                onPhoto: model.read,
                isReadingPhoto: model.isReadingPhoto,
                onSubmit: model.submit
            )

            if model.isWorking {
                Spacer()
                ProgressView("Searching the dictionary…")
                Spacer()
            } else if let results = model.results, let puzzle = model.puzzle {
                List {
                    Section {
                        LabeledContent("Words", value: "\(results.finds.count)")
                        LabeledContent("Points available", value: "\(results.totalScore)")
                        LabeledContent("Pangrams", value: "\(results.finds.count { $0.isPangram })")
                    } header: {
                        Text("\(String(puzzle.centerLetter).uppercased()) · \(puzzle.outerLetters.map { String($0).uppercased() }.joined(separator: " "))")
                    }

                    ForEach(results.byFirstLetter, id: \.letter) { group in
                        Section(String(group.letter).uppercased()) {
                            ForEach(group.finds) { find in
                                HStack {
                                    Text(find.word)
                                    if find.isPangram {
                                        Text("PANGRAM")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(.yellow, in: .capsule)
                                            .foregroundStyle(.black)
                                    }
                                    Spacer()
                                    Text("\(find.score)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                Spacer()
                EmptyStateView(
                    symbol: "hexagon",
                    message: "Type today's seven letters — center letter first — or tap the camera to read them from a screenshot, and I'll find every word in the hive."
                )
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationStack { SpellingBeeView().navigationTitle("Spelling Bee") }
}
