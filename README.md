# NYT Games Helper

A personal iPhone app, plus the Python solvers it grew out of, for the New York
Times word games: **Wordle**, **Spelling Bee** and **Letter Boxed**. Built for
one person's phone and sideloaded; not on the App Store.

| Folder | What it is |
| --- | --- |
| `iOS app/` | The SwiftUI app — the deliverable. |
| `python - modified from p073/` | The original Python solvers: the algorithmic reference. |

`CLAUDE.md` holds the design decisions and the details of how each piece works.

## Status — 21 November 2026

### Working, with tests passing

| Game | Typing the puzzle in | Reading it from a picture |
| --- | --- | --- |
| **Wordle** | Tappable board: type a guess, tap tiles to colour them | ✅ **Read board**: the whole board from a screenshot or photo. Take a new one after each play. |
| **Spelling Bee** | One line, e.g. `n acdehl` | ✅ Camera button on the entry field |
| **Letter Boxed** | One line, e.g. `abc def ghi jkl` | — not yet |
| **Best opening words** | Reference screen, computed ahead of time | — |

- Pictures can come from **Latest Screenshot** (one tap, for playing on the same
  phone), **Choose from Photos**, or **Take a Photo** of another screen.
- Wordle reads light mode, dark mode and high-contrast colours. It ignores a row
  that's typed but not entered, and asks for another picture if a row was caught
  mid-flip.
- Laid out for **iPhone Duo** as well as ordinary iPhones: on the open inner
  screen, Wordle's board sits beside the suggestions. On short screens the tiles
  shrink to fit.
- 64 tests pass, on the iPhone 17 Pro and iPhone Duo simulators. Built with
  Xcode 27.1; runs on iOS 26 and later.

### Not yet tried

- **Real NYT screenshots.** The picture readers have been tested only on hand-placed
  letters and on screens drawn to look like the games. This is the most important
  next check.
- **On the phone itself**: the Photos permission prompt, Latest Screenshot, and
  the camera.
- **The Duo layout by eye.** The Duo simulator's screen came back blank in
  screenshots, so the side-by-side layout is built and tested but hasn't been
  looked at.

### Next

1. Install on the phone. Try Wordle and Spelling Bee with real screenshots, and
   turn any misread into a test case.
2. Read Letter Boxed from a picture.
3. Look at the Duo layout in Xcode's iPhone Duo simulator, opened and folded.

## Building

```bash
cd "iOS app"
xcodebuild test -project NYTGamesHelper.xcodeproj -scheme NYTGamesHelper \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

To install on the phone, open the project in Xcode, plug the phone in and pick it
as the run destination.
