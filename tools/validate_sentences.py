import json, re, sys
from pathlib import Path

BASE = Path(__file__).parent
HIRAGANA = re.compile(r'^[぀-ゟー]+$')

def validate(sentences_path: Path | str, kanji_path: Path | str) -> bool:
    with open(sentences_path, encoding='utf-8') as f:
        sentence_data = json.load(f)
    with open(kanji_path, encoding='utf-8') as f:
        kanji_list = json.load(f)

    kanji_chars = {k['character'] for k in kanji_list}
    sentence_chars = {d['character'] for d in sentence_data}
    missing = kanji_chars - sentence_chars
    if missing:
        print(f"MISSING sentences for {len(missing)} kanji: {list(missing)[:10]}")

    errors = []
    for entry in sentence_data:
        char = entry['character']
        sents = entry.get('sentences', [])
        if len(sents) != 9:
            errors.append(f"{char}: expected 9 sentences, got {len(sents)}")
            continue
        difficulties = sorted(s['difficulty'] for s in sents)
        if difficulties != list(range(1, 10)):
            errors.append(f"{char}: difficulties {difficulties} not 1-9")
        for s in sents:
            for r in s.get('valid_readings', []):
                if not HIRAGANA.match(r):
                    errors.append(f"{char} diff={s['difficulty']}: reading '{r}' not hiragana")
            if char not in s.get('text_kanji', ''):
                errors.append(f"{char} diff={s['difficulty']}: target kanji missing from sentence")

    if errors:
        print(f"\n{len(errors)} errors:")
        for e in errors[:20]:
            print(' ', e)
        return False
    total_sentences = sum(len(entry.get('sentences', [])) for entry in sentence_data)
    print(f"Validation passed: {len(sentence_data)} kanji, {total_sentences} sentences.")
    return True

if __name__ == '__main__':
    sentences_path = BASE / 'data' / 'sentences.json'
    kanji_path = BASE / 'data' / 'kanji.json'
    try:
        ok = validate(sentences_path, kanji_path)
    except FileNotFoundError as e:
        print(f"ERROR: file not found: {e.filename}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)
    sys.exit(0 if ok else 1)
