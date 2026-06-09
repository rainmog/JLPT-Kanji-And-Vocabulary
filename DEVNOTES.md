# Kanji App Dev Notes

## Current State (2026-06-09 — Item info sheets, practice preview, practice identification tracker)

**App**: Flutter 3.44.0, offline-first kanji + vocabulary study app  
**Data**: 2230 kanji (davidluzgouveia/kanji-data `jlpt_new`); 1023 sentences (103 N4 + 181 N3 + 739 N2); 8,254 JLPT vocab (N5–N1)  
**DB**: SQLite 12.9 MB; `jlpt_questions`: 115 N5 + 132 N4 + 145 N3 + 109 N2 + 67 N1 questions  
**Question types**: kanji_reading, kanji_writing, fill_blank, synonym, sentence_reorder, paragraph_reorder, comprehension  
**Kanji counts**: N5=80, N4=166, N3=367, N2=373, N1=1244  
**Sentence status**: N4 done, N3 done, N2 done (739/739). N1 not started.  
**Test history**: `test_history` table (user data via `_runMigrations()`). `HistoryRepository` + `TestHistoryScreen`. All 3 result screens save history.  
**Content**: All JLPT questions (N5–N1) are original compositions. N4 reading passages: 花屋で, 音楽練習室のお知らせ, 料理の話 (rewritten 2026-06-01 to replace passages derived from official JLPT materials).  
**v1.0.0** pushed to https://github.com/rainmog/JLPT-Kanji-And-Vocabulary (private). APK at `kanji_app/build/app/outputs/flutter-apk/app-release.apk`. Release assets (APK + kanji.db) uploaded to GitHub releases manually.  
**UI**: Hub-and-spoke redesign complete for all hub/config/practice/session screens. 9 orphaned screens pending deletion. `Clear User Data` in Settings resets all tables + SharedPrefs and returns to onboarding. DB index: `tools/export_db_index.py` → `tools/data/kanji_index.csv` + `kanji_index.json`.  
**Repo**: `.gitignore` kept local only (`.git/info/exclude`). `tools/dev_artifacts/` holds generation scripts + batch outputs locally, excluded from git. N1–N5 question JSONs tracked in `tools/data/`.
**Kana**: 223 kana characters (hiragana + katakana, full + dakuten + handakuten + combos + extended katakana) + 131 kana words in DB. `kana_progress` is a runtime table (created by `_runMigrations`). N4+ onboarding calls `kanaRepo.setAllLearned()` directly (no settings flag). Asset DB version bumped to 2. Test mode: fixed 2-per-char format (kana→romaji MC + romaji→kana MC per targeted char). `setStatus` uses `ON CONFLICT DO UPDATE SET status` to preserve `consecutive_correct`. Targets screen: ⋮ menu → "Set all to learned" (confirm dialog) or "Select to mark learned" (selection mode with bottom bar).
**Practice tracker**: `practice_correct_count INTEGER DEFAULT 0` added to `user_progress`, `vocabulary_progress`, `kana_progress` via `_runMigrations` try/catch ALTER TABLE. Incremented fire-and-forget on correct answer in practice sessions (not JLPT tests). Reset to 0 in `markLearned`. Shown in results screens. Kanji/kana test mode selects highest-count items first (`ORDER BY COALESCE(p.practice_correct_count, 0) DESC`).
**Item info sheets**: `lib/widgets/item_info_sheet.dart` — `KanjiInfoContent`, `VocabInfoContent`, `KanaInfoContent` + `showKanjiInfoSheet` / `showVocabInfoSheet` / `showKanaInfoSheet` helpers. All use `showModalBottomSheet(isScrollControlled: true)` + `DraggableScrollableSheet`. Long-press on selection grid tiles; tap in vocab dictionary; kanji detail screen is now a full rewrite using `KanjiInfoContent`.
**Practice preview**: `lib/screens/practice_preview_screen.dart` — sealed `PreviewItems` (Kanji/Vocab/Kana). Inserted between config and session for all 3 practice types. `onBegin: void Function(BuildContext)` receives preview screen's context to avoid stale context in push. Kanji config fetches list via `SentenceRepository.pickKanjiForSession` then passes `fixedKanjiIds` to `SessionScreen`/`QuizController` to bypass filter queries.

