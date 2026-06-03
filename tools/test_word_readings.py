#!/usr/bin/env python3
"""
Test script to validate word reading fixes.

Verifies that:
1. All token readings match sentence valid_readings
2. Known problem words are fixed
3. No duplicate or invalid readings exist
"""

import json
import sys
from pathlib import Path

BASE = Path(__file__).parent
SENTENCES_PATH = BASE / 'data' / 'sentences.json'

def test_word_readings():
    """Test word reading consistency."""
    with open(SENTENCES_PATH, encoding='utf-8') as f:
        data = json.load(f)

    errors = []
    fixed_count = 0

    # Test 1: All tokens in valid_readings
    print("TEST 1: Token-to-valid_readings consistency")
    print("-" * 60)
    for entry in data:
        char = entry['character']
        for sent in entry.get('sentences', []):
            text = sent.get('text_kanji', '')
            valid_readings = set(sent.get('valid_readings', []))

            for token in sent.get('text_structured', []):
                if token.get('kanji_char') == char:
                    reading = token['reading']
                    if reading not in valid_readings:
                        errors.append(f"  {char}: '{text}' token '{token['surface']}' "
                                    f"(reading: {reading}) not in {sorted(valid_readings)}")

    if errors:
        print(f"FAILED: {len(errors)} token mismatches found")
        for e in errors[:5]:
            print(e)
        if len(errors) > 5:
            print(f"  ... and {len(errors) - 5} more")
        return False
    else:
        print("PASSED: All tokens in valid_readings")

    # Test 2: Known problem words are fixed
    print("\nTEST 2: Known problem words fixed")
    print("-" * 60)
    problems = {
        '間違え': 'まちがえ',
        '休み': 'やすみ',
        '学校': 'がっこう',
    }

    for entry in data:
        for sent in entry.get('sentences', []):
            valid_readings = set(sent.get('valid_readings', []))
            for token in sent.get('text_structured', []):
                if token['surface'] in problems:
                    expected = problems[token['surface']]
                    if expected in valid_readings:
                        fixed_count += 1
                    else:
                        errors.append(f"  {token['surface']}: expected {expected} in {valid_readings}")

    if errors:
        print(f"FAILED: {len(errors)} known words not fixed")
        for e in errors[:5]:
            print(e)
        return False
    else:
        print(f"PASSED: {fixed_count} problem words correctly fixed")

    # Test 3: Valid readings are non-empty
    print("\nTEST 3: Non-empty valid_readings")
    print("-" * 60)
    empty_count = 0
    for entry in data:
        for sent in entry.get('sentences', []):
            if not sent.get('valid_readings'):
                empty_count += 1
                errors.append(f"  {entry['character']}: {sent.get('text_kanji', '')} has empty valid_readings")

    if empty_count > 0:
        print(f"FAILED: {empty_count} sentences with empty valid_readings")
        for e in errors[:5]:
            print(e)
        return False
    else:
        print("PASSED: All valid_readings non-empty")

    # Test 4: No duplicate readings
    print("\nTEST 4: No duplicate readings in valid_readings")
    print("-" * 60)
    dups = 0
    for entry in data:
        for sent in entry.get('sentences', []):
            readings = sent.get('valid_readings', [])
            if len(readings) != len(set(readings)):
                dups += 1
                errors.append(f"  {entry['character']}: duplicates in {readings}")

    if dups > 0:
        print(f"FAILED: {dups} sentences with duplicate readings")
        for e in errors[:5]:
            print(e)
        return False
    else:
        print("PASSED: No duplicate readings")

    print("\n" + "=" * 60)
    print("ALL TESTS PASSED")
    print("=" * 60)
    return True

if __name__ == '__main__':
    try:
        success = test_word_readings()
    except FileNotFoundError as e:
        print(f"ERROR: {e.filename} not found", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)
    sys.exit(0 if success else 1)
