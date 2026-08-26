import Foundation

/// Why a typed description of a puzzle couldn't be understood.
///
/// Deliberately a value with a human sentence in it, not a thrown string: the UI
/// renders `message` directly under the text field, and a future photo-based input
/// path will produce the same errors from a bad scan.
struct PuzzleInputError: Error, Equatable {
    let message: String

    init(_ message: String) { self.message = message }
}

/// Turns some description of a puzzle into the puzzle itself.
///
/// Today the only conforming types are text parsers, driven by what the user types.
/// The long-term plan is to read the puzzle from a photo of the screen it's being
/// played on; that becomes another conformance producing the same `Puzzle` value,
/// and nothing downstream — solver, view model, or view — has to change. This is
/// the seam that keeps that promise, so keep raw text on this side of it.
protocol PuzzleInputSource {
    associatedtype Puzzle
    associatedtype Description

    func parse(_ description: Description) -> Result<Puzzle, PuzzleInputError>
}

/// A parser driven by a line the user typed.
protocol TextPuzzleParser: PuzzleInputSource where Description == String {
    /// Shown under the field as a hint, and in the game's help.
    static var placeholder: String { get }
    static var syntaxHelp: String { get }
}