## Data Pipeline

1. **parse_kanjidic2.py** → `tools/data/kanji.json` — character, jlpt_level (1=N1…5=N5), readings, meaning, stroke count  
   ⚠ KANJIDIC2 `<jlpt>` frozen at pre-2010 4-level system. After any re-parse, re-apply level retag from `davidluzgouveia/kanji-data`.
2. **tag_kanji.py** → `tools/data/kanji_tags.json` — 598/2230 tagged; 35 semantic categories in `TAG_RULES`. Vocab also tagged at build time via same rules.
3. **parse_jmdict.py** → `tools/data/vocab_pos_tags.json` — POS + register tags from JMdict_e.gz; 99.1% match rate (8181/8254). Run once when JMdict updates. Tags: noun, verb, adjective, adverb, conjunction, particle, expression, interjection, pronoun, counter, suffix, prefix, auxiliary, colloquial, honorific, polite, slang, archaic, onomatopoeia.
4. **Sentence generation** → `tools/data/sentences_v2.json` — 9 sentences per kanji, difficulty 1–9
5. **build_db.py** → `kanji_app/assets/kanji.db` — merges semantic tags (TAG_RULES) + POS tags (vocab_pos_tags.json)

### Sentence Generation — Compact Format (current)

Use `tools/expand_compact.py` + compact `.txt` files in `tools/compact/`. Much cheaper token-wise than Python batch files.

```
# Batch NNN: kanji list
X
1|text_kanji|tokens|English translation
...9 lines...
Y
1|...
```

**Token notation** (space-separated):
- `surface:reading` — regular token
- `*surface:reading` — target kanji token

Punctuation: `。:。` `、:、` Particles: `は:は` `を:を` etc.  
`valid_readings` auto-derived from all `*` tokens.

**Critical — `*` placement**: prefix the whole token: `*昨夜:さくや` not `昨*夜:さくや`. Embedded `*` silently creates a T() with `*` in the surface.

**Field 2 (text_kanji)**: plain Japanese only — no `*`, no `:`, no token notation.

**Readings**: hiragana only. No katakana, no parentheses like `するど(い)`.

**Post-expand pipeline** (run after each batch):
```bash
python3 tools/expand_compact.py tools/compact/batch_NNN.txt   # check warnings
python3 tools/build_db.py                                       # must pass validation
```

Expander warnings = malformed lines. Fix compact file, then remove affected characters from `sentences_v2.json` and re-run.

**Check remaining kanji** (example: N3):
```bash
python3 -c "import json; done={e['character'] for e in json.load(open('tools/data/sentences_v2.json'))}; k=json.load(open('tools/data/kanji.json')); print([x['character'] for x in k if x['jlpt_level']==3 and x['character'] not in done])"
```

**Batch history**: N4 = gen_batch_001–012 (Python). N3 = 013–030 (013–028 Python, 029–030 compact). N2 = 031–104 (compact). All batch scripts moved to `tools/dev_artifacts/`. New batches use compact format.

**Sentence quality guidelines**:
- d1–d3: plain, common words, short (N4–N5 vocab)
- d4–d6: natural compound words, moderate complexity
- d7–d9: literary/formal/technical, real-world (not obscure academic)
- Avoid template-feel ("Xは大切です"), archaic vocabulary at d7–d9
- Cover both major readings per kanji (e.g. つき and げつ/がつ for 月)
- `valid_readings` must match K token reading exactly (not full compound)

## Architecture

### Navigation model

Hub-and-spoke: `HomeScreen` is the root; all screens push onto navigator and pop back. No bottom tab bar. `AppRoute.to()` for 180ms fade transitions.

### Screens

