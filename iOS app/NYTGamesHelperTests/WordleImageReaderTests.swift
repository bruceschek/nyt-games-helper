import CoreGraphics
import Testing
import UIKit
@testable import NYTGamesHelper

/// The NYT's tile colours, light mode, dark mode and high contrast.
enum Palette {
    static let light = (green: 0x6AAA64, yellow: 0xC9B458, grey: 0x787C7E, page: 0xFFFFFF)
    static let dark = (green: 0x538D4E, yellow: 0xB59F3B, grey: 0x3A3A3C, page: 0x121213)
    static let contrast = (green: 0xF5793A, yellow: 0x85C0F9, grey: 0x787C7E, page: 0xFFFFFF)
}

/// A board laid out the way the game draws it, as the reader receives it: the
/// letters Vision found — one per tile, minus any it skipped — plus a colour for
/// every point on screen.
private struct FakeBoard {
    typealias Colors = (green: Int, yellow: Int, grey: Int, page: Int)

    var rows: [(word: String, marks: String)]   // marks: g / y / . — or blank for unplayed
    var colors: Colors = Palette.light
    var extraGlyphs: [RecognizedGlyph] = []
    /// Tiles whose letter Vision "didn't see", as (row, column).
    var skipped: Set<[Int]> = []

    static let pitch: CGFloat = 201, tile: CGFloat = 186
    static let left: CGFloat = 100, top: CGFloat = 330

    func tileRect(row: Int, column: Int) -> CGRect {
        CGRect(x: Self.left + CGFloat(column) * Self.pitch, y: Self.top + CGFloat(row) * Self.pitch,
               width: Self.tile, height: Self.tile)
    }

    var screen: WordleScreen {
        var glyphs = extraGlyphs
        for (r, row) in rows.enumerated() {
            for (c, letter) in row.word.enumerated() where !skipped.contains([r, c]) {
                let tile = tileRect(row: r, column: c)
                glyphs.append(RecognizedGlyph(letter: letter, frame: CGRect(
                    x: tile.midX - 30, y: tile.midY - 38, width: 60, height: 76)))
            }
        }
        return WordleScreen(glyphs: glyphs.shuffled(), colorIn: color(in:))
    }

    func color(in rect: CGRect) -> RGBColor? {
        let point = CGPoint(x: rect.midX, y: rect.midY)
        for r in 0..<6 {
            for column in 0..<5 where tileRect(row: r, column: column).contains(point) {
                let marks = r < rows.count ? Array(rows[r].marks) : []
                let hex = switch marks.indices.contains(column) ? marks[column] : " " {
                case "g": colors.green
                case "y": colors.yellow
                case ".": colors.grey
                default:  colors.page
                }
                return RGBColor(hex: hex)
            }
        }
        return RGBColor(hex: colors.page)
    }
}

/// Small letters, as on the on-screen keyboard, or a title's letters close together.
private func lettersInLine(_ text: String, x: CGFloat, y: CGFloat, height: CGFloat, step: CGFloat) -> [RecognizedGlyph] {
    text.lowercased().enumerated().map { index, letter in
        RecognizedGlyph(letter: letter, frame: CGRect(x: x + CGFloat(index) * step, y: y, width: height * 0.7, height: height))
    }
}

@Suite("Wordle from a picture")
struct WordleImageReaderTests {
    let reader = WordleImageReader()

    private func read(_ board: FakeBoard) throws -> [Guess] {
        try reader.parse(board.screen).get().guesses
    }

