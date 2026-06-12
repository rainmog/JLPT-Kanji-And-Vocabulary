#!/usr/bin/env python3
"""
Filter vocab JLPT levels using Core 2k/6k Optimized Anki deck(s).

The Core 2k/6k deck has no JLPT level data — it is frequency-ordered only.
This script uses the deck as a presence/absence filter:

  - Vocab entry in Core 6k         → keep existing level (unchanged)
  - N1 entry NOT in Core 6k        → jlpt_level = 0  ("other")
  - Non-N1 entry NOT in Core 6k    → unchanged

jlpt_level = 0 words are silently excluded from N-level study screens.

The script accepts multiple .apkg files (all three parts).

Usage:
    python3 tools/import_core6k.py tools/Core_2k6k_Part_0*.apkg [--dry-run]
    python3 tools/build_db.py

Deck fields used:
    field 0  Vocabulary-Kanji  — word (kanji form, or kana if no kanji)
    field 2  Vocabulary-Kana   — reading in pure kana
"""

import argparse
import json
import re
import sqlite3
import sys
import tempfile
import zipfile
from pathlib import Path

BASE = Path(__file__).parent
VOCAB_PATH = BASE / 'data' / 'vocab.json'

HTML_RE = re.compile(r'<[^>]+>')
FURIGANA_RE = re.compile(r'\[.*?\]')


def normalize(text: str) -> str:
    t = HTML_RE.sub('', text)
    t = FURIGANA_RE.sub('', t)
    return t.strip()


def load_deck_words(apkg_path: str) -> set[tuple[str, str]]:
    """Return set of (Vocabulary-Kanji, Vocabulary-Kana) pairs from one .apkg."""
    words: set[tuple[str, str]] = set()
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(apkg_path, 'r') as z:
            names = z.namelist()
            db_name = 'collection.anki21' if 'collection.anki21' in names else 'collection.anki2'
            z.extract(db_name, tmp)

        conn = sqlite3.connect(Path(tmp) / db_name)
        c = conn.cursor()
        c.execute('SELECT flds FROM notes')
        for (flds_raw,) in c.fetchall():
            fields = flds_raw.split('\x1f')
            if len(fields) < 3:
                continue
            kanji = normalize(fields[0])   # Vocabulary-Kanji
            kana  = normalize(fields[2])   # Vocabulary-Kana
            if kanji:
                words.add((kanji, kana))
                words.add((kanji, ''))     # word-only fallback
        conn.close()
    return words


def apply(apkg_paths: list[str], dry_run: bool) -> None:
    all_words: set[tuple[str, str]] = set()
    for path in apkg_paths:
        print(f'Loading {Path(path).name}...')
        deck_words = load_deck_words(path)
        all_words |= deck_words
        print(f'  {len(deck_words) // 2} notes  (running total: {len(all_words) // 2})')

    vocab: list[dict] = json.loads(VOCAB_PATH.read_text(encoding='utf-8'))

    matched = 0
    demoted: list[str] = []
    unchanged_n1 = 0

    for entry in vocab:
        word    = entry['word']
        reading = entry['reading']
        level   = entry['jlpt_level']

        in_deck = (
            (word, reading) in all_words or
            (word, '') in all_words or
            (reading, '') in all_words  # deck uses kana form as word (e.g. その, できる)
        )

        if in_deck:
            matched += 1
        elif level == 1:
            entry['jlpt_level'] = 0
            demoted.append(word)
        else:
            unchanged_n1 += 1  # non-N1, not in deck — fine

    total_n1_original = sum(1 for e in vocab if e['jlpt_level'] in (0, 1) and
                             (e['jlpt_level'] == 1 or e['word'] in {w for w in demoted}))

    print(f'\nResults:')
    print(f'  In Core 6k (kept):         {matched}')
    print(f'  N1 → other (not in deck):  {len(demoted)}')
    print(f'  Non-N1, not in deck:       {unchanged_n1}')
    print(f'  Total entries:             {len(vocab)}')

    if demoted:
        sample = ', '.join(demoted[:12]) + (f'  … (+{len(demoted)-12} more)' if len(demoted) > 12 else '')
        print(f'\n  Demoted sample: {sample}')

    if not dry_run:
        VOCAB_PATH.write_text(
            json.dumps(vocab, ensure_ascii=False, indent=2),
            encoding='utf-8',
        )
        print(f'\nWrote {VOCAB_PATH}')
        print('Run python3 tools/build_db.py to rebuild the database.')
    else:
        print('\n(dry-run — vocab.json not modified)')


def main():
    parser = argparse.ArgumentParser(description='Filter vocab using Core 2k/6k Anki deck.')
    parser.add_argument('apkg', nargs='+', help='.apkg file(s) — all three parts')
    parser.add_argument('--dry-run', action='store_true', help='Preview without writing')
    args = parser.parse_args()

    missing = [p for p in args.apkg if not Path(p).exists()]
    if missing:
        for p in missing:
            print(f'Error: not found: {p}', file=sys.stderr)
        sys.exit(1)

    apply(args.apkg, dry_run=args.dry_run)


if __name__ == '__main__':
    main()
