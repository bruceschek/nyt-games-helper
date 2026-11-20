import SwiftUI

/// One letter box.
///
/// A blank or uncoloured tile is drawn as an outlined white box, which is what the
/// player sees before they've said anything about the letter.
struct WordleTile: View {
    let letter: Character?
    let mark: LetterMark
    /// Draws the outline heavier, to show which row is being worked on.
    var isActive = false

    @Environment(\.wordleTileSize) private var size

    var body: some View {
        Text(letter.map { String($0).uppercased() } ?? " ")
            .font(.system(size: size * 0.54, weight: .bold, design: .rounded))
            .foregroundStyle(mark == .notInWord ? Color.primary : .white)
            .frame(width: size, height: size)
            .background(fill, in: .rect(cornerRadius: size * 0.15))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.15)
                    .strokeBorder(border, lineWidth: isActive ? 2 : 1)
            }
    }

    private var fill: Color {
        switch mark {
        case .rightSpot: .green
        case .wrongSpot: .yellow
        case .notInWord: Color(.systemBackground)
        }
    }

    private var border: Color {
        mark == .notInWord ? Color.secondary.opacity(isActive ? 0.7 : 0.35) : .clear
    }
}

extension EnvironmentValues {
    /// The side of one tile. The board picks the largest size that fits the space
    /// it has — the Duo's outer screen with the keyboard up is far shorter than
    /// its inner one.
    @Entry var wordleTileSize: CGFloat = 52
}

/// A row that's already been locked in.
struct LockedRow: View {
    let guess: Guess

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(guess.letters.enumerated()), id: \.offset) { index, letter in
                WordleTile(letter: letter, mark: guess.marks[index])
            }
        }
    }
}

/// An empty placeholder row, so the board keeps its full height from the start.
struct PlaceholderRow: View {
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<WordleBoard.length, id: \.self) { _ in
                WordleTile(letter: nil, mark: .notInWord)
                    .opacity(0.4)
            }
        }
    }
}

#Preview {
    VStack(spacing: 6) {
        LockedRow(guess: Guess(word: "crane", marks: [.notInWord, .rightSpot, .notInWord, .notInWord, .wrongSpot]))
        PlaceholderRow()
    }
}
