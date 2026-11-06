"""Repair wrong compound readings in sentence tokens, validated against JMdict.

`fix_compound_readings.py` catches readings that are *truncated* (会議 → "ぎ").
This pass catches the rest of the same family of bad generated data, found by
auditing every kanji token in the sentences against JMdict + the vocabulary
table:

  * readings that are simply wrong:   不足 → ぶそく (ふそく), 暫定 → ぎん,
                                      母親 → ぼしん, 文学 → ぶngaku
  * readings with junk glued on:      時代 → じだい。, 育ち → そだち、その,
                                      解決 → かいけつ（
  * okurigana dropped:                並ぶ → なら (ならぶ)

A multi-kanji word's reading is replaced by the dictionary reading when the
dictionary has exactly one, or when several exist and the vocabulary table (or
a clearly closest candidate) picks one. A wrong target token with no
trustworthy replacement can't be used as a quiz answer: its sentence is
dropped (or, if that would leave the kanji without sentences, demoted so it
yields no questions), exactly like the compound repair.

Tokens that carry okurigana are only cleaned of junk / get their dropped
okurigana restored. Their stems legitimately differ from the dictionary form
(超え → こえ, 避け → さけ), so replacing them from a dictionary would corrupt
good data.

Patches both tools/data/sentences_v2.json and kanji_app/assets/kanji.db.
Idempotent: writes nothing on clean data. build_db.py refuses to build while
repairs are pending.

Usage: python3 tools/fix_reading_mismatches.py [--dry-run] [--jmdict PATH]
"""
import argparse
import difflib
import gzip
import json
import re
import sqlite3
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fix_compound_readings import (  # noqa: E402
    DB_PATH, JSON_PATH, ROOT, demote, hira, is_kanji, is_misaligned,
)

# Valid readings JMdict doesn't list (names, set phrases).
KNOWN_GOOD = {
    ('弘法', 'こうぼう'),
    ('鎌足', 'かまたり'),
    ('水面', 'みずおもて'),
    ('三十', 'さんじゅっ'),
    ('朝陽', 'あさひ'),
    ('一棟', 'いっとう'),
    ('桃園', 'とうえん'),
    ('夏冬', 'なつふゆ'),
    ('賢い', 'さとい'),
    ('逃がす', 'のがす'),
}

# Endings of a dictionary-form verb / adjective. A single-kanji word with one
# of these is looked up as-is; other okurigana endings (…り, …え, …け) are
# inflected stems or nouns whose reading legitimately differs from the entry.
DICT_ENDINGS = 'うくぐすつぬぶむるいか'

_LEADING_KANA = re.compile(r'^[ぁ-ゖァ-ヺー]+')
_ALL_KANA = re.compile(r'[ぁ-ゖァ-ヺー]+')
_TRAILING_PUNCT = re.compile(r'[。、，,！!？?「」『』（）()・…\s]+$')


def merged_junk(reading):
    """True when a reading has other tokens' text spilled into it (a delimiter
    or kanji inside it) — the sentence's furigana can't be trusted."""
    core = _TRAILING_PUNCT.sub('', reading)
    return bool(re.search('[、,，:：・]', core)) or any(is_kanji(c) for c in core)
MIN_SIMILARITY = 0.7


def find_jmdict(explicit):
    candidates = [Path(explicit)] if explicit else []
    candidates += [ROOT / 'tools' / 'JMdict_e.gz', ROOT / 'tools' / 'dev_artifacts' / 'JMdict_e.gz']
    candidates += [p / 'tools' / 'dev_artifacts' / 'JMdict_e.gz' for p in ROOT.parents]
    for c in candidates:
        if c.is_file():
            return c
    sys.exit('JMdict_e.gz not found — pass --jmdict PATH')


def load_jmdict(path):
    """surface -> ordered list of hiragana readings (JMdict entry order)."""
    out = defaultdict(list)
    with gzip.open(path) as f:
        for _, el in ET.iterparse(f):
            if el.tag != 'entry':
                continue
            kebs = [k.findtext('keb') for k in el.findall('k_ele')]
            rebs = [hira(r.findtext('reb')) for r in el.findall('r_ele')]
            for k in kebs:
                for r in rebs:
                    if r not in out[k]:
                        out[k].append(r)
            el.clear()
    return out


