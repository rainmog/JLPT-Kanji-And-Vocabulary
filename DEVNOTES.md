# Kanji App Dev Notes

## Current State (2026-06-14)

**App**: Flutter 3.44.0, offline-first kanji + vocabulary study app  
**Data**: 2230 kanji (N5=80, N4=166, N3=367, N2=373, N1=1244); 9 sentences each; 7173 vocab (N5=657, N4=588, N3=1625, N2=1589, N1=920, Other=1794)  
**DB**: SQLite 28.0 MB; `_assetDbVersion=7`; 695 vocab tagged `usually_kana`; 1794 vocab level 0 ("other" — not in Core 6k, browsable via Other button in select vocab)  
**Repo**: https://github.com/rainmog/JLPT-Kanji-And-Vocabulary (private). APK: `kanji_app/build/app/outputs/flutter-apk/app-release.apk`.

---

## Data Pipeline

Run in order when rebuilding:

```bash
python3 tools/dedup_vocab.py          # deduplicate vocab.json (keep easiest level per word)
python3 tools/parse_jmdict.py tools/JMdict_e.gz   # POS + usually_kana tags → vocab_pos_tags.json
ANTHROPIC_API_KEY=... python3 tools/translate_jlpt.py  # JLPT translations (skip if n*_questions.json already have them)
python3 tools/build_db.py             # merges all sources → kanji.db
```

**Sources:**
- `tools/data/kanji.json` — from `parse_kanjidic2.py` + davidluzgouveia/kanji-data retag. ⚠ KANJIDIC2 `<jlpt>` is frozen (pre-2010); always re-apply level retag after re-parse.
- `tools/data/kanji_tags.json` — from `tag_kanji.py`; 598/2230 kanji tagged, 35 categories. Vocab tagged at build time.
- `tools/data/vocab_pos_tags.json` — from `parse_jmdict.py` (JMdict_e.gz, 99% match); includes `usually_kana` tag.
- `tools/data/jlpt_vocab_waller.json` — Waller JLPT overrides (tanos.co.uk, CC BY); elevates words to easier level only; never overrides level 0.
- `tools/data/sentences_v2.json` — 9 sentences per kanji, difficulty 1–9. All 2230 complete.
- `tools/data/n1–n5_questions.json` — JLPT practice questions.

**Vocab level 0 pipeline** (run only when reclassifying):
```bash
python3 tools/dedup_vocab.py
python3 tools/import_core6k.py tools/Core_2k6k_*.apkg
python3 tools/build_db.py
```

**Font subset** (regenerate if kanji.json expands):
```bash
python3 << 'EOF'
import json; chars = set()
for k in json.load(open('tools/data/kanji.json')): chars.add(k['character'])
for s in json.load(open('tools/data/sentences_v2.json')):
    for field in ['text_kanji', 'text_structured']:
        v = s.get(field, '')
        if isinstance(v, str): chars.update(v)
        elif isinstance(v, list):
            for tok in v:
                if isinstance(tok, dict): chars.update(tok.get('surface','') + tok.get('reading',''))
for c in list(range(0x20,0x7F)) + list(range(0x3041,0x3097)) + list(range(0x30A0,0x3100)) + list(range(0x3000,0x303F)): chars.add(chr(c))
chars.update('ー々〜')
with open('/tmp/kanji_app_unicodes.txt','w') as f: f.write(','.join(hex(ord(c)) for c in chars if ord(c) > 0x1F))
EOF
pyftsubset kanji_app/assets/fonts/NotoSerifCJKjp-Regular.otf \
  --unicodes="$(cat /tmp/kanji_app_unicodes.txt)" \
  --output-file=kanji_app/assets/fonts/NotoSerifCJKjp-Subset.otf \
  --layout-features='*' --name-IDs='*'
```

**Public DB export**: `python3 tools/export_public_db.py` → `tools/export/kanji_app_data.db` (no user tables).

---

## Architecture

**Navigation**: `MainShell` root with persistent bottom nav bar (4 tabs: Study & Test, Progress, Dictionary, JLPT). Tab 3 (JLPT) loads `JlptTestScreen`. All other screens push/pop via `AppRoute.to()` (180ms fade). `KBackHeader` and `KSetupHeader` both auto-hide back button when `Navigator.canPop` is false (tab context). Screens that should return to the nav bar (e.g. `JlptTestResultScreen`) must use `Navigator.pushAndRemoveUntil(context, AppRoute.to(const MainShell()), (_) => false)` — never `HomeScreen()` directly.

**All screens on KDesign** except: `kanji_detail_screen`, `test_session_screen`.

