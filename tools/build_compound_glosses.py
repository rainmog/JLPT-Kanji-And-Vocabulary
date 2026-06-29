#!/usr/bin/env python3
"""
Build English glosses for sentence compounds that are NOT in the curated vocab deck.

These compounds surface in kanji compound practice (WordQuestion) but have no
vocabulary row, so the feedback popup had no meaning to show. We resolve them with:
  1. JMdict (exact surface, then deinflected dictionary forms)
  2. Claude API translation for whatever JMdict can't cover (segmentation
     artifacts, ad-hoc compounds)

Output: tools/data/compound_glosses.json  {surface: "meaning; meaning"}
Consumed by build_db.py → compound_glosses(word, meanings) table.

Usage:
    python3 tools/build_compound_glosses.py                 # JMdict + API
    python3 tools/build_compound_glosses.py --jmdict-only   # skip API pass
Re-running is safe — existing glosses in the JSON are kept (resumable API pass).
"""
import gzip
import json
import os
import re
import sqlite3
import sys
import time
from pathlib import Path

BASE = Path(__file__).parent
DB = BASE.parent / 'kanji_app' / 'assets' / 'kanji.db'
JMDICT = BASE / 'dev_artifacts' / 'JMdict_e.gz'
OUT = BASE / 'data' / 'compound_glosses.json'

KANJI_RE = re.compile(r'[一-鿿㐀-䶿豈-﫿]')

# ── Deinflection (mirror of sentence_repository.dart _deinflectCandidates) ──
_I_TO_U = {'き': 'く', 'ぎ': 'ぐ', 'し': 'す', 'ち': 'つ', 'に': 'ぬ',
           'ひ': 'ふ', 'び': 'ぶ', 'み': 'む', 'り': 'る', 'い': 'う'}
_A_TO_U = {'か': 'く', 'が': 'ぐ', 'さ': 'す', 'た': 'つ', 'な': 'ぬ',
           'ば': 'ぶ', 'ま': 'む', 'ら': 'る', 'わ': 'う', 'は': 'う'}
_TE_TA = {'して': ['する', 'す'], 'した': ['する', 'す'],
          'いて': ['く'], 'いた': ['く'], 'いで': ['ぐ'], 'いだ': ['ぐ'],
          'んで': ['む', 'ぶ', 'ぬ'], 'んだ': ['む', 'ぶ', 'ぬ'],
          'って': ['る', 'う', 'つ'], 'った': ['る', 'う', 'つ']}


def deinflect(s: str) -> list[str]:
    out: set[str] = set()
    for suf in ['ています', 'ていました', 'ていた', 'ている', 'てた', 'てる']:
        if s.endswith(suf):
            out.update(deinflect(s[:-len(suf)] + 'て'))
            break
    if len(s) >= 2:
        for e in _TE_TA.get(s[-2:], []):
            out.add(s[:-2] + e)
    if s.endswith(('て', 'た')):
        out.add(s[:-1] + 'る')
    for suf in ['まして', 'ました', 'ません', 'ます']:
        if s.endswith(suf):
            b = s[:-len(suf)]
            out.add(b + 'る')
            if b and b[-1] in _I_TO_U:
                out.add(b[:-1] + _I_TO_U[b[-1]])
            break
    for suf in ['なかった', 'ない']:
        if s.endswith(suf):
            b = s[:-len(suf)]
            out.add(b + 'る')
            if b and b[-1] in _A_TO_U:
                out.add(b[:-1] + _A_TO_U[b[-1]])
            break
    if s.endswith('かった'):
        out.add(s[:-3] + 'い')
    if s.endswith('くて'):
        out.add(s[:-2] + 'い')
    if s.endswith('く'):
        out.add(s[:-1] + 'い')
    out.discard(s)
    return list(out)