def is_all_kanji(s):
    return len(s) >= 2 and all(is_kanji(c) for c in s)


def has_kanji(s):
    return any(is_kanji(c) for c in s)


def okurigana(surface):
    """Trailing hiragana of a surface (the okurigana), '' if none."""
    n = 0
    while n < len(surface) and '぀' <= surface[-1 - n] <= 'ゟ':
        n += 1
    return surface[len(surface) - n:] if n else ''


class Resolver:
    def __init__(self, jm, vocab, kun_stems=None):
        self.jm = jm
        self.vocab = vocab  # surface -> {reading: count}
        self.kun = kun_stems or {}  # kanji -> {kun reading stems}

    def candidates(self, surface):
        out = list(self.vocab.get(surface, {}))
        for r in self.jm.get(surface, []):
            if r not in out:
                out.append(r)
        return out

    def pick(self, surface, reading, cands):
        """Best replacement for a wrong [reading], or None if untrustworthy."""
        if len(cands) == 1:
            return cands[0]  # the dictionary knows exactly one reading
        known = self.vocab.get(surface, {})
        scored = sorted(
            ((difflib.SequenceMatcher(None, reading, c).ratio(),
              c in known, -i, c) for i, c in enumerate(cands)), reverse=True)
        best = scored[0]
        if best[0] < MIN_SIMILARITY:
            return None
        rivals = [x for x in scored[1:] if x[0] == best[0]]
        if rivals and not (best[1] and not any(r[1] for r in rivals)):
            return None  # a tie only the curated vocabulary table may break
        return best[3]

    def fix_token(self, token):
        """Returns ('ok'|'fixed'|'unresolved', new_reading)."""
        surface = token.get('surface', '')
        old = token.get('reading', '')
        if not has_kanji(surface):
            return 'ok', old

        # Cosmetic junk: sentence punctuation glued to the end (うつくしい。).
        stripped = _TRAILING_PUNCT.sub('', old)
        pure = bool(_ALL_KANA.fullmatch(stripped))
        base = stripped if pure else old
        norm = hira(base)

        if (surface, norm) in KNOWN_GOOD:
            return ('fixed', base) if base != old else ('ok', old)

        tail = okurigana(surface)
        if tail:
            # Inflected / okurigana words: restore dropped okurigana only.
            if pure and not norm.endswith(tail) and (norm + tail) in self.candidates(surface):
                base = base + tail
                norm = norm + tail
            if pure and len(surface) - len(tail) == 1 and surface[-1] in DICT_ENDINGS:
                # One-kanji dictionary-form word whose stem isn't a kun reading
                # of its kanji (招く → しょうく = on reading + okurigana).
                cands = self.candidates(surface)
                stem = norm[:-len(tail)] if norm.endswith(tail) else norm
                if cands and norm not in cands and stem not in self.kun.get(surface[0], set()):
                    new = self.pick(surface, norm, cands)
                    if new is None:
                        return 'unresolved', old
                    return 'fixed', new
            return ('fixed', base) if pure and base != old else ('ok', old)

        if not is_all_kanji(surface):
            return ('fixed', base) if pure and base != old else ('ok', old)

        cands = self.candidates(surface)
        if not cands:
            return ('fixed', base) if pure and base != old else ('ok', old)
        if pure and norm in cands:
            return ('fixed', base) if base != old else ('ok', old)
        lead = _LEADING_KANA.match(old)
        new = self.pick(surface, hira(lead.group(0)) if lead else norm, cands)
        if new is None:
            return 'unresolved', old
        return 'fixed', new


