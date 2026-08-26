# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
uv run main.py       # run the app (creates venv + installs pinned Python automatically)
uv sync               # install the dev dependency group (ruff)
uv run ruff check     # lint
uv run ruff format    # format
```

There is no test runner or test suite — `test/` contains standalone exploratory scripts
(`t.py`, `lb.py`), not automated tests. Run them directly with `uv run test/<script>.py`
if needed; they load the shared dictionary from `dict/` via a `DICT_DIR` constant anchored
to `__file__`.

To change the Python version, edit `.python-version` and re-run `uv sync`.

## Architecture

Everything lives in a single `main.py`, organized into `######`-delimited sections in this
order: dictionary/trie utilities → Spelling Bee → Letter Boxed → Wordle (v3, the current
implementation) → menu/UI. `main()` at the bottom loads the shared dictionaries once, prints
a menu, then loops reading a short code (`w`, `b`, `l`, `f`, `q`) and dispatching to
the matching solver in an `if`/`elif` chain — each solver is self-contained and takes its own
`entry` string parsed from a follow-up prompt. Each dispatch is wrapped in `try/except` so an
error inside one game returns to the menu instead of killing the app.

**Shared dictionary data**, loaded once in `main()` and passed into solvers:
- `raw_dictionary_list` / `raw_dictionary_list5` — full word list and the 5-letter subset,
  from `load_all_words()`, which reads `dict/nwl2023.txt` (NWL2023, the NASPA tournament
  Scrabble word list; a plain word-per-line list, ~196k words, all lowercase alpha).
- `dic_freq` / `dic_freq5` — word→frequency-rank maps from `load_all_words_freq()`, which
  reads `dict/wordFrequency.csv`. Only the top ~5k words have frequency data; unranked
  words sort to the end.
- `dic_tri` — the full word list loaded into a nested-dict trie via `load_dictionary_as_tri()`
  / `insertIntoDict()`, used by Spelling Bee's recursive search. Letter Boxed does not use
  the trie; it filters the flat list directly.

**Per-game notes:**
- **Wordle** (`w`, `wordle_interactive`) is the interactive assistant — it infers per-letter
  min/max occurrence counts across guesses to handle duplicate letters correctly, and only
  commits parsed green/yellow state to the running board after a guess fully validates, so a
  malformed guess can't corrupt later results. (Two earlier implementations were removed: one
  with duplicate-letter bugs, and a one-shot pattern filter that couldn't express yellows.)
  Candidate answers come from `load_wordle_answers()`, not the full Scrabble dictionary --
  otherwise it can suggest a word Wordle would never pick. Candidates are ranked by
  `load_word_form_ranks()` rather than the lemma-based `wordFrequency.csv`, so inflected forms
  like `tried` aren't scored as if they were rare (see `dict/SOURCES.md`). `rank()`'s sink
  value for unranked words is computed from whichever rank dict is passed in
  (`max(dic_freq.values()) + 1`), not hardcoded, so it stays correct regardless of the source's
  scale.
- **Spelling Bee** (`spelling_bee`, `spelling_bee_find_words_with_constraints`) does a
  recursive trie walk collecting all words that use only the allowed letters and contain the
  required letter, filtering to 4+ letters at print time, flagging pangrams, and totaling
  NYT-style score (4-letter = 1pt, 5+ = 1pt/letter, +7 for a pangram).
- **Letter Boxed** (`letter_boxed`) parses `entry` as four comma/space-separated letter
  groups (the four sides of the box), builds a `letter_to_side` map to enforce the
  "no consecutive letters from the same side" rule, then recursively chains words
  (`add_another_word`) where each word starts with the previous word's last letter, searching
  for the solution using the fewest words (ties broken by fewest total letters) that covers
  all 12 letters. It loads its own word list via `load_all_words()` internally rather than
  using the passed-in trie. `max_common_chars` (default: unlimited) can cap how many letters
  a candidate word may share with letters already used, trading completeness for speed on
  puzzles where the full search is slow.
