import SwiftUI

/// The app shell: one game on screen at a time, switched from the menu in the top
/// corner of the navigation bar.
struct RootView: View {
    @State private var game: Game = .wordle

    var body: some View {
        NavigationStack {
            Group {
                switch game {
                case .wordle:       WordleView()
                case .spellingBee:  SpellingBeeView()
                case .letterBoxed:  LetterBoxedView()
                case .openingWords: OpeningWordsView()
                }
            }
            .navigationTitle(game.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Game", selection: $game) {
                            ForEach(Game.allCases) { option in
                                Label(option.title, systemImage: option.symbol).tag(option)
                            }
                        }
                    } label: {
                        Label("Choose a game", systemImage: "square.grid.2x2")
                    }
                }
            }
        }
    }
}

#Preview {
    RootView()
}
