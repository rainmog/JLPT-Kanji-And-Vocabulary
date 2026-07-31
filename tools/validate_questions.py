#!/usr/bin/env python3
"""
Mechanical fairness validator for JLPT question JSON.

Checks the things a machine can prove (see jlpt-test-guidelines.md §6/§9):
  - correct_option is an int in 1..4
  - no two option strings are identical (duplicate options)
  - reorder: correct_order present, references opts 1..4 once each,
    and correct_option appears in correct_order
  - display fields (when present) contain no bare kanji outside {..|..} ruby,
    and ruby readings are kana
  - required fields present per type; translation present
  - flags exact-duplicate stems within a level (possible copy/paste)

Semantic checks (dual answers, level scope, natural Japanese) are NOT done here —
they need human/LLM review. This pass narrows where to look.

Usage:
  python3 tools/validate_questions.py --level 5
  python3 tools/validate_questions.py            # all levels
"""

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

BASE = Path(__file__).parent
DATA = BASE / 'data'

KANJI_START, KANJI_END = '一', '鿿'
HIRA_START, HIRA_END = '぀', 'ゟ'
KATA_START, KATA_END = '゠', 'ヿ'


def has_kanji(s):
    return any(KANJI_START <= c <= KANJI_END for c in s)


def is_kana_only(s):
    for c in s:
        if KANJI_START <= c <= KANJI_END:
            return False
    return True


def strip_ruby(display):
    """Return text with {kanji|reading} runs removed, to find bare kanji."""
    out = []
    i = 0
    while i < len(display):
        if display[i] == '{':
            end = display.find('}', i)
            if end == -1:
                out.append(display[i:])
                break
            i = end + 1
        else:
            out.append(display[i])
            i += 1
    return ''.join(out)


def ruby_readings(display):
    """Yield reading parts from {kanji|reading} runs."""
    i = 0
    while i < len(display):
        if display[i] == '{':
            end = display.find('}', i)
            if end == -1:
                break
            run = display[i + 1:end]
            if '|' in run:
                yield run.split('|', 1)[1]
            i = end + 1
        else:
            i += 1


def check_question(q, idx):
    errs = []
    warns = []

    def e(msg):
        errs.append(msg)

    def w(msg):
        warns.append(msg)

    qtype = q.get('question_type', '?')
    section = q.get('section', '?')

    # correct_option
    co = q.get('correct_option')
    if not isinstance(co, int) or not (1 <= co <= 4):
        e(f'correct_option must be int 1..4, got {co!r}')

    # options present + no duplicates
    opts = [q.get(f'option_{i}') for i in range(1, 5)]
    if any(o is None or o == '' for o in opts):
        e('missing one or more option_1..4')
    else:
        dupes = [o for o, n in Counter(opts).items() if n > 1]
        if dupes:
            e(f'duplicate option(s): {dupes}')

    # required text fields
    if not q.get('question_stem'):
        e('missing question_stem')
    if not q.get('question_translation'):
        w('missing question_translation')

    # reading questions need a passage link
    if qtype == 'comprehension':
        if q.get('passage_id') is None:
            e('comprehension question missing passage_id')
        # passage itself may live on the first question of the group;
        # warn only if no passage anywhere on this row
        if not q.get('passage'):
            w('comprehension row has no passage text (ok if grouped)')

    # reorder-specific
    if qtype == 'sentence_reorder':
        order = q.get('correct_order')
        if not order:
            e('sentence_reorder missing correct_order')
        else:
            parts = [p.strip() for p in order.split(',')]
            nums = []
            for p in parts:
                if not p.isdigit():
                    e(f'correct_order has non-int part {p!r}')
                else:
                    nums.append(int(p))
            if sorted(nums) != [1, 2, 3, 4]:
                e(f'correct_order must be a permutation of 1..4, got {order!r}')
            if isinstance(co, int) and co not in nums:
                e(f'correct_option {co} not present in correct_order {order!r}')
    else:
        if q.get('correct_order'):
            w(f'{qtype} has correct_order set (only reorder uses it)')

    # display / furigana sanity
    for field in ['question_stem_display', 'passage_display', 'passage_title_display',
                  'option_1_display', 'option_2_display', 'option_3_display',
                  'option_4_display']:
        disp = q.get(field)
        if not disp:
            continue
        bare = strip_ruby(disp)
        if has_kanji(bare):
            e(f'{field} has bare kanji outside ruby: {bare!r}')
        for r in ruby_readings(disp):
            if not is_kana_only(r):
                e(f'{field} ruby reading not kana: {r!r}')

    prefix = f'[#{idx} {section}/{qtype}]'
    return [f'{prefix} ERROR: {m}' for m in errs], [f'{prefix} warn: {m}' for m in warns]


def check_level(level):
    path = DATA / f'n{level}_questions.json'
    if not path.exists():
        print(f'no file for level {level}: {path}')
        return 0, 0
    data = json.load(open(path, encoding='utf-8'))
    all_errs, all_warns = [], []
    stems = Counter()
    for i, q in enumerate(data):
        errs, warns = check_question(q, i)
        all_errs += errs
        all_warns += warns
        stems[q.get('question_stem', '')] += 1
    for stem, n in stems.items():
        if n > 1 and stem:
            all_warns.append(f'[dup-stem x{n}] {stem[:40]}...')

    print(f'\n=== N{level} ({len(data)} questions) ===')
    for m in all_errs:
        print(m)
    for m in all_warns:
        print(m)
    print(f'N{level}: {len(all_errs)} errors, {len(all_warns)} warnings')
    return len(all_errs), len(all_warns)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--level', type=int, help='1..5; omit for all')
    args = ap.parse_args()
    levels = [args.level] if args.level else [1, 2, 3, 4, 5]
    total_e = 0
    for lv in levels:
        e, _ = check_level(lv)
        total_e += e
    print(f'\nTOTAL errors: {total_e}')
    sys.exit(1 if total_e else 0)


if __name__ == '__main__':
    main()
