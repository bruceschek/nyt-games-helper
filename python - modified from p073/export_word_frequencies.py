"""Export a frequency ranking for every legal Wordle guess.

The old ranking came from `google-10000-english.txt`, a web crawl.  It covered
only 818 of the 2,315 answers -- 'foist', 'hoist', 'moist' and 1,494 others had
no entry at all, so the solver fell back to alphabetical order for them.  It also
ranked web vocabulary ('login', 'forum', 'click') above ordinary English
('choir', 'flour', 'brave').

The replacement is `wordfreq`, which blends subtitles, books, news, Wikipedia and
web text and reports a Zipf score: 1 is vanishingly rare, 7 is 'the'.  It knows
every one of the 2,315 answers.  The package is a 54 MB dependency and is only
ever needed here, so the scores are exported once and the app ships the result --
the same arrangement as `export_openers.py`.

    uv run --with wordfreq export_word_frequencies.py

Writes `dict/wordle-word-frequencies.txt` and copies it into the iOS bundle.
Two whitespace-separated columns, most common first, so a reader that only wants
an ordering can use the line number and ignore the score.
"""

from pathlib import Path

from wordfreq import zipf_frequency

from main import load_wordle_guesses

HERE = Path(__file__).resolve().parent
DESTS = [
    HERE / "dict" / "wordle-word-frequencies.txt",
    HERE.parent / "iOS app" / "NYTGamesHelper" / "Resources" / "wordle-word-frequencies.txt",
]


def main() -> None:
    words = sorted(set(load_wordle_guesses()))
    scored = sorted(((zipf_frequency(w, "en"), w) for w in words), key=lambda p: (-p[0], p[1]))

    known = sum(1 for zipf, _ in scored if zipf > 0)
    print(f"{len(scored):,} legal guesses, {known:,} with a frequency ({100 * known / len(scored):.1f}%)")

    body = "".join(f"{word}\t{zipf:.2f}\n" for zipf, word in scored)
    for dest in DESTS:
        dest.write_text(body)
        print(f"wrote {dest}")


if __name__ == "__main__":
    main()
