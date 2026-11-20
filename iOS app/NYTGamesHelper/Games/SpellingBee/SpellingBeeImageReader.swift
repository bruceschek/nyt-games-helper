import CoreGraphics

/// Where the seven hexagons of a hive sit in a picture, and which letters have
/// been read from them so far.
///
/// Working out the shape first is what makes photo input reliable. Vision reads
/// a hive letter correctly whenever it reports one, but it silently skips some
/// lone capitals — `I` most of all. Five letters are enough to place all seven
/// hexagons, and then the ones still blank can be cut out and read again.
struct HiveLayout: Equatable {
    /// Index 0 is the center; 1–6 run clockwise from the top.
    let slots: [CGPoint]
    /// Distance from the center hexagon to each outer one.
    let spacing: CGFloat
    var letters: [Character?]

    var missing: [Int] { letters.indices.filter { letters[$0] == nil } }

    /// A box around a hexagon's letter: about one letter wide, so that the boxes
    /// laid side by side read as a word, and short enough to stay inside the hexagon.
    func cropRect(for slot: Int) -> CGRect {
        let width = spacing * 0.45, height = spacing * 0.6
        return CGRect(x: slots[slot].x - width / 2, y: slots[slot].y - height / 2, width: width, height: height)
    }

    /// How much smaller than the largest letter a hive letter may be. Vision's box
    /// for an `I` or a `W` differs a little from an `M`, but never by this much.
    static let sizeTolerance = 0.6

    /// How far off the ring a letter may sit, and how far off a 60° step it may
    /// point, and still count as on it — room for a photo taken at an angle.
    static let ringTolerance = 0.25
    static let angleTolerance = Double.pi / 12

    /// Where each hexagon is in a perfect hive one unit across, center first, then
    /// clockwise from the top.
    static let idealSlots: [CGPoint] = [.zero] + (0..<6).map { k in
        let theta = Double(k) * .pi / 3
        return CGPoint(x: sin(theta), y: -cos(theta))
    }

