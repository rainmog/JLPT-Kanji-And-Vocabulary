"""Repair truncated compound-word readings in sentence tokens.

Some target tokens in sentences_v2.json store only the target kanji's part of
the reading instead of the whole word, e.g. 会議 -> "ぎ" (target 議) or
日記 -> "き" (target 記). Word-practice questions then use that fragment as the
correct answer while the distractors are full-word readings, and sentence
furigana is wrong.

A token is suspect when its surface holds >= 2 kanji and either
  * its reading is shorter than the number of kanji (can't cover the word), or
  * it is a target token whose reading equals the target kanji's own
    standalone on/kun reading.
The correct reading is taken from the same surface elsewhere in the data
(most common non-suspect reading), else from the vocabulary table.

Some sentences are misaligned as a whole (readings shifted onto neighbouring
tokens, e.g. 移行:が / が:たいせい). Fixing one token there would leave the rest
of the furigana wrong, so misaligned sentences are dropped, as are sentences
with an unresolvable suspect token. If that would leave a kanji with no
sentences, its sentences are kept but demoted (no quiz target), so no
question is ever built from unreliable readings.

Patches both tools/data/sentences_v2.json and kanji_app/assets/kanji.db.

Usage: python3 tools/fix_compound_readings.py [--dry-run]
"""
import json
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / 'tools' / 'data' / 'sentences_v2.json'
DB_PATH = ROOT / 'kanji_app' / 'assets' / 'kanji.db'


def hira(s):
    return ''.join(chr(ord(c) - 0x60) if 'ァ' <= c <= 'ヶ' else c for c in s or '')


def is_kanji(c):
    return '一' <= c <= '鿿' or c == '々'


def kanji_count(surface):
    return sum(is_kanji(c) for c in surface)


def load_reference(db):
    standalone = {}
    for ch, on, kun in db.execute('SELECT character, on_reading, kun_reading FROM kanji'):
        rs = set()
        for part in re.split(r'[、,，\s]+', f'{on or ""},{kun or ""}'):
            p = hira(part.split('.')[0].strip('-').strip())
            if p:
                rs.add(p)
        standalone[ch] = rs
    vocab = defaultdict(Counter)
    for w, r in db.execute('SELECT word, reading FROM vocabulary'):
        if w and r:
            vocab[w][hira(r)] += 1
    return standalone, vocab


def is_suspect(token, standalone):
    surface = token.get('surface', '')
    nk = kanji_count(surface)
    if nk < 2:
        return False
    reading = hira(token.get('reading', ''))
    if len(reading) < nk:
        return True
    # Checked against every kanji in the word, not just the tagged target, so
    # the verdict doesn't change once a token has been demoted (kanji_char
    # cleared) — otherwise a re-run would trust a demoted bad reading.
    return any(reading in standalone.get(c, set()) for c in surface if is_kanji(c))


def build_good_map(all_token_lists, standalone):
    good = defaultdict(Counter)
    for tokens in all_token_lists:
        if is_misaligned(tokens):
            continue
        for t in tokens:
            s = t.get('surface', '')
            if kanji_count(s) >= 2 and t.get('reading') and not is_suspect(t, standalone):
                good[s][hira(t['reading'])] += 1
    return good


def resolve(surface, good, vocab):
    if good.get(surface):
        return good[surface].most_common(1)[0][0]
    if vocab.get(surface):
        return vocab[surface].most_common(1)[0][0]
    return None


_PUNCT = re.compile(r'[。、，,．.！!？?「」『』（）()\s・…\-—*:：;；〜~]')


def _norm(s):
    return _PUNCT.sub('', hira(s))


def is_misaligned(tokens):
    """True when readings are shifted relative to surfaces: a kana-only token
    whose reading isn't its own text (punctuation ignored), or the same kanji
    surface repeated back-to-back (tokenizer duplication). Patching a single
    token in such a sentence would leave the rest of its furigana wrong."""
    for t in tokens:
        s = t.get('surface', '')
        if s and not any(is_kanji(c) for c in s):
            r = _norm(t.get('reading', ''))
            if r and r != _norm(s):
                return True
    for a, b in zip(tokens, tokens[1:]):
        if a.get('surface') == b.get('surface') and kanji_count(a.get('surface', '')) > 0:
            return True
    return False


