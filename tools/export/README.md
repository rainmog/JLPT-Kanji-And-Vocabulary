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
