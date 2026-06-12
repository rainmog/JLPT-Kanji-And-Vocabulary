"""
Generate English translations for all JLPT questions.
Adds question_translation (and passage_translation for passage questions) to each JSON file.
Safe to re-run — skips questions that already have translations.

Usage:
    python3 tools/translate_jlpt.py
"""
import json
import sys
import time
from pathlib import Path
import anthropic

BASE = Path(__file__).parent
DATA = BASE / 'data'
FILES = [(5, DATA/'n5_questions.json'), (4, DATA/'n4_questions.json'),
         (3, DATA/'n3_questions.json'), (2, DATA/'n2_questions.json'),
         (1, DATA/'n1_questions.json')]

import os
if not os.environ.get('ANTHROPIC_API_KEY'):
    print('ERROR: set ANTHROPIC_API_KEY before running this script', file=sys.stderr)
    sys.exit(1)
client = anthropic.Anthropic()

BATCH_SIZE = 10


def translate_batch(items: list[dict]) -> list[str]:
    """Send a batch of {text, correct_answer?} dicts, return list of translations.

    For items with correct_answer: fill the blank with the English translation of
    correct_answer, wrapped in **bold** (e.g. **turn off**). No ___ in output.
    For items without correct_answer: translate naturally.
    """
    batch_data = [
        {'text': x['text'], **({'correct_answer': x['correct_answer']} if 'correct_answer' in x else {})}
        for x in items
    ]
    prompt = (
        "Translate each Japanese item to natural English.\n"
        "Rules:\n"
        "- Items with 'correct_answer': fill the blank (（　）or similar) with the English "
        "translation of the correct_answer, wrapped in **bold** like **word**. "
        "Do NOT use ___ in the output.\n"
        "- Items without 'correct_answer': translate naturally.\n"
        "Return ONLY a JSON array of strings — one translation per item, same order. "
        "No explanations.\n\n"
        + json.dumps(batch_data, ensure_ascii=False)
    )
    resp = client.messages.create(
        model='claude-haiku-4-5-20251001',
        max_tokens=2048,
        messages=[{'role': 'user', 'content': prompt}],
    )
    text = resp.content[0].text.strip()
    # Strip markdown code fences if present
    if text.startswith('```'):
        text = text.split('\n', 1)[1].rsplit('```', 1)[0].strip()
    return json.loads(text)


def translate_passage_batch(items: list[dict]) -> list[str]:
    """Translate passage texts (longer context)."""
    prompt = (
        "Translate each Japanese passage to natural English. "
        "Return ONLY a JSON array of strings — one translation per item, same order. "
        "Preserve paragraph structure with newlines.\n\n"
        + json.dumps([x['text'] for x in items], ensure_ascii=False)
    )
    resp = client.messages.create(
        model='claude-haiku-4-5-20251001',
        max_tokens=4096,
        messages=[{'role': 'user', 'content': prompt}],
    )
    text = resp.content[0].text.strip()
    if text.startswith('```'):
        text = text.split('\n', 1)[1].rsplit('```', 1)[0].strip()
    return json.loads(text)


def process_file(level: int, path: Path):
    qs = json.load(open(path, encoding='utf-8'))
    changed = False

    # Clear translations that still have ___ placeholders — they used the old
    # blank-as-___ format and need re-translation with the answer filled in English.
    for q in qs:
        if '___' in (q.get('question_translation') or ''):
            del q['question_translation']
            changed = True

    # --- 1. Translate passages (cached by passage_id) ---
    passage_cache: dict[int, str] = {}
    passage_todo: list[dict] = []  # {idx_in_cache, passage_id, text}
    seen_passage_ids: set[int] = set()

    for q in qs:
        pid = q.get('passage_id')
        if pid and pid not in seen_passage_ids:
            seen_passage_ids.add(pid)
            if 'passage_translation' not in q:
                passage_todo.append({'passage_id': pid, 'text': q['passage']})

    if passage_todo:
        print(f'  N{level}: translating {len(passage_todo)} passages...')
        for i in range(0, len(passage_todo), BATCH_SIZE):
            batch = passage_todo[i:i+BATCH_SIZE]
            try:
                translations = translate_passage_batch(batch)
                for item, tr in zip(batch, translations):
                    passage_cache[item['passage_id']] = tr
                time.sleep(0.3)
            except Exception as e:
                print(f'  ERROR on passage batch {i}: {e}', file=sys.stderr)
                raise

    # Apply passage translations to all questions sharing that passage_id
    for q in qs:
        pid = q.get('passage_id')
        if pid:
            if pid in passage_cache:
                q['passage_translation'] = passage_cache[pid]
                changed = True
            elif 'passage_translation' in q:
                passage_cache[pid] = q['passage_translation']

    # --- 2. Translate question stems ---
    stem_todo: list[dict] = []  # {qi: index in qs}
    for qi, q in enumerate(qs):
        if 'question_translation' not in q:
            item: dict = {'qi': qi, 'text': q['question_stem']}
            # For fill-blank questions, include the correct answer so the
            # translator can embed it in English with **bold** instead of ___.
            if '（' in q['question_stem']:
                opt_key = f'option_{q["correct_option"]}'
                item['correct_answer'] = q.get(opt_key, '')
            stem_todo.append(item)

    if stem_todo:
        print(f'  N{level}: translating {len(stem_todo)} question stems...')
        for i in range(0, len(stem_todo), BATCH_SIZE):
            batch = stem_todo[i:i+BATCH_SIZE]
            try:
                translations = translate_batch(batch)
                for item, tr in zip(batch, translations):
                    qs[item['qi']]['question_translation'] = tr
                    changed = True
                time.sleep(0.3)
            except Exception as e:
                print(f'  ERROR on stem batch {i}: {e}', file=sys.stderr)
                raise

    if changed:
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(qs, f, ensure_ascii=False, indent=2)
        print(f'  N{level}: saved {path.name}')
    else:
        print(f'  N{level}: all translations present, skipped')


if __name__ == '__main__':
    for level, path in FILES:
        if not path.exists():
            print(f'N{level}: file not found, skipping')
            continue
        print(f'Processing N{level}...')
        process_file(level, path)
    print('Done.')