    /// Finds the hive among every letter read from a screen.
    ///
    /// A screen holds far more letters than the hive — words found so far, the word
    /// being typed, the rank, the buttons — so this goes by shape, not content:
    ///
    /// 1. The hive letters are the biggest text on screen; much smaller text is ignored.
    /// 2. The hive's middle is the point with the most big letters around it at one
    ///    distance, each in a different one of six directions 60° apart. Every big
    ///    letter is tried as that point, and so is the third corner of an
    ///    equilateral triangle on every pair — two neighbouring outer letters and
    ///    the center form one — which finds the middle even when the center letter
    ///    itself was missed. A word typed in the same big font fails the direction
    ///    test: seen from anywhere, its letters bunch into one or two directions.
    /// 3. The letters found are matched to their hexagons, and a stretch-and-skew
    ///    transform fitted from a perfect hive onto them places the hexagons that
    ///    are still blank — exact for a flat screen photographed at an angle.
    static func find(in glyphs: [RecognizedGlyph]) -> HiveLayout? {
        guard let tallest = glyphs.map(\.frame.height).max(), tallest > 0 else { return nil }
        let large = glyphs.filter { $0.frame.height >= tallest * sizeTolerance }
        guard large.count >= 3 else { return nil }

        var candidates = large.map(\.center)
        for i in large.indices {
            for j in large.indices where j > i {
                let a = large[i].center, b = large[j].center
                let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                let h = sqrt(3) / 2
                let offset = CGPoint(x: -(b.y - a.y) * h, y: (b.x - a.x) * h)
                candidates.append(CGPoint(x: mid.x + offset.x, y: mid.y + offset.y))
                candidates.append(CGPoint(x: mid.x - offset.x, y: mid.y - offset.y))
            }
        }

        // Neighbouring hexagons are well over a letter apart; letters in a word aren't.
        let minimumSpacing = tallest * 1.5

        var best: (center: CGPoint, matches: [(slot: Int, glyph: RecognizedGlyph)], score: Double)?
        for point in candidates {
            let distances = large.map { distance(point, $0.center) }
            for radius in distances where radius >= minimumSpacing {
                let onRing = large.indices
                    .filter { abs(distances[$0] - radius) <= radius * ringTolerance }
                    .map { large[$0] }
                guard onRing.count >= 3 else { continue }
                let matches = sixfold(onRing, around: point)
                guard matches.count >= 3 else { continue }
                let centerGlyph = large.indices
                    .filter { distances[$0] <= radius * 0.3 }
                    .min { distances[$0] < distances[$1] }
                    .map { large[$0] }
                // More hexagons filled wins; then a found center letter; then fit.
                let fit = matches.map { abs(distance(point, $0.glyph.center) - radius) / radius }.reduce(0, +)
                let score = Double(matches.count) * 10 + (centerGlyph != nil ? 5 : 0) - fit
                if score > best?.score ?? -.infinity {
                    best = (point, (centerGlyph.map { [(0, $0)] } ?? []) + matches, score)
                }
            }
        }
        guard let best else { return nil }

        // Fit the perfect hive onto what was found. Without a center letter, the
        // candidate point stands in for it.
        var pairs = best.matches.map { (idealSlots[$0.slot], $0.glyph.center) }
        if !best.matches.contains(where: { $0.slot == 0 }) { pairs.append((.zero, best.center)) }
        guard let transform = affineFit(pairs) else { return nil }

        let slots = idealSlots.map { $0.applying(transform) }
        let spacing = slots.dropFirst().map { distance(slots[0], $0) }.reduce(0, +) / 6

        var layout = HiveLayout(slots: slots, spacing: spacing, letters: Array(repeating: nil, count: 7))
        var claimed = [CGFloat](repeating: .infinity, count: 7)
        for glyph in large {
            let nearest = slots.indices.min { distance(slots[$0], glyph.center) < distance(slots[$1], glyph.center) }!
            let gap = distance(slots[nearest], glyph.center)
            if gap <= spacing * 0.35, gap < claimed[nearest] {
                layout.letters[nearest] = glyph.letter
                claimed[nearest] = gap
            }
        }
        return layout
    }

    /// The largest set of `letters` that sit in different directions from `center`,
    /// 60° apart give or take `angleTolerance`, each labelled with its outer hexagon
    /// (1 = straight up, then clockwise).
    private static func sixfold(_ letters: [RecognizedGlyph], around center: CGPoint) -> [(slot: Int, glyph: RecognizedGlyph)] {
        let angles = letters.map { angle(from: center, to: $0.center) }
        var best: [(slot: Int, glyph: RecognizedGlyph)] = []
        for reference in angles {
            var bySlot: [Int: (glyph: RecognizedGlyph, off: Double)] = [:]
            for (letter, theta) in zip(letters, angles) {
                let steps = (theta - reference) / (.pi / 3)
                let off = abs(steps - steps.rounded()) * .pi / 3
                guard off <= angleTolerance else { continue }
                let k = ((Int(steps.rounded()) % 6) + 6) % 6
                if off < bySlot[k]?.off ?? .infinity { bySlot[k] = (letter, off) }
            }
            guard bySlot.count > best.count else { continue }
            // Number each hexagon by its own direction: 1 is straight up (the NYT
            // draws one there; a tilted photo moves it less than 30°), then clockwise.
            best = bySlot.map { k, entry in
                let theta = remainder(reference + Double(k) * .pi / 3, 2 * .pi)
                let step = Int((theta / (.pi / 3)).rounded())
                return ((step % 6 + 6) % 6 + 1, entry.glyph)
            }
        }
        return best
    }