def repair_sentence(sentence, resolver):
    """Mutates [sentence]; returns ('ok'|'fixed'|'unresolved', changes).
    'unresolved' = a *target* token is wrong with no trustworthy fix."""
    if is_misaligned(sentence['text_structured']):
        return 'ok', []  # handled by fix_compound_readings
    if any(has_kanji(t.get('surface', '')) and merged_junk(t.get('reading', ''))
           for t in sentence['text_structured']):
        return 'unresolved', []  # another token's text spilled into a reading
    changes = []
    unresolved = False
    for t in sentence['text_structured']:
        status, new = resolver.fix_token(t)
        if status == 'unresolved':
            if t.get('kanji_char'):
                unresolved = True
            continue
        if status == 'fixed' and new != t['reading']:
            old = t['reading']
            t['reading'] = new
            changes.append((t['surface'], old, new))
            vr = sentence.get('valid_readings')
            if isinstance(vr, list) and old in vr:
                sentence['valid_readings'] = [new if r == old else r for r in vr]
    if unresolved:
        return 'unresolved', changes
    return ('fixed' if changes else 'ok'), changes


def main(dry_run=False, jmdict=None):
    db = sqlite3.connect(DB_PATH)
    vocab = defaultdict(Counter)
    for w, r in db.execute('SELECT word, reading FROM vocabulary'):
        if w and r and has_kanji(w):
            vocab[w][hira(r)] += 1
    kun = {}
    for ch, kr in db.execute('SELECT character, kun_reading FROM kanji'):
        kun[ch] = {hira(p.split('.')[0].strip('-')) for p in re.split(r'[・、,\s]+', kr or '') if p}
    resolver = Resolver(load_jmdict(find_jmdict(jmdict)), vocab, kun)

    raw_json = JSON_PATH.read_text(encoding='utf-8')
    data = json.loads(raw_json)
    raw_db = {}
    db_rows = []
    for sid, kid, ts, vr in db.execute(
            'SELECT id, kanji_id, text_structured, valid_readings FROM sentences'):
        raw_db[sid] = (ts, vr)
        db_rows.append((sid, kid, json.loads(ts), json.loads(vr) if vr else None))

    stats = Counter()
    examples = []
    for k in data:
        kept, pending_drop = [], []
        for s in k['sentences']:
            status, changes = repair_sentence(s, resolver)
            stats[status] += 1
            examples.extend((k['character'], *c) for c in changes)
            (pending_drop if status == 'unresolved' else kept).append(s)
        if pending_drop and not kept:
            for s in pending_drop:
                demote(s, None)
            kept = pending_drop
            stats['demoted'] += len(pending_drop)
        else:
            stats['dropped'] += len(pending_drop)
        k['sentences'] = kept

    db_stats = Counter()
    per_kanji = defaultdict(list)
    for row in db_rows:
        per_kanji[row[1]].append(row)
    updates, deletes = [], []
    for kid, rows in per_kanji.items():
        results = []
        for sid, _, tokens, vr in rows:
            sent = {'text_structured': tokens, 'valid_readings': vr}
            status, _ = repair_sentence(sent, resolver)
            db_stats[status] += 1
            results.append((sid, status, sent))
        survivors = [r for r in results if r[1] != 'unresolved']
        for sid, status, sent in results:
            if status == 'unresolved' and not survivors:
                demote(sent, None)
                updates.append((sid, sent))
                db_stats['demoted'] += 1
            elif status == 'unresolved':
                deletes.append(sid)
                db_stats['dropped'] += 1
            elif status == 'fixed':
                updates.append((sid, sent))

    print('JSON :', dict(stats))
    print('DB   :', dict(db_stats))
    for e in examples[:25]:
        print('  ', e)

    changed = []
    for sid, sent in updates:
        ts = json.dumps(sent['text_structured'], ensure_ascii=False)
        vr = (json.dumps(sent['valid_readings'], ensure_ascii=False)
              if sent['valid_readings'] is not None else None)
        if (ts, vr) != raw_db[sid]:
            changed.append((ts, vr, sid))
    new_json = json.dumps(data, ensure_ascii=False, indent=2)

    pending = bool(changed or deletes or new_json != raw_json)
    if dry_run:
        print(f'dry run — would write {len(changed)} updates, {len(deletes)} deletes, '
              f'JSON {"changed" if new_json != raw_json else "unchanged"}')
        return pending

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
    return pending


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--jmdict')
    args = ap.parse_args()
    main(args.dry_run, args.jmdict)
