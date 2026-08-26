# NYT Games Helpers

Solvers and helpers for the New York Times word games: Wordle, Spelling Bee,
and Letter Boxed.

Pure Python — no third-party runtime dependencies. Managed with
[uv](https://docs.astral.sh/uv/).

## Quick start

```bash
uv run main.py
```

That's it. `uv run` creates the virtual environment, installs the pinned
Python, and launches the app in one step — no `uv sync` or activation needed.

You'll get a menu:

```
Game menu:
  w   Wordle
  b   Spelling Bee
  l   Lettered Box
  f   Find optimal starting words for Wordle
  q   Quit
```

## Development

```bash
uv sync             # install the dev group (ruff)
uv run ruff check   # lint
uv run ruff format  # format
```

To change the Python version, edit `.python-version` and re-run `uv sync`.

## Layout

| Path      | Purpose                                       |
| --------- | --------------------------------------------- |
| `main.py` | All game solvers and the menu loop            |
| `dict/`   | Word list (`nwl2023.txt`) and frequency data  |
| `test/`   | Standalone experiment scripts                 |
| `backup/` | Historical snapshot of `main.py`              |

The word list is [NWL2023](https://github.com/scrabblewords/scrabblewords), the NASPA
tournament Scrabble word list — curated for word games, no phrases/hyphens/proper nouns.
