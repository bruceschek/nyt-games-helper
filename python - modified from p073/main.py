import csv
import itertools
import re
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, Iterator, List, Tuple

# Data files live alongside this script, so anchor to it rather than to the
# current working directory.  Lets the app be launched from anywhere.
DICT_DIR = Path(__file__).resolve().parent / "dict"




############################################################################################################
######  functions purely for dictionary of words, loading it, searching it, etc.
############################################################################################################f

def insertIntoDict(word: str, dictionary: dict) -> object:
    if len(word) == 0:
        if "|" in dictionary: # last char of a word terminates in "|"
            return
        dictionary["|"] = {}  # last char of a word terminates in "|" followed by an empty dict
        return

    first = word[0]   # first char of word
    if first == '%':
        print("we found a %")
    wordStrippedOfFirstChar = word[1:]

    if first in dictionary:
        insertIntoDict(wordStrippedOfFirstChar, dictionary[first])
        return
    else:
        dictionary[first] = {}
        insertIntoDict(wordStrippedOfFirstChar, dictionary[first])
        return


def isInDict(word: str, d: dict):
    # print("called isInDict on: " + word)
    if len(word) == 0:
        if "|" in d:
            return True
        else:
            # todo - Long ago, we had a problem, but I think its fixed now!! :)
            #    ...formerly, this method would throw exception if the word was something like "happyz' ( = real word + spurious character)
            #    ...But, as of 19-03-02, I think its fixed.
            # print("Houston, we have a problem!!!  Must be substring of real word!")
            return False

    firstLetter = word[0]
    # print('firstLetter:[', firstLetter, ']')
    substringAfterFirstLetter = word[1:]

    if firstLetter in d:
        nextLevelDict = d[firstLetter]
        # print("nextLevelDict contains these keys:")
        # for k in nextLevelDict:
        #     print('key = ', k)
        return isInDict(substringAfterFirstLetter, nextLevelDict)
    else:
        return False


def isSubstringInDict(substring: str, d: dict):
    if len(substring) == 0:
        return True
    firstLetter = substring[0]
    substringAfterFirstLetter = substring[1:]
    if firstLetter in d:
        nextLevelDict = d[firstLetter]
        return isSubstringInDict(substringAfterFirstLetter, nextLevelDict)
    else:
        return False


# Functions purely for Debugging
def printWordsInDict(word: str, d: dict):

    for s in d:
        if s == "|":
            print(word)
        else:
            printWordsInDict(word + s, d[s])
    return


def find_words_from_substring_list(str_so_far: str, substrings, d: dict, results: list):

    if len(substrings) == 0:
        return # base case

    for s in substrings:
        new_str = str_so_far + s

        if isSubstringInDict(new_str, d):
            if isInDict(new_str, d):
                results.append(new_str)
                # continue

            new_list = substrings.copy()
            new_list.remove(s)
            if len(new_list) == 0:
                return
            find_words_from_substring_list(new_str, new_list, d, results)

    return


def find_words_that_exhaust_the_list(str_so_far: str, substrings, d: dict, results: list, full_words: list):

    if len(substrings) == 0:
        return # base case

    for s in substrings:
        new_str = str_so_far + s

        if isSubstringInDict(new_str, d):
            if isInDict(new_str, d):
                results.append(new_str)
                full_words.append(new_str)

            new_list = substrings.copy()
            new_list.remove(s)
            if len(new_list) == 0:
                return
            find_words_from_substring_list(new_str, new_list, d, results)

    return


def load_dictionary_as_tri(raw_dictionary_list, word_length: int = None):
    """
    Loads words from the dictionary file into a nested dictionary structure.
    If word_length is specified, only words of that length are included.
    """
    dic = {}
    for word in raw_dictionary_list:
        if any(not c.isalpha() for c in word):  # Ensure the word is valid
            print(f"Houston, we have a problem, erroneous character in dictionary text file, word: {word}")
            exit()

        if word_length is None or len(word) == word_length:  # Apply word length filter if provided
            insertIntoDict(word, dic)

    return dic


# returns a list of all words in english language
def load_all_words() -> list:
    files_to_read = [DICT_DIR / 'nwl2023.txt']
    content = []
    for f in files_to_read:
        with open(f, "r") as file:
            content = file.readlines()
        # remove whitespace characters like `\n` at the end of each line
        content = [x.strip() for x in content]
    return content


def load_all_words_freq(word_length: int = None) -> Tuple[Dict[str, int], Dict[str, int]]:
    """
    Returns two dictionaries:
      - lemma_to_rank: All lemmas and their rank
      - lemma_to_rank_n: Lemmas of length `word_length` and their rank
    Beweare that the same word can occur 2 or more times due to different parts of speech (like "feel" can be noun or verb)..
       in which case we accept only the one that has higher frequency
    """
    lemma_to_rank = {}
    lemma_to_rank_n = {}
    filename = DICT_DIR / "wordFrequency.csv"
    with open(filename, 'r', newline='', encoding='utf-8-sig') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            lemma = row['lemma']
            rank = int(row['rank'])
            if lemma not in lemma_to_rank:
                lemma_to_rank[lemma] = rank
                if len(lemma) == word_length:
                    lemma_to_rank_n[lemma] = rank
    return lemma_to_rank, lemma_to_rank_n


def load_wordle_answers() -> List[str]:
    """The 2,315 words Wordle actually draws its answers from.

    A curated list -- the NYT chose words an ordinary player would recognise --
    so it is both the right thing to score guesses against and a sound test of
    whether a word is worth recommending.  See dict/SOURCES.md.
    """
    with open(DICT_DIR / "wordle-answers.txt") as file:
        return [line.strip() for line in file if line.strip()]


def load_wordle_guesses() -> List[str]:
    """Every word Wordle accepts as a guess: the answers plus 10,657 others.

    Not the same set as the five-letter words of nwl2023.txt -- 47 of those are
    rejected by the game -- so openers are chosen from here instead.
    """
    answers = load_wordle_answers()
    with open(DICT_DIR / "wordle-allowed-guesses.txt") as file:
        allowed = [line.strip() for line in file if line.strip()]
    return answers + allowed


