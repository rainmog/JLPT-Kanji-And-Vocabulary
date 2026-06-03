"""
Build per-kanji compound word lookup from JMdict simplified.
Output: data/compound_dict.json  { "食": [{word, reading, meaning, common}, ...], ... }
"""
import json, sys
from pathlib import Path
from collections import defaultdict

BASE = Path(__file__).parent
JMDICT = Path('/tmp/jmdict-eng-3.6.2.json')

if not JMDICT.exists():
    print("ERROR: JMdict not found at /tmp/jmdict-eng-3.6.2.json", file=sys.stderr)
    print("Download: https://github.com/scriptin/jmdict-simplified/releases/latest", file=sys.stderr)
    sys.exit(1)

print("Loading JMdict...", flush=True)
data = json.load(open(JMDICT, encoding='utf-8'))
words = data['words']
print(f"  {len(words):,} entries", flush=True)

def is_cjk(c: str) -> bool:
    return '一' <= c <= '鿿'

# Build kanji → compounds mapping
kanji_compounds: dict[str, list] = defaultdict(list)

for w in words:
    kana_forms = w.get('kana', [])
    senses = w.get('sense', [])
    if not kana_forms or not senses:
        continue

    # Best English gloss
    gloss = ''
    for s in senses:
        glosses = [g['text'] for g in s.get('gloss', []) if g.get('lang') == 'eng']
        if glosses:
            gloss = glosses[0]
            break

    for k in w.get('kanji', []):
        text: str = k['text']
        common: bool = k.get('common', False)

        # Must be multi-char and contain at least one CJK character
        if len(text) < 2:
            continue
        cjk_chars = [c for c in text if is_cjk(c)]
        if not cjk_chars:
            continue

        # Find correct kana reading for this kanji form
        reading = ''
        for kana in kana_forms:
            applies = kana.get('appliesToKanji', ['*'])
            if '*' in applies or text in applies:
                reading = kana['text']
                break
        if not reading:
            continue

        for char in set(cjk_chars):
            kanji_compounds[char].append({
                'word': text,
                'reading': reading,
                'meaning': gloss,
                'common': common,
            })

# Sort each kanji's list: common first, then shorter words, deduplicate by word
result: dict[str, list] = {}
for char, compounds in kanji_compounds.items():
    compounds.sort(key=lambda x: (not x['common'], len(x['word'])))
    seen: set[str] = set()
    deduped = []
    for c in compounds:
        if c['word'] not in seen:
            seen.add(c['word'])
            deduped.append(c)
    result[char] = deduped[:30]  # cap at 30 per kanji

out = BASE / 'data' / 'compound_dict.json'
with open(out, 'w', encoding='utf-8') as f:
    json.dump(result, f, ensure_ascii=False, indent=2)

print(f"Written {out}")
print(f"  Kanji with compounds: {len(result):,}")
covered = sum(1 for v in result.values() if any(c['common'] for c in v))
print(f"  With at least one common compound: {covered:,}")
