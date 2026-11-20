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
    ///
    /// `fast` switches Vision to its quicker, rougher reader — a second opinion
    /// when the careful one gets a row wrong (see `WordleImageReader.read`).
    static func glyphs(in image: CGImage, fast: Bool = false) async throws -> [RecognizedGlyph] {
        let observations = try await observe(image, fast: fast)
        let size = CGSize(width: image.width, height: image.height)

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
                glyphs.append(RecognizedGlyph(letter: letter, frame: pixels(box.boundingBox.cgRect, in: size)))
            }
        }
        return glyphs
    }

    private static func observe(_ image: CGImage, fast: Bool) async throws -> [RecognizedTextObservation] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = fast ? .fast : .accurate
        // The puzzles are letters, not words — correction "fixes" them into words.
        request.usesLanguageCorrection = false
        return try await request.perform(on: image, orientation: .up)
    }

    /// Vision's normalised, bottom-left-origin box → image pixels, top-left origin.
    private static func pixels(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: rect.minX * size.width, y: (1 - rect.maxY) * size.height,
               width: rect.width * size.width, height: rect.height * size.height)
    }

    /// Cuts each rectangle out of `image`, lines the pieces up side by side and
    /// reads the row, returning one letter (or nil) per rectangle.
    ///
    /// Vision skips some lone capitals — an `I` in its own hexagon or tile
    /// especially — but reads the same letters reliably once they sit next to each
    /// other like a word.
    static func lettersInRow(from image: CGImage, cutting rects: [CGRect], fast: Bool = false) async throws -> [Character?] {
        guard let strip = row(from: image, cutting: rects) else { return rects.map { _ in nil } }

        // In reading order, as Vision returns them — not re-sorted by position.
        let read = try await glyphs(in: strip.image, fast: fast)

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

    /// The pieces laid side by side on white, each cleaned to black on white —
    /// separate from `lettersInRow` so a test can look at what Vision was shown.
    ///
    /// The cleaning matters: the pieces come off yellow and grey hexagons, and
    /// green, yellow, grey or near-black tiles with white letters, and Vision reads
    /// a uniform black-on-white row far more reliably than that patchwork.
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
        if let data = context.data {
            let bytes = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
            for index in rects.indices {
                clean(bytes, bytesPerRow: context.bytesPerRow,
                      x: Int(margin + CGFloat(index) * cellWidth), y: Int(margin),
                      width: Int(cellWidth), height: Int(cellHeight))
            }
        }
        guard let strip = context.makeImage() else { return nil }
        return (strip, margin, cellWidth)
    }

    /// Turns one piece black on white: its background is the average colour round
    /// its edge, and anything clearly different from that is letter.
    private static func clean(_ bytes: UnsafeMutablePointer<UInt8>, bytesPerRow: Int,
                              x: Int, y: Int, width: Int, height: Int) {
        guard width > 4, height > 4 else { return }
        let edge = max(1, min(width, height) / 12)
        var sum = [0.0, 0.0, 0.0], count = 0.0
        for row in y..<y + height {
            for column in x..<x + width {
                let onEdge = row < y + edge || row >= y + height - edge
                    || column < x + edge || column >= x + width - edge
                guard onEdge else { continue }
                let i = row * bytesPerRow + column * 4
                for channel in 0..<3 { sum[channel] += Double(bytes[i + channel]) }
                count += 1
            }
        }
        let background = sum.map { $0 / count }
        for row in y..<y + height {
            for column in x..<x + width {
                let i = row * bytesPerRow + column * 4
                let difference = (0..<3).map { abs(Double(bytes[i + $0]) - background[$0]) }.max()!
                let value: UInt8 = difference > 255 * 0.3 ? 0 : 255
                bytes[i] = value; bytes[i + 1] = value; bytes[i + 2] = value
            }
        }
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

/// A colour as three components in 0...1.
struct RGBColor: Equatable {
    var red: Double, green: Double, blue: Double

    /// Hue in degrees, 0..<360.
    var hue: Double {
        let high = max(red, green, blue), low = min(red, green, blue)
        guard high > low else { return 0 }
        let delta = high - low
        let h: Double = switch high {
        case red:   (green - blue) / delta
        case green: (blue - red) / delta + 2
        default:    (red - green) / delta + 4
        }
        return (h * 60 + 360).truncatingRemainder(dividingBy: 360)
    }

    var saturation: Double {
        let high = max(red, green, blue)
        return high == 0 ? 0 : (high - min(red, green, blue)) / high
    }

    var brightness: Double { max(red, green, blue) }

    /// From `0xRRGGBB` — how the NYT's colours are written down.
    init(hex: Int) {
        red = Double((hex >> 16) & 0xff) / 255
        green = Double((hex >> 8) & 0xff) / 255
        blue = Double(hex & 0xff) / 255
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red; self.green = green; self.blue = blue
    }
}

/// An image's pixels, held so colours can be sampled from it.
struct ImagePixels {
    let width: Int, height: Int
    private let bytes: [UInt8]

    init?(_ image: CGImage) {
        let width = image.width, height = image.height
        self.width = width
        self.height = height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        bytes = buffer
    }

    /// The average colour inside `rect` (pixels, top-left origin), or nil if the
    /// rectangle falls outside the image.
    func averageColor(in rect: CGRect) -> RGBColor? {
        let area = rect.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !area.isNull, area.width >= 1, area.height >= 1 else { return nil }
        var red = 0.0, green = 0.0, blue = 0.0, count = 0.0
        for y in Int(area.minY)..<Int(area.maxY) {
            for x in Int(area.minX)..<Int(area.maxX) {
                let i = (y * width + x) * 4
                red += Double(bytes[i]); green += Double(bytes[i + 1]); blue += Double(bytes[i + 2])
                count += 1
            }
        }
        return RGBColor(red: red / count / 255, green: green / count / 255, blue: blue / count / 255)
    }
}