**✅ = updated to KDesign/k_setup system** | **⬜ = not yet updated** | **❌ = orphaned (unreachable)**

✅ **home_screen.dart**: Hub root. `ConsumerStatefulWidget`; `initState` triggers `_runAutoProgression()` via `addPostFrameCallback`. Top icon bar → configurable tracker card (`homeTrackers`, heading "CURRENT TARGETS") → hero block (kanji/vocab/kana target counts + "TODAY'S GOAL" ring + "Test Targets" OutlinedButton + "Start studying" ElevatedButton) → 3 quick-launch tiles (Set targets / Dictionary / JLPT). Body is a `Stack`: `HomeBgLayer` + `SakuraPetalsOverlay`. `_targetCountProvider` returns `({int kanji, int vocab, int kana})`; kana row shown conditionally. Navigation pops invalidate `_targetCountProvider`.
✅ **study_picker_screen.dart**: Picker for Kana / Kanji / Vocab → launches respective config screen.
✅ **target_practice_config_screen.dart**: Kanji target practice config — mode, JLPT levels, tags, count, difficulty range. Uses `k_setup.dart`.
✅ **kana_practice_config_screen.dart**: Kana quiz type selector + session size → `KanaPracticeScreen`. Entry point for Matching Game and Speed Reading. Uses `k_setup.dart`.
✅ **vocab_practice_config_screen.dart**: Vocab practice config — direction, answer mode, furigana, game mode. Uses `k_setup.dart`.
✅ **targets_screen.dart**: "Your Targets" hub. Daily goal stepper. N5–N1 buttons for kanji/vocab → grid/list. Hiragana/Katakana → `SelectTargetKanaScreen`. Done state: gold border + star. Save Targets sticky footer.
✅ **jlpt_test_intro_screen.dart** (`JlptTestScreen`): Level+section picker. Level chips, section seg, Resume/Start Fresh. `loadJlptProgress`. Uses `k_setup.dart`.
✅ **test_history_screen.dart**: Filter chips + animated history list. Expandable `_DetailPanel`. `KBackHeader`.
✅ **settings_screen.dart**: `KBackHeader`. Audio / Appearance / Data sections. Fully uses `k_setup.dart`.
✅ **credits_screen.dart**: `LogoWidget(size:140)` + version + "developed by David Garwood-Bish". Data sources / Assets / Fonts panels. JLPT disclaimer.
✅ **vocabulary_dictionary_screen.dart**: Search bar + N-level filter chips + `_VocabRow` list. `_allVocabProvider` FutureProvider.
✅ **session_screen.dart**: Unified quiz UI. Custom header (back + "I know this" + progress bar). KanjiQuestion 2×2 reading/meaning grids; WordQuestion/SentenceQuestion stacked MC or type field. Auto-advance 800ms correct / 1200ms wrong.
✅ **kana_practice_screen.dart**: Kana quiz session. Animated prompt (easeOutBack), MC 4-state buttons, auto-advance.
✅ **vocab_practice_screen.dart**: Vocab quiz. `RubyText` with furigana suppressed for learned kanji. MC + keyboard modes.
✅ **matching_game_screen.dart**: Memory card game. Custom header with timer. Face-down/up/matched card states. Last 5 results in `MatchingGameScreen.history`.
✅ **speed_read_screen.dart**: Flash word/kana then MC pick. Ghosted hint at 55% opacity (not hidden). Last 5 results in `SpeedReadScreen.history`.
✅ **session_summary_screen.dart**: Post-session summary. Animated score RichText, stat pills, learned char tiles.
✅ **jlpt_test_result_screen.dart**: JLPT test results. Total score card + section breakdown (colored left border) + missed questions. Converted to `ConsumerStatefulWidget`.
✅ **onboarding_welcome_screen.dart** / **onboarding_level_selection_screen.dart**: Onboarding flow redesigned. Carousel with `_StateTile` cards, pill dots. Level selection navigates to `OnboardingAutoProgressionScreen` — all level/clean-start setup happens there.
✅ **onboarding_auto_progression_screen.dart**: Post-level-selection page. Explanation card + auto-progression toggle. `_finish()` applies level targets (N5: `applyN5Targets` + `setKanaTargetBatch`; N4–N1: `applyLevelTargets` + `setAllLearned` for kana; clean start: no targets, auto-progression fills). Sets `homeTrackers`. Navigates to HomeScreen removing all onboarding routes.
⬜ **select_target_kanji_screen.dart**: "By Level" + "By Category" → `KanjiGridScreen` (5-col grid).
⬜ **vocab_list_screen.dart**: 3-col grid, color-coded. `VocabFilter.level(n)` for TargetsScreen.
⬜ **select_target_kana_screen.dart**: Kana target selection by row.
⬜ **word_result_screen.dart**: Shows `correctMeaning` subtitle (top-3).
⬜ **matching_game_config_screen.dart** / **speed_read_config_screen.dart**: Config screens for games.
⬜ **jlpt_test_session_screen.dart**: JLPT test session. Save/resume via `jlpt_progress_nN` SharedPreferences; includes `vocabIds`/`grammarIds`/`readingIds`.
⬜ **vocab_test_session_screen.dart** / **vocab_test_result_screen.dart**: Vocab test stack.
⬜ **kanji_detail_screen.dart**: Kanji detail view.
⬜ **kanji_data_license_screen.dart**: License detail pushed from Credits.
⬜ **stats_screen.dart**: PageView — Kanji/Vocab progress bars by level + tag. Not yet wired into nav.
⬜ **onboarding_n5_screen.dart** / **onboarding_welcome_back_screen.dart**: Remaining onboarding screens (N5 setup, returning user).