def load_word_zipf() -> Dict[str, float]:
    """word -> Zipf frequency for every legal Wordle guess; 1 is rare, 7 is 'the'.

    Word *forms*, not lemmas, so 'tried' and 'moved' are scored in their own right
    rather than folded into their headword.  Written by export_word_frequencies.py
    from the wordfreq package, which blends subtitles, books, news, Wikipedia and
    web text -- so unlike the web crawl it replaces it knows all 2,315 answers and
    doesn't rank 'login' above 'flour'.  0.00 means wordfreq had no data.
    """
    scores = {}
    with open(DICT_DIR / "wordle-word-frequencies.txt") as file:
        for line in file:
            if line.strip():
                word, zipf = line.split()
                scores[word] = float(zipf)
    return scores


def load_word_form_ranks() -> Dict[str, int]:
    """word -> commonness rank, 1 being the most common; line number is the rank.

    The ordering of load_word_zipf(), for callers that want a position rather than
    a score.  Covers only the 12,972 legal Wordle guesses, so a rank here means
    'nth commonest five-letter word Wordle accepts', not nth commonest in English.
    """
    with open(DICT_DIR / "wordle-word-frequencies.txt") as file:
        return {line.split()[0]: rank for rank, line in enumerate(file, start=1) if line.strip()}



############################################################################################################
######  spelling bee

# used for spelling bee, (and anything else?)
def spelling_bee_find_words_with_constraints(d: dict, possible_letters: str, required: str):
    results = []
    # assure that we've included the required char in the possible_letters search
    if required not in possible_letters:
        possible_letters += required

    def search_words(current_word, remaining_dict):
        """ Recursively search for words that meet the constraints """
        if "|" in remaining_dict and required in current_word:
            results.append(current_word)  # Found a valid word

        for letter in remaining_dict:
            if letter in possible_letters:  # Only use allowed letters
                search_words(current_word + letter, remaining_dict[letter])

    for letter in possible_letters:
        if letter in d:
            search_words(letter, d[letter])

    return results

def spelling_bee( entry, dic ):
    # Split using space or comma (or both), max 3 parts
    parts = re.split(r"[ ,]+", entry.strip(), maxsplit=1)

    if len(parts) != 2 or not parts[0] or not parts[1]:
        print("✋ Please enter the required letter and the optional letters, e.g. 'n acdehl'")
        return

    necessary_char  = parts[0]
    optional_chars = parts[1]
    all_letters = set(necessary_char) | set(optional_chars)

    # print(f"nec: {necessary_char}, optional: {optional_chars}")
    matching_words = spelling_bee_find_words_with_constraints(dic, optional_chars, necessary_char)
    matching_words.sort()
    # print(f"\nWords that meet the constraints: {matching_words}")

    count = 0
    total_score = 0
    first_char = ""
    for word in matching_words:
        if len(word) >= 4:
            count += 1
            is_pangram = set(word) >= all_letters
            score = (1 if len(word) == 4 else len(word)) + (7 if is_pangram else 0)
            total_score += score
            if word[0] != first_char:
                first_char = word[0]
                print( f"----{first_char}----" )
            tag = "  \U0001F389 PANGRAM" if is_pangram else ""
            print( f"{count}. {word} ({score} pt{'s' if score != 1 else ''}){tag}" )

    print(f"\nTotal possible score: {total_score} across {count} words")


############################################################################################################
######  letter box

def letter_boxed(entry, max_common_chars=None):
    print("Starting Letter Boxed")
    print("The Puzzle Content:", entry)

    # Filter valid words, i.e., test whether the word is part of a valid solution to Letter Boxed game.
    def is_valid_word(word):
        if len(word) < 3:
            return False
        for c in word:
            if c not in all_letters:
                return False
        for i in range(len(word) - 1):
            a = word[i]
            b = word[i + 1]
            if letter_to_side[a] == letter_to_side[b]:
                return False
        return True

    # recursive attempt to add another word to a growing list of words ("word_sequence") that solve the puzzle.
    # Solutions are ranked first by fewest words, then by fewest total letters among ties.
    # NOTE: since python has no means of passing a value type by reference, our "hack" is to encapsulate
    #   the actual best_word_count in a single-value list which is indeed passed by reference
    def add_another_word(word_sequence, used_chars_so_far, best_word_count, best_letter_count, best_solution):
        # Adding one more word can only grow the sequence, so once we're already as long
        # as the best known solution, this branch can't improve on it.
        if len(word_sequence) >= best_word_count[0]:
            return

        most_recent_added_word = word_sequence[-1]
        last_letter = most_recent_added_word[-1]

        # Note that in some cases, there will be no valid words starting with one of the valid letters
        if last_letter not in words_starting_with:
            return

        for word in words_starting_with[last_letter]:
            if word in word_sequence:
                continue
            # Determine how many characters in common between used_chars_so_far and the new word.
            # We hope for no common chars, (or at least a very small number)
            common_chars = used_chars_so_far & set(word)
            if max_common_chars is not None and len(common_chars) > max_common_chars:
                continue

            new_used_chars_so_far = used_chars_so_far | set(word)
            new_word_sequence = word_sequence + [word]

            if len(new_used_chars_so_far) == 12:
                word_count = len(new_word_sequence)
                letter_count = sum(len(w) for w in new_word_sequence)
                is_new_word_count_milestone = word_count < best_word_count[0]
                is_better = is_new_word_count_milestone or (
                    word_count == best_word_count[0] and letter_count < best_letter_count[0]
                )
                if is_better:
                    best_letter_count[0] = (
                        letter_count if is_new_word_count_milestone
                        else min(best_letter_count[0], letter_count)
                    )
                    best_word_count[0] = word_count
                    best_solution[0] = (new_word_sequence, letter_count)
                    if is_new_word_count_milestone:
                        print(f"Found a {word_count}-word solution: {new_word_sequence},   total letters: {letter_count}")
            else:
                add_another_word(new_word_sequence, new_used_chars_so_far, best_word_count, best_letter_count, best_solution)

    # Split using space or comma (or both), max 3 parts
    sides = re.split(r"[ ,]+", entry.strip(), maxsplit=3)
    # result is a data structure like the following...
    #   Given this entry='abc,def,ghi,jkl' the line of code above generates a data structure like this....
    # sides = [
    #     ['a', 'b', 'c'],
    #     ['d', 'e', 'f'],
    #     ['g', 'h', 'i'],
    #     ['j', 'k', 'l']
    # ]

    # Generate a set of all necessary letters, i.e., the 12 letters surrounding the letter box puzzle board:
    # all_letters = set(letter for side in sides for letter in side)
    all_letters = set()
    for side in sides:
        for letter in side:
            all_letters.add(letter)

    # Tag each letter with the name of its respective side of the box:
    letter_to_side = {}
    side_names = ['top', 'right', 'bottom', 'left']
    for i, side in enumerate(sides):
        for letter in side:
            letter_to_side[letter] = side_names[i]

    # Build filtered word list
    # Start with the raw list of strings representing all English words
    full_list_of_words = load_all_words()
    valid_words = [w for w in full_list_of_words if is_valid_word(w)]

    # starts_with a dictionary, where key is a letter and value is a
    #   list of all valid_words that start with that letter
    words_starting_with = {}
    for word in valid_words:
        first_letter = word[0]
        if first_letter not in words_starting_with:
            words_starting_with[first_letter] = []
        words_starting_with[first_letter].append(word)

    # For each of the letters in all_letters, sort the collection of words starting with that letter, longest through shortest
    for letter in all_letters:
        if letter in words_starting_with:
            words = words_starting_with[letter]
            words_sorted_starting_with_longest = sorted(words, key=len, reverse=True)
            words_starting_with[letter] = words_sorted_starting_with_longest

    start = time.time()

    # sort in place, putting longest first
    valid_words.sort(key=len, reverse=True)

    # begin the search for solutions, starting with longest words.  We'll sequentially seek solutions
    #  with fewer words, and each time we find a shorter (word count) solution, we'll only list words with equal or less.
    best_word_count = [10_000]
    # We'll also keep track of "best letter count", and in turn sequentially list only solutions with less/equal
    #   total letter count across all the words in the solution
    best_letter_count = [10_000]
    best_solution = [None]
    for word in valid_words:
        add_another_word( [word], set( word ), best_word_count, best_letter_count, best_solution )

    elapsed = time.time() - start
    if best_solution[0]:
        sequence, letter_count = best_solution[0]
        print(f"\nBest solution: {sequence},   total letters: {letter_count}")
    else:
        print("\nNo solution found.")
    print(f"Elapsed time: {int(elapsed // 60)} minutes, {int(elapsed % 60)} seconds")


