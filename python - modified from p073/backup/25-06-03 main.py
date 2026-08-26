import re
import copy
import random
from operator import is_not

import time

############################################################################################################
######  functions purely for dictionary of words, loading it, searching it, etc.
############################################################################################################

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

    if len(substrings) == 0:  return # base case

    for s in substrings:
        new_str = str_so_far + s

        if isSubstringInDict(new_str, d):
            if isInDict(new_str, d):
                results.append(new_str)
                # continue

            new_list = substrings.copy()
            new_list.remove(s)
            if len(new_list) == 0:  return
            find_words_from_substring_list(new_str, new_list, d, results)

    return


def find_words_that_exhaust_the_list(str_so_far: str, substrings, d: dict, results: list, full_words: list):

    if len(substrings) == 0:  return # base case

    for s in substrings:
        new_str = str_so_far + s

        if isSubstringInDict(new_str, d):
            if isInDict(new_str, d):
                results.append(new_str)
                full_words.append(new_str)

            new_list = substrings.copy()
            new_list.remove(s)
            if len(new_list) == 0:  return
            find_words_from_substring_list(new_str, new_list, d, results)

    return


def load_dictionary(word_length: int = None):
    """
    Loads words from the dictionary file into a nested dictionary structure.
    If word_length is specified, only words of that length are included.
    """
    dic = {}
    content = load_all_words()

    for word in content:
        if any(not c.isalpha() for c in word):  # Ensure the word is valid
            print(f"Houston, we have a problem, erroneous character in dictionary text file, word: {word}")
            exit()

        if word_length is None or len(word) == word_length:  # Apply word length filter if provided
            insertIntoDict(word, dic)

    return dic

# returns a list of all words in english language
def load_all_words() -> list:
    files_to_read = ['dict/2of12inf.txt' ]
    content = []
    for f in files_to_read:
        with open(f, "r") as file:
            content = file.readlines()
        # remove whitespace characters like `\n` at the end of each line
        content = [x.strip() for x in content]
    return content



############################################################################################################
######  wordle

def wordle_filter(entry, words5):
    """
    Filters words that:
    - Match a given pattern (with '*' as wildcards).
    - Contain all characters in necessary_chars at least once (unless marked '-' for none).
    - Do NOT contain any characters in disallowed_chars.
    """

    # Split using space or comma (or both), max 3 parts
    parts = re.split(r"[ ,]+", entry.strip(), maxsplit=2)

    pattern = parts[0]
    necessary_chars = "" if len(parts) > 1 and parts[1] == "-" else (parts[1] if len(parts) > 1 else "")
    disallowed_chars = parts[2] if len(parts) > 2 else ""

    # Convert pattern with '*' to regex pattern
    regex_pattern = "^" + pattern.replace("*", ".") + "$"

    # First round: match pattern and include all necessary chars
    filtered_words_first_round = [
        word for word in words5
        if re.fullmatch(regex_pattern, word)
        and all(char in word for char in necessary_chars)
    ]

    # Second round: exclude words containing any disallowed char
    filtered_words_final = [
        word for word in filtered_words_first_round
        if all(char not in word for char in disallowed_chars)
    ]

    print("wordle, possible words:\n", filtered_words_final)
    return filtered_words_final

def find_optimal_starting_words_for_wordle(words5):
    best_score = 0.0
    optimal_three_words = []
    number_of_trials = 10_000_000   # each trial encompasses:  try a 3 word collection, against a large num of possible wordle answers
    number_of_iterations_per_trial = 500 # number of random possible answers, assessed by the 3-word starting lines

    # a "trial" encompasses selection of three words as starting point, followed by scorring a huge
    #   number of possible answer words against those three
    for n in range(number_of_trials):
        three_words = []
        # pick the three word set
        for index in range(3):
            word = ""
            while True:
                word = random.choice(words5)
                all_letters = "".join(three_words) + word
                # disallow words ending in s (because every darn noun in the dict has a plural, which is unlikely to appear in wordle
                is_not_plural = word[4] != 's'
                #   and assure that all letters across the three words are unique
                are_all_unique = len(set(all_letters)) == (index+1)*5
                if is_not_plural and are_all_unique:
                    # we found a valid work to add to the "three words"
                    break
            three_words.append(word)
        score = 0
        for _ in range(number_of_iterations_per_trial):
            trial_word = random.choice(words5)
            for word in three_words:
                for index, char in enumerate(word):
                    if char == trial_word[index]:
                        score += 3 # actually, this is like a 3, because it will inherently get one more point below
            for char in trial_word:
                for word in three_words:
                    if char in word:
                        score += 1
        final_score = score / number_of_iterations_per_trial
        if final_score > best_score:
            best_score = final_score
            optimal_three_words = three_words
            print(f"three words: {three_words}, score = {best_score}")



