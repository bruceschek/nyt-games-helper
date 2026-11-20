import CoreGraphics
import Testing
import UIKit
@testable import NYTGamesHelper

/// Lays out a hive the way the NYT draws it: a center letter and six around it,
/// clockwise from the top.
private func hive(
    center: Character, outer: [Character],
    at origin: CGPoint = CGPoint(x: 600, y: 1400),
    radius: CGFloat = 150, letterHeight: CGFloat = 60
) -> [RecognizedGlyph] {
    func glyph(_ letter: Character, _ point: CGPoint) -> RecognizedGlyph {
        RecognizedGlyph(letter: letter, frame: CGRect(
            x: point.x - letterHeight * 0.35, y: point.y - letterHeight / 2,
            width: letterHeight * 0.7, height: letterHeight))
    }
    var glyphs = [glyph(center, origin)]
    for (index, letter) in outer.enumerated() {
        // Flat-topped hexagons tile with neighbours at 30°, 90°, 150°… — but the
        // NYT hive has one straight above, so start at 0° (up) and step 60°.
        let theta = Double(index) * .pi / 3
        glyphs.append(glyph(letter, CGPoint(
            x: origin.x + radius * sin(theta),
            y: origin.y - radius * cos(theta))))
    }
    return glyphs
}

/// A line of text, e.g. found words or the word being typed.
private func row(_ text: String, y: CGFloat, height: CGFloat, x: CGFloat = 100) -> [RecognizedGlyph] {
    text.enumerated().map { index, letter in
        RecognizedGlyph(letter: letter, frame: CGRect(
            x: x + CGFloat(index) * height * 0.8, y: y, width: height * 0.7, height: height))
    }
}

@Suite("Spelling Bee from a picture")
struct SpellingBeeImageReaderTests {
    let reader = SpellingBeeImageReader()

    @Test("a bare hive reads center first, then clockwise from the top")
    func bareHive() throws {
        let puzzle = try reader.parse(hive(center: "n", outer: Array("acdehl"))).get()
        #expect(puzzle.centerLetter == "n")
        #expect(puzzle.outerLetters == Array("acdehl"))
    }

    @Test("small text elsewhere on the screen is ignored")
    func ignoresSmallText() throws {
        var glyphs = hive(center: "n", outer: Array("acdehl"))
        glyphs += row("youhavefoundwords", y: 300, height: 20)
        glyphs += row("handle", y: 400, height: 20)
        glyphs += row("enterdelete", y: 1800, height: 25)
        let puzzle = try reader.parse(glyphs.shuffled()).get()
        #expect(puzzle.centerLetter == "n")
        #expect(Set(puzzle.outerLetters) == Set("acdehl"))
    }

    @Test("a word being typed in the same big font doesn't fool it")
    func ignoresTypedWord() throws {
        var glyphs = hive(center: "n", outer: Array("acdehl"))
        glyphs += row("CHANNEL".lowercased(), y: 1000, height: 60, x: 300)
        let puzzle = try reader.parse(glyphs.shuffled()).get()
        #expect(puzzle.centerLetter == "n")
        #expect(Set(puzzle.outerLetters) == Set("acdehl"))
    }

    @Test("a photo taken at an angle still reads")
    func skewed() throws {
        // Squash vertically and shear, as a phone held below a laptop screen would.
        let glyphs = hive(center: "t", outer: Array("ironsu")).map { glyph in
            let c = glyph.center
            let moved = CGPoint(x: c.x + (c.y - 1400) * 0.15, y: 1400 + (c.y - 1400) * 0.8)
            return RecognizedGlyph(letter: glyph.letter, frame: CGRect(
                x: moved.x - glyph.frame.width / 2, y: moved.y - glyph.frame.height / 2,
                width: glyph.frame.width, height: glyph.frame.height))
        }
        let puzzle = try reader.parse(glyphs).get()
        #expect(puzzle.centerLetter == "t")
        #expect(Set(puzzle.outerLetters) == Set("ironsu"))
    }