    /// The least-squares affine map taking each `from` point onto its `to` point,
    /// or nil if the points are too few or all in a line.
    private static func affineFit(_ pairs: [(from: CGPoint, to: CGPoint)]) -> CGAffineTransform? {
        guard pairs.count >= 3 else { return nil }
        // Normal equations: [Σxx Σxy Σx; Σxy Σyy Σy; Σx Σy n] · coefficients = rhs.
        var m = [[Double]](repeating: [0, 0, 0], count: 3)
        var rx = [Double](repeating: 0, count: 3), ry = rx
        for (from, to) in pairs {
            let v = [from.x, from.y, 1.0]
            for i in 0..<3 {
                for j in 0..<3 { m[i][j] += v[i] * v[j] }
                rx[i] += v[i] * to.x
                ry[i] += v[i] * to.y
            }
        }
        func solve(_ r: [Double]) -> [Double]? {
            let det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
                    - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
                    + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
            guard abs(det) > 1e-9 else { return nil }
            return (0..<3).map { col in
                var c = m
                for row in 0..<3 { c[row][col] = r[row] }
                let d = c[0][0] * (c[1][1] * c[2][2] - c[1][2] * c[2][1])
                      - c[0][1] * (c[1][0] * c[2][2] - c[1][2] * c[2][0])
                      + c[0][2] * (c[1][0] * c[2][1] - c[1][1] * c[2][0])
                return d / det
            }
        }
        guard let x = solve(rx), let y = solve(ry) else { return nil }
        return CGAffineTransform(a: x[0], b: y[0], c: x[1], d: y[1], tx: x[2], ty: y[2])
    }

    /// The puzzle, once all seven letters are known.
    func puzzle() -> Result<SpellingBeePuzzle, PuzzleInputError> {
        let found = letters.compactMap { $0 }
        guard found.count == 7 else {
            return .failure(PuzzleInputError("I could only make out \(found.count) of the hive's 7 letters. Try a sharper picture, or type them in."))
        }
        guard Set(found).count == 7 else {
            let read = found.map { String($0).uppercased() }.joined(separator: " ")
            return .failure(PuzzleInputError("I read \(read), but a hive has 7 different letters, so one must be misread. Fix it in the box above."))
        }
        return .success(SpellingBeePuzzle(centerLetter: found[0], outerLetters: Array(found.dropFirst())))
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Clockwise from straight up. Image y grows downward.
    private static func angle(from center: CGPoint, to point: CGPoint) -> Double {
        atan2(point.x - center.x, -(point.y - center.y))
    }
}

/// Reads today's hive from a screenshot or photo.
///
/// The second implementation of `PuzzleInputSource` for Spelling Bee, alongside
/// the typed-text parser, producing the same `SpellingBeePuzzle`. `parse` is the
/// pure half — letters already read, laid out into a hive — and is what the tests
/// drive. `read` adds the Vision passes in front of it.
struct SpellingBeeImageReader: PuzzleInputSource {
    typealias Puzzle = SpellingBeePuzzle
    typealias Description = [RecognizedGlyph]

    func parse(_ glyphs: [RecognizedGlyph]) -> Result<SpellingBeePuzzle, PuzzleInputError> {
        guard let layout = HiveLayout.find(in: glyphs) else { return .failure(Self.noHive(glyphs)) }
        return layout.puzzle()
    }

    func read(_ photo: PuzzlePhoto) async throws -> Result<SpellingBeePuzzle, PuzzleInputError> {
        let glyphs = try await TextRecognizer.glyphs(in: photo.image)
        guard var layout = HiveLayout.find(in: glyphs) else { return .failure(Self.noHive(glyphs)) }

        // Read all seven as a row even when one is missing: a lone "I" cut out on
        // its own is no easier for Vision than it was in its hexagon.
        if !layout.missing.isEmpty {
            let row = try await TextRecognizer.lettersInRow(
                from: photo.image, cutting: layout.slots.indices.map(layout.cropRect(for:)))
            for slot in layout.missing { layout.letters[slot] = row[slot] }
        }
        return layout.puzzle()
    }

    private static func noHive(_ glyphs: [RecognizedGlyph]) -> PuzzleInputError {
        glyphs.isEmpty
            ? PuzzleInputError("I couldn't find any letters in that picture. Try a screenshot with the hive in view.")
            : PuzzleInputError("I found letters but couldn't pick out the hive's shape. Try a picture with the whole hive in view, or type the letters in.")
    }
}