def repair_sentence(sentence, standalone, good, vocab):
    """Returns ('ok'|'fixed'|'unresolved', changes). Mutates sentence in place
    for fixable tokens; unresolved means the sentence is misaligned or at
    least one suspect token had no known reading."""
    if is_misaligned(sentence['text_structured']):
        return 'unresolved', []
    changes = []
    unresolved = False
    for t in sentence['text_structured']:
        if not is_suspect(t, standalone):
            continue
        new = resolve(t['surface'], good, vocab)
        if new is None:
            unresolved = True
            continue
        old = t['reading']
        if hira(old) == new:
            continue
        t['reading'] = new
        changes.append((t['surface'], old, new))
        vr = sentence.get('valid_readings')
        if isinstance(vr, list) and old in vr:
            sentence['valid_readings'] = [new if r == old else r for r in vr]
    if unresolved:
        return 'unresolved', changes
    return ('fixed' if changes else 'ok'), changes


def demote(sentence, standalone):
    """Keep the sentence but strip every quiz target from it, so no question
    is ever built from its (unreliable) readings."""
    for t in sentence['text_structured']:
        if t.get('kanji_char'):
            t['is_kanji'] = False
            t['kanji_char'] = None


def main(dry_run):
    db = sqlite3.connect(DB_PATH)
    standalone, vocab = load_reference(db)

    raw_json = JSON_PATH.read_text(encoding='utf-8')
    data = json.loads(raw_json)
    raw_db = {}
    db_rows = []
    for sid, kid, ts, vr in db.execute(
            'SELECT id, kanji_id, text_structured, valid_readings FROM sentences'):
        raw_db[sid] = (ts, vr)
        db_rows.append((sid, kid, json.loads(ts), json.loads(vr) if vr else None))

    good = build_good_map(
        [s['text_structured'] for k in data for s in k['sentences']]
        + [r[2] for r in db_rows], standalone)

    # --- JSON source ---
    stats = Counter()
    examples = []
    for k in data:
        kept = []
        pending_drop = []
        for s in k['sentences']:
            status, changes = repair_sentence(s, standalone, good, vocab)
            stats[status] += 1
            examples.extend((k['character'], *c) for c in changes)
            (pending_drop if status == 'unresolved' else kept).append(s)
        if pending_drop and not kept:
            for s in pending_drop:
                demote(s, standalone)
            kept = pending_drop
            stats['demoted'] += len(pending_drop)
        else:
            stats['dropped'] += len(pending_drop)
        k['sentences'] = kept

    # --- Asset DB ---
    db_stats = Counter()
    per_kanji = defaultdict(list)
    for row in db_rows:
        per_kanji[row[1]].append(row)
    updates, deletes = [], []
    for kid, rows in per_kanji.items():
        results = []
        for sid, _, tokens, vr in rows:
            sent = {'text_structured': tokens, 'valid_readings': vr}
            status, _ = repair_sentence(sent, standalone, good, vocab)
            db_stats[status] += 1
            results.append((sid, status, sent))
        survivors = [r for r in results if r[1] != 'unresolved']
        for sid, status, sent in results:
            if status == 'unresolved' and not survivors:
                demote(sent, standalone)
                updates.append((sid, sent))
                db_stats['demoted'] += 1
            elif status == 'unresolved':
                deletes.append(sid)
                db_stats['dropped'] += 1
            elif status == 'fixed':
                updates.append((sid, sent))

    print('JSON :', dict(stats))
    print('DB   :', dict(db_stats))
    for e in examples[:15]:
        print('  ', e)

    # Only rows whose serialized content actually changes are written, so a
    # re-run on already-repaired data touches neither file.
    changed = []
    for sid, sent in updates:
        ts = json.dumps(sent['text_structured'], ensure_ascii=False)
        vr = (json.dumps(sent['valid_readings'], ensure_ascii=False)
              if sent['valid_readings'] is not None else None)
        if (ts, vr) != raw_db[sid]:
            changed.append((ts, vr, sid))
    new_json = json.dumps(data, ensure_ascii=False, indent=2)

    if dry_run:
        print(f'dry run — would write {len(changed)} updates, {len(deletes)} deletes, '
              f'JSON {"changed" if new_json != raw_json else "unchanged"}')
        return

    if new_json != raw_json:
        JSON_PATH.write_text(new_json, encoding='utf-8')
    if changed or deletes:
        with db:
            db.executemany(
                'UPDATE sentences SET text_structured = ?, valid_readings = ? WHERE id = ?',
                changed)
            db.executemany('DELETE FROM sentences WHERE id = ?', [(s,) for s in deletes])
        db.execute('VACUUM')
    print(f'wrote {len(changed)} updates, {len(deletes)} deletes, '
          f'JSON {"changed" if new_json != raw_json else "unchanged"}')


if __name__ == '__main__':
    main('--dry-run' in sys.argv)
