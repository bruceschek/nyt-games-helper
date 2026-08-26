import SwiftUI

/// A static reference, not a search.
///
/// These four-word sets were worked out once against Wordle's fixed answer list and
/// shipped with the app — see `OpeningWords`.
struct OpeningWordsView: View {
    private let reference = OpeningWords.reference

    var body: some View {
        if let reference {
            List {
                Section {
                    Text("""
                        Four opening guesses, played in this order. Between them they cover \
                        \(reference.minUniqueLetters) different letters including every vowel, \
                        and they're scored against all \(reference.answerPoolSize) words Wordle \
                        can pick as an answer.
                        """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                ForEach(Array(reference.sets.enumerated()), id: \.element.id) { index, set in
                    Section {
                        ForEach(Array(set.words.enumerated()), id: \.offset) { position, word in
                            HStack {
                                Text("\(position + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                                Text(word).font(.body.monospaced())
                                Spacer()
                                if position < set.expectedRemaining.count {
                                    Text("~\(set.expectedRemaining[position], specifier: "%.0f") left")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text(index == 0 ? "Best set" : "Alternative \(index)")
                    } footer: {
                        Text("Score \(set.score, specifier: "%.2f") · \(set.distinctLetters) letters")
                    }
                }
            }
            .listStyle(.insetGrouped)
        } else {
            ContentUnavailableView(
                "Opening words unavailable",
                systemImage: "star.slash",
                description: Text("openers.json didn't load. Regenerate it with `uv run export_openers.py` in the Python project.")
            )
        }
    }
}

#Preview {
    NavigationStack { OpeningWordsView().navigationTitle("Best Opening Words") }
}
