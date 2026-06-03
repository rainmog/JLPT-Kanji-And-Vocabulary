#!/usr/bin/env python3
"""
Comprehensive validation pipeline for kanji database.

Checks:
  a) Every character in sentences has entry in kanji.json
  b) Every sentence has non-empty valid_readings
  c) Every token reading is hiragana (except katakana for katakana words)
  d) No duplicate readings in valid_readings arrays
  e) For sentences with target kanji, at least one valid_reading matches the target
"""

import json
import sys
from pathlib import Path
from collections import defaultdict

BASE = Path(__file__).parent
KANJI_PATH = BASE / 'data' / 'kanji.json'
SENTENCES_PATH = BASE / 'data' / 'sentences_v2.json'


def is_hiragana(char):
    """Check if character is hiragana."""
    return '぀' <= char <= 'ゟ'


def is_katakana(char):
    """Check if character is katakana."""
    return '゠' <= char <= 'ヿ'


def is_valid_reading(text):
    """Check if text is valid Japanese reading (hiragana or katakana, no kanji)."""
    if not text:
        return False
    for char in text:
        if not (is_hiragana(char) or is_katakana(char) or char in '。、，！？・'):
            # Allow some punctuation, but no kanji or other characters
            return False
    return True


def validate_all():
    """Run all validation checks. Return True if pass, False if fail."""
    try:
        with open(KANJI_PATH, encoding='utf-8') as f:
            kanji_list = json.load(f)
        with open(SENTENCES_PATH, encoding='utf-8') as f:
            sentences_data = json.load(f)
    except FileNotFoundError as e:
        print(f"ERROR: missing file: {e.filename}", file=sys.stderr)
        return False
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON in {e.doc}: {e}", file=sys.stderr)
        return False

    # Build kanji set
    kanji_chars = {k['character'] for k in kanji_list}
    print(f"Loaded {len(kanji_list)} kanji entries")
    print(f"Loaded {len(sentences_data)} sentence entries")

    errors = []
    warnings = []

    # Check A: Every character in sentences has entry in kanji.json
    print("\nCheck A: Character coverage in kanji.json...", end=" ")
    for entry in sentences_data:
        char = entry['character']
        if char not in kanji_chars:
            errors.append({
                'type': 'missing_kanji',
                'char': char,
                'details': f"Character '{char}' in sentences.json but not in kanji.json"
            })
    print(f"OK ({len([e for e in errors if e['type'] == 'missing_kanji'])} errors)")

    # Check B: Every sentence has non-empty valid_readings
    print("Check B: Non-empty valid_readings...", end=" ")
    b_errors = []
    for entry in sentences_data:
        char = entry['character']
        for idx, sent in enumerate(entry.get('sentences', [])):
            valid_readings = sent.get('valid_readings', [])
            if not valid_readings:
                b_errors.append({
                    'type': 'empty_valid_readings',
                    'char': char,
                    'sentence': sent.get('text_kanji', ''),
                    'difficulty': sent.get('difficulty', '?'),
                    'details': f"Sentence has empty valid_readings"
                })
    errors.extend(b_errors)
    print(f"OK ({len(b_errors)} errors)")

    # Check C: Every kanji token reading is hiragana/katakana
    print("Check C: Valid reading characters...", end=" ")
    c_errors = []
    for entry in sentences_data:
        char = entry['character']
        for sent in entry.get('sentences', []):
            for token in sent.get('text_structured', []):
                if not token.get('is_kanji', False):
                    continue  # non-kanji tokens may have romaji/digit/punctuation readings
                reading = token.get('reading', '')
                if reading and not is_valid_reading(reading):
                    c_errors.append({
                        'type': 'invalid_reading_chars',
                        'char': char,
                        'sentence': sent.get('text_kanji', ''),
                        'token_surface': token['surface'],
                        'reading': reading,
                        'details': f"Token reading '{reading}' contains non-kana characters"
                    })
    errors.extend(c_errors)
    print(f"OK ({len(c_errors)} errors)")

    # Check D: No duplicate readings in valid_readings arrays
    print("Check D: No duplicate valid_readings...", end=" ")
    d_errors = []
    for entry in sentences_data:
        char = entry['character']
        for sent in entry.get('sentences', []):
            valid_readings = sent.get('valid_readings', [])
            if len(valid_readings) != len(set(valid_readings)):
                dupes = [r for r in valid_readings if valid_readings.count(r) > 1]
                d_errors.append({
                    'type': 'duplicate_readings',
                    'char': char,
                    'sentence': sent.get('text_kanji', ''),
                    'duplicates': list(set(dupes)),
                    'details': f"Duplicate readings in valid_readings: {list(set(dupes))}"
                })
    errors.extend(d_errors)
    print(f"OK ({len(d_errors)} errors)")

    # Check E: For sentences with target kanji, at least one valid_reading matches a target token
    print("Check E: Target kanji coverage in valid_readings...", end=" ")
    e_errors = []
    for entry in sentences_data:
        char = entry['character']
        for sent in entry.get('sentences', []):
            valid_readings = sent.get('valid_readings', [])
            text_structured = sent.get('text_structured', [])

            # Find all tokens that are marked as the target character
            target_tokens = [t for t in text_structured if t.get('kanji_char') == char]

            if target_tokens:
                # At least one token reading should be in valid_readings
                token_readings = [t['reading'] for t in target_tokens]
                has_match = any(reading in valid_readings for reading in token_readings)

                if not has_match:
                    e_errors.append({
                        'type': 'target_reading_mismatch',
                        'char': char,
                        'sentence': sent.get('text_kanji', ''),
                        'difficulty': sent.get('difficulty', '?'),
                        'target_tokens': [t['surface'] for t in target_tokens],
                        'token_readings': token_readings,
                        'valid_readings': valid_readings,
                        'details': f"No target token reading matches valid_readings. Tokens: {token_readings}, Valid: {valid_readings}"
                    })

    errors.extend(e_errors)
    print(f"OK ({len(e_errors)} errors)")

    # Print summary
    print("\n" + "=" * 80)
    print("VALIDATION SUMMARY")
    print("=" * 80)

    if errors:
        print(f"\n✗ VALIDATION FAILED: {len(errors)} errors found")
        print("\nFirst 20 errors:\n")

        for i, error in enumerate(errors[:20], 1):
            print(f"{i}. [{error['type']}] Character: {error.get('char', '?')}")
            print(f"   {error['details']}")
            if 'sentence' in error:
                print(f"   Sentence: {error['sentence']}")
            if 'difficulty' in error:
                print(f"   Difficulty: {error['difficulty']}")
            print()

        if len(errors) > 20:
            print(f"... and {len(errors) - 20} more errors")

        print("=" * 80)
        return False
    else:
        print(f"\n✓ Validation complete: 0 errors, {len(warnings)} warnings")
        print("=" * 80)
        return True


if __name__ == '__main__':
    success = validate_all()
    sys.exit(0 if success else 1)
