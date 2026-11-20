# CLAUDE.md

Guidance for Claude Code working in this folder.

## What this folder is

Two subprojects that share a purpose: helping Bruce play the New York Times word
games (Wordle, Spelling Bee, Letter Boxed).

| Path | What it is |
| --- | --- |
| `python - modified from p073/` | The working Python solvers. The **algorithmic reference** and the lab for trying ideas out. Continues to run and be edited. |
| `iOS app/` | The **deliverable**: a native SwiftUI iPhone app, written from scratch, inspired by the Python version but not a transcription of it. |

The Python project has its own `CLAUDE.md` documenting its internals in depth —
read it before touching anything algorithmic. It began life as the standalone
p073 project, which now sits dormant in two places:
`~/dev/legacy/pycharm/p073-NYT games-former eastside` and
`~/dev/projects/0059-NYT games-eastside [p073]-iOS in 0090`.
Neither is edited; the copy in this folder is the live one.

## Standing decisions

These were settled on 2026-08-26 and shouldn't be re-litigated without Bruce.

- **Personal app, sideloaded to Bruce's own iPhone. Never distributed.** This
  makes the word-list licensing question moot. NWL2023 (NASPA), the Wordle
  answer/guess lists (NYT) and everything else in `dict/` ship into the app
  bundle as-is. Earlier notes in this project treated licensing as a blocker for
  an App Store release — that scenario is not on the table, so ignore them.
- **One git repo, rooted at this folder**, covering both subprojects. The Python
  folder's inherited `.git` (pointing at `bruceschek/nyt-games-helpers`) is
  removed; that GitHub repo remains intact as history, and the dormant p073
  folders still hold their own clone of it.
- **Target: iOS 26, iPhone only**, signed with Bruce's personal Apple ID team.
  Current SwiftUI APIs are fair game — no back-deployment compromises.
- **v1 ships all three games** plus a static best-openers reference.

## The input model — the one architectural constraint that matters

Today the user types the puzzle state on the keyboard, the way they did in the
Python app. **Eventually the app will read the puzzle from a photo of the screen
the game is being played on.** That is not being built now, but it dictates the
structure:

> A solver must never see raw text. Each game defines a **plain Swift value type
> describing the puzzle state** — `WordleBoard`, `SpellingBeePuzzle`,
> `LetterBoxedPuzzle`. The solver takes that value and returns results. Typed
> text is turned into that value by a *parser*, which is one implementation of an
> input source. A camera/OCR path will be another implementation producing the
> identical value type, and nothing downstream of it will need to change.

Practical consequences when writing code here:

- Parsing lives in its own type per game, never inside a view or a solver.
- Parse failures are a typed error the UI can render as a helpful sentence, not
  a `print` and a `continue` (which is how the Python version copes).
- Puzzle state is a value the user can hold, edit, and re-submit — not something
  accumulated inside a `while` loop. The Python Wordle assistant keeps its
  running min/max letter counts as loop-local state; on iOS that state belongs
  to the board value, so it can be re-derived, undone, or replaced wholesale by a
  future photo.
- Solvers stay pure and synchronous where they're fast enough (they all are), so
  they're trivially testable without a UI.

## Terminology: write for a person, not for the old CLI

The Python app uses terse codes because it's a personal REPL: menu letters
`w`/`b`/`l`/`f`, `+` for green and `-` for yellow, "optional letters", "starting
words". **Do not carry any of that into the iOS UI.** Use plain English and the
names the games themselves use. Reasonable defaults:

| Python | iOS UI |
| --- | --- |
| `f` — "find optimal starting words" | "Best opening words" |
| `+` / `-` / plain | "Right spot" / "Wrong spot" / "Not in the word" |
| "necessary char" / "optional chars" | "Center letter" / "Outer letters" (NYT's own terms) |
| "entry" | "the puzzle" / "today's letters" |
| "dic", "raw_dictionary_list5" | `wordList`, `fiveLetterWords` |

Internal Swift naming should be idiomatic Swift, not a port of the Python
identifiers. Match the algorithm, not the vocabulary.

## The iOS app

### Shape

A game picker in the navigation bar's top corner (Bruce's preference) switching
between three game screens plus the openers reference. Each game screen: a text
field to describe the puzzle, a submit action, and a results list.

### Layout

```
iOS app/
  NYTGamesHelper.xcodeproj      — one app target, one test target
  NYTGamesHelper/
    App/          — app entry, root view, the Game enum behind the picker
    Games/
      Wordle/       WordleBoard, WordleSolver, WordleInputParser, WordleView
      SpellingBee/  SpellingBeePuzzle, SpellingBeeSolver, …
      LetterBoxed/  LetterBoxedPuzzle, LetterBoxedSolver, …
      Openers/      static reference screen, reads openers.json
    Core/         — WordLists, Trie, LetterSet, PuzzleInput, PuzzleEntryField
    Resources/    — the word lists, plus openers.json
  NYTGamesHelperTests/          — Swift Testing suites
```

Both targets use Xcode's **synchronized file groups**, so a new `.swift` file in
any of those folders joins the build automatically and a new file in `Resources/`
is bundled automatically — there's nothing to add to the project file.

### How the user describes a puzzle

**Wordle uses a tappable board**, not typed text. A row is built in two steps,
which is what `WordleModel.Phase` tracks:

1. **Typing** — five blank outlined tiles. A 1×1 invisible `TextField` behind the
   tiles is what the keyboard is actually attached to; the tiles just render what
   it holds. That field must stay `.textInputAutocapitalization(.never)` — letting
   it upper-case the text makes every keystroke round-trip through the binding as
   the model lower-cases it back, and characters get dropped when typing at speed.
