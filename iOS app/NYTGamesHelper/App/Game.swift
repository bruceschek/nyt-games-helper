import SwiftUI

/// The things this app can help with. Names and blurbs are what the user sees, so
/// they're written for a person rather than borrowed from the Python version.
enum Game: String, CaseIterable, Identifiable {
    case wordle
    case spellingBee
    case letterBoxed
    case openingWords

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wordle:       "Wordle"
        case .spellingBee:  "Spelling Bee"
        case .letterBoxed:  "Letter Boxed"
        case .openingWords: "Best Opening Words"
        }
    }

    var blurb: String {
        switch self {
        case .wordle:       "Narrow down what today's answer can still be."
        case .spellingBee:  "Every word in the hive, and what it's worth."
        case .letterBoxed:  "The shortest chain that uses all twelve letters."
        case .openingWords: "Four guesses that cover the most ground."
        }
    }

    var symbol: String {
        switch self {
        case .wordle:       "square.grid.3x3.fill"
        case .spellingBee:  "hexagon.fill"
        case .letterBoxed:  "square.dashed"
        case .openingWords: "star.fill"
        }
    }
}