**Background animations**: All 4 `MainShell` tabs (Study & Test, Progress, Dictionary, JLPT) now include the full overlay stack: `HomeBgLayer`, `SakuraPetalsOverlay`, `SpaceAgeStarsOverlay`, `SnowOverlay`, `FallingBlocksOverlay`. Scaffold `backgroundColor` is transparent for animated themes.

**Orphaned screens**: all deleted as of 2026-06-11.

### Key services / repos

- **sentence_repository.dart**: `buildMixedTestQuestions` — 2 `WordQuestion` + 1 `KanjiQuestion` per kanji. Skips `usually_kana` compounds. `_containsKanji()` guards kana-surface tokens. `buildSentenceQuestions` — `isTarget` uses `surface.contains(char)` to catch compounds where `kanji_char` != target (e.g. 庭園 when target is 園). `_stripOkurigana()` trims trailing shared hiragana from furigana hints (食べる → た, 難しい → むずか). Period tokens (。) filtered out for display consistency.
- **vocab_repository.dart**: `VocabWord.isUsuallyKana`, `VocabWord.levelLabel`. Orders by `jlpt_level DESC, id ASC`.
- **settings_service.dart**: `homeTrackers`, `dailyGoal` (default 100), `autoProgressionEnabled/Quota`, `completedKanjiLevels/VocabLevels`, `jlptGoal` (0=not set, 1–5 for N1–N5), audio/appearance.
- **auto_progression_service.dart**: fills targets up to quota; detects completed levels. Called from `HomeScreen.initState`.
- **database_service.dart**: `_assetDbVersion=7`. Bump when shipping new `kanji.db`. Saves/restores `user_progress`; runtime tables survive via `_runMigrations`.
- **history_repository.dart**: `getHistory({testType?, level?, limit})` — optional `level` filter applied in Dart after fetch (avoids SQL type mismatch).

### Design system

- **`widgets/k_setup.dart`**: `KSetupField`, `KSeg`, `KChoiceList`, `KCountChips`, `KDualRange`, `KGameButton`, `KStickyFooter`, `KStartButton`, `KBackButton`, `KSetupHeader`, `KBackHeader`, `KToggle`, `KPanel`, `KSettingRow`, `KSectionLabel`.
- **`theme.dart` → `KDesign`**: `KDesign.ink/inkSoft/inkFaint/line/tint/soft/gold/goldSoft/shadowSm/shadowAccent`.
- **8 themes**: Simple Light, Simple Black, Spring Sakura (default), Starman, Love Letter, Chou-chou Green, Big Rabbit Green, Midnight City. Animated themes (`galaxy/loveLetter/lily/totoro/midnightCity`) use transparent scaffold + overlay layers. `FallingBlocksOverlay` widget kept as stub (always returns SizedBox.shrink).
- **Theme palette notes**: Simple Black uses warm neutral grays, lighter muted/accent for contrast on dark bg. Starman: cool blue-grey (Rosy Granite accent). Midnight City: pure black bg, Charcoal Blue surface, Light Blue accent, Ghost White text. Love Letter: wintry navy/slate blues. Chou-chou Green: blue-tinted rain. Themes redesigned 2026-06-12.

**Background animations** (`app_theme_backgrounds.dart`): Love Letter uses `_SnowLayer` + `_SparkleLayer` + `_SilverTwinkleLayer`. Chou-chou Green uses `_HazeLayer` + `_GentleRainLayer`. Unused (implemented, not wired to any theme): `_AuroraWavesLayer`, `_FirefliesLayer`, `_ParticleDustLayer`, `_ShootingStarsLayer`.
- `AppColors` uses getters into mutable `_currentTheme` — **never `const`**.
- Material Design 2 (`useMaterial3: false`).

### Fonts

**English** (OFL, variable TTFs): Inter (default), Nunito, VT323, Crimson Pro, Quicksand, Space Grotesk. Selectable via `englishFonts` map in `settings_service.dart`.  
**Japanese**: `NotoSerifCJKjp-Subset.otf` (2.5 MB, 3116 codepoints). Source: `NotoSerifCJKjp-Regular.otf` (kept in assets). Last subset: 2026-06-11.

---

## Database Schema (abbreviated)

