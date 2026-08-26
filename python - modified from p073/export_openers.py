"""Export the best opening-word sets to JSON for the iOS app.

The Wordle answer pool is a fixed list that has not changed since 2021, so the
optimal opener sets are a constant.  The search runs here, once, on the Mac; the
app ships the results and never searches.  See the root CLAUDE.md.

    uv run export_openers.py [top_n]
"""

import json
import sys
import time
from pathlib import Path

from main import (
    STARTING_SET_MIN_UNIQUE_LETTERS,
    STARTING_SET_REQUIRED_LETTERS,
    build_familiar_words,
    find_best_starting_word_sets,
    load_wordle_answers,
    load_wordle_guesses,
    order_and_rerank_starting_word_sets,
)

DEST = Path(__file__).resolve().parents[1] / "iOS app" / "NYTGamesHelper" / "Resources" / "openers.json"


def main() -> None:
    top_n = int(sys.argv[1]) if len(sys.argv) > 1 else 25

    answers = load_wordle_answers()
    guesses = load_wordle_guesses()
    words5 = sorted(set(answers) | set(guesses))
    familiar = build_familiar_words()

    print(f"searching (answers: {len(answers):,}, legal guesses: {len(words5):,})...")
    start = time.time()
    best = find_best_starting_word_sets(
        words5,
        answers,
        familiar_words=familiar,
        max_unfamiliar=0,
        min_unique_letters=STARTING_SET_MIN_UNIQUE_LETTERS,
        required_letters=STARTING_SET_REQUIRED_LETTERS,
        top_n=max(top_n, 150),
    )
    print(f"  searched in {time.time() - start:.1f}s, {len(best)} candidate sets")

    start = time.time()
    ranked = order_and_rerank_starting_word_sets(best, answers, STARTING_SET_REQUIRED_LETTERS)
    print(f"  ordered in {time.time() - start:.1f}s")

    payload = {
        "generatedBy": "export_openers.py",
        "minUniqueLetters": STARTING_SET_MIN_UNIQUE_LETTERS,
        "requiredLetters": STARTING_SET_REQUIRED_LETTERS,
        "answerPoolSize": len(answers),
        "sets": [
            {
                "words": r["order"],
                "score": round(r["score"], 3),
                "distinctLetters": len(set("".join(r["order"]))),
                "expectedRemaining": [round(v, 1) for v in r["metrics"]["expected_remaining"]],
            }
            for r in ranked[:top_n]
        ],
    }

    DEST.write_text(json.dumps(payload, indent=2) + "\n")
    print(f"wrote {len(payload['sets'])} sets to {DEST}")


if __name__ == "__main__":
    main()