############################################################################################################
######  Wordle
######  First up...   Utilities used by the Wordle helpers
############################################################################################################

def replace_char_at_index(s: str, char: str, index: int) -> str:
    if not (0 <= index < len(s)):
        raise IndexError("Index out of range.")
    if len(char) != 1:
        raise ValueError("Replacement character must be a single character.")
    return s[:index] + char + s[index + 1:]


############################################################################################################
######  Wordle: interactive assistant
############################################################################################################
# Expects:
#   dic:      list[str], the candidate *answers* -- should be load_wordle_answers(), not the
#             full Scrabble dictionary, since Wordle only ever picks from its own curated list.
#   dic_freq: dict[str,int] mapping word->rank (lower rank = more common) -- pass
#             load_word_form_ranks() rather than a lemma-based list, so inflected forms like
#             'tried' aren't treated as equally rare as truly obscure words.  See
#             dict/SOURCES.md for why both distinctions matter.
#
# Input format for each guess:
#   Use '+' before a letter for GREEN, '-' before a letter for YELLOW, and plain letters for GREY.
#   Example for guess 'crane' where r is green, a is yellow, others grey:
#       "+r -a c n e" (spaces optional)
#
#   Enter 'x' to exit.

def wordle_interactive(dic: List[str], dic_freq: Dict[str, int]):
    # Symbols for board rendering / parsing
    green  = "+"
    yellow = "-"
    grey   = "."

    # State across guesses
    yellow_letters: Dict[str, List[int]] = {}   # {letter: [banned_indices]}
    green_letters = grey * 5                    # the 5 known greens ('.' where unknown)

    # Per-letter count constraints inferred across guesses:
    #   min_counts[c] = minimum number of times c must occur in the answer
    #   max_counts[c] = maximum number of times c can occur in the answer
    min_counts = defaultdict(int)
    max_counts = defaultdict(lambda: 5)         # start generous; we will tighten

    wordle_game_board = ""

    # Words outside dic_freq sink below every ranked word, whatever scale dic_freq uses.
    unranked_sink = max(dic_freq.values(), default=0) + 1

    def rank(word: str) -> int:
        return dic_freq.get(word, unranked_sink)

    while green_letters.count(grey) > 0:
        t = "enter row of 5 chars (use + for green, - for yellow, plain for grey; 'x' to quit) > "
        entry = input(t).strip()
        if entry.lower() == "x":
            return

        # Normalize: remove spaces
        entry = entry.replace(" ", "")

        # Parse the mixed stream of flags and letters into:
        #   letters[0..4] and statuses[0..4] where status in ['+','-','.']
        # Parse into LOCAL structures first; only commit to the running
        # green_letters/yellow_letters state once the whole entry validates,
        # so a malformed guess can't corrupt state built up from earlier guesses.
        letters = []
        statuses = []
        pending_green = {}   # {index: char}
        pending_yellow = []  # [(char, index)]
        parse_error = None
        flag = None
        index_into_actual_word = 0
        i = 0
        while i < len(entry):
            ch = entry[i]
            if ch == green:
                flag = green
                i += 1
                continue
            if ch == yellow:
                flag = yellow
                i += 1
                continue
            # ch is a letter
            if not ch.isalpha():
                i += 1
                continue
            ch = ch.lower()

            if index_into_actual_word >= 5:
                parse_error = f"position {index_into_actual_word} is out of range (0-4)"
                break

            letters.append(ch)
            if flag == green:
                statuses.append(green)
                pending_green[index_into_actual_word] = ch
                flag = None
            elif flag == yellow:
                statuses.append(yellow)
                pending_yellow.append((ch, index_into_actual_word))
                flag = None
            else:
                statuses.append(grey)
            index_into_actual_word += 1
            i += 1

        if parse_error:
            print(f"✋ Error: {parse_error}")
            continue

        if len(letters) != 5 or len(statuses) != 5:
            print("✋ Parse error: please provide exactly 5 letters, using '+' for green and '-' for yellow.")
            print(f"   Parsed {len(letters)} letters and {len(statuses)} statuses from: '{entry}'")
            continue

        # Entry is fully valid; now commit to the running board state.
        for idx, ch in pending_green.items():
            green_letters = replace_char_at_index(green_letters, ch, idx)
        for ch, idx in pending_yellow:
            yellow_letters.setdefault(ch, []).append(idx)

        # Build per-guess evidence to update global min/max counts correctly (handles duplicates)
        non_grey = Counter()       # letters marked green or yellow in THIS guess
        grey_in_guess = Counter()  # letters marked grey in THIS guess

        for idx, c in enumerate(letters):
            if statuses[idx] in (green, yellow):
                non_grey[c] += 1
            else:
                grey_in_guess[c] += 1

        # Update min/max counts from this guess
        for c in set(letters):
            # At least this many in the answer
            min_counts[c] = max(min_counts[c], non_grey[c])
            
            # Handle grey letters correctly
            if grey_in_guess[c] > 0:
                # If any grey of c in this guess, then total occurrences in the answer
                # cannot exceed the *non_grey* count we saw for c in this guess
                max_counts[c] = min(max_counts[c], non_grey[c])
                
                # Special case: if all instances of c in this guess are grey, then c is not in the answer
                if non_grey[c] == 0:
                    max_counts[c] = 0

        # Derive a strict "forbidden" set from max_counts==0 (not a blanket "unused")
        forbidden = {c for c, mx in max_counts.items() if mx == 0}

        # For display
        just_5_letters = "".join(letters)
        map_of_green_and_yellow_positions = "".join(statuses)

        wordle_game_board += just_5_letters + '\n'
        wordle_game_board += map_of_green_and_yellow_positions + '\n'

        print("----- your entry -----")
        print(wordle_game_board)
        print("-----")

        # De-duplicate yellow banned indices
        for k in yellow_letters:
            yellow_letters[k] = sorted(set(yellow_letters[k]))

        # Now filter candidates
        good_words: List[str] = []
        for word in dic:
            ok = True

            # 1) forbid letters outright
            if any(c in forbidden for c in word):
                continue

            # 2) greens must match
            for idx, gc in enumerate(green_letters):
                if gc != grey and word[idx] != gc:
                    ok = False
                    break
            if not ok:
                continue

            # 3) yellows: must be present, but not at any banned index
            for y, banned_idxs in yellow_letters.items():
                if y not in word:
                    ok = False
                    break
                if any(word[i] == y for i in banned_idxs):
                    ok = False
                    break
            if not ok:
                continue

            # 4) per-letter min/max (handles duplicates & greys correctly)
            wc = Counter(word)

            # meet mins
            for c, mn in min_counts.items():
                if wc[c] < mn:
                    ok = False
                    break
            if not ok:
                continue

            # not exceed maxes
            for c, mx in max_counts.items():
                if wc[c] > mx:
                    ok = False
                    break
            if not ok:
                continue

            good_words.append(word)

        # Sort by frequency rank (lower is better)
        good_words.sort(key=rank)

        print("----- possible solutions -----")
        print(f"There are {len(good_words)} possible words that could solve the puzzle.")
        for index, word in enumerate(good_words[:12]):
            print(word, ", rank:", rank(word))
        print("----- end of list -----\n")


