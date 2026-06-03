#!/usr/bin/env python3
"""
Parse JMdict_e.gz and extract POS + register tags for our vocab entries.
Outputs tools/data/vocab_pos_tags.json: {"word|reading": ["noun", "verb", ...]}

Usage:
    python3 tools/parse_jmdict.py [path/to/JMdict_e.gz]
    python3 tools/build_db.py   # picks up vocab_pos_tags.json automatically
"""
import gzip, re, json, sys
from pathlib import Path

BASE = Path(__file__).parent

# JMdict entity code → our tag name
POS_MAP = {
    'n': 'noun', 'n-adv': 'noun', 'n-suf': 'noun', 'n-pref': 'noun', 'n-t': 'noun',
    'v1': 'verb', 'v1-s': 'verb',
    'v5r': 'verb', 'v5k': 'verb', 'v5g': 'verb', 'v5s': 'verb', 'v5t': 'verb',
    'v5n': 'verb', 'v5b': 'verb', 'v5m': 'verb', 'v5u': 'verb', 'v5u-s': 'verb',
    'v5aru': 'verb', 'v5k-s': 'verb', 'v5r-i': 'verb',
    'vi': 'verb', 'vt': 'verb', 'vk': 'verb',
    'vs': 'verb', 'vs-c': 'verb', 'vs-s': 'verb', 'vs-i': 'verb',
    'vz': 'verb', 'v2a-s': 'verb', 'v4h': 'verb', 'v4r': 'verb', 'vr': 'verb', 'vn': 'verb',
    'adj-i': 'adjective', 'adj-ix': 'adjective', 'adj-na': 'adjective',
    'adj-nari': 'adjective', 'adj-t': 'adjective', 'adj-f': 'adjective',
    'adj-ku': 'adjective', 'adj-shiku': 'adjective', 'adj-kari': 'adjective',
    'adv': 'adverb', 'adv-to': 'adverb',
    'conj': 'conjunction',
    'prt': 'particle',
    'exp': 'expression',
    'int': 'interjection',
    'pn': 'pronoun',
    'ctr': 'counter',
    'suf': 'suffix',
    'pref': 'prefix',
    'aux': 'auxiliary', 'aux-v': 'auxiliary', 'aux-adj': 'auxiliary',
}

MISC_MAP = {
    'col': 'colloquial',
    'hon': 'honorific',
    'pol': 'polite',
    'sl': 'slang',
    'arch': 'archaic',
    'on-mim': 'onomatopoeia',
    'vulg': 'slang',
}

ENTRY_RE = re.compile(r'<entry>(.*?)</entry>', re.DOTALL)
KEB_RE   = re.compile(r'<keb>(.*?)</keb>')
REB_RE   = re.compile(r'<reb>(.*?)</reb>')
POS_RE   = re.compile(r'<pos>&([^;]+);</pos>')
MISC_RE  = re.compile(r'<misc>&([^;]+);</misc>')


def parse_jmdict(jmdict_path: str) -> dict[str, list[str]]:
    print(f'Reading {jmdict_path}...')
    with gzip.open(jmdict_path, 'rb') as f:
        content = f.read().decode('utf-8')

    print('Parsing entries...')
    lookup: dict[str, set[str]] = {}

    for m in ENTRY_RE.finditer(content):
        entry = m.group(1)
        kebs = KEB_RE.findall(entry)
        rebs = REB_RE.findall(entry)

        tags: set[str] = set()
        for code in POS_RE.findall(entry):
            t = POS_MAP.get(code)
            if t:
                tags.add(t)
        for code in MISC_RE.findall(entry):
            t = MISC_MAP.get(code)
            if t:
                tags.add(t)

        if not tags:
            continue

        if kebs:
            for keb in kebs:
                for reb in rebs:
                    lookup.setdefault(f'{keb}|{reb}', set()).update(tags)
        else:
            for reb in rebs:
                lookup.setdefault(f'{reb}|{reb}', set()).update(tags)

    print(f'Built lookup with {len(lookup)} keyed entries')
    return {k: sorted(v) for k, v in lookup.items()}


def main():
    # Resolve JMdict path
    if len(sys.argv) > 1:
        jmdict_path = sys.argv[1]
    else:
        candidates = [
            BASE.parent / 'JMdict_e.gz',
            Path.home() / 'Downloads' / 'JMdict_e.gz',
        ]
        jmdict_path = next((str(p) for p in candidates if p.exists()), None)
        if not jmdict_path:
            print('Error: JMdict_e.gz not found. Provide path as argument.', file=sys.stderr)
            sys.exit(1)

    lookup = parse_jmdict(jmdict_path)

    vocab_path = BASE / 'data' / 'vocab.json'
    vocab_data = json.loads(vocab_path.read_text())

    result: dict[str, list[str]] = {}
    matched = 0
    for entry in vocab_data:
        key = f"{entry['word']}|{entry['reading']}"
        tags = lookup.get(key)
        if tags:
            result[key] = tags
            matched += 1

    out_path = BASE / 'data' / 'vocab_pos_tags.json'
    out_path.write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print(f'Matched {matched} / {len(vocab_data)} vocab entries ({matched/len(vocab_data)*100:.1f}%)')
    print(f'Saved → {out_path}')

    # Tag distribution
    from collections import Counter
    tag_counts: Counter = Counter()
    for tags in result.values():
        tag_counts.update(tags)
    print('\nTag distribution:')
    for tag, count in tag_counts.most_common():
        print(f'  {tag}: {count}')


if __name__ == '__main__':
    main()