2. **Colorizing** — after **Colorize**, tapping a tile cycles it white → yellow →
   green → white, so a wrong pick is corrected by carrying on round rather than
   starting the row over. **Accept** locks the row into the `WordleBoard` and
   starts a fresh one; **Edit letters** goes back to step 1, keeping the colours
   unless the letters actually change.

The board stops after six rows, or as soon as a row comes back all green. `Undo
last row` pulls the last locked row back into the draft. The board is pinned and
only the suggestions scroll, so the tiles and buttons stay reachable.

`WordleInputParser` is no longer on screen but is kept — the tests use it, and it
is still the worked example of what a `PuzzleInputSource` looks like.

The other two games still take one typed line; the `?` button on each shows the
same text as that parser's `syntaxHelp`.

| Game | Typed as | Meaning |
| --- | --- | --- |
| Spelling Bee | `n acdehl` | center letter first, then the outer six. `nacdehl` works too. |
| Letter Boxed | `abc def ghi jkl` | the four sides, three letters each. |

### Porting notes per game

Line references are into `python - modified from p073/main.py` (1,322 lines).

- **Wordle** (`wordle_interactive`, :453). The real work of the port. Infers
  per-letter minimum and maximum occurrence counts across guesses so duplicate
  letters behave correctly — that logic is the valuable part and must survive
  intact. Candidates come from the 2,315-word answer list, never the Scrabble
  dictionary, and rank by `wordle-word-frequencies.txt` — a Zipf score for every
  legal guess, so no answer is ever unranked (see below).
- **Spelling Bee** (`spelling_bee`, :248). Recursive trie walk for words using
  only the allowed letters and containing the center letter; 4+ letters, flag
  pangrams, NYT scoring (4 letters = 1pt, 5+ = 1pt/letter, +7 pangram).
- **Letter Boxed** (`letter_boxed`, :286). Four sides of three letters; chain
  words where each starts with the previous word's last letter and no two
  consecutive letters share a side; fewest words wins, ties broken by fewest
  letters.
- **Best opening words** (`find_optimal_starting_words_for_wordle`, :1145).
  **Do not port this search to Swift.** The answer pool is a fixed list that
  hasn't changed since 2021, so the optimal opener sets are a *constant*. Run the
  Python search once on the Mac, export the results to `openers.json`, and ship
  that. The iOS screen just displays them. This also sidesteps the
  `max_unfamiliar > 0` slowness (~100s) entirely.

Everything else is fast in CPython already (trie build 0.45s, Letter Boxed
0.26–0.55s, Wordle filtering instant), and the hot loops are integer bit-mask
arithmetic that maps 1:1 onto Swift — compute is a non-issue on device.

### Data

`dict/` is 2.1 MB of plain text, checked in rather than downloaded so the app
works offline. `python - .../dict/SOURCES.md` records what each file is and its
traps — read it before swapping a list. The iOS app copies what it needs into
`Resources/`; the Python project keeps its own copy. If a list changes, both need
updating.

## Working here

- The Python project uses `uv`: `uv run main.py`, `uv run ruff check`. There is
  no test suite — `test/` holds exploratory scripts.
- The iOS project builds with Xcode 26.6 / Swift 6.3, Swift 5 language mode.

  ```bash
  cd "iOS app"
  xcodebuild -project NYTGamesHelper.xcodeproj -scheme NYTGamesHelper \
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
  xcodebuild test -project NYTGamesHelper.xcodeproj -scheme NYTGamesHelper \
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
  ```

  Signing is set up: automatic, team `TEQCSJPVNF` (the one most of Bruce's other
  Swift projects use), bundle id `com.schechter.NYTGamesHelper`. A device build
  works from the command line — add `-allowProvisioningUpdates` the first time on
  a new machine so Xcode can fetch the profile:

  ```bash
  xcodebuild -project NYTGamesHelper.xcodeproj -scheme NYTGamesHelper \
      -sdk iphoneos -destination 'generic/platform=iOS' \
      -allowProvisioningUpdates build
  ```

  To install on the phone, open the project in Xcode, plug the phone in and pick
  it as the run destination. The signing certificate expires July 2027.
- **Regenerate `openers.json`** with `uv run export_openers.py` in the Python
  project whenever the Wordle answer list or the search settings change. It writes
  straight into `iOS app/NYTGamesHelper/Resources/` and takes about 45 seconds.
- **Word frequencies are exported, not computed at runtime.** `uv run --with
  wordfreq export_word_frequencies.py` writes `wordle-word-frequencies.txt` into
  both `dict/` and the iOS bundle: every legal guess with a Zipf score, most common
  first. Regenerate it if either Wordle list changes. It replaced
  `google-10000-english.txt`, which knew only 818 of the 2,315 answers — `foist`,
  `hoist` and `moist` among the 1,497 it missed — and ranked web words like `login`
  above `flour`. `wordfreq` is a 54 MB package needed only to produce that file, so
  it stays out of the project's dependencies; pass it with `--with`.
- Unlike the Python side, the Swift solvers **have** unit tests, and new ones
  should. Where a behaviour exists in the Python version, assert against a value
  taken from it — that's how the Spelling Bee and Letter Boxed ports were checked,
  and it's much cheaper than reasoning about correctness from scratch. Note that
  Letter Boxed can have ties, so assert the shape of the answer (word count, total
  letters) rather than the exact words.
- Driving the Simulator UI from a script only half works: `osascript` **keystroke**
  reaches the app fine, but System Events **click at** hangs (it needs a permission
  that isn't granted). So a board can be typed into from a script but not tapped.
  Cover behaviour with the `@MainActor` tests in `ModelTests.swift` instead — that
  is where the type → colorize → accept flow lives, independent of the views.