    @Test("played rows are read; the row being typed is left out")
    func playedRows() throws {
        let guesses = try read(FakeBoard(rows: [
            ("crane", ".g..y"),
            ("brute", ".gy.g"),
            ("fri", ""),          // typed, not entered
        ]))
        #expect(guesses == [
            Guess(word: "crane", marks: [.notInWord, .rightSpot, .notInWord, .notInWord, .wrongSpot]),
            Guess(word: "brute", marks: [.notInWord, .rightSpot, .wrongSpot, .notInWord, .rightSpot]),
        ])
    }

    @Test("dark mode and high contrast", arguments: [false, true])
    func darkAndContrast(highContrast: Bool) throws {
        let colors = highContrast ? Palette.contrast : Palette.dark
        let guesses = try read(FakeBoard(rows: [("slate", "y.g.g")], colors: colors))
        #expect(guesses.first?.marks == [.wrongSpot, .notInWord, .rightSpot, .notInWord, .rightSpot])
    }

    @Test("the grid is placed from a few letters, wherever they fall")
    func gridFromFewLetters() throws {
        var board = FakeBoard(rows: [("crane", "....."), ("pious", "..g..")])
        // Vision saw only three letters on the whole board.
        board.skipped = [[0, 0], [0, 2], [0, 4], [1, 0], [1, 1], [1, 2], [1, 4]]
        let screen = board.screen
        let grid = try #require(WordleGrid.find(in: screen.glyphs, colorIn: screen.colorIn))
        #expect(abs(grid.pitch - FakeBoard.pitch) < 1)
        let first = board.tileRect(row: 0, column: 0)
        #expect(hypot(grid.origin.x - first.midX, grid.origin.y - first.midY) < 2)
    }

    @Test("a top row whose letters were all missed is still found by its colour")
    func topRowByColour() throws {
        var board = FakeBoard(rows: [("crane", ".g..y"), ("pious", "..g..")])
        board.skipped = [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]]
        let screen = board.screen
        let grid = try #require(WordleGrid.find(in: screen.glyphs, colorIn: screen.colorIn))
        #expect(abs(grid.origin.y - board.tileRect(row: 0, column: 0).midY) < 2)
    }

    @Test("a letter Vision skipped is reported if nothing fills it in")
    func skippedLetter() {
        var board = FakeBoard(rows: [("crane", "....."), ("pious", "..g..")])
        board.skipped = [[1, 1]]
        let result = reader.parse(board.screen)
        guard case .failure(let problem) = result else { Issue.record("expected a failure"); return }
        #expect(problem.message.contains("row 2"))
    }

    @Test("the keyboard and the title are not mistaken for the board")
    func ignoresKeyboardAndTitle() throws {
        var board = FakeBoard(rows: [("crane", "....."), ("pious", "..g..")])
        board.extraGlyphs = lettersInLine("Wordle", x: 440, y: 140, height: 66, step: 40)
            + lettersInLine("QWERTYUIOP", x: 40, y: 1960, height: 44, step: 117)
            + lettersInLine("ASDFGHJKL", x: 98, y: 2140, height: 44, step: 117)
            + lettersInLine("ENTER", x: 20, y: 2325, height: 35, step: 25)
            + lettersInLine("ZXCVBNM", x: 216, y: 2320, height: 44, step: 117)
        #expect(try read(board).map(\.word) == ["crane", "pious"])
    }

    @Test("a solving row ends the board")
    func solved() throws {
        let board = try reader.parse(FakeBoard(rows: [("crane", ".g..y"), ("grape", "ggggg")]).screen).get()
        #expect(board.isSolved)
    }

    @Test("a capital I read as l is put right")
    func ellToEye() throws {
        #expect(try read(FakeBoard(rows: [("lnput", "....g")])).first?.word == "input")
    }

    @Test("a row caught mid-flip asks for another picture")
    func halfFlipped() {
        let result = reader.parse(FakeBoard(rows: [("crane", ".g.  ")]).screen)
        guard case .failure(let problem) = result else { Issue.record("expected a failure"); return }
        #expect(problem.message.contains("flipping"))
    }

    @Test("a misread that isn't a word is reported, naming the row")
    func notAWord() {
        let result = reader.parse(FakeBoard(rows: [("crane", "....."), ("qxzvb", ".....")]).screen)
        guard case .failure(let problem) = result else { Issue.record("expected a failure"); return }
        #expect(problem.message.contains("row 2"))
        #expect(problem.message.contains("QXZVB"))
    }

    @Test("an empty board says so")
    func nothingPlayed() {
        #expect(throws: PuzzleInputError.self) {
            try reader.parse(FakeBoard(rows: [("crane", "")]).screen).get()
        }
        #expect(throws: PuzzleInputError.self) {
            try reader.parse(WordleScreen(glyphs: [], colorIn: { _ in nil })).get()
        }
    }

    @Test("tile colours", arguments: [
        (0x6AAA64, "g"), (0x538D4E, "g"), (0xF5793A, "g"),
        (0xC9B458, "y"), (0xB59F3B, "y"), (0x85C0F9, "y"),
        (0x787C7E, "."), (0x3A3A3C, "."),
        (0xFFFFFF, " "), (0x121213, " "),
    ])
    func colours(hex: Int, expected: String) {
        let reading = WordleImageReader.reading(of: RGBColor(hex: hex))
        let got = switch reading {
        case .played(let mark): mark.rawValue
        case .unplayed, .unreadable: " "
        }
        #expect(got == expected)
    }
}

