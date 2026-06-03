#!/usr/bin/env python3
"""
Export kanji_index.csv and kanji_index.json from kanji.json.

Data sources:
  - KANJIDIC2 (readings, stroke count, meanings): CC BY-SA 3.0
    https://www.edrdg.org/kanjidic/kanjidic2.html
  - davidluzgouveia/kanji-data (JLPT level assignments): MIT
    https://github.com/davidluzgouveia/kanji-data
"""

import json
import csv
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "data")
KANJI_JSON = os.path.join(DATA_DIR, "kanji.json")
OUT_CSV = os.path.join(DATA_DIR, "kanji_index.csv")
OUT_JSON = os.path.join(DATA_DIR, "kanji_index.json")

LEVEL_MAP = {1: "N1", 2: "N2", 3: "N3", 4: "N4", 5: "N5"}

def load_kanji():
    with open(KANJI_JSON, encoding="utf-8") as f:
        return json.load(f)

def build_rows(kanji_list):
    rows = []
    for k in kanji_list:
        level_num = k.get("jlpt_level")
        rows.append({
            "character": k["character"],
            "jlpt": LEVEL_MAP.get(level_num, ""),
            "on_reading": k.get("on_reading", ""),
            "kun_reading": k.get("kun_reading", ""),
            "meaning": k.get("meaning", ""),
            "stroke_count": k.get("stroke_count", ""),
        })
    return rows

def write_csv(rows):
    credits = [
        "# kanji_index.csv — JLPT Kanji Index",
        "# Data: KANJIDIC2 (CC BY-SA 3.0) https://www.edrdg.org/kanjidic/kanjidic2.html",
        "# JLPT levels: davidluzgouveia/kanji-data (MIT) https://github.com/davidluzgouveia/kanji-data",
    ]
    with open(OUT_CSV, "w", encoding="utf-8", newline="") as f:
        for line in credits:
            f.write(line + "\n")
        writer = csv.DictWriter(f, fieldnames=["character", "jlpt", "on_reading", "kun_reading", "meaning", "stroke_count"])
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} rows → {OUT_CSV}")

def write_json(rows):
    payload = {
        "_credits": {
            "kanji_data": "KANJIDIC2 (CC BY-SA 3.0) — https://www.edrdg.org/kanjidic/kanjidic2.html",
            "jlpt_levels": "davidluzgouveia/kanji-data (MIT) — https://github.com/davidluzgouveia/kanji-data",
        },
        "count": len(rows),
        "kanji": rows,
    }
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print(f"Wrote {len(rows)} entries → {OUT_JSON}")

if __name__ == "__main__":
    kanji_list = load_kanji()
    rows = build_rows(kanji_list)
    write_csv(rows)
    write_json(rows)
