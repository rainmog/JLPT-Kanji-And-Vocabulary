#!/usr/bin/env python3
"""
Validator to fix word reading bugs in sentences.json.

Applies manual corrections for known problematic words and compound words
where valid_readings doesn't match the actual token reading.
"""

import json
import sys
from pathlib import Path
from collections import defaultdict

BASE = Path(__file__).parent
SENTENCES_PATH = BASE / 'data' / 'sentences.json'

def fix_readings():
    """Fix word reading inconsistencies."""
    with open(SENTENCES_PATH, encoding='utf-8') as f:
        data = json.load(f)

    # Manual fixes: (char, sentence_text, token_surface) -> correct_valid_readings
    # These are cases where valid_readings needs to be updated to match the actual token reading
    FIXES = {
        # Format: (character, sentence_contains, token_surface) -> correct_valid_readings
        ('空', '空がきれいです', '空'): ['そら', 'くう'],
        ('空', '空に星があります', '空'): ['そら', 'くう'],
        ('金', '金を持っています', '金'): ['かね', 'きん', 'こん', 'ごん'],
        ('間', 'その間に準備をしておきます', '間'): ['あいだ', 'かん', 'けん'],
        ('間', '夫婦の間に子どもがいます', '間'): ['あいだ', 'かん', 'けん'],
        ('間', '部屋の間に壁があります', '間'): ['ま', 'かん', 'けん'],
        ('魚', '川に魚がいます', '魚'): ['さかな', 'ぎょ'],
        ('魚', '新鮮な魚を買いました', '魚'): ['さかな', 'ぎょ'],
        ('魚', '様々な魚の種類を学びました', '魚'): ['さかな', 'ぎょ'],
        ('魚', '毎日魚を食べます', '魚'): ['さかな', 'ぎょ'],
        ('魚', '海の魚と川の魚は異なる特性を持つ', '魚'): ['さかな', 'ぎょ'],
        ('魚', '養殖魚産業の発展は食糧確保に寄与している', '魚'): ['さかな', 'ぎょ'],
        ('魚', '魚が好きです', '魚'): ['さかな', 'ぎょ'],
    }

    # Strategy: instead of key-based lookups, we'll scan and fix based on logic
    # 1. Find all cases where token reading is not in valid_readings
    # 2. For compound words (len > 1), update valid_readings to include token reading
    # 3. Track which ones we fix

    fixed_count = 0
    issues = []

    for entry in data:
        char = entry['character']
        for sent in entry.get('sentences', []):
            text = sent.get('text_kanji', '')
            valid_readings = sent.get('valid_readings', [])

            for token_idx, token in enumerate(sent.get('text_structured', [])):
                surface = token['surface']
                reading = token['reading']
                kanji_char = token.get('kanji_char')

                # Only fix tokens that are marked as target kanji
                if kanji_char != char:
                    continue

                # If reading is not in valid_readings, we might need to fix it
                if reading not in valid_readings:
                    # This is likely a compound word where valid_readings was incomplete
                    is_compound = len(surface) > 1

                    if is_compound:
                        # For compound words, add the actual reading
                        if reading not in valid_readings:
                            valid_readings.append(reading)
                            fixed_count += 1
                            issues.append({
                                'char': char,
                                'sentence': text,
                                'word': surface,
                                'reading': reading,
                                'action': f'added {reading} to valid_readings'
                            })

    # Apply manual fixes from FIXES dict
    for entry in data:
        char = entry['character']
        for sent in entry.get('sentences', []):
            text = sent.get('text_kanji', '')

            # Check if this sentence matches any manual fix
            for (fix_char, fix_text, fix_surface), fix_readings in FIXES.items():
                if char == fix_char and fix_text in text:
                    # Find token with matching surface
                    for token in sent.get('text_structured', []):
                        if token['surface'] == fix_surface:
                            old_readings = set(sent.get('valid_readings', []))
                            sent['valid_readings'] = list(set(fix_readings) | old_readings)
                            if sent['valid_readings'] != list(old_readings):
                                fixed_count += 1
                                issues.append({
                                    'char': char,
                                    'sentence': text,
                                    'word': fix_surface,
                                    'reading': fix_surface,
                                    'action': f'fixed valid_readings to {sent["valid_readings"]}'
                                })

    # Save corrected data
    with open(SENTENCES_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print("=" * 80)
    print("WORD READING VALIDATOR - FIX REPORT")
    print("=" * 80)
    print(f"\nFixed {fixed_count} reading issues:")
    for issue in issues[:30]:
        print(f"\n  Char: {issue['char']}")
        print(f"  Sentence: {issue['sentence']}")
        print(f"  Word: {issue['word']}")
        print(f"  Action: {issue['action']}")

    if len(issues) > 30:
        print(f"\n... and {len(issues) - 30} more issues")

    print("\n" + "=" * 80)
    print(f"Completed: {fixed_count} fixes applied to sentences.json")
    print("=" * 80)

if __name__ == '__main__':
    try:
        fix_readings()
    except FileNotFoundError as e:
        print(f"ERROR: {e.filename} not found", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)
