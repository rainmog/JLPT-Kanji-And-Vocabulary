#!/usr/bin/env python3
"""
Fetch JLPT N5–N1 vocabulary from the Jisho API and write tools/data/vocab.json.

Each entry: {word, reading, meanings: str, acceptable_answers: [str], jlpt_level: int, tags: [str]}

Run: python tools/import_vocab.py
"""
import json, time, requests
from pathlib import Path

BASE = Path(__file__).parent

JLPT_LEVELS = [5, 4, 3, 2, 1]

# JMdict field-code → human tag mapping
FIELD_TAGS = {
    'food': 'food', 'anat': 'anatomy', 'med': 'medical', 'mus': 'music',
    'sports': 'sports', 'comp': 'computers', 'biol': 'biology', 'chem': 'chemistry',
    'math': 'mathematics', 'ling': 'linguistics', 'law': 'law', 'bus': 'business',
    'finc': 'finance', 'mil': 'military', 'arch': 'architecture',
    'MA': 'martial arts', 'Buddh': 'buddhism', 'Shinto': 'shinto',
    'astron': 'astronomy', 'geog': 'geography', 'agric': 'agriculture',
    'zool': 'zoology', 'bot': 'botany', 'cloth': 'clothing',
}

LEVEL_BAND = {5: 'Beginner', 4: 'Beginner', 3: 'Intermediate', 2: 'Advanced', 1: 'Advanced'}

def fetch_level(jlpt_level: int) -> list[dict]:
    keyword = f'%23jlpt-n{jlpt_level}'
    url = f'https://jisho.org/api/v1/search/words?keyword={keyword}'
    words = []
    page = 1
    while True:
        resp = requests.get(f'{url}&page={page}', timeout=15)
        resp.raise_for_status()
        data = resp.json().get('data', [])
        if not data:
            break
        for entry in data:
            word = _parse_entry(entry, jlpt_level)
            if word:
                words.append(word)
        print(f'  N{jlpt_level} page {page}: {len(data)} entries ({len(words)} total)')
        page += 1
        time.sleep(0.5)
    return words


def _parse_entry(entry: dict, jlpt_level: int) -> dict | None:
    japanese = entry.get('japanese', [])
    if not japanese:
        return None
    first = japanese[0]
    word = first.get('word') or first.get('reading', '')
    reading = first.get('reading') or word
    if not word or not reading:
        return None

    senses = entry.get('senses', [])
    if not senses:
        return None

    all_glosses = []
    field_tags = set()
    for sense in senses:
        for gloss in sense.get('english_definitions', []):
            if gloss and gloss not in all_glosses:
                all_glosses.append(gloss)
        for field in sense.get('field', []):
            if field in FIELD_TAGS:
                field_tags.add(FIELD_TAGS[field])
        for part in sense.get('parts_of_speech', []):
            p = part.lower()
            if 'animal' in p or 'creature' in p:
                field_tags.add('animals')

    if not all_glosses:
        return None

    band = LEVEL_BAND[jlpt_level]
    compound_tags = [f'{band} {t.title()}' for t in field_tags]
    tags = compound_tags + [t.title() for t in field_tags]

    return {
        'word': word,
        'reading': reading,
        'meanings': all_glosses[0],
        'acceptable_answers': all_glosses,
        'jlpt_level': jlpt_level,
        'tags': sorted(set(tags)),
    }


def main():
    out = BASE / 'data' / 'vocab.json'
    all_words = []
    for level in JLPT_LEVELS:
        print(f'Fetching N{level}...')
        words = fetch_level(level)
        all_words.extend(words)
        print(f'  N{level}: {len(words)} words')
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(all_words, ensure_ascii=False, indent=2))
    print(f'\nTotal: {len(all_words)} words → {out}')


if __name__ == '__main__':
    main()