❌ **about_screen.dart**: Superseded by `credits_screen.dart`. Delete when cleaning up.
❌ **filter_screen.dart**: Old filter-then-launch flow. Replaced by config screens.
❌ **review_screen.dart**: Old review flow. Not reachable from new nav.
❌ **result_screen.dart**: Old result screen. Replaced by session_summary / word_result.
❌ **test_intro_screen.dart**: Old kanji test intro. Replaced by `target_practice_config_screen.dart`.
❌ **vocab_test_intro_screen.dart**: Old vocab test intro. Not reachable from new nav.
❌ **untargeted_practice_screen.dart**: Old untargeted flow. Replaced by `study_picker_screen.dart`.
❌ **word_session_screen.dart**: Only imported by `word_result_screen.dart` (circular). Entry point no longer exists in new nav.
❌ **session_config_screen.dart**: Only imported by orphaned `untargeted_practice_screen.dart`.

### Data
- **kana_repository.dart**: `KanaCharacter`, `KanaWord` models. Queries by type/row/status. `recordResult()` updates `kana_progress` with consecutive-correct logic (3 → learned). `getWordsForTargetedRows()` filters words to targeted kana with "all-chars" → "at-least-one" fallback.
- **kanji_repository.dart**: Queries kanji by level/tags, progress
- **sentence_repository.dart**: Sentence retrieval with difficulty filtering. `buildMixedTestQuestions` builds 2 `WordQuestion` (compound) + 1 `KanjiQuestion` (on/kun) per target kanji for the formal test. `WordQuestion.wordMeaning` carries the compound's vocabulary meaning for feedback (looked up from `vocabulary` table via `_vocabMeaning()` with per-call cache); `WordQuestion.englishTranslation` carries the sentence translation. `KanjiQuestion.meaning` stores the full comma-separated kanji meaning (for top-3 feedback display); `correctMeaning` stays single for option matching. `_containsKanji()` guards compound token selection — pure-kana surfaces (e.g. くらい for 位) are skipped.
- **progress_repository.dart**: Mark learned/unlearned, log sessions, `getLearnedKanjiCharacters()`
- **vocab_repository.dart**: `VocabWord` model; all vocab queries; `getProgressByTag()` for tag progress bars; singleton `vocabRepo`. `getVocabByLevels` and `getVocabByTagsAndLevels` order by `jlpt_level DESC, id ASC` (commonality order; id ≈ Jisho frequency rank within level).
- **settings_service.dart**: Riverpod provider for `AppSettings`. Key fields: `homeTrackers: List<String>` (default `['kanji:all','vocab:all']`), `showTrackerPicker: bool`, `animationsEnabled`, `ambientSfx`/`ambientVolume`/`sfxVolume`/`sfxEnabled`/`ambientEnabled`, `englishFont`, `dailyGoal`, `autoProgressionEnabled` (default true), `autoProgressionKanjiQuota` (default 15), `autoProgressionVocabQuota` (default 30), `completedKanjiLevels: List<int>`, `completedVocabLevels: List<int>`. `ambientTracks` const map uses `{label: id}` format (matches font maps).
- **auto_progression_service.dart**: `AutoProgressionService.run({required AppSettings settings})` — fills kanji/vocab/kana targets up to quota; detects newly completed JLPT levels; returns `({AutoProgressionResult result, AppSettings updatedSettings})`. Called from `HomeScreen.initState` via `addPostFrameCallback`. Caller saves `updatedSettings` via `settingsProvider.notifier.update`. `AutoProgressionResult.hasCompletions` drives the completion dialog.

