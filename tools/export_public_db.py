#!/usr/bin/env python3
"""
Export a clean public version of kanji.db for GitHub release.

Strips runtime-only tables (user_progress, session_log) and copies all
content tables into a standalone release DB.

Output: tools/export/
  kanji_app_data.db  — clean content-only SQLite database
  schema.sql         — CREATE TABLE statements for all exported tables
  README.md          — attribution and licence summary

Usage:
    python3 tools/export_public_db.py
    python3 tools/export_public_db.py --out /path/to/output/dir
"""

import argparse
import sqlite3
import shutil
import sys
from pathlib import Path

BASE = Path(__file__).parent
SOURCE_DB = BASE.parent / 'kanji_app' / 'assets' / 'kanji.db'
DEFAULT_OUT = BASE / 'export'

SKIP_TABLES = {'user_progress', 'session_log'}

README_CONTENT = """\
# JLPT Kanji & Vocabulary — Public Data

SQLite database of kanji, vocabulary, sentences, JLPT practice questions,
and kana data used in the **JLPT Kanji & Vocabulary** Android app
([Google Play](https://play.google.com/store/apps/details?id=com.rainmog.kanji_app)).

## Tables

| Table | Description |
|-------|-------------|
| `kanji` | 2230 JLPT N1–N5 kanji with readings, meanings, stroke count |
| `kanji_tags` | Thematic tags per kanji (animals, food, body, …) |
| `sentences` | 9 graded example sentences per kanji (difficulty 1–9) |
| `vocabulary` | 8 000+ JLPT-classified vocab entries with readings and meanings |
| `vocabulary_tags` | POS and thematic tags per vocab entry |
| `jlpt_questions` | Official-style JLPT N1–N5 practice questions |
| `kana` | Hiragana + katakana with rōmaji |
| `kana_words` | Common words written in kana |

## Data Sources & Licences

**Kanji readings / meanings / stroke count** — KANJIDIC2
Licence: Creative Commons Attribution-ShareAlike 4.0 (CC BY-SA 4.0)
© James William Breen / Electronic Dictionary Research and Development Group
<https://www.edrdg.org/wiki/index.php/KANJIDIC_Project>

**Vocabulary** — JMdict/EDICT
Licence: Creative Commons Attribution-ShareAlike 4.0 (CC BY-SA 4.0)
© Electronic Dictionary Research and Development Group
<https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project>

**JLPT level assignments (kanji)** — kanji-data by David Gouveia
Licence: MIT
<https://github.com/davidluzgouveia/kanji-data>

This database is itself distributed under CC BY-SA 4.0, as required by the
upstream KANJIDIC2 and JMdict licences.

"JLPT" is a registered trademark of the Japan Educational Exchanges and Services (JEES).
This data is not affiliated with or endorsed by JEES or the Japan Foundation.
"""

SCHEMA_HEADER = """\
-- kanji_app_data.db — public schema
-- Tables: kanji, kanji_tags, sentences, vocabulary, vocabulary_tags,
--         jlpt_questions, kana, kana_words
-- Runtime tables (user_progress, session_log) are NOT included.

"""


def export(src: Path, out_dir: Path) -> None:
    if not src.exists():
        print(f'ERROR: source DB not found: {src}', file=sys.stderr)
        sys.exit(1)

    out_dir.mkdir(parents=True, exist_ok=True)
    dest = out_dir / 'kanji_app_data.db'
    schema_path = out_dir / 'schema.sql'
    readme_path = out_dir / 'README.md'

    shutil.copy2(src, dest)

    conn = sqlite3.connect(dest)
    c = conn.cursor()

    c.execute("SELECT name FROM sqlite_master WHERE type='table'")
    all_tables = [r[0] for r in c.fetchall()]
    to_drop = [t for t in all_tables if t in SKIP_TABLES]
    for t in to_drop:
        c.execute(f'DROP TABLE [{t}]')
        # Remove sqlite_sequence entry so the autoincrement counter doesn't leak info
        c.execute("DELETE FROM sqlite_sequence WHERE name = ?", (t,))

    conn.commit()
    conn.isolation_level = None
    c.execute("VACUUM")

    # Collect schema for remaining tables
    c.execute(
        "SELECT sql FROM sqlite_master WHERE type IN ('table','index') AND sql IS NOT NULL "
        "ORDER BY type DESC, name"
    )
    schema_lines = [r[0] + ';\n' for r in c.fetchall()]
    conn.close()

    schema_path.write_text(SCHEMA_HEADER + '\n'.join(schema_lines), encoding='utf-8')
    readme_path.write_text(README_CONTENT, encoding='utf-8')

    size_mb = dest.stat().st_size / 1_000_000
    print(f'Exported  {dest}  ({size_mb:.1f} MB)')
    print(f'Schema    {schema_path}')
    print(f'README    {readme_path}')
    print(f'Dropped tables: {to_drop}')


def main():
    parser = argparse.ArgumentParser(description='Export public DB.')
    parser.add_argument('--out', type=Path, default=DEFAULT_OUT, help='Output directory')
    args = parser.parse_args()
    export(SOURCE_DB, args.out)


if __name__ == '__main__':
    main()
