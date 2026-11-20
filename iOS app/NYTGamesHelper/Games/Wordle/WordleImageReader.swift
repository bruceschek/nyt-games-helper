import CoreGraphics

/// Where the board's tiles are in a picture: the center of the top-left tile and
/// the step from one tile to the next, which is the same across and down.
struct WordleGrid: Equatable {
    static let rows = 6

    let origin: CGPoint
    let pitch: CGFloat

    func center(row: Int, column: Int) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(column) * pitch, y: origin.y + CGFloat(row) * pitch)
    }

    /// A box round the tile's letter — what gets cut out to be read. About one
    /// letter wide: cut-outs a whole tile wide leave gaps between the letters so
    /// big that Vision no longer reads the row as a word (`IDIOM` came back `WOIGI`).
    func letterRect(row: Int, column: Int) -> CGRect {
        let c = center(row: row, column: column)
        let width = pitch * 0.5, height = pitch * 0.6
        return CGRect(x: c.x - width / 2, y: c.y - height / 2, width: width, height: height)
    }

    /// A strip across the top of the tile, inside its border and above its letter,
    /// where only the tile's own colour shows.
    func colorRect(row: Int, column: Int) -> CGRect {
        let c = center(row: row, column: column)
        return CGRect(x: c.x - pitch * 0.2, y: c.y - pitch * 0.37, width: pitch * 0.4, height: pitch * 0.08)
    }

    /// Finds the board from the letters Vision read on it.
    ///
    /// Vision reads Wordle's tiles one letter at a time — they're too far apart to
    /// read as words — and skips plenty of them (an `I` or an `O` on its own, white
    /// letters on coloured tiles). That's fine: a few letters are enough to place
    /// the grid, because the tiles are evenly spaced.
    ///
    /// 1. Keep the biggest letters; most of the on-screen keyboard's are smaller.
    /// 2. The tile step is the gap between letters (across or down) that the most
    ///    other gaps are whole multiples of.
    /// 3. The board's letters all sit at the same point within a step; the largest
    ///    group that agrees is the board, and stray letters — title, keyboard —
    ///    fall out. The top row is the highest with at least two of them.
    ///
    /// 4. Letters alone can leave the board's edge in doubt — three letters in the
    ///    middle columns fit more than one placement. `colorIn`, when given, settles
    ///    it: played tiles are coloured and the page around the board isn't, so the
    ///    placement covering the most coloured tiles wins, and a top row whose
    ///    letters were all missed is still found by its colour.
    static func find(in glyphs: [RecognizedGlyph], colorIn: ((CGRect) -> RGBColor?)? = nil) -> WordleGrid? {
        guard let tallest = glyphs.map(\.frame.height).max(), tallest > 0 else { return nil }
        let large = glyphs.filter { $0.frame.height >= tallest * 0.75 }
        guard large.count >= 2 else { return nil }

        // Gaps across (same line) and down (same column), each well over a letter.
        let minimumGap = tallest * 1.2
        var gaps: [CGFloat] = []
        for a in large {
            for b in large where b.center.x > a.center.x || b.center.y > a.center.y {
                let dx = b.center.x - a.center.x, dy = b.center.y - a.center.y
                if abs(dy) < tallest * 0.35, dx > minimumGap { gaps.append(dx) }
                if abs(dx) < tallest * 0.35, dy > minimumGap { gaps.append(dy) }
            }
        }
        guard !gaps.isEmpty else { return nil }

        // The tile step is the gap that the most other gaps are whole multiples of.
        // Stray letters — the title's, the keyboard's — make gaps that fit nothing.
        func multiples(of step: CGFloat) -> [CGFloat] {
            gaps.compactMap { gap in
                let k = (gap / step).rounded()
                guard k >= 1, k <= 5, abs(gap / k - step) < step * 0.05 else { return nil }
                return gap / k
            }
        }
        let best = gaps.max { a, b in
            let (ma, mb) = (multiples(of: a).count, multiples(of: b).count)
            return ma == mb ? a < b : ma < mb
        }!
        let fitted = multiples(of: best)
        let pitch = fitted.reduce(0, +) / CGFloat(fitted.count)

        // The board's letters all sit at the same place within a step, across and
        // down. Find the biggest group that agrees, and go by that alone.
        func offset(_ value: CGFloat, from reference: CGFloat) -> CGFloat {
            let d = (value - reference) / pitch
            return abs(d - d.rounded())
        }
        let aligned = large.map { reference in
            large.filter {
                offset($0.center.x, from: reference.center.x) < 0.15
                    && offset($0.center.y, from: reference.center.y) < 0.15
            }
        }.max { $0.count < $1.count }!
        guard aligned.count >= 2 else { return nil }

        func phase(_ values: [CGFloat]) -> CGFloat {
            let angles = values.map { 2 * .pi * $0 / pitch }
            let mean = atan2(angles.map(sin).reduce(0, +), angles.map(cos).reduce(0, +))
            return mean / (2 * .pi) * pitch
        }
        let phaseX = phase(aligned.map(\.center.x)), phaseY = phase(aligned.map(\.center.y))

        let onGrid = aligned.map { glyph in
            (row: Int(((glyph.center.y - phaseY) / pitch).rounded()),
             column: Int(((glyph.center.x - phaseX) / pitch).rounded()))
        }

        let rowCounts = Dictionary(grouping: onGrid, by: \.row).mapValues(\.count)
        guard var topRow = rowCounts.filter({ $0.value >= 2 }).keys.min() else { return nil }
        let columns = onGrid.filter { $0.row >= topRow && $0.row < topRow + rows }.map(\.column)
        guard let lowest = columns.min(), let highest = columns.max(),
              highest - lowest < WordleBoard.length else { return nil }

        func grid(row: Int, column: Int) -> WordleGrid {
            WordleGrid(origin: CGPoint(x: phaseX + CGFloat(column) * pitch, y: phaseY + CGFloat(row) * pitch),
                       pitch: pitch)
        }
        // Every placement of five columns that covers all the letters found.
        let placements = Array((highest - (WordleBoard.length - 1))...lowest)
        let middle = CGFloat(lowest + highest) / 2

        guard let colorIn else {
            let first = placements.min { abs(CGFloat($0) + 2 - middle) < abs(CGFloat($1) + 2 - middle) }!
            return grid(row: topRow, column: first)
        }

        func played(_ candidate: WordleGrid, row: Int, column: Int) -> Bool {
            guard let color = colorIn(candidate.colorRect(row: row, column: column)),
                  case .played = WordleImageReader.reading(of: color) else { return false }
            return true
        }
        // The top row's letters may all have been missed; its colour still shows.
        for _ in 0..<rows where phaseY + CGFloat(topRow - 1) * pitch > 0 {
            let above = grid(row: topRow - 1, column: placements[0])
            let coloured = (-1...WordleBoard.length).count { played(above, row: 0, column: $0) }
            guard coloured >= 3 else { break }
            topRow -= 1
        }
        let first = placements.max { a, b in
            func score(_ column: Int) -> (Int, CGFloat) {
                let candidate = grid(row: topRow, column: column)
                let inside = (0..<rows).reduce(0) { total, row in
                    total + (0..<WordleBoard.length).count { played(candidate, row: row, column: $0) }
                }
                return (inside, -abs(CGFloat(column) + 2 - middle))
            }
            return score(a) < score(b)
        }!
        return grid(row: topRow, column: first)
    }
}