############################################################################################################
######  Wordle: scoring helpers for choosing starting words
############################################################################################################

def answer_pool_letter_stats(answer_pool: List[str]) -> Tuple[List[List[int]], List[int]]:
    """Letter statistics of the words we're scoring guesses against.

    Returns positional[slot][letter] -- how many answers have that letter in that
    slot -- and occurrences[letter], the letter's total count across the pool
    (counting repeats, so 'geese' contributes 3 to 'e').
    """
    positional = positional_letter_counts(answer_pool)
    occurrences = [0] * 26
    for word in answer_pool:
        for ch in word:
            occurrences[ord(ch) - ord("a")] += 1
    return positional, occurrences


def exact_starting_word_score(
    word: str, positional: List[List[int]], occurrences: List[int], pool_size: int
) -> float:
    """A word's expected score against a random answer from the pool.

    Same quantity the old Monte Carlo loop estimated -- 5 points per letter
    landing in the right slot, 1 per letter of the answer the word contains --
    but summed over the whole pool instead of sampled from it, so it is exact and
    carries no noise.  Sampling 1,000 trial answers had a standard deviation of
    ~0.15 on a spread of under 1.0 across the top 200 sets, which meant the
    ranking it produced was mostly luck.

    A set's score is just the sum of its words' scores: neither term in the
    original loop couples one word to another, so nothing here measures how well
    the words work *together*.  That job belongs entirely to the coverage
    constraints applied when the sets are built.
    """
    greens = 5 * sum(positional[i][ord(ch) - ord("a")] for i, ch in enumerate(word))
    presence = sum(occurrences[ord(ch) - ord("a")] for ch in set(word))
    return (greens + presence) / pool_size


def letter_mask(word: str) -> int:
    """The word's letter set as a 26-bit mask; 'a' is bit 0."""
    mask = 0
    for ch in word:
        mask |= 1 << (ord(ch) - ord("a"))
    return mask


def group_words_by_letter_set(words5: List[str]) -> Dict[int, List[str]]:
    """Eligible opening words grouped by letter set (a 26-bit mask).

    Only words with five *distinct* letters can pull their weight as an opener,
    and words ending in 's' are dropped because plurals are rarely the answer.
    Anagrams share a mask and so collapse into a single bucket, which is what
    makes the combination search below tractable: 'least' and 'steal' cover
    exactly the same letters, so they are interchangeable for coverage purposes.
    """
    groups: Dict[int, List[str]] = defaultdict(list)
    for word in words5:
        if len(set(word)) == 5 and not word.endswith("s"):
            groups[letter_mask(word)].append(word)
    return groups


def positional_letter_counts(words5: List[str]) -> List[List[int]]:
    """counts[position][letter index] = how many words have that letter there."""
    counts = [[0] * 26 for _ in range(5)]
    for word in words5:
        for i, ch in enumerate(word):
            counts[i][ord(ch) - ord("a")] += 1
    return counts