### Design system

- **`widgets/k_setup.dart`**: Shared widget library for all config/settings screens. Public `K`-prefixed widgets: `KSetupField`, `KSeg`/`KSegOption`, `KChoiceList`/`KChoiceItem`, `KCountChips`, `KDualRange`, `KGameButton`, `KStickyFooter`, `KStartButton`, `KBackButton`, `KSetupHeader`, `KBackHeader`, `KToggle`, `KPanel`, `KSettingRow`, `KSectionLabel`. Import this, never duplicate.
- **`theme.dart` → `KDesign`**: Static design-token class. All color/shadow tokens derived from `ThemeColors` (multi-theme safe). Key tokens: `KDesign.ink(c)`, `KDesign.inkSoft(c)`, `KDesign.inkFaint(c)`, `KDesign.line(c)`, `KDesign.tint(c)`, `KDesign.soft(c)`, `KDesign.gold`, `KDesign.goldSoft`, `KDesign.shadowSm(c)`.
- **`theme_provider.dart`**: `themeColorsProvider` Riverpod provider exposes current `ThemeColors`.

### Utilities
- **romaji_converter.dart**: na/ni/nu/ne/no, nn→ん, n+consonant→ん
- **answer_validator.dart**: Check input vs valid readings
- **structured_sentence.dart**: Sentence display with target kanji highlight + known kanji coloring
- **app_route.dart**: `AppRoute.to(page)` — 180ms fade `PageRouteBuilder`
- **scale_on_press.dart**: `ScaleOnPress` wrapper (Listener, not GestureDetector) — 4% press-down scale
- **logo_widget.dart**: Book logo via Flutter widgets; theme-aware; needs `Material` ancestor
- **startup_logo_overlay.dart**: One-shot splash overlay; `_shown` flag persists for process lifetime. Both `Stack` widgets in `_AppRoot` use `fit: StackFit.expand` so overlay fills screen.
- **ruby_text.dart**: `RubyText` widget. Params: `showFurigana`, `suppressedKanji: Set<String>?`, `centered: bool`. JLPT furigana suppression: kanji at or below test level shown bare.
- **sakura_overlay.dart**: Falling petal overlay (Sakura theme only; first Stack child in HomeScreen body)
- **app_theme_backgrounds.dart**: `HomeBgLayer` — dispatches to `_StarfieldLayer` (Starman) or `_RetroLayer` (Copyright Lawsuit)