############################################################################################################
######  spelling bee

# used for spelling bee, (and anything else?)
def spelling_bee_find_words_with_constraints(d: dict, possible_letters: str, required: str):
    results = []
    # assure that we've included the required char in the possible_letters search
    if not required in possible_letters: possible_letters += required

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

    necessary_char  = parts[0]
    optional_chars = parts[1]

    # print(f"nec: {necessary_char}, optional: {optional_chars}")
    matching_words = spelling_bee_find_words_with_constraints(dic, optional_chars, necessary_char)
    matching_words.sort()
    # print(f"\nWords that meet the constraints: {matching_words}")

    count = 0
    first_char = ""
    for word in matching_words:
        if len(word) >= 4:
            count += 1
            if word[0] != first_char:
                first_char = word[0]
                print( f"----{first_char}----" )
            print( f"{count}. {word}" )


############################################################################################################
######  letter box

    # search for words and in turn sequences of words that solve the puzzle.
    # the assumption, entering here, is that at least one letter was added to "word_so_far",
    #  before arriving, and next we'll either conclude that the word is a full word, or
    #  add another latter.
def recursive_search(full_dict,  # the original, complete dictionary
                     remaining_dict,  # correlates to progress exploring "word_so_far
                     letter_groups_scoring,  # new copy created and updated in each successive call
                     word_so_far,
                     most_recent_group,  # the index of the group from which latest letter was chosen
                     solution_so_far,  # the current word sequence being built (Not necessary successfully_
                     solutionS_so_far  # the collection of successful sequences found so far
                     ):
    for letter, (group_index, used_yet) in letter_groups_scoring.items():
        # verify that the letter is located in a valid group.
        #   also, not the aggressive approach:  we dont allow re-use of used letters!!
        #   this will give SUPER efficient results, minimal number of words!!!

        # debug temp
        # we need to try with and without assuring that the letter has not been used yet
        # if not used_yet and group_index != most_recent_group:
        if group_index != most_recent_group:
            if letter in remaining_dict:
                new_word_so_far = word_so_far + letter
                new_remaining_dict = remaining_dict[letter]
                new_letter_groups_scoring = copy.deepcopy(letter_groups_scoring)
                # mark this character as "used"!  (True)
                new_letter_groups_scoring[letter] = (group_index, True)

                # debug
                print(new_word_so_far)
                print()

                if "|" in new_remaining_dict and len(word_so_far) >= 3:
                    # OPTION 1: Accept the word as complete, even though we also may ba able to build a longer word
                    #   (OPTION 2 below, allows extending the current word with even more letters)
                    new_solution_so_far = solution_so_far + [new_word_so_far]
                    # debug temp
                    # print("found |, solution so far:" + str(solution_so_far) )

                    # if all the letters have been used, then we declare that we've found a new solution
                    if all(used for (_, used) in new_letter_groups_scoring.values()):
                        solutionS_so_far.append(new_solution_so_far)
                        print(solution_so_far)
                        print()
                        # return

                    else:
                        # Start a new word
                        for next_letter, (next_group_index, next_used_yet) in new_letter_groups_scoring.items():
                            if not next_used_yet and next_letter in full_dict:
                                recursive_search(full_dict,
                                                 full_dict[next_letter],
                                                 copy.deepcopy(new_letter_groups_scoring),
                                                 next_letter,
                                                 next_group_index,
                                                 new_solution_so_far,
                                                 solutionS_so_far)

                # OPTION 2: Regardless of "|", you can still continue building the current word
                recursive_search(full_dict,
                                 new_remaining_dict,
                                 new_letter_groups_scoring,
                                 new_word_so_far,
                                 group_index,
                                 solution_so_far,
                                 solutionS_so_far)

    return solutionS_so_far