    @Test("the hive is still placed when letters are missing — the center among them")
    func layoutWithGaps() throws {
        let full = hive(center: "i", outer: Array("acdehl"))
        // Lose the center and the top letter, as Vision does with a lone I.
        let glyphs = full.enumerated().filter { ![0, 1].contains($0.offset) }.map(\.element)
        let layout = try #require(HiveLayout.find(in: glyphs))
        #expect(layout.missing == [0, 1])
        #expect(layout.letters.compactMap { $0 } == Array("cdehl"))
        for (slot, glyph) in zip(layout.slots, full) {
            #expect(hypot(slot.x - glyph.center.x, slot.y - glyph.center.y) < 5)
        }
    }

    @Test("a missing letter is reported, not guessed")
    func tooFew() {
        let glyphs = Array(hive(center: "n", outer: Array("acdehl")).dropLast())
        #expect(throws: PuzzleInputError.self) { try reader.parse(glyphs).get() }
    }

    @Test("a misread duplicate is reported with what was read")
    func duplicate() throws {
        let result = reader.parse(hive(center: "n", outer: Array("acdehe")))
        guard case .failure(let problem) = result else {
            Issue.record("expected a failure"); return
        }
        #expect(problem.message.contains("N A C D E H E"))
    }

    @Test("no letters at all")
    func empty() {
        #expect(throws: PuzzleInputError.self) { try reader.parse([]).get() }
    }

    @Test("lone capitals Vision misreads as digits are mapped back")
    func normalisation() {
        #expect(TextRecognizer.normalised("0") == "o")
        #expect(TextRecognizer.normalised("1") == "i")
        #expect(TextRecognizer.normalised("Q") == "q")
        #expect(TextRecognizer.normalised("?") == nil)
    }
}

/// Draws a hive the way the game does — grey hexagons, a yellow one in the
/// middle, a bold capital in each — and runs it through Vision. Slower than the
/// tests above, but it's the only one that proves the real recogniser and the
/// reader agree on what a hive looks like.
@Suite("Spelling Bee from a rendered screenshot")
struct SpellingBeeRenderedTests {

    private func renderHive(center: Character, outer: [Character]) -> CGImage {
        let size = CGSize(width: 1179, height: 2556)   // iPhone 17 Pro screenshot
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let origin = CGPoint(x: size.width / 2, y: 1500)
            let side: CGFloat = 130
            let spacing = side * sqrt(3) * 1.05

            func hexagon(at point: CGPoint, color: UIColor, letter: Character) {
                let path = UIBezierPath()
                for corner in 0..<6 {
                    let theta = CGFloat(corner) * .pi / 3
                    let p = CGPoint(x: point.x + side * cos(theta), y: point.y + side * sin(theta))
                    corner == 0 ? path.move(to: p) : path.addLine(to: p)
                }
                path.close()
                color.setFill()
                path.fill()

                let text = String(letter).uppercased() as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 90, weight: .bold),
                    .foregroundColor: UIColor.black,
                ]
                let box = text.size(withAttributes: attributes)
                text.draw(at: CGPoint(x: point.x - box.width / 2, y: point.y - box.height / 2),
                          withAttributes: attributes)
            }

            hexagon(at: origin, color: UIColor(red: 0.97, green: 0.85, blue: 0.19, alpha: 1), letter: center)
            for (index, letter) in outer.enumerated() {
                let theta = CGFloat(index) * .pi / 3
                hexagon(at: CGPoint(x: origin.x + spacing * sin(theta),
                                    y: origin.y - spacing * cos(theta)),
                        color: UIColor(white: 0.9, alpha: 1), letter: letter)
            }

            // Some of the clutter a real screen has.
            let small: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 40)]
            ("You have found 3 words" as NSString).draw(at: CGPoint(x: 80, y: 400), withAttributes: small)
            ("Delete      Enter" as NSString).draw(at: CGPoint(x: 350, y: 2150), withAttributes: small)
        }
        return image.cgImage!
    }

    @Test("Vision plus the reader recover the puzzle", arguments: [
        ("n", "acdehl"),
        ("t", "ironsu"),
        ("w", "bilmoy"),
    ])
    func endToEnd(center: String, outer: String) async throws {
        let image = renderHive(center: Character(center), outer: Array(outer))
        let puzzle = try await SpellingBeeImageReader().read(PuzzlePhoto(image: image)).get()
        #expect(puzzle.centerLetter == Character(center))
        #expect(puzzle.outerLetters == Array(outer))
    }
}