```sql
-- Asset tables (in kanji.db):
kanji(id, character, jlpt_level 1=N1…5=N5, on_reading, kun_reading, meaning, stroke_count)
kanji_tags(kanji_id, tag)
sentences(id, kanji_id, difficulty 1–9, text_kanji, text_structured JSON, english_translation, valid_readings JSON)
vocabulary(id, word, reading, meanings, acceptable_answers JSON, jlpt_level 0=other…5=N5, tags JSON)
vocabulary_tags(vocab_id, tag)   -- includes 'usually_kana' for 695 entries
jlpt_questions(id, level, section, question_type, ...)
kana(id, character, type, romaji, acceptable_romaji, row, counterpart)
kana_words(id, word, romaji, acceptable_romaji, meaning, type)

-- Runtime (created by _runMigrations, not in asset DB):
user_progress(kanji_id PK, status, consecutive_correct, total_seen, total_correct, practice_correct_count)
session_log(id, mode, kanji_ids, score, timestamp ms, question_count)
vocabulary_targets(vocab_id, added_at)
vocabulary_progress(vocab_id, word_to_meaning, meaning_to_word, learned_at, practice_correct_count)
kana_progress(kana_id, status, consecutive_correct, total_seen, total_correct, practice_correct_count)
test_history(id, timestamp, test_type, level, section, score, total, detail)
```

---

## JLPT Difficulty Cap

| JLPT | level | Max d |
|------|-------|-------|
| N5   | 5     | 2     |
| N4   | 4     | 2     |
| N3   | 3     | 3     |
| N2   | 2     | 5     |
| N1   | 1     | 7     |

D8–D9 in general practice only. Falls back uncapped if <3 sentences within cap.

---

## Gotchas

