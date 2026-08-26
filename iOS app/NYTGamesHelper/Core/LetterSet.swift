import Foundation

/// A set of distinct letters packed into the low 26 bits of an `Int`.
///
/// The solvers lean on this heavily — "does this word only use these letters",
/// "how many distinct letters do these words cover between them" — and as bit
/// arithmetic each of those is one instruction instead of a `Set` allocation.
struct LetterSet: Equatable, Hashable {
    private(set) var bits: Int

    init(bits: Int = 0) { self.bits = bits }

    init(_ letters: some Sequence<Character>) {
        bits = 0
        for letter in letters { insert(letter) }
    }

    static func bit(for letter: Character) -> Int {
        guard let ascii = letter.lowercased().first?.asciiValue,
              ascii >= 97, ascii <= 122
        else { return 0 }
        return 1 << Int(ascii - 97)
    }

    mutating func insert(_ letter: Character) { bits |= Self.bit(for: letter) }

    func contains(_ letter: Character) -> Bool { bits & Self.bit(for: letter) != 0 }
    func isSubset(of other: LetterSet) -> Bool { bits & ~other.bits == 0 }
    func union(_ other: LetterSet) -> LetterSet { LetterSet(bits: bits | other.bits) }
    func intersection(_ other: LetterSet) -> LetterSet { LetterSet(bits: bits & other.bits) }

    var count: Int { bits.nonzeroBitCount }
    var isEmpty: Bool { bits == 0 }

    var letters: [Character] {
        (0..<26).compactMap { index in
            bits & (1 << index) != 0
                ? Character(UnicodeScalar(UInt8(97 + index)))
                : nil
        }
    }
}
