import SwiftUI

/// The shared way of describing a puzzle: a text field, a hint, and somewhere for a
/// parse error to land.
///
/// Every game screen enters its puzzle through this. A game that can read its
/// puzzle from a picture passes `onPhoto`, and the field grows a camera button
/// offering a screenshot or a fresh photo; the game decides what to do with it.
struct PuzzleEntryField: View {
    let placeholder: String
    let help: String
    @Binding var text: String
    var error: PuzzleInputError?
    var onPhoto: ((PuzzlePhoto) -> Void)? = nil
    var onPhotoProblem: ((PuzzleInputError) -> Void)? = nil
    var isReadingPhoto = false
    let onSubmit: () -> Void

    @State private var showingHelp = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onSubmit(onSubmit)
                    .submitLabel(.go)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))

                if let onPhoto {
                    PhotoSourceButton(isReading: isReadingPhoto, onPhoto: onPhoto, onProblem: { onPhotoProblem?($0) }) {
                        Image(systemName: "camera.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Read the puzzle from a picture")
                }

                Button("Go", action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let error {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    Text(error.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button { showingHelp = true } label: {
                    Label("How to type this", systemImage: "questionmark.circle")
                        .font(.footnote)
                        .labelStyle(.iconOnly)
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingHelp) {
            NavigationStack {
                ScrollView {
                    Text(help)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle("How to type this")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingHelp = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

/// Shown before a puzzle has been entered.
struct EmptyStateView: View {
    let symbol: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Nothing yet", systemImage: symbol)
        } description: {
            Text(message)
        }
    }
}