def pick_best_placed_anagram(candidates: List[str], counts: List[List[int]]) -> str:
    """Of a bucket of anagrams, the one whose letters sit in their commonest slots.

    All anagrams of a mask are equally good at covering letters, but they differ
    on green (exact-position) hits, so prefer the arrangement most likely to
    land letters where answers actually put them.
    """
    return max(
        candidates,
        key=lambda w: sum(counts[i][ord(ch) - ord("a")] for i, ch in enumerate(w)),
    )


def pick_representative_word(bucket: List[str], counts: List[List[int]], familiar: set) -> str:
    """The word to stand for a letter set, preferring one the player will know.

    Anagrams cover identical letters, so where a bucket holds a familiar spelling
    there is no reason to put the obscure one forward: 'least' does the same work
    as 'tesla'.  Only the arrangement of the letters is given up, and that is
    worth far less than being able to recognise the word.
    """
    known = [word for word in bucket if word in familiar]
    return pick_best_placed_anagram(known or bucket, counts)


def build_starting_word_search_space(
    words5: List[str],
) -> Tuple[Dict[int, List[str]], List[List[int]], List[int], List[List[int]]]:
    """The lookup tables both combination searches below share.

    Returns the mask->words groups, the positional letter counts used to pick
    among anagrams, the letter search order (rarest first), and, per letter, the
    masks that contain it.
    """
    groups = group_words_by_letter_set(words5)
    counts = positional_letter_counts(words5)
    masks = list(groups)

    # Rarest letter first: the earlier a letter forces a decision, the sooner
    # hopeless branches die.
    letter_frequency = [0] * 26
    for mask in masks:
        for letter in range(26):
            if mask >> letter & 1:
                letter_frequency[letter] += 1
    letter_order = sorted(range(26), key=lambda letter: letter_frequency[letter])

    masks_containing: List[List[int]] = [[] for _ in range(26)]
    for mask in masks:
        for letter in range(26):
            if mask >> letter & 1:
                masks_containing[letter].append(mask)

    return groups, counts, letter_order, masks_containing


############################################################################################################
######  Wordle: the candidate 4-word sets themselves
######
######  Both searches below build combinations directly rather than drawing words at
######  random and throwing away the ones that don't fit.  Rejection sampling can't
######  work here: fewer than one in a million random 4-word draws reaches 19 unique
######  letters, so 50,000 random draws typically produce *nothing*.  Building them
######  means every combination produced is a keeper, and no combination repeats.
######
######  Both walk *letters* rather than words, rarest letter first.  At each step the
######  rarest still-uncovered letter is either given up on ("skipped") or covered by
######  the next word chosen.  That gives every combination exactly one construction
######  order, which is what rules out duplicates.  Two budgets bound the search: at
######  most `set_size * 5 - min_unique_letters` letters may be shared between the
######  chosen words, and at most `26 - min_unique_letters` letters may be skipped.
############################################################################################################

def enumerate_starting_word_sets(
    words5: List[str],
    set_size: int = 4,
    min_unique_letters: int = 19,
    required_letters: str = "",
) -> Iterator[List[str]]:
    """Yield every distinct combination of `set_size` openers, once each.

    `required_letters` narrows the results to sets whose words between them cover
    every one of those letters -- 'aeiouy' to insist on the vowels, say.

    Exhaustive, deterministic, and a generator because the full space is far too
    big to hold: 1,309,058 combinations at `min_unique_letters=20` (~110s to
    walk) and 158,312,403 at 19 (~56 min).  Consume it with itertools.islice
    unless you really do want all of them -- `sample_starting_word_sets` is the
    better choice for feeding the scorer.
    """
    groups, counts, letter_order, masks_containing = build_starting_word_search_space(words5)
    required = letter_mask(required_letters)
    chosen: List[int] = []

    def search(
        position: int,
        union: int,
        skipped: int,
        skips_left: int,
        shared_left: int,
        decided: Dict[int, int],
    ) -> Iterator[List[str]]:
        words_left = set_size - len(chosen)
        if not words_left:
            if union & required == required:
                yield [pick_best_placed_anagram(groups[m], counts) for m in chosen]
            return

        # Required letters are mostly common ones, so they sit at the end of the
        # rarest-first walk and rarely get refused a skip before the words run
        # out.  This is the check that actually prunes.
        if (required & ~union).bit_count() > 5 * words_left:
            return

        for index in range(position, 26):
            letter = letter_order[index]
            if union >> letter & 1:
                continue

            # Skipping a letter has to bar it from every later word too, or the
            # same combination gets reached twice: once by skipping the letter
            # and once by covering it.
            if skips_left > 0 and not required >> letter & 1:
                yield from search(index + 1, union, skipped | 1 << letter, skips_left - 1, shared_left, decided)

            for mask in masks_containing[letter]:
                if mask & skipped:
                    continue
                overlap = mask & union
                shared = overlap.bit_count()
                if shared > shared_left:
                    continue
                # A letter the words share sits in two of them, so either one
                # could have been the word that covered it -- two routes to the
                # same combination.  Keep only the route that took the lower
                # mask first.
                if overlap and any(
                    mask < decided[bit] for bit in range(26) if overlap >> bit & 1 and bit in decided
                ):
                    continue
                chosen.append(mask)
                yield from search(
                    index + 1, union | mask, skipped, skips_left, shared_left - shared, {**decided, letter: mask}
                )
                chosen.pop()
            return          # this letter was the one decision point at this depth

    yield from search(0, 0, 0, 26 - min_unique_letters, set_size * 5 - min_unique_letters, {})


############################################################################################################
######  Wordle: picking the best set
######
######  The score is exact and adds up over the four words, so the best set can be found
######  outright instead of sampled: sort the candidate words by score, walk combinations
######  best-first, and abandon a branch as soon as even four perfect remaining words
######  couldn't catch the worst result already held.  That searches the whole space --
######  all 158m sets at 19 letters -- in well under a minute, and the answer is provably
######  the best rather than the luckiest of a sample.
############################################################################################################

# How common a word must be to count as one the player knows, on the Zipf scale.
# Only used to widen the Wordle answer list, which is the real basis of familiarity,
# so a strict limit here doesn't strand common words -- it just adds fewer non-answers.
# 4.0 is where the band stops being plain inflections ('years', 'asked', 'works') and
# starts filling with proper nouns and brands ('moses', 'tesla', 'kraft').
FAMILIAR_WORD_MIN_ZIPF = 4.0