def letter_box_search(dic, letter_groups):
    # letter tracking dictionary.
    # this dict contains letters as keys, and values of tuples: (group, used_yet?)
    #   where "group" is an index of the four sides of the box (each containing 4 letters) and
    #   where "used_yet?" tells us if the current level of recursion has used that letter yet
    letter_groups_scoring_starting_point = {}
    for index, letters_on_this_side in enumerate(letter_groups):
        for char in letters_on_this_side:
            letter_groups_scoring_starting_point[char] = (index, False)

    # a "solution" is a list of words, in order, that solve the puzzle
    solutions = []
    for letter in letter_groups_scoring_starting_point:
        group_index, _ = letter_groups_scoring_starting_point[letter]
        starting_letter_groups_scoring = copy.deepcopy(letter_groups_scoring_starting_point)
        starting_letter_groups_scoring[letter] = (group_index, True)

        if letter in dic:
            recursive_search(dic,
                             dic[letter],
                             starting_letter_groups_scoring,
                             letter,
                             group_index,
                             [],
                             solutions)

    for s in solutions:
        print(s)

    return solutions

def letter_box(entry, dic):
    # Split using space or comma (or both), max 3 parts
    letter_groups = re.split(r"[ ,]+", entry.strip(), maxsplit=3)

    word_sequence = letter_box_search(dic, letter_groups)

    word_sequence.sort()

    print(f"\nWords that meet the constraints: {word_sequence}")

############################################################################################################
######  letter box 2 (with MUCH more help from AI)

# def letter_box2(entry):
#     print("Starting Letter Boxed")
#
#     # Filter valid words, i.e., test whether the word is part of a valid solution to Letter Box
#     def is_valid_word(word):
#         if len(word) < 3:  return False
#         if any(c not in all_letters for c in word):
#             return False
#         for a, b in zip(word, word[1:]):
#             if letter_to_side[a] == letter_to_side[b]:
#                 return False
#         return True
#
#     # recursive attempt to add another word to a growing list ("word_sequence") that solve the puzzle
#     # NOTE: best_word_count keeps track of the smallest number of words used to solve the puzzle found as yet.
#     # NOTE: since python has no means of passing a value type by reference, our "hack" is to encapsulate
#     #   the actual best_word_count in a singly-value list
#     def add_another_word(word_sequence, used_chars_so_far, best_word_count):
#         most_recent_added_word = word_sequence[-1]
#         last_letter = most_recent_added_word[-1]
#         for word in words_starting_with[last_letter]:
#             if word in word_sequence: break
#             # Determine how many characters in common between used_chars_so_far and the new word.
#             # We hope for no common chars, (or at least a very small nummber
#             max_common_chars = 2
#             common_chars = used_chars_so_far & set(word)
#             if len(common_chars) <= max_common_chars:
#                 new_used_chars_so_far = used_chars_so_far | set(word)
#                 new_word_sequence = word_sequence + [word]
#                 # if the total number of letters used is 12, then clearly we've found a solution to the puzzle.
#                 if len(new_used_chars_so_far) == 12:
#                     if len( new_word_sequence ) <= best_word_count[0] and len( new_word_sequence ) <= 3:
#                         letter_count = sum(len(w) for w in new_word_sequence)
#                         print(f"Solution: {new_word_sequence},   total letters: {letter_count}")
#                         best_word_count[0] = len( new_word_sequence )
#                     return
#                 else:
#                     add_another_word(new_word_sequence, new_used_chars_so_far, best_word_count)
#
#     # Split using space or comma (or both), max 3 parts
#     sides = re.split(r"[ ,]+", entry.strip(), maxsplit=3)
#     # result is a data structure like...
#     # sides = [
#     #     ['a', 'b', 'c'],
#     #     ['d', 'e', 'f'],
#     #     ['g', 'h', 'i'],
#     #     ['j', 'k', 'l']
#     # ]
#
#     # simply a set of all necessary letters
#     all_letters = set(letter for side in sides for letter in side)
#
#     # Tag each letter to its respective side of the box in the Letter Box game
#     letter_to_side = {}
#     side_names = ['top', 'right', 'bottom', 'left']
#     for i, side in enumerate(sides):
#         for letter in side:
#             letter_to_side[letter] = side_names[i]
#
#     # Build filtered word list
#     # Start with a raw list of strings representing all English words
#     dictionary = load_all_words()
#     valid_words = [w for w in dictionary if is_valid_word(w)]
#
#     # starts_with is dictionary, where key is a letter and value is a
#     #   list of all valid_words that start with that letter
#     words_starting_with = {}
#     for word in valid_words:
#         first_letter = word[0]
#         if first_letter not in words_starting_with:
#             words_starting_with[first_letter] = []
#         words_starting_with[first_letter].append(word)
#
#     # For each of the letters in all_letters, sort the collection of words starting with that letter, longest through shortest
#     for letter in all_letters:
#         if letter in words_starting_with:
#             words = words_starting_with[letter]
#             words_sorted_starting_with_longest = sorted(words, key=len, reverse=True)
#             words_starting_with[letter] = words_sorted_starting_with_longest
#
#     start = time.time()
#
#     # sort in place, putting longest first
#     valid_words.sort(key=len, reverse=True)
#     # begin the search for solutions, starting with longest words
#     best_word_count = [1000]
#     for word in valid_words:
#         # note, I think its provable that if word len is less than 7, then there will be no new solutions
#         #  (with JUST ONE or TWO WORDS), because we've already tried all the longer words that follow
#         #  the shorter one in the solution word sequence.
#         if len( word ) < 7: break
#         add_another_word( [word], set( word ), best_word_count )
#
#     elapsed = time.time() - start
#     print(f"Elapsed time: {int(elapsed // 60)} minutes, {int(elapsed % 60)} seconds")