- **Opening-word search** (`f`) finds the best set of four opening guesses, working entirely
  from Wordle's own word lists rather than the Scrabble dictionary (`load_wordle_guesses`,
  `load_wordle_answers` — see `dict/SOURCES.md`). Guesses come from the 12,972 words the game
  accepts; they are scored against the 2,315 words it can actually pick as the answer. Both
  matter: 47 five-letter NWL words are illegal guesses, and scoring against all of NWL
  optimises for `sangh` and `compt` turning up as the answer.
  `group_words_by_letter_set` reduces the 5,805 eligible openers (5 distinct letters, no
  trailing `s`) to 4,098 distinct 26-bit letter masks, collapsing anagrams;
  `pick_best_placed_anagram` picks a concrete word back out of each mask, favouring the
  arrangement most likely to score greens.
  - `exact_starting_word_score` is the closed form of what the old code sampled with Monte
    Carlo: 5 points per letter in the right slot, 1 per letter of the answer the word
    contains, summed over the whole pool rather than sampled from it. Verified against
    100k-iteration sampling (agrees to 3 decimals) and ~100x faster. Sampling 1,000 trial
    answers carried σ≈0.15 against a top-200 spread under 1.0, so the old ranking was mostly
    noise. Note the score is *additive over the four words* — neither term couples one word
    to another, so nothing in the score measures how the words work together; that job
    belongs entirely to the coverage constraints.
  - `find_best_starting_word_sets` exploits that additivity: sort candidates by score, walk
    combinations best-first, and prune a branch when even perfect remaining words couldn't
    beat the worst result held. Searches the entire 158m-set space in ~40s and returns the
    provable optimum. Cross-checked against an exhaustive scan of the 20-letter space —
    identical top 5. Runs in a few seconds at `max_unfamiliar=0`.
  - `max_unfamiliar` caps how many words in a set may fall outside `familiar_words`, and
    `pick_representative_word` prefers a recognisable spelling when a letter set has one,
    since anagrams cover the same letters anyway. Familiarity is membership, not a score:
    `build_familiar_words` unions the answer list (curated for exactly this) with the
    commonest word forms from `load_word_form_ranks`, up to `FAMILIAR_WORD_RANK_LIMIT`.
    Neither source alone works — the answer list has no inflections, and the web-derived
    frequency list is missing plain words like `crane`. Demanding four everyday words costs
    ~0.8%: `slime broke chant pudgy` (14.76) against `shine bract flume podgy` (14.88).
    Obscure words print with a `*`.
    **Caveat:** `max_unfamiliar > 0` is far slower than `0` — measured at ~100s for just the
    top set (vs. a few seconds at `max_unfamiliar=0`), because allowing obscure words admits
    the whole 4,098-mask candidate pool instead of the 1,398 that pass the familiarity
    filter, and the score-bound pruning is much weaker across that much bigger field. `f`
    prints a warning before running when this is selected. Not something `top_n` can fix —
    even `top_n=1` pays this cost, since it's the search itself that's slow, not the number
    of results collected.
  - Coverage settings are `STARTING_SET_MIN_UNIQUE_LETTERS` (19) and
    `STARTING_SET_REQUIRED_LETTERS` (`aeiouy`). 19 rather than 20 because covering a 20th
    letter forces one of `fjqvwxz` into the set, and repeating a common letter is worth more:
    best-possible scores are 13.14 at 20 letters, 14.45 at 19, 15.64 at 18. Requiring the
    vowels is nearly free; requiring `n` on top changes nothing, as it earns its place
    unaided.
  - The additive score is order-blind — a set's score is a plain sum, the same whichever of
    the 4! ways you play its words. `f`'s final ranking layers ordering on top in a second
    pass: `find_best_starting_word_sets` first collects a shortlist (`pool_size_for_rerank =
    max(top_n, min(ORDER_RERANK_POOL_SIZE, top_n * ORDER_RERANK_MULTIPLIER))`, i.e. wider than
    what's displayed but scaled to the request rather than a flat floor — a flat 150 measured
    at ~4 minutes once `max_unfamiliar` was raised, for a request that only wanted the top 3),
    then `order_and_rerank_starting_word_sets` picks each set's best of 24 orderings and
    re-sorts the shortlist by that. This is explicitly a heuristic on top of the exact search,
    not part of it — a set that scores slightly lower but orders much better could exist
    outside the shortlist and would never be found; `f` prints a note saying so.
    - `wordle_feedback_pattern(guess, answer)` computes real green/yellow/grey marks,
      including Wordle's duplicate-letter rule (greens consume a letter first, only the
      leftover is available for yellows) — verified by hand against `sassy` vs `class`.
    - `compute_order_metrics` tracks, per prefix length: `expected_remaining` (the standard
      "expected partition size", `sum(group_size²)/N` grouping answers by feedback signature
      so far) and `required_missing` (how many required letters — the vowels — are still
      uncovered). `order_quality_key` sorts on `(required_missing[1], expected_remaining[0],
      expected_remaining[1], expected_remaining[2])` — fewest vowels missing after word 2
      first, then reward a first word that narrows fast on its own, then word 2's, then
      word 3's. Cross-checked against brute force over all 24 permutations.
    - **`required_missing[1]` is inert at the current settings, and provably so.** It sorts
      first but never decides anything, because no set the search can return covers all of
      `aeiouy` in its first two words. Measured across the top-150 shortlist: 147 sets top
      out at 4 of the 6 vowels by word 2, 3 reach 5, none reach 6. The cause is a slot count,
      not luck. Two words holding all six vowels have to be disjoint (a shared letter costs a
      letter the set cannot spare), so they spend 6 vowels + 4 consonants = 10 letters; words
      3 and 4 then have 10 slots and must supply 9 *new* letters to reach
      `STARTING_SET_MIN_UNIQUE_LETTERS` = 19. Every vowel is already spent, so each vowel
      those words contain is a repeat, and two repeats cap the set at 18 — meaning at least
      one of the last two words must contain no `a/e/i/o/u/y` whatsoever. Exactly one of the
      5,805 eligible openers qualifies: `crwth`, which is not in `familiar_words` and so is
      filtered out before the search starts. So it is 0 of 150, and 0 of *every* set, at
      `max_unfamiliar=0`. What binds here is the 19-letter floor, not the scoring or the
      ordering pass:
      - 19 letters, all familiar — impossible (unconstrained best: `slime broke chant pudgy`, 14.76)
      - 19 letters, `max_unfamiliar=1` — `soapy guide crwth blank`, 14.07
      - 18 letters, all familiar — `foamy guide shalt crank`, 15.11 (unconstrained best at 18: 15.64)

      The 18-letter row *outscores* the 19-letter optimum, since 18-letter sets are free to
      repeat common letters. So front-loading the vowels trades against the letter-coverage
      floor, not against score. Leave the key first in the tuple — it costs nothing and starts
      working the moment either setting moves — but do not read a set's ordering as evidence
      that it won on vowels.
    - `best_order_for_set` finds the one ordering (of 4! = 24) minimizing that key for a
      single set; `order_and_rerank_starting_word_sets` does this for the whole shortlist,
      caching each word's feedback pattern across the whole answer pool once (`word_patterns_
      against_pool`, packed into a single 0–242 code per answer so prefix signatures fold
      cheaply) so words shared between sets aren't recomputed. Ordering ~150 sets takes a few
      seconds on top of the search itself.
  - `enumerate_starting_word_sets` is an exhaustive generator over the candidate sets, no
    longer used by `f` but kept for exploring the space: 1,309,058 sets of four fully
    disjoint words (~110s to walk), 158,312,403 at 19 letters (~56 min), which is why it is a
    generator and not a list. It walks *letters* (rarest first) rather than words — each step
    either skips the rarest uncovered letter or covers it with the next word, bounded by a
    shared-letter budget and a skip budget. Two subtleties keep sets unique: a skipped letter
    is barred from every later word, and where a shared letter sits in two chosen words only
    the lower-masked route is kept. Both were verified against brute force; without them the
    walk overcounts fully-disjoint sets by ~4x. `required_letters` narrows to sets covering
    given letters (at 20 letters: 1,281,352 survive `aeiou`, 1,240,449 `aeiouy`, 1,153,176
    `aeiouny`).

**Data files** (`dict/`, `wordle/`) are checked into the repo rather than downloaded, so the
app runs fully offline. `dict/SOURCES.md` records where each one came from and what it is
good for — read it before swapping a word list, since the lemma-vs-word-form distinction in
`wordFrequency.csv` silently skews any statistics built from it. `backup/` holds a single historical snapshot of `main.py` for
reference and is excluded from ruff linting (`pyproject.toml`).