def build_familiar_words(min_zipf: float = FAMILIAR_WORD_MIN_ZIPF) -> List[str]:
    """Words worth recommending out loud: Wordle answers plus common word forms.

    The answer list carries most of the weight, being curated for exactly this
    -- words an ordinary player knows.  The frequency list then adds forms that
    are perfectly familiar but never used as answers, like 'tried' and 'asked'.
    Neither source alone suffices: the answer list omits inflections, and no
    frequency list is a good enough judge of familiarity to be trusted alone.
    """
    familiar = set(load_wordle_answers())
    familiar |= {word for word, zipf in load_word_zipf().items() if zipf >= min_zipf}
    return sorted(familiar)


# Four openers sharing no letter cover 20 of the 26, but that last letter has to be one
# of fjqvwxz, and those hardly ever turn up in an answer.  Repeating a common letter is
# worth more: the best 19-letter set beats the best 20-letter set 14.45 to 13.14 on the
# full dictionary.  Requiring the vowels costs almost nothing, since only a handful of
# letters go uncovered anyway.  ('n' needn't be required -- it earns its place unaided.)
STARTING_SET_MIN_UNIQUE_LETTERS = 19
STARTING_SET_REQUIRED_LETTERS = "aeiouy"


def find_best_starting_word_sets(
    words5: List[str],
    answer_pool: List[str],
    familiar_words: List[str] = None,
    max_unfamiliar: int = 0,
    set_size: int = 4,
    min_unique_letters: int = STARTING_SET_MIN_UNIQUE_LETTERS,
    required_letters: str = STARTING_SET_REQUIRED_LETTERS,
    top_n: int = 25,
) -> List[Tuple[float, List[str]]]:
    """The `top_n` highest-scoring sets, exactly, best first.

    Guesses come from `words5`; they are scored against `answer_pool`, the words
    that might actually be the answer.

    Anything outside `familiar_words` counts as obscure, and a set may hold at
    most `max_unfamiliar` of them -- pass None to stop caring.  Insisting on four
    everyday words is cheap: it costs about 0.8% of the best score and turns
    'shine bract flume podgy' (14.88) into 'slime broke chant pudgy' (14.76).  It
    is also much quicker, since the candidate list shrinks from 4,098 letter sets
    to 1,398.
    """
    positional, occurrences = answer_pool_letter_stats(answer_pool)
    pool_size = len(answer_pool)
    familiar = set(familiar_words) if familiar_words is not None else None

    # One representative word per letter set, scored and flagged for familiarity.
    candidates = []
    for mask, bucket in group_words_by_letter_set(words5).items():
        word = pick_representative_word(bucket, positional, familiar or set())
        obscure = 0 if familiar is None or word in familiar else 1
        candidates.append(
            (exact_starting_word_score(word, positional, occurrences, pool_size), mask, word, obscure)
        )
    candidates.sort(reverse=True)

    required = letter_mask(required_letters)
    best: List[Tuple[float, List[str]]] = []
    worst_kept = float("-inf")

    def search(start: int, chosen: List[str], union: int, total: float, obscure_used: int) -> None:
        nonlocal worst_kept
        words_left = set_size - len(chosen)

        if not words_left:
            if union.bit_count() >= min_unique_letters and union & required == required:
                best.append((total, list(chosen)))
                best.sort(key=lambda pair: pair[0], reverse=True)
                del best[top_n:]
                if len(best) == top_n:
                    worst_kept = best[-1][0]
            return

        # Can what's left still reach the coverage we need?
        if union.bit_count() + 5 * words_left < min_unique_letters:
            return
        if (required & ~union).bit_count() > 5 * words_left:
            return

        for index in range(start, len(candidates)):
            score, mask, word, obscure = candidates[index]
            # Candidates are sorted best first, so once the most optimistic
            # finish falls short of what we already hold, so does every one after.
            if total + score * words_left <= worst_kept:
                return
            if obscure_used + obscure > max_unfamiliar:
                continue
            chosen.append(word)
            search(index + 1, chosen, union | mask, total + score, obscure_used + obscure)
            chosen.pop()

    search(0, [], 0, 0.0, 0)
    return best


############################################################################################################
######  Wordle: ordering the four words within a set
######
######  The additive score above is deliberately order-blind -- a set's score is the same
######  whichever of the 4! ways you play its words, because it is a plain sum.  But playing
######  order matters in practice: an order that nails down the vowels early, or that narrows
######  the field fast, gets you closer to the answer sooner, even though it ends up testing
######  the exact same letters either way.  This section scores *orderings*, not sets, and
######  re-ranks a shortlist of already-good sets by their best ordering.
######
######  The metric is the standard "expected partition size": for a given prefix of words,
######  group the answer pool by the feedback pattern that prefix would produce, and take
######  E[remaining] = sum(group_size^2) / N.  A low value means the prefix usually narrows
######  the field to a small handful of answers; a high value means most answers still look
######  alike after those words.  This is computed against the real green/yellow/grey rule,
######  including its duplicate-letter handling (wordle_feedback_pattern), not a same-letter
######  count -- the two disagree whenever a guess repeats a letter the answer has only once.
############################################################################################################

def wordle_feedback_pattern(guess: str, answer: str) -> Tuple[int, int, int, int, int]:
    """One guess's marks against one answer: 2 green, 1 yellow, 0 grey, per slot.

    Matches Wordle's actual duplicate-letter rule rather than a naive per-letter
    comparison: greens are resolved first and consume a letter from the answer,
    and only what's left over is available to satisfy yellows.  That is what
    stops a guess like 'sassy' from getting two yellow s's against an answer
    that holds only one spare 's'.
    """
    result = [0, 0, 0, 0, 0]
    remaining = list(answer)
    for i in range(5):
        if guess[i] == answer[i]:
            result[i] = 2
            remaining[i] = None
    leftover = Counter(c for c in remaining if c is not None)
    for i in range(5):
        if result[i] == 2:
            continue
        c = guess[i]
        if leftover.get(c, 0) > 0:
            result[i] = 1
            leftover[c] -= 1
    return tuple(result)


