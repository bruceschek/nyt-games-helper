import CoreGraphics
import Vision

/// One letter found in a picture, and where it sits.
///
/// `frame` is in image pixels with the origin at the top left, so distances mean
/// the same thing horizontally and vertically — the game readers reason about
/// layout (which letter is in the middle of the hive, which side of the box a
/// letter is on), and normalised coordinates would squash that on a tall screenshot.
struct RecognizedGlyph: Equatable {
    let letter: Character
    let frame: CGRect

    var center: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
}

/// Reads every letter it can see in an image, one glyph per letter.
///
/// This is the only place the app touches Vision. Everything after it works on
/// plain `RecognizedGlyph` values, which is what lets the game readers be tested
/// with hand-placed letters instead of photos.
enum TextRecognizer {

    /// `image` must be upright — `PuzzlePhoto` sees to that — so that glyph frames
    /// line up with the pixels for `lettersInRow` to cut from.
    static func glyphs(in image: CGImage) async throws -> [RecognizedGlyph] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        // The puzzles are letters, not words — correction "fixes" them into words.
        request.usesLanguageCorrection = false

        let observations = try await request.perform(on: image)
        let upright = CGSize(width: image.width, height: image.height)

        var glyphs: [RecognizedGlyph] = []
        for observation in observations {
            guard let text = observation.topCandidates(1).first else { continue }
            let string = text.string
            // Vision groups letters on the same line into one observation — the two
            // hexagons either side of the hive's middle often come back as "L H" —
            // so split every observation into its characters and box each one.
            for index in string.indices {
                guard let letter = normalised(string[index]),
                      let box = text.boundingBox(for: index..<string.index(after: index))
                else { continue }
                let rect = box.boundingBox.cgRect
                glyphs.append(RecognizedGlyph(
                    letter: letter,
                    frame: CGRect(
                        x: rect.minX * upright.width,
                        y: (1 - rect.maxY) * upright.height,
                        width: rect.width * upright.width,
                        height: rect.height * upright.height
                    )
                ))
            }
        }
        return glyphs
    }

    /// Cuts each rectangle out of `image`, lines the pieces up side by side and
    /// reads the row, returning one letter (or nil) per rectangle.
    ///
    /// Vision skips some lone capitals — an `I` in its own hexagon especially — but
    /// reads the same letters reliably once they sit next to each other like a word.
    static func lettersInRow(from image: CGImage, cutting rects: [CGRect]) async throws -> [Character?] {
        guard let strip = row(from: image, cutting: rects) else { return rects.map { _ in nil } }

        // In reading order, as Vision returns them — not re-sorted by position.
        let read = try await glyphs(in: strip.image)

        // Vision reads the row as one word, and gets the letters right, but its
        // box for each single letter within a word is loose. So when it found
        // exactly one letter per piece, go by order; positions are the fallback.
        if read.count == rects.count { return read.map(\.letter) }

        var letters = [Character?](repeating: nil, count: rects.count)
        var heights = [CGFloat](repeating: 0, count: rects.count)
        for glyph in read {
            let index = Int(((glyph.center.x - strip.margin) / strip.cellWidth).rounded(.down))
            guard letters.indices.contains(index), glyph.frame.height > heights[index] else { continue }
            letters[index] = glyph.letter
            heights[index] = glyph.frame.height
        }
        return letters
    }

    /// The pieces laid side by side on white — separate from `lettersInRow` so a
    /// test can look at what Vision was shown.
    static func row(from image: CGImage, cutting rects: [CGRect]) -> (image: CGImage, margin: CGFloat, cellWidth: CGFloat)? {
        guard let tallest = rects.map(\.height).max(), tallest > 0,
              let widest = rects.map(\.width).max() else { return nil }
        // Small crops from a distant photo read better scaled up.
        let scale = max(1, 160 / tallest)
        let cellWidth = (widest * scale).rounded(.up)
        let cellHeight = (tallest * scale).rounded(.up)
        let margin = cellHeight / 2
        let width = Int(cellWidth * CGFloat(rects.count) + 2 * margin)
        let height = Int(cellHeight + 2 * margin)

        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        for (index, rect) in rects.enumerated() {
            guard let piece = image.cropping(to: rect.integral) else { continue }
            context.draw(piece, in: CGRect(x: margin + CGFloat(index) * cellWidth, y: margin,
                                           width: cellWidth, height: cellHeight))
        }
        guard let strip = context.makeImage() else { return nil }
        return (strip, margin, cellWidth)
    }

    /// Lower-cases a letter, and maps the digits and marks a lone capital is most
    /// often misread as back to the letter. Anything else that isn't a letter is
    /// dropped.
    static func normalised(_ character: Character) -> Character? {
        switch character {
        case "0": return "o"
        case "1", "|": return "i"
        default:
            guard character.isLetter, character.isASCII else { return nil }
            return Character(character.lowercased())
        }
    }
}
