# Where the data in this directory came from

Everything here is checked in rather than downloaded, so the app runs offline.

## `wordle-answers.txt` — 2,315 words
The original Wordle answer list: the words the game actually picks from, in
alphabetical order (the shipped list is in play order; this mirror is sorted).
Fetched 2026-08-09 from
<https://gist.github.com/cfreshman/a03ef2cba789d8cf00c08f767e0fad7b>.

Every entry is five lowercase letters and every one is also in `nwl2023.txt`.
This is a *curated* list — the NYT picked words an ordinary player would know —
which is why it serves double duty here as the scoring target and as the test of
whether a word is familiar enough to recommend.

## `wordle-allowed-guesses.txt` — 10,657 words
The words Wordle accepts as guesses but will never use as an answer. Disjoint
from the answer list; the two together are the 12,972 legal guesses.
Fetched 2026-08-09 from
<https://gist.github.com/cfreshman/cdcdf777450c5b5301e439061d29694c>.

Worth knowing: 47 five-letter words in `nwl2023.txt` are *not* legal Wordle
guesses, so scoring openers against the Scrabble list alone can recommend a word
the game rejects.

## `google-10000-english.txt` — 10,000 words
The 10,000 most common English words by frequency in the Google web corpus, most
common first — line number *is* the rank. Fetched 2026-08-09 from
<https://github.com/first20hours/google-10000-english>.

Unlike `wordFrequency.csv` this lists **word forms**, not lemmas, so `tried`
(2352), `moved` (2252) and `asked` (1072) each have their own entry. It is used
for the optional `max_rank` dial on how common a recommended opener must be. Be
aware of its origins: it is a web crawl, so it carries `click` and `email` high
up, and misses ordinary but web-rare words — `crane` is absent entirely.

## `wordFrequency.csv` — 5,050 rows
Top-5,000 English **lemmas** with corpus frequencies; columns `rank, lemma, PoS,
freq`, part-of-speech tagged (`j` adjective, `r` adverb, `x` negation). The
format matches the free sample from <https://www.wordfrequency.info> (COCA, the
Corpus of Contemporary American English); it predates this file, so that is an
inference from the format rather than a recorded fact.

Because it lists lemmas, inflected forms are absent — `tried`, `asked`, `moved`,
`spent`, `taken` have no row, and neither does `crane`. Only 694 of its entries
are five letters. It was the basis for opener selection until the Wordle lists
above replaced it; `wordle_interactive` still uses it to rank suggestions by
commonness.

## `nwl2023.txt` — 196,601 words
NWL2023, the NASPA tournament Scrabble word list: one lowercase word per line,
all lengths. The general-purpose dictionary behind Spelling Bee and Letter Boxed.

Fine for local use, but NASPA licenses this list commercially, so check the terms
before redistributing it inside anything shipped (an App Store build, a hosted
service). ENABLE or SCOWL are the usual freely-redistributable substitutes and
cover the same ground for Spelling Bee and Letter Boxed. The Wordle answer and
guess lists above are NYT's curated content and sit in the same grey area; the
`google-10000-english` list is the one source here with a clean permissive licence.
