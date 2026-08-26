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

def number_of_unique_letters(word):
    return len(set(word))

##############################################
# generate list of words with large letter counts
##############################################


big_words = []
dic = load_all_words()
for word in dic:
    char_count = len( set(word) )
    if char_count >= 12:
        big_words.append( word )

# big_words.sort(key=number_of_unique_letters)
# big_words.sort(key=len)
big_words.sort(key=lambda w: (len(w), w))
# print("number of unique letters, number of letters, word")
print("number of letters, word")
for word in big_words:
    unique_letter_count = len(set(word))
    if unique_letter_count == 12:
        s = set(word)
        letters = list(s)
        letters.sort()
        # print(f"{unique_letter_count}, {len(word)}, {word}")
        print(f"{len(word)}, {word}, {letters}")


##############################################
# histogram of occurrences of specific letter counts of words across the entire dict
##############################################


# length_counts = {}
# for n in range(3, 30):
#     length_counts[n] = 0

# for word in dic:
#     n = len(word)
#     # print(word, n)
#     if n >= 3:
#         length_counts[len(word)] += 12

# print()
# print("Histogram of word lengths, across entire dictionary:")
# print("(excluding words of 1 or 2 character length.)")

# for length in sorted(length_counts):
#     count = length_counts[length]
#     print(f"words with letter count: {length}, number of occurrences: {count}")


#####################################

# print()
# test = ["accomplishments", "superconductivities", "electroencephalographic"]
# for word in test:
#     print( word, len(set(word)), len(word) )