/// What a picture of a Wordle game gives the reader: the letters Vision found,
/// and a way to ask what colour any part of the picture is.
///
/// The colour lookup is a closure so tests can paint a board without pixels.
struct WordleScreen {
    let glyphs: [RecognizedGlyph]
    let colorIn: (CGRect) -> RGBColor?
}

/// Reads the guesses played so far from a screenshot or photo of the game.
///
/// The third `PuzzleInputSource`, after the two typed-text parsers, and it produces
/// the same `WordleBoard` the tappable board builds — so a new picture after each
/// play simply replaces the board.
///
/// `parse` is the pure half, given letters already read; `read` adds Vision in
/// front, including a second pass that cuts each played row's tiles out and reads
/// them as a word, which fills in the letters the first pass skipped.
struct WordleImageReader: PuzzleInputSource {
    typealias Puzzle = WordleBoard
    typealias Description = WordleScreen

    func parse(_ screen: WordleScreen) -> Result<WordleBoard, PuzzleInputError> {
        guard let grid = WordleGrid.find(in: screen.glyphs, colorIn: screen.colorIn) else { return .failure(Self.noBoard) }
        return playedRows(on: grid, colorIn: screen.colorIn).flatMap { marks in
            let letters = marks.indices.map { row in Self.letters(of: row, on: grid, from: screen.glyphs) }
            return board(marks: marks, letters: letters)
        }
    }

    // MARK: - Steps

    /// Each played row's colours, top down, stopping at the first row not yet played.
    func playedRows(on grid: WordleGrid, colorIn: (CGRect) -> RGBColor?) -> Result<[[LetterMark]], PuzzleInputError> {
        var rows: [[LetterMark]] = []
        for row in 0..<WordleGrid.rows {
            let tiles = (0..<WordleBoard.length).map { column -> TileReading in
                guard let color = colorIn(grid.colorRect(row: row, column: column)) else { return .unreadable }
                return Self.reading(of: color)
            }
            let marks = tiles.compactMap { if case .played(let mark) = $0 { mark } else { nil } }
            if marks.isEmpty { break }
            guard marks.count == WordleBoard.length else {
                return .failure(PuzzleInputError("Row \(row + 1) looks half-coloured — maybe it was still flipping over. Take another picture once it settles."))
            }
            rows.append(marks)
            if marks.allSatisfy({ $0 == .rightSpot }) { break }
        }
        guard !rows.isEmpty else {
            return .failure(PuzzleInputError("I found the board, but no guesses have been played on it yet."))
        }
        return .success(rows)
    }

