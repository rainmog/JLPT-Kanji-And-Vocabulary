#!/usr/bin/env python3
"""
Audit script to detect word reading inconsistencies in sentences.json.

Tracks each unique word (surface + reading) combination and flags:
1. Words with multiple different readings (likely bugs)
2. Tokens that don't match valid_readings in their sentence
3. Known problematic words (九つ, 間違える, etc.)
"""

import json
import sys
from pathlib import Path
from collections import defaultdict

BASE = Path(__file__).parent
SENTENCES_PATH = BASE / 'data' / 'sentences.json'

def audit_words():
    """Audit word readings for inconsistencies."""
    with open(SENTENCES_PATH, encoding='utf-8') as f:
        data = json.load(f)

    # Track word -> set of readings seen
    word_readings = defaultdict(set)

    # Track problematic cases
    problems = []
    token_not_in_valid = []

    total_sentences = 0
    total_tokens = 0

    for entry in data:
        char = entry['character']
        for sent_idx, sent in enumerate(entry.get('sentences', [])):
            total_sentences += 1
            text = sent.get('text_kanji', '')
            valid_readings = set(sent.get('valid_readings', []))

            for token_idx, token in enumerate(sent.get('text_structured', [])):
                total_tokens += 1
                surface = token['surface']
                reading = token['reading']

                # Track word readings
                word_readings[surface].add(reading)

                # Check if this token's reading is in valid_readings (if not punctuation/particle)
                is_kanji_word = token.get('is_kanji', False)
                is_target = token.get('kanji_char') == char

                if is_kanji_word and is_target:
                    if reading not in valid_readings:
                        token_not_in_valid.append({
                            'word': surface,
                            'reading': reading,
                            'valid_readings': list(valid_readings),
                            'sentence': text,
                            'difficulty': sent.get('difficulty', '?'),
                            'char': char
                        })

    # Find words with multiple readings (likely variants or bugs)
    multi_reading_words = {
        word: readings for word, readings in word_readings.items()
        if len(readings) > 1 and len(word) > 1  # Filter out single chars which may have legitimate variants
    }

    # Specific checks for known problematic words
    known_problems = {
        '九つ': 'kokonotsu/kokono (not kokonots)',
        '間違える': 'machigaeru (not kanchigaeru)',
        '間違え': 'machigae (not kanchigae)',
    }

    print("=" * 80)
    print("WORD READING AUDIT REPORT")
    print("=" * 80)
    print(f"\nScanned {total_sentences} sentences with {total_tokens} tokens")
    print(f"Found {len(word_readings)} unique words")
    print()

    # Report known problematic words
    print("KNOWN PROBLEM WORDS:")
    print("-" * 80)
    for problem_word, expected in known_problems.items():
        if problem_word in word_readings:
            readings = word_readings[problem_word]
            print(f"✗ '{problem_word}' -> {readings}")
            print(f"  Expected: {expected}")
            # Find examples
            for entry in data:
                for sent in entry.get('sentences', []):
                    for token in sent.get('text_structured', []):
                        if token['surface'] == problem_word:
                            print(f"  Example: {sent.get('text_kanji', '')} (reading: {token['reading']})")
                            print(f"           Valid readings in sentence: {sent.get('valid_readings', [])}")
                            break
            print()

    # Report words with multiple readings
    print("\nWORDS WITH MULTIPLE READINGS (likely bugs):")
    print("-" * 80)
    if multi_reading_words:
        for word in sorted(multi_reading_words.keys(), key=lambda w: len(multi_reading_words[w]), reverse=True)[:30]:
            readings = sorted(multi_reading_words[word])
            print(f"'{word}': {readings}")
            # Find first example for each reading
            for reading in readings:
                for entry in data:
                    for sent in entry.get('sentences', []):
                        for token in sent.get('text_structured', []):
                            if token['surface'] == word and token['reading'] == reading:
                                print(f"  - {reading}: '{sent.get('text_kanji', '')}'")
                                break
    else:
        print("(none found)")
    print()

    # Report tokens not in valid_readings
    print("\nTOKENS NOT IN SENTENCE'S VALID_READINGS:")
    print("-" * 80)
    if token_not_in_valid:
        # Group by word
        by_word = defaultdict(list)
        for prob in token_not_in_valid:
            by_word[prob['word']].append(prob)

        for word in sorted(by_word.keys())[:20]:
            problems = by_word[word]
            print(f"\n'{word}':")
            for prob in problems[:3]:
                print(f"  Reading: {prob['reading']}")
                print(f"  Valid in sentence: {prob['valid_readings']}")
                print(f"  Sentence: {prob['sentence']}")
                print(f"  Char: {prob['char']}, Difficulty: {prob['difficulty']}")
    else:
        print("(none found)")
    print()

    print("=" * 80)
    print(f"SUMMARY: {len(token_not_in_valid)} token mismatches, "
          f"{len(multi_reading_words)} words with variant readings")
    print("=" * 80)

if __name__ == '__main__':
    try:
        audit_words()
    except FileNotFoundError as e:
        print(f"ERROR: {e.filename} not found", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)