### Theme
- **9 themes**: Simple Light, Simple Black, Spring Sakura (default), Starman, Potential Copyright Lawsuit #01, Love Letter, Chou-chou Green, Big Rabbit Green, Midnight City
- `AppColors` uses getters into mutable `_currentTheme` — **not const**. `setCurrentTheme()` called in `KanjiApp.build()`.
- `ThemeColors` has `buttonRadius` (default 10) + `containerRadius` (default 8)
- Material Design 2 (`useMaterial3: false`)
- `appBarTheme`/`tabBarTheme` set in `buildTheme()` — follows `colors.fg`, not default white

## Kanji Status System

`user_progress.status` TEXT:
- `'unlearned'` — default; general practice pool
- `'target'` — user-selected focus; appears in target practice/test
- `'learned'` — passed test (3/3 correct); furigana suppressed in sentences

## JLPT Difficulty Cap

| JLPT | DB `jlpt_level` | Max difficulty |
|------|-----------------|----------------|
| N5   | 5               | 2              |
| N4   | 4               | 2              |
| N3   | 3               | 3              |
| N2   | 2               | 5              |
| N1   | 1               | 7              |

D8–D9 appear in general practice only, never in tests. Falls back to uncapped if fewer than 3 sentences within cap.

## Database Schema

```sql
CREATE TABLE kanji (
  id INTEGER PRIMARY KEY,
  character TEXT UNIQUE NOT NULL,
  jlpt_level INTEGER,          -- 1=N1 (hardest) … 5=N5 (easiest)
  on_reading TEXT, kun_reading TEXT, meaning TEXT, stroke_count INTEGER
);
CREATE TABLE sentences (
  id INTEGER PRIMARY KEY,
  kanji_id INTEGER NOT NULL,
  difficulty INTEGER,
  text_kanji TEXT,
  text_structured TEXT,        -- JSON array
  english_translation TEXT,
  valid_readings TEXT,         -- JSON array
  FOREIGN KEY (kanji_id) REFERENCES kanji(id)
);
CREATE TABLE user_progress (
  kanji_id INTEGER PRIMARY KEY,
  status TEXT DEFAULT 'unlearned',
  consecutive_correct INTEGER DEFAULT 0,
  total_seen INTEGER DEFAULT 0,
  total_correct INTEGER DEFAULT 0
);
CREATE TABLE session_log (
  id INTEGER PRIMARY KEY,
  mode TEXT, kanji_ids TEXT, score INTEGER,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
-- Vocabulary (static, baked into asset DB)
CREATE TABLE vocabulary (
  id INTEGER PRIMARY KEY,
  word TEXT NOT NULL,              -- kanji form; equals reading if no kanji
  reading TEXT NOT NULL,           -- hiragana
  meanings TEXT NOT NULL,
  acceptable_answers TEXT NOT NULL, -- JSON array
  jlpt_level INTEGER NOT NULL,     -- 5=N5 … 1=N1
  tags TEXT NOT NULL               -- JSON array (currently always [])
);
CREATE TABLE vocabulary_tags (
  vocab_id INTEGER NOT NULL, tag TEXT NOT NULL,
  PRIMARY KEY (vocab_id, tag), FOREIGN KEY (vocab_id) REFERENCES vocabulary(id)
);
-- Vocabulary user data (created by _runMigrations(), NOT in asset DB)
CREATE TABLE vocabulary_targets (
  vocab_id INTEGER PRIMARY KEY REFERENCES vocabulary(id), added_at INTEGER NOT NULL
);
CREATE TABLE vocabulary_progress (
  vocab_id INTEGER PRIMARY KEY REFERENCES vocabulary(id),
  word_to_meaning INTEGER NOT NULL DEFAULT 0,
  meaning_to_word INTEGER NOT NULL DEFAULT 0,
  learned_at INTEGER   -- unix timestamp; permanent once set
);
CREATE TABLE jlpt_questions (
  id INTEGER PRIMARY KEY, level INTEGER NOT NULL,
  type TEXT NOT NULL,   -- kanji_reading|kanji_writing|fill_blank|synonym|sentence_reorder|paragraph_reorder|comprehension
  -- ... question fields
  correct_order TEXT    -- non-null for sentence_reorder and paragraph_reorder
);
CREATE INDEX idx_sentences_kanji_id ON sentences(kanji_id);
CREATE INDEX idx_progress_status ON user_progress(status);
CREATE INDEX idx_kanji_level ON kanji(jlpt_level);
```