/// Draws a Wordle screenshot — title, board, keyboard — and reads it with the real
/// Vision and pixel sampling, the way a picture from the phone is read.
@Suite("Wordle from a rendered screenshot")
struct WordleRenderedTests {

    private func render(rows: [(word: String, marks: String)], dark: Bool) -> CGImage {
        let colors = dark ? Palette.dark : Palette.light
        let size = CGSize(width: 1179, height: 2556)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        func ui(_ hex: Int) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                    blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        }
        let ink = dark ? UIColor.white : UIColor.black
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            ui(colors.page).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            func text(_ string: String, size: CGFloat, color: UIColor, centeredIn rect: CGRect) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: size, weight: .bold), .foregroundColor: color]
                let box = (string as NSString).size(withAttributes: attributes)
                (string as NSString).draw(at: CGPoint(x: rect.midX - box.width / 2, y: rect.midY - box.height / 2),
                                          withAttributes: attributes)
            }

            text("Wordle", size: 70, color: ink, centeredIn: CGRect(x: 0, y: 120, width: size.width, height: 100))

            let tile: CGFloat = 186, gap: CGFloat = 15
            let left = (size.width - 5 * tile - 4 * gap) / 2
            for r in 0..<6 {
                let row = r < rows.count ? rows[r] : (word: "", marks: "")
                let letters = Array(row.word.uppercased()), marks = Array(row.marks)
                for c in 0..<5 {
                    let rect = CGRect(x: left + CGFloat(c) * (tile + gap), y: 330 + CGFloat(r) * (tile + gap),
                                      width: tile, height: tile)
                    let mark: Character = c < marks.count ? marks[c] : " "
                    let fill: Int? = switch mark {
                    case "g": colors.green
                    case "y": colors.yellow
                    case ".": colors.grey
                    default: nil
                    }
                    if let fill {
                        ui(fill).setFill()
                        context.fill(rect)
                    } else {
                        ui(dark ? 0x3A3A3C : 0xD3D6DA).setStroke()
                        context.cgContext.setLineWidth(6)
                        context.cgContext.stroke(rect.insetBy(dx: 3, dy: 3))
                    }
                    if c < letters.count {
                        text(String(letters[c]), size: 96, color: fill == nil ? ink : .white, centeredIn: rect)
                    }
                }
            }

            // The on-screen keyboard.
            let keyRows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
            for (k, keys) in keyRows.enumerated() {
                let keyWidth: CGFloat = 105, keyGap: CGFloat = 12
                let rowWidth = CGFloat(keys.count) * keyWidth + CGFloat(keys.count - 1) * keyGap
                for (i, key) in keys.enumerated() {
                    let rect = CGRect(x: (size.width - rowWidth) / 2 + CGFloat(i) * (keyWidth + keyGap),
                                      y: 1900 + CGFloat(k) * 180, width: keyWidth, height: 160)
                    ui(dark ? 0x818384 : 0xD3D6DA).setFill()
                    context.fill(rect)
                    text(String(key), size: 50, color: ink, centeredIn: rect)
                }
            }
            text("ENTER", size: 36, color: ink, centeredIn: CGRect(x: 10, y: 2260, width: 140, height: 160))
        }.cgImage!
    }

    @Test("Vision plus pixel sampling recover the board", arguments: [false, true])
    func endToEnd(dark: Bool) async throws {
        let image = render(rows: [("crane", ".g..y"), ("brute", ".gy.g"), ("fri", "")], dark: dark)
        let board = try await WordleImageReader().read(PuzzlePhoto(image: image)).get()
        #expect(board.guesses == [
            Guess(word: "crane", marks: [.notInWord, .rightSpot, .notInWord, .notInWord, .wrongSpot]),
            Guess(word: "brute", marks: [.notInWord, .rightSpot, .wrongSpot, .notInWord, .rightSpot]),
        ])
    }

    @Test("a row with an I in it reads", arguments: ["pious", "input", "idiom"])
    func capitalI(word: String) async throws {
        let image = render(rows: [("crane", "....."), (word, "..g..")], dark: false)
        let board = try await WordleImageReader().read(PuzzlePhoto(image: image)).get()
        #expect(board.guesses.map(\.word) == ["crane", word])
    }
}


