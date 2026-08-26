import re
import time
from pathlib import Path

DICT_DIR = Path(__file__).resolve().parent.parent / "dict"


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


def letter_boxed(entry):
    print("Starting Letter Boxed")

    # Filter valid words, i.e., test whether the word is part of a valid solution to Letter Boxed game.
    def is_valid_word(word):
        if len(word) < 3:
            return False
        if any(c not in all_letters for c in word):
            return False
        for a, b in zip(word, word[1:]):
            if letter_to_side[a] == letter_to_side[b]:
                return False
        return True

    # recursive attempt to add another word to a growing list of words ("word_sequence") that solve the puzzle.
    # NOTE: best_word_count keeps track of the smallest number of words found to solve the puzzle, as yet.
    # NOTE: since python has no means of passing a value type by reference, our "hack" is to encapsulate
    #   the actual best_word_count in a single-value list which is indeed passed by reference
    def add_another_word(word_sequence, used_chars_so_far, best_word_count):
        most_recent_added_word = word_sequence[-1]
        last_letter = most_recent_added_word[-1]

        # Note that in some cases, there will be no valid words starting with one of the valid letters
        if last_letter not in words_starting_with:
            return

        for word in words_starting_with[last_letter]:
            if word in word_sequence:
                break
            # Determine how many characters in common between used_chars_so_far and the new word.
            # We hope for no common chars, (or at least a very small nummber
            max_common_chars = 2
            common_chars = used_chars_so_far & set(word)
            if len(common_chars) <= max_common_chars:
                new_used_chars_so_far = used_chars_so_far | set(word)
                new_word_sequence = word_sequence + [word]
                # if the total number of letters used is 12, then clearly we've found a solution to the puzzle.
                if len(new_used_chars_so_far) == 12:
                    if len( new_word_sequence ) <= best_word_count[0] and len( new_word_sequence ) <= 3:
                        letter_count = sum(len(w) for w in new_word_sequence)
                        print(f"Solution: {new_word_sequence},   total letters: {letter_count}")
                        best_word_count[0] = len( new_word_sequence )
                    return
                else:
                    add_another_word(new_word_sequence, new_used_chars_so_far, best_word_count)

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
    all_letters = set(letter for side in sides for letter in side)

    # Tag each letter with the name of its respective side of the box:
    letter_to_side = {}
    side_names = ['top', 'right', 'bottom', 'left']
    for i, side in enumerate(sides):
        for letter in side:
            letter_to_side[letter] = side_names[i]

    # Build filtered word list
    # Start with the raw list of strings representing all English words
    dictionary = load_all_words()
    valid_words = [w for w in dictionary if is_valid_word(w)]

    # starts_with is dictionary, where key is a letter and value is a
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
    # begin the search for solutions, starting with longest words
    best_word_count = [1000]
    for word in valid_words:
        # note, I think its provable that if word len is less than 7, then there will be no new solutions
        #  (with JUST ONE or TWO WORDS), because we've already tried all the longer words that follow
        #  the shorter one in the solution word sequence.
        if len( word ) < 7:
            break
        add_another_word( [word], set( word ), best_word_count )

    elapsed = time.time() - start
    print(f"Elapsed time: {int(elapsed // 60)} minutes, {int(elapsed % 60)} seconds")



def main():
    print("Let's get started...") 

    # enter here the actual letters on the four sides of the Letter Boxed board, as in this example:
    entry = "sxi,rdh,cfn,aet"  # "aog,vit,swb,ner" 
    letter_boxed(entry)

    print("completed")
    exit()

if __name__ == '__main__':
    main()