    /// The board, from each played row's colours and letters.
    func board(marks: [[LetterMark]], letters: [[Character?]]) -> Result<WordleBoard, PuzzleInputError> {
        var guesses: [Guess] = []
        for (row, (rowMarks, rowLetters)) in zip(marks, letters).enumerated() {
            let found = rowLetters.compactMap { $0 }
            guard found.count == WordleBoard.length else {
                return .failure(PuzzleInputError("I couldn't make out every letter in row \(row + 1). Try a sharper picture."))
            }
            guard let word = Self.legalWord(found) else {
                return .failure(PuzzleInputError("I read row \(row + 1) as \(String(found).uppercased()), which isn't a word Wordle accepts. Try a sharper picture."))
            }
            guesses.append(Guess(word: word, marks: rowMarks))
        }
        return .success(WordleBoard(guesses: guesses))
    }

    /// The letters Vision found on a row's tiles, one per tile, nil where it found none.
    static func letters(of row: Int, on grid: WordleGrid, from glyphs: [RecognizedGlyph]) -> [Character?] {
        (0..<WordleBoard.length).map { column in
            let c = grid.center(row: row, column: column)
            return glyphs
                .filter { abs($0.center.x - c.x) < grid.pitch * 0.3 && abs($0.center.y - c.y) < grid.pitch * 0.3 }
                .max { $0.frame.height < $1.frame.height }?
                .letter
        }
    }

    private static let noBoard = PuzzleInputError("I couldn't find the Wordle board in that picture. Try a screenshot with the whole board in view.")

    // MARK: - Colours

    /// What one tile shows.
    enum TileReading: Equatable {
        case played(LetterMark)
        /// White, or the near-black of dark mode: typed but not yet entered, or empty.
        case unplayed
        /// Off the edge of the picture.
        case unreadable
    }

    static func reading(of color: RGBColor) -> TileReading {
        if color.saturation < 0.25 {
            // Played grey is mid-tone in both modes (#787C7E light, #3A3A3C dark);
            // an unplayed tile is the page colour.
            return (0.17...0.7).contains(color.brightness) ? .played(.notInWord) : .unplayed
        }
        switch color.hue {
        case 38..<80:   return .played(.wrongSpot)   // yellow  #C9B458 / #B59F3B
        case 80..<170:  return .played(.rightSpot)   // green   #6AAA64 / #538D4E
        case 170..<270: return .played(.wrongSpot)   // blue, high contrast #85C0F9
        default:        return .played(.rightSpot)   // orange, high contrast #F5793A
        }
    }

    // MARK: - Words

    /// The word as read if Wordle accepts it; otherwise the one reading with
    /// `l`s turned to `i`s that it accepts, if there's exactly one — a capital `I`
    /// read as `l` is Vision's commonest slip on these tiles.
    static func legalWord(_ letters: [Character]) -> String? {
        let word = String(letters)
        if WordLists.legalWordleGuesses.contains(word) { return word }

        let ells = letters.indices.filter { letters[$0] == "l" }
        guard !ells.isEmpty else { return nil }
        var found: [String] = []
        for subset in 1..<(1 << ells.count) {
            var attempt = letters
            for (bit, index) in ells.enumerated() where subset & (1 << bit) != 0 { attempt[index] = "i" }
            let candidate = String(attempt)
            if WordLists.legalWordleGuesses.contains(candidate) { found.append(candidate) }
        }
        return found.count == 1 ? found[0] : nil
    }
}

extension WordleImageReader {
    /// The whole path from a picture: Vision for the letters, the pixels for colour.
    func read(_ photo: PuzzlePhoto) async throws -> Result<WordleBoard, PuzzleInputError> {
        let glyphs = try await TextRecognizer.glyphs(in: photo.image)
        guard let pixels = ImagePixels(photo.image) else {
            return .failure(PuzzleInputError("Something went wrong reading that picture. Try again."))
        }
        guard let grid = WordleGrid.find(in: glyphs, colorIn: pixels.averageColor(in:)) else { return .failure(Self.noBoard) }

        let marks: [[LetterMark]]
        switch playedRows(on: grid, colorIn: pixels.averageColor(in:)) {
        case .failure(let problem): return .failure(problem)
        case .success(let rows): marks = rows
        }

        var letters: [[Character?]] = []
        for row in marks.indices {
            let firstPass = Self.letters(of: row, on: grid, from: glyphs)
            let tiles = (0..<WordleBoard.length).map { grid.letterRect(row: row, column: $0) }

            // Read the row's five tiles again, cut out and side by side as a word —
            // carefully first, then roughly. The careful reader can be confidently
            // wrong: it read IDIOM, which looks much the same turned over, upside
            // down as "WOIGI", where the rough one got it.
            var best = firstPass
            for fast in [false, true] {
                let reread = try await TextRecognizer.lettersInRow(from: photo.image, cutting: tiles, fast: fast)
                let word = reread.compactMap { $0 }
                if word.count == WordleBoard.length, Self.legalWord(word) != nil {
                    best = reread
                    break
                }
                best = zip(best, reread).map { $0 ?? $1 }
            }
            letters.append(best)
        }
        return board(marks: marks, letters: letters)
    }
}