def letter_boxed(entry):
    print("Starting Letter Boxed")
    print("The Puzzle Content:", entry)

    # Filter valid words, i.e., test whether the word is part of a valid solution to Letter Boxed game.
    def is_valid_word(word):
        if len(word) < 3:  return False
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
        if last_letter not in words_starting_with:  return

        for word in words_starting_with[last_letter]:
            if word in word_sequence: break
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
        if len( word ) < 7: break
        add_another_word( [word], set( word ), best_word_count )

    elapsed = time.time() - start
    print(f"Elapsed time: {int(elapsed // 60)} minutes, {int(elapsed % 60)} seconds")


############################################################################################################
######  U/I stuff
############################################################################################################

def main():
    print(f"Let's get started...")  # Press ⌘F8 to toggle the breakpoint.
    dic = load_dictionary()
    dic5 = load_dictionary( word_length=5 )
    words5 = []
    for word in load_all_words():
        if len(word) == 5:  words5.append( word )


    # debug
    # find_optimal_starting_words_for_wordle(words5)


    entry = "rev ail muh toy"  # requires 2 words
    entry = "qio,ems,cut,nhv"  # 3 words
    entry = "usn,gli,jyo,cth"  # 2 words
    entry = "rvh,eai,wnp,mog"
    entry = "sxi,rdh,cfn,aet"
    # 25-06-01 actual
    # entry = "aog vit swb ner"   # 3 words

    letter_boxed(entry)
    exit()

    while True:
        entry = input("which game? > ")
        if entry == 'w': # wordle
            entry = input("Wordle: filter pattern, necessary_chars, disallowed chars> ")
            wordle_filter( entry, words5 )
        if entry == 'b': # spelling bee
            entry = input("Spelling Bee: required letter, optional letters> ")
            spelling_bee( entry, dic )
        if entry == 'l': # Lettered Box
            entry = input("Lettered Box: four sets of four letters> ")
            letter_box( entry, dic )
        if entry == 'f':
            find_optimal_starting_words_for_wordle(words5)
        if entry == 'q':
            break

if __name__ == '__main__':
    main()


##################################################
# letter boxed


    # 25-06-02
    # "sxi,rdh,cfn,aet"
    # only one 2-word solution
    # Solution: ['dentifrices', 'shes', 'saxes'],   total letters: 20
    # Solution: ['handicrafts', 'saxes'],   total letters: 16

    # 25-06-01
    # entry = "aog vit swb ner"   # 3 words
    '''
    Solution: ['vegetarians', 'snob', 'bow'],   total letters: 18
    Solution: ['vegetarians', 'snow', 'web'],   total letters: 18
    Solution: ['vegetarians', 'sown', 'nab'],   total letters: 18
    Solution: ['vegetarians', 'stow', 'web'],   total letters: 18
    Solution: ['vegetarians', 'sob', 'bow'],   total letters: 17
    Solution: ['vegetarians', 'sow', 'web'],   total letters: 17
    Solution: ['bestowing', 'grave'],   total letters: 14
    Solution: ['browning', 'gravest'],   total letters: 15
    Solution: ['bravest', 'trowing'],   total letters: 14
    Elapsed time: 15 minutes, 15 seconds
    '''