# ── Collect compounds needing glosses ──────────────────────────────────────
def collect_compounds() -> dict[str, str]:
    """Return {surface: representative_reading} for compounds absent from vocab."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    vocab = set(r[0] for r in c.execute('SELECT word FROM vocabulary'))
    usually_kana = set(r[0] for r in c.execute(
        "SELECT v.word FROM vocabulary v JOIN vocabulary_tags t "
        "ON v.id=t.vocab_id WHERE t.tag='usually_kana'"))

    def in_vocab(w):
        return w in vocab or any(x in vocab for x in deinflect(w))

    surfaces: dict[str, str] = {}
    for (ts,) in c.execute('SELECT text_structured FROM sentences'):
        try:
            toks = json.loads(ts)
        except (json.JSONDecodeError, TypeError):
            continue
        for t in toks:
            s = t.get('surface', '')
            if len(s) > 1 and KANJI_RE.search(s) and s not in usually_kana and not in_vocab(s):
                surfaces.setdefault(s, t.get('reading', ''))
    conn.close()
    return surfaces


# ── JMdict gloss index ─────────────────────────────────────────────────────
ENTRY_RE = re.compile(r'<entry>(.*?)</entry>', re.DOTALL)
KEB_RE = re.compile(r'<keb>(.*?)</keb>')
SENSE_RE = re.compile(r'<sense>(.*?)</sense>', re.DOTALL)
GLOSS_RE = re.compile(r'<gloss[^>]*>(.*?)</gloss>')


def build_jmdict_index() -> dict[str, str]:
    """keb → 'gloss; gloss' from the first sense of the first entry holding it."""
    print(f'Reading {JMDICT}...')
    with gzip.open(JMDICT, 'rt', encoding='utf-8') as f:
        data = f.read()
    idx: dict[str, str] = {}
    for entry in ENTRY_RE.findall(data):
        kebs = KEB_RE.findall(entry)
        if not kebs:
            continue
        sense = SENSE_RE.search(entry)
        if not sense:
            continue
        glosses = GLOSS_RE.findall(sense.group(1))
        if not glosses:
            continue
        meaning = '; '.join(glosses[:2])
        for keb in kebs:
            idx.setdefault(keb, meaning)
    print(f'  {len(idx)} JMdict headwords indexed')
    return idx


def jmdict_gloss(surface: str, idx: dict[str, str]) -> str | None:
    if surface in idx:
        return idx[surface]
    for cand in deinflect(surface):
        if cand in idx:
            return idx[cand]
    return None


# ── Claude API translation for the remainder ───────────────────────────────
BATCH_SIZE = 25


def translate_batch(items: list[dict], client) -> list[str]:
    prompt = (
        "Translate each Japanese word/compound to a SHORT English dictionary gloss "
        "(1-4 words, like a dictionary definition, no trailing period). "
        "Use the reading for disambiguation. "
        "Return ONLY a JSON array of strings, one per item, same order.\n\n"
        + json.dumps(items, ensure_ascii=False)
    )
    resp = client.messages.create(
        model='claude-haiku-4-5-20251001',
        max_tokens=2048,
        messages=[{'role': 'user', 'content': prompt}],
    )
    text = resp.content[0].text.strip()
    if text.startswith('```'):
        text = text.split('\n', 1)[1].rsplit('```', 1)[0].strip()
    return json.loads(text)


def main():
    jmdict_only = '--jmdict-only' in sys.argv

    glosses: dict[str, str] = {}
    if OUT.exists():
        glosses = json.loads(OUT.read_text())
        print(f'Loaded {len(glosses)} existing glosses (resuming)')

    surfaces = collect_compounds()
    print(f'{len(surfaces)} compounds absent from vocab')

    idx = build_jmdict_index()
    need_api: list[tuple[str, str]] = []
    jm_hits = 0
    for surface, reading in surfaces.items():
        if surface in glosses:
            continue
        g = jmdict_gloss(surface, idx)
        if g:
            glosses[surface] = g
            jm_hits += 1
        else:
            need_api.append((surface, reading))
    print(f'JMdict resolved {jm_hits}; {len(need_api)} need API translation')
    OUT.write_text(json.dumps(glosses, ensure_ascii=False, indent=0, sort_keys=True))

    if jmdict_only or not need_api:
        print(f'Wrote {len(glosses)} glosses → {OUT}')
        return

    if not os.environ.get('ANTHROPIC_API_KEY'):
        print('ERROR: set ANTHROPIC_API_KEY for the API pass (or use --jmdict-only)',
              file=sys.stderr)
        sys.exit(1)
    import anthropic
    client = anthropic.Anthropic()

    for i in range(0, len(need_api), BATCH_SIZE):
        chunk = need_api[i:i + BATCH_SIZE]
        items = [{'word': w, 'reading': r} for w, r in chunk]
        try:
            results = translate_batch(items, client)
        except Exception as e:  # noqa: BLE001 — best-effort, keep going
            print(f'  batch {i // BATCH_SIZE} failed: {e}; retrying once')
            time.sleep(2)
            results = translate_batch(items, client)
        for (w, _r), gloss in zip(chunk, results):
            if isinstance(gloss, str) and gloss.strip():
                glosses[w] = gloss.strip().rstrip('.')
        OUT.write_text(json.dumps(glosses, ensure_ascii=False, indent=0, sort_keys=True))
        print(f'  {min(i + BATCH_SIZE, len(need_api))}/{len(need_api)} translated')

    print(f'Wrote {len(glosses)} glosses → {OUT}')


if __name__ == '__main__':
    main()