def word_patterns_against_pool(word: str, answer_pool: List[str]) -> List[int]:
    """Each answer's feedback pattern for `word`, packed into a single 0..242 code.

    Packing the 5 base-3 digits (grey/yellow/green) into one int makes patterns
    cheap to fold into a running per-answer signature across several words --
    see compute_order_metrics.
    """
    packed = []
    for answer in answer_pool:
        value = 0
        for digit in wordle_feedback_pattern(word, answer):
            value = value * 3 + digit
        packed.append(value)
    return packed


def compute_order_metrics(
    order: Tuple[str, ...], pattern_lookup: Dict[str, List[int]], pool_size: int, required_mask: int
) -> Dict[str, list]:
    """Per-prefix-length stats for playing `order`'s words in that sequence.

    expected_remaining[k] is E[answers remaining] after the first k+1 words, and
    required_missing[k] is how many letters of `required_mask` (the vowels, for
    the default search) are *still* uncovered at that point -- 0 once they're
    all in.  A count rather than a yes/no: covering all 6 vowels in 2 five-letter
    words needs about 3 vowels apiece, which the words that actually win on
    score rarely have, so a strict "all by word 2?" gate is met by ~none of
    them and would silently stop distinguishing orderings at all.
    """
    signature = [0] * pool_size
    covered = 0
    required_size = required_mask.bit_count()
    expected_remaining = []
    required_missing = []
    for word in order:
        signature = [sig * 243 + p for sig, p in zip(signature, pattern_lookup[word])]
        group_sizes = Counter(signature)
        expected_remaining.append(sum(size * size for size in group_sizes.values()) / pool_size)
        covered |= letter_mask(word)
        required_missing.append(required_size - (covered & required_mask).bit_count())
    return {"expected_remaining": expected_remaining, "required_missing": required_missing}


def order_quality_key(metrics: Dict[str, list]) -> tuple:
    """Sort key for orderings, low is better -- see the section docstring above.

    Priority order: fewest required letters (vowels) still missing after word
    2 -- the explicit "preferably within the top two" ask, graded rather than
    all-or-nothing; then reward a first word that narrows fast on its own (the
    "three letters right away" case); then word 2's narrowing, then word 3's.
    Word 4 is never a useful tiebreaker, since by then every ordering has
    tested the same four words and converges to the same value.
    """
    er = metrics["expected_remaining"]
    return (metrics["required_missing"][1], er[0], er[1], er[2])


def best_order_for_set(
    words: List[str], pattern_lookup: Dict[str, List[int]], pool_size: int, required_mask: int
) -> Tuple[Tuple[str, ...], Dict[str, list]]:
    """The one ordering of `words` (out of 4! = 24) with the best order_quality_key."""
    best_key = None
    best_order: Tuple[str, ...] = tuple(words)
    best_metrics: Dict[str, list] = {}
    for order in itertools.permutations(words):
        metrics = compute_order_metrics(order, pattern_lookup, pool_size, required_mask)
        key = order_quality_key(metrics)
        if best_key is None or key < best_key:
            best_key, best_order, best_metrics = key, order, metrics
    return best_order, best_metrics


def order_and_rerank_starting_word_sets(
    scored_sets: List[Tuple[float, List[str]]], answer_pool: List[str], required_letters: str
) -> List[Dict]:
    """Re-rank `scored_sets` (score, words) by their best ordering, best first.

    This is a heuristic layered on top of the exact additive search, not a
    replacement for it: `scored_sets` should already be the top sets by that
    score (find_best_starting_word_sets), since re-ordering is only applied to
    -- and can only choose among -- the sets handed to it.  A set that scores
    slightly lower on the sum but orders much better than everything in this
    shortlist will never be seen if it didn't make the shortlist.
    """
    pool_size = len(answer_pool)
    required_mask = letter_mask(required_letters)
    pattern_lookup: Dict[str, List[int]] = {}

    results = []
    for score, words in scored_sets:
        for word in words:
            if word not in pattern_lookup:
                pattern_lookup[word] = word_patterns_against_pool(word, answer_pool)
        order, metrics = best_order_for_set(words, pattern_lookup, pool_size, required_mask)
        results.append({"score": score, "order": order, "metrics": metrics})

    results.sort(key=lambda r: order_quality_key(r["metrics"]) + (-r["score"],))
    return results


# How many of the top additive-score sets to hand to the order-quality re-ranker, as a
# multiple of top_n and capped at ORDER_RERANK_POOL_SIZE.  Wider than what's displayed, so a
# strong ordering has more sets to be found among -- but it has to scale with top_n rather
# than being a flat floor: find_best_starting_word_sets gets much slower to collect a wide
# top-K as max_unfamiliar grows (the candidate pool it draws from grows too), and a flat
# 150-set floor measured at ~30s with max_unfamiliar=0 took over four minutes at
# max_unfamiliar=2 for a request that only wanted the top 3.
ORDER_RERANK_MULTIPLIER = 6
ORDER_RERANK_POOL_SIZE = 150