## Sentence Structure

```json
{
  "difficulty": 1,
  "text_kanji": "文字列",
  "text_structured": [
    {"surface": "...", "reading": "...", "is_kanji": false, "kanji_char": null},
    {"surface": "...", "reading": "...", "is_kanji": true,  "kanji_char": "字"}
  ],
  "english_translation": "...",
  "valid_readings": ["reading1"]
}
```

## Gotchas

1. **JLPT levels**: 1=N1 (hardest), 5=N5 (easiest). KANJIDIC2 `<jlpt>` frozen at pre-2010 4-level system — re-running `parse_kanjidic2.py` wipes modern levels. Re-apply retag from `davidluzgouveia/kanji-data` after any re-parse.
2. **N5 vocab ≠ N5 kanji**: kanji like 赤/花/空 are N5 vocab but N4 kanji-reading level. DB uses kanji-reading level. Some N4 kanji appear in N5 tests — intentional.
3. **Romaji 'n'**: trailing 'n' stays as 'n'. Type "nn" or "n"+consonant to get ん.
4. **DB rebuilds** drop and recreate all tables — resets `user_progress` to unlearned. Exception: version-triggered rebuilds (see gotcha #18) preserve `user_progress`.
5. **is_kanji tokens** require non-null `kanji_char`.
6. **AppColors not const**: uses getters. Never add `const` to `TextStyle(color: AppColors.X)`.
7. **`late final` in Riverpod notifiers**: re-navigation rebuilds the notifier; `late final` throws `LateInitializationError`. Use `late`.
8. **Cached DB**: app copies asset DB to `getApplicationDocumentsDirectory()` on first run; uses local copy forever. Rebuild check verifies kanji count (≥2230) AND vocab count (>0) — stale pre-vocab DB auto-rebuilds. Manual fix: `rm ~/Documents/kanji.db` and relaunch. Stale APK: rebuild + reinstall. For intentional content updates, use the version system (gotcha #18).
9. **DB race condition**: `database_service.dart` uses `static Future<Database>? _initFuture` pattern to prevent multiple concurrent callers each running `_init()`.
10. **T() requires two args**: `T(surface, reading)` — single-arg call crashes. Check: `grep -n 'T("[^"]*")[,\]]' tools/gen_batch_NNN.py`
11. **valid_readings must match K token reading exactly**: use kanji's reading within compound (e.g. `K("月日","つきひ","月")` → `valid_readings=["つきひ"]`).
12. **`INSERT OR IGNORE` + `lastrowid` unreliable**: on conflict, `lastrowid` returns previous insert's ID. Always `SELECT id FROM ... WHERE ...` after `INSERT OR IGNORE`. (Fixed in `build_db.py` vocab population.)
13. **Vocabulary tags**: derived at DB build time by character-matching against `TAG_RULES` in `tag_kanji.py`. 35 semantic categories; 4740 tag rows across 8254 vocab entries. Rebuild DB to update.
14. **`vocabulary_targets`/`vocabulary_progress` are user data**: created by `_runMigrations()` at runtime, NOT in asset DB. Rebuilding `kanji.db` does not wipe them.
15. **Timer callbacks need `mounted` check**: any `Timer` callback calling `Navigator`/`setState` must check `if (!mounted) return;` first.
16. **Text underlines without Material ancestor**: Flutter Text outside `Material` shows yellow underlines. Fix: wrap in `Material(color: ...)` + `TextDecoration.none` on all TextStyles.
17. **JLPT save/resume requires saving question IDs**: `buildSession` uses `ORDER BY RANDOM()` — resuming without saved IDs loads a different question set. Always save `vocabIds`/`grammarIds`/`readingIds` alongside index/answers, and use `buildSessionFromIds` on resume.
18. **Asset DB versioning**: `database_service.dart` has `_assetDbVersion` (currently `1`). Bump when shipping a new `kanji.db` asset. On version mismatch, `_init()` saves `user_progress` to memory, copies fresh asset DB, restores progress, then stamps the new version in SharedPreferences key `db_asset_version`. `vocabulary_targets`/`vocabulary_progress`/`test_history` survive regardless (runtime tables). To ship N1 content: build new DB, bump `_assetDbVersion` to `2`.
19. **Kana-surface compound tokens**: some kanji like 位 have vocab entries written in kana (くらい = "approximately"). Sentences may mark these as `is_kanji=true` with the target `kanji_char`, but the surface is pure kana. `sentence_repository` guards against this with `_containsKanji(surface)` — without it, compound questions show kana instead of kanji.
20. **Auto-progression trigger**: runs in `HomeScreen.initState` via `addPostFrameCallback`. Only fires once per mount. Invalidates `_targetCountProvider` if anything was added. Completion popup shows once per level (persisted in `completedKanjiLevels`/`completedVocabLevels` in AppSettings).
21. **user_progress UPSERT**: all status mutations use `INSERT ... ON CONFLICT(kanji_id) DO UPDATE SET` — plain UPDATEs fail silently for new users whose `user_progress` table has no pre-seeded rows. Read queries use LEFT JOIN + COALESCE for the same reason.

## Known Limitations

1. **export_service.dart**: file picker removed (Android SDK 36 compat). `importProgress()` stubbed to return false.
2. **Vocabulary tags**: `vocabulary_tags` empty. Future: use JMdict XML directly.
3. **Tags sparse**: 598/2230 kanji tagged; 4740 vocab tag rows. Expand `TAG_RULES` in `tag_kanji.py` to add more.

## File Paths

```
kanji-app/
├── kanji_app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/              # All screen .dart files
│   │   ├── repositories/         # kanji_, sentence_, progress_, vocab_repository.dart
│   │   ├── services/             # database_service.dart (migrations), settings, export, sound
│   │   ├── widgets/              # ScaleOnPress, LogoWidget, StartupLogoOverlay, overlays
│   │   ├── controllers/          # Session state
│   │   ├── utils/                # romaji_converter, answer_validator, app_route, vocab_answer_validator
│   │   └── theme/                # theme.dart, sakura_theme_v2.dart, app_theme_backgrounds.dart
│   └── assets/kanji.db           # 13 MB SQLite
├── tools/
│   ├── parse_kanjidic2.py        # KANJIDIC2 → kanji.json
│   ├── tag_kanji.py
│   ├── import_vocab.py           # Jisho API → vocab.json (run once)
│   ├── build_db.py               # All data → kanji.db
│   ├── validate_database.py
│   ├── export_db_index.py        # → kanji_index.csv + kanji_index.json
│   ├── dev_artifacts/            # generation scripts + batch files (local only, gitignored)
│   └── data/
│       ├── kanji.json            # 2230 kanji
│       ├── sentences_v2.json     # 1023 hand-crafted sentences (N4+N3+N2, local only)
│       ├── n1_questions.json     # JLPT question sources (tracked)
│       ├── n2_questions.json
│       ├── n3_questions.json
│       ├── n4_questions.json
│       └── n5_questions.json
└── DEVNOTES.md
```

## Commands

```bash
# Data pipeline
python3 tools/parse_kanjidic2.py
python3 tools/tag_kanji.py
python3 tools/import_vocab.py           # run once; writes vocab.json
python3 tools/expand_compact.py tools/compact/batch_NNN.txt
python3 tools/build_db.py

# App
cd kanji_app && flutter run
cd kanji_app && flutter run -d linux    # desktop testing
cd kanji_app && flutter analyze --no-pub
cd kanji_app && flutter build apk --release
cd kanji_app && flutter install
```