1. **JLPT levels inverted**: 1=N1 hardest, 5=N5 easiest throughout.
2. **N5 vocab ≠ N5 kanji**: 赤/花/空 are N5 vocab but N4 kanji level. Intentional.
3. **Romaji 'n'**: trailing 'n' stays 'n'. Use "nn" or "n"+consonant for ん.
4. **DB rebuilds** from scratch drop all runtime tables. Version bumps preserve `user_progress`.
5. **AppColors not const**: getters into mutable `_currentTheme`. Never `const TextStyle(color: AppColors.X)`.
6. **`late final` in Riverpod notifiers**: re-navigation rebuilds notifier → `LateInitializationError`. Use `late`.
7. **Cached DB**: copied to `getApplicationDocumentsDirectory()` on first run. Stale check: kanji count ≥2230 AND vocab count >0. Version bump triggers safe re-copy + progress restore.
8. **DB race condition**: `_initFuture` static pattern prevents concurrent `_init()` calls.
9. **`INSERT OR IGNORE` + `lastrowid`**: unreliable on conflict. Always `SELECT id WHERE ...` after.
10. **JLPT save/resume**: `buildSession` uses `ORDER BY RANDOM()`. Save `vocabIds`/`grammarIds`/`readingIds`; use `buildSessionFromIds` on resume.
11. **Asset DB versioning**: `_assetDbVersion=7`. Bump to ship new `kanji.db`. Runtime tables survive regardless.
12. **Kana-surface compounds**: 位→くらい etc. `_containsKanji()` guards against pure-kana surfaces.
13. **user_progress UPSERT**: use `INSERT ... ON CONFLICT DO UPDATE`. Plain UPDATE fails silently for new users.
14. **Timer callbacks**: check `if (!mounted) return` before setState/Navigator.
15. **Vocab level 0**: "other" (not in Core 6k). Waller overrides skipped for level 0. Browsable via "Other" button in select vocab screen.
16. **Sentence `isTarget` for compounds**: `kanji_char` in `text_structured` points to one kanji per token (usually first). For multi-kanji compounds, check `surface.contains(char)` as fallback — otherwise 庭園 shows standalone 園 when target is 園.
17. **Hero card (home screen)**: Variant C outline design — white `surface` card, `1.5px line` border, `shadowSm`. "Start studying" button carries the accent gradient. Goal ring uses `colors.accent` fill + `KDesign.soft` track. `_GoalRing` and `_ShimmerButton` both require `ThemeColors colors` param. Session card target counts use `fontSize: 22` (number) / `13` (label).
21. **JLPT goal card**: `_JlptGoalCard` — 3-state tap cycle (remaining / % / fraction) for kanji+vocab progress toward goal. Shows most recent section test results; always renders all 3 sections (vocab/grammar/reading) when any data exists. Public providers: `allProgressProvider` (renamed from private) and `jlptTestDataProvider(level)` — both must be invalidated when test data changes. `jlptTestDataProvider` is `autoDispose.family` but survives while `MainShell` tabs stay mounted; callers must explicitly `ref.invalidate()` after test completion.
22. **JLPT result screen navigation**: `JlptTestResultScreen` wraps Scaffold in `PopScope(canPop: false)`. Both back-press and "Back to Home" button call `_invalidateAndPop` — invalidates `allProgressProvider` + `jlptTestDataProvider(level)` then navigates to `MainShell`. Never navigate to `HomeScreen()` directly from result screens (loses nav bar).
18. **`paragraph_reorder` = multiple choice**: Options are composite ordering strings (e.g. "ウ→ア→イ→エ"), not individual chips. Do NOT route to `_SentenceReorderWidget` — only `sentence_reorder` uses the drag-and-drop UI. N1 paragraph_reorder has 5-part `correct_order` which made the drag UI impossible to complete (5 slots, 4 chips).
19. **Practice session kanji count**: `sentence`/`word` modes pick proportionally fewer kanji than questions (10q→4k, 20q→5k, 30q→6k, 40q→8k) — each kanji contributes multiple questions. `wordpractice` mode keeps 1:1 (1 question per kanji). Vocab selects `count/2` words; `VocabPracticeScreen` shows each word twice (queue doubled + shuffled).
20. **JLPT translations**: `question_translation` + `passage_translation` columns in `jlpt_questions`. 568/568 questions + 35 passages translated (2026-06-12). UI renders `**bold**` markdown in translations via `_translationText()` in `jlpt_test_session_screen.dart`. Passage interstitial shows after EVERY passage group (including the last). Re-generate fill-blank translations: run `tools/apply_translations.py` (no API needed) or re-run `tools/translate_jlpt.py` (needs `ANTHROPIC_API_KEY`) then `build_db.py`. `translate_jlpt.py` now clears `___` translations and passes `correct_answer` so blanks are filled with English + bold.
23. **Speed read feedback**: after answering, stays in `_Phase.feedback` until user taps. Vocab mode shows word + reading + top-2 meanings card; kana mode shows "Tap to continue" only (romaji already visible in options). `_advanceFromFeedback()` handles next/done logic. `_FeedbackCard` widget in `speed_read_screen.dart`. `SpeedReadQuestion.meaning` is nullable — null for kana.
24. **Speed read ready phase**: `_Phase.ready` (2000ms) fires between questions — 3 dots animate in at 500ms intervals to draw eyes back to center before the kanji flashes.
25. **Practice preview list**: `PracticePreviewScreen` uses `ListView.separated` (was grid). Each row: 60×60 character box left, readings + meaning right, JLPT chip. Tap row opens full info sheet. Vocab font size adapts: 26px for ≤3 chars, 18px longer.
26. **Parallel learned system**: `AppSettings.learnedVia` = `'test'` (default) | `'practice'`. In practice mode items reach `learned` via a decrementing counter (`practice_progress` column on user_progress/vocabulary_progress/kana_progress): +1 per correct practice answer, −1 (floored 0) per wrong, promote at `kPracticeLearnThreshold=4` (`lib/utils/learning_constants.dart`). Repos' `recordPracticeProgress` return `PracticeResult` record `(promoted, learned, progress)`. Practice screens collect latest result per item id and `await` the final write before navigating to the summary, which renders a per-item "Learning progress" section (Learned ✓ / "N more to learn"). Practice-mode hides the home-screen Test button entirely; mark-as-known stays in both modes. Column added via guarded ALTERs in `_runMigrations` — **no `_assetDbVersion` bump** (a bump rebuilds the DB and only preserves kanji `user_progress`, wiping vocab/kana progress).
27. **Per-JLPT-level progress totals**: `kanjiRepo.getProgressByLevel`/`getProgressByTag` must `LEFT JOIN user_progress` (not inner). Inner join makes the denominator count only kanji that already have a progress row, so untouched levels (N3/N2/N1) read 0/0 and the top ring shows only targeted count instead of 2230. `getActiveLevel` depends on these totals being the full deck.
28. **spacedShuffle** (`lib/utils/spaced_shuffle.dart`): `spacedShuffle<T>(items, keyOf, {minGap=3, rng})` — greedy placement so the same key is never back-to-back (gap of `minGap` where the pool allows, else largest-gap fallback). Applied to test/word/sentence/mixed question builders + vocab/kana practice queues. Compound dedup in word/mixed builders uses a `seen` set so a compound appears once per test.
29. **Not-enough-targets popup**: `confirmShortSession` (`lib/widgets/short_session_dialog.dart`) clamps + confirms when available targets < requested session size. Wired at vocab (words×2), kana (char pool), and kanji `wordpractice` launch points — modes where the shortfall is predictable.

---

## Commands

```bash
# Data
python3 tools/dedup_vocab.py
python3 tools/parse_jmdict.py tools/JMdict_e.gz
python3 tools/build_db.py

# App
cd kanji_app && flutter run
cd kanji_app && flutter run -d linux
cd kanji_app && flutter analyze --no-pub
cd kanji_app && flutter build apk --release
cd kanji_app && flutter install
```