def find_optimal_starting_words_for_wordle(
    words5: List[str],
    answer_pool: List[str],
    familiar_words: List[str] = None,
    max_unfamiliar: int = 0,
    top_n: int = 25,
    min_unique_letters: int = STARTING_SET_MIN_UNIQUE_LETTERS,
    required_letters: str = STARTING_SET_REQUIRED_LETTERS,
    order_rerank_pool_size: int = ORDER_RERANK_POOL_SIZE,
) -> None:
    print("find_optimal_starting_words_for_wordle")
    allowance = (
        "everyday words only"
        if not max_unfamiliar
        else f"up to {max_unfamiliar} obscure word(s), marked *"
    )
    print(
        f"searching every set of 4 words covering {min_unique_letters}+ letters "
        f"including '{required_letters}', {allowance},"
    )
    print(f"scored against {len(answer_pool):,} possible answers...")
    if max_unfamiliar:
        # Allowing obscure words lets the whole 4,098-mask candidate pool compete
        # instead of the 1,398 that pass the familiarity filter, and the
        # branch-and-bound's pruning is weaker across that much bigger field --
        # measured at ~100s for just the top set, well past the few seconds the
        # everyday-words-only search takes.
        print("note: obscure words allowed, so this search is much slower -- expect a couple of minutes.")

    pool_size_for_rerank = max(top_n, min(order_rerank_pool_size, top_n * ORDER_RERANK_MULTIPLIER))
    start = time.time()
    best = find_best_starting_word_sets(
        words5,
        answer_pool,
        familiar_words=familiar_words,
        max_unfamiliar=max_unfamiliar,
        min_unique_letters=min_unique_letters,
        required_letters=required_letters,
        top_n=pool_size_for_rerank,
    )
    print(f"searched in {time.time() - start:.1f}s, found {len(best)} candidate set(s)")

    print(f"ranking their best word order (of the {len(best)} shortlisted, by their exact score)...")
    start = time.time()
    ranked = order_and_rerank_starting_word_sets(best, answer_pool, required_letters)
    print(f"ordered in {time.time() - start:.1f}s")
    print(
        "note: only the shortlist above was reordered -- this is a heuristic re-rank of "
        "already-strong sets, not a re-optimization of the whole search over orderings."
    )

    familiar = set(familiar_words) if familiar_words is not None else None
    required_count = len(set(required_letters))

    print()
    print("final ranking!! (ordered to cover the required letters early and narrow the field fast)")
    for rank, result in enumerate(ranked[:top_n], start=1):
        order = result["order"]
        er = result["metrics"]["expected_remaining"]
        covered_by_2 = required_count - result["metrics"]["required_missing"][1]
        order_str = " → ".join(f"{w}{'' if familiar is None or w in familiar else '*'}" for w in order)
        remaining_str = " → ".join(f"{v:.1f}" for v in er)
        print(
            f"{rank}) {order_str}  -- set score: {result['score']:.2f}, "
            f"{len(set(''.join(order)))} letters, required letters by #2: {covered_by_2}/{required_count}, "
            f"E[answers remaining]: {remaining_str}"
        )
    print()


############################################################################################################
######  U/I stuff
############################################################################################################

def prompt_int_with_default(prompt_text: str, default: int, allow_zero: bool = False) -> int:
    raw = input(f"{prompt_text} [suggested: {default}, hit enter to accept] > ").strip()
    if not raw:
        return default
    try:
        value = int(raw)
    except ValueError:
        print(f"  Not a whole number; using suggested value {default}.")
        return default
    if value < 0 or (value == 0 and not allow_zero):
        print(f"  Must be {'zero or more' if allow_zero else 'positive'}; using suggested value {default}.")
        return default
    return value


def main():
    print("python version:", sys.version)
    print("Let's get started...")
    raw_dictionary_list = load_all_words()
    raw_dictionary_list5 = [ x for x in raw_dictionary_list if len(x) == 5 ]
    len_raw_dictionary_list = len(raw_dictionary_list)
    len_raw_dictionary_list5 = len(raw_dictionary_list5)

    dic_freq, dic_freq5 = load_all_words_freq( word_length=5 )
    len_dic_freq, len_dic_freq5 = len(dic_freq), len(dic_freq5)

    dic_tri = load_dictionary_as_tri(raw_dictionary_list) # simple list of all words

    print(f"counts: \nflat dict: {len_raw_dictionary_list}, \n5 letter dict: {len_raw_dictionary_list5}, \ntop 5k by freq: {len_dic_freq}, \nby freq 5 letter: {len_dic_freq5}")
    # temp = sorted( dic_freq.items(), key = lambda item: item[1] )
    # for pair in temp:
    #     print(pair[1], pair[0])

    # find_optimal_starting_words_for_wordle(words5)
    # exit()

    # entry = "rev ail muh toy"  # requires 2 words
    # entry = "qio,ems,cut,nhv"  # 3 words
    # entry = "usn,gli,jyo,cth"  # 2 words
    # entry = "rvh,eai,wnp,mog"
    # entry = "sxi,rdh,cfn,aet"
    # entry = "dpa,mil,ntc,rou"
    # entry = "wfa,ing,hdt,sbe"
    # 25-06-01 actual
    # entry = "aog vit swb ner"   # 3 words
    # entry = "tom,rxl,ehp,vak" # 'porthole', 'eve', 'eke', 'exam'], but hem/em found porthole, evoke, exam
    # entry = "fmh,tde,icl,ysu"
    # entry = "sie,zth,aqn,blu"
    # entry = "nks,cut,aro,hbl"

    # entry = "aky,jtb,sil,uof"
    # letter_boxed(entry)
    # exit()

    print("Game menu:")
    print("  w   Wordle")
    print("  b   Spelling Bee")
    print("  l   Lettered Box")
    print("  f   Find optimal starting words for Wordle")
    print("  q   Quit")

    while True:
        choice = input("which game? > ")
        try:
            if choice == "w":
                # Candidate answers must come from Wordle's own curated list, not all of
                # NWL2023 -- otherwise the assistant can suggest a word Wordle would never
                # pick, or never guess. Rank by word-form frequency, not lemma frequency,
                # so inflected forms like 'tried' aren't scored as if they were rare.
                wordle_interactive( load_wordle_answers(), load_word_form_ranks() )
            elif choice == 'b': # spelling bee
                game_input = input("Spelling Bee: required letter, optional letters> ")
                spelling_bee( game_input, dic_tri )
            elif choice == 'l': # Lettered Box
                game_input = input("Lettered Box: four sets of four letters> ")
                letter_boxed( game_input )  # loads its own word list internally
            elif choice == 'f':
                max_unfamiliar = prompt_int_with_default(
                    "Obscure words allowed per set (0 = everyday words only, fast; "
                    "1+ = slower, a couple of minutes)",
                    0,
                    allow_zero=True,
                )
                top_n = prompt_int_with_default("How many of the best sets to list", 25)
                # Guess anything the game accepts, but score against the words it can
                # actually pick as the answer.  Both lists come from Wordle itself
                # rather than the Scrabble dictionary -- see dict/SOURCES.md.
                find_optimal_starting_words_for_wordle(
                    load_wordle_guesses(),
                    load_wordle_answers(),
                    familiar_words=build_familiar_words(),
                    max_unfamiliar=max_unfamiliar,
                    top_n=top_n,
                )
            elif choice == 'q':
                break
            else:
                print(f"Unrecognized choice: {choice!r}")
        except Exception as e:
            print(f"⚠️  '{choice}' hit an error and was aborted: {e}")

if __name__ == '__main__':
    main()

