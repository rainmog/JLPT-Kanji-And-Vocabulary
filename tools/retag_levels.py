#!/usr/bin/env python3
"""
Re-tag all kanji in tools/data/kanji.json with modern JLPT N-levels from kanjiapi.dev.

KANJIDIC2's jlpt field uses the old pre-2010 4-level system (1=hardest, 4=easiest).
kanjiapi.dev returns modern N-levels: N5=5, N4=4, N3=3, N2=2, N1=1, null=not in JLPT.

Usage:
  python3 tools/retag_levels.py           # update kanji.json
  python3 tools/retag_levels.py --dry-run  # print changes only
"""
import json, time, sys, requests
from pathlib import Path
from collections import Counter

BASE = Path(__file__).parent
DATA = BASE / 'data' / 'kanji.json'
API = 'https://kanjiapi.dev/v1/kanji/{}'
DELAY = 0.1  # seconds between requests; kanjiapi.dev is free, be polite


def fetch_jlpt(char: str) -> int | None:
    try:
        resp = requests.get(API.format(char), timeout=10)
        if resp.status_code == 404:
            return None
        resp.raise_for_status()
        return resp.json().get('jlpt')  # int 1–5 or null
    except Exception as e:
        print(f'  WARN {char}: {e}')
        return None


def main():
    dry_run = '--dry-run' in sys.argv
    kanji = json.loads(DATA.read_text(encoding='utf-8'))
    total = len(kanji)

    print(f'Loaded {total} kanji. Fetching modern JLPT levels from kanjiapi.dev...')
    old_dist = Counter(e['jlpt_level'] for e in kanji)
    print(f'Current: {dict(sorted(old_dist.items()))}')

    changes = []   # (char, old, new)
    no_data = []   # chars where API returned null (kept existing level)
    errors = []    # chars that failed entirely

    for i, entry in enumerate(kanji):
        char = entry['character']
        old_level = entry['jlpt_level']
        new_level = fetch_jlpt(char)

        if new_level is None:
            no_data.append(char)
        elif new_level != old_level:
            changes.append((char, old_level, new_level))
            if not dry_run:
                entry['jlpt_level'] = new_level

        if (i + 1) % 100 == 0:
            print(f'  {i + 1}/{total} done ({len(changes)} changes so far)...')

        time.sleep(DELAY)

    # --- Summary ---
    print(f'\n=== Level changes: {len(changes)} ===')
    by_transition = Counter(f'N{o}→N{n}' for _, o, n in changes)
    for transition, count in sorted(by_transition.items()):
        print(f'  {transition}: {count} kanji')

    if 0 < len(changes) <= 60:
        print('\nChanged kanji:')
        for char, old, new in changes:
            print(f'  {char}  N{old} → N{new}')

    print(f'\nNo API data for {len(no_data)} kanji (level unchanged):')
    if no_data:
        print(f'  {"  ".join(no_data[:30])}{"  ..." if len(no_data) > 30 else ""}')

    new_dist = Counter(e['jlpt_level'] for e in kanji)
    print(f'\nNew distribution: {dict(sorted(new_dist.items()))}')

    if dry_run:
        print('\n[DRY RUN] kanji.json not written.')
        return

    DATA.write_text(json.dumps(kanji, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'\nWrote {DATA}')
    print('Next: python3 tools/build_db.py')


if __name__ == '__main__':
    main()
