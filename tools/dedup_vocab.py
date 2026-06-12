#!/usr/bin/env python3
"""
Deduplicate vocab.json: for each word+reading pair that appears at multiple
JLPT levels, keep the entry with the highest jlpt_level (easiest/most basic).

Example: 川/かわ at [N5, N3] → keep N5.
Example: これ等/これら at [N3, N1] → keep N3.

Rationale: if a word appears in N5 lists it belongs at N5, not N1.

Usage:
    python3 tools/dedup_vocab.py [--dry-run]
"""
import argparse
import json
from collections import defaultdict
from pathlib import Path

BASE = Path(__file__).parent
VOCAB_PATH = BASE / 'data' / 'vocab.json'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    vocab: list[dict] = json.loads(VOCAB_PATH.read_text(encoding='utf-8'))

    # Group by (word, reading), keep entry with max jlpt_level (easiest)
    best: dict[tuple[str, str], dict] = {}
    for entry in vocab:
        key = (entry['word'], entry['reading'])
        if key not in best or entry['jlpt_level'] > best[key]['jlpt_level']:
            best[key] = entry

    deduped = list(best.values())
    removed = len(vocab) - len(deduped)

    print(f'Original: {len(vocab)} entries')
    print(f'After dedup: {len(deduped)} entries  ({removed} removed)')

    # Show some examples
    seen: dict[tuple[str, str], list[int]] = defaultdict(list)
    for e in vocab:
        seen[(e['word'], e['reading'])].append(e['jlpt_level'])
    examples = [(k, sorted(v, reverse=True)) for k, v in seen.items() if len(v) > 1][:10]
    for (w, r), levels in examples:
        kept = best[(w, r)]['jlpt_level']
        print(f'  {w}/{r}: {["N"+str(l) for l in levels]} → kept N{kept}')

    if not args.dry_run:
        VOCAB_PATH.write_text(json.dumps(deduped, ensure_ascii=False, indent=2), encoding='utf-8')
        print(f'\nWrote {VOCAB_PATH}')
    else:
        print('\n(dry-run — not written)')


if __name__ == '__main__':
    main()
