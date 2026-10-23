# Next Steps

Testing pass on **1.0.6+15** (uploaded to Play 2026-10-23). Report findings next session.

- **Verify in real use**: (a) every practice session shows the selected count — kanji (all modes), vocab, kana; (b) word-practice answers are full-word readings (会議 → かいぎ, not ぎ); (c) SRS progression feels right — items return on the 1/2/4/9/21-day ladder, learned items leave rotation, new items arrive daily (defaults 15 kanji / 30 vocab per day).
- **Tune if needed**: new-items-per-day = Settings → auto-progression quotas. Sessions top up with not-yet-due items to reach the count; if items feel over-reviewed, consider topping up with new items first instead.
- **Small cleanups (non-blocking)**: delete dead `getNextUntargetedVocab` (`vocab_repository.dart`) and unused `_fetchVocabMeanings` (`sentence_repository.dart`, analyzer warning); rename the `backfill*ForTest` helpers in `database_service.dart` (production methods with test names); prune old `srs_new_<track>_<day>` prefs keys; `lib_backup_redesign/` is analyzer noise — delete it or exclude it in `analysis_options.yaml`.
- **Data**: 皐 lost its quiz targets to a false positive in the reading repair (皐月 → さつき is correct) — whitelist if wanted. ~1.3k sentences have benign surface/text mismatches (kana spellings, missing punctuation) — left as-is.

---

# Future Ideas

- **Story Mode** — progression lock with point economy. Toggle in Settings. Points: start 50, target kanji 5pts each, tests cost 20pts (refund = correct count). Open questions: (1) "clear" = all learned or pass rate? (2) ordering = DB/stroke/frequency? (3) 0pts = locked or practice-only? (4) kanji-only or also vocab? Needs `StoryModeService` + new DB tables; touches all result screens and target selection.
- **Vocab level reclassification** - 1794 "Other" words need proper JLPT levels. Candidates: jisho.org API scan of `#jlpt-n1`→`#jlpt-n5`, or jpdb.io data. Script: `tools/import_core6k.py` (presence filter), `tools/dedup_vocab.py`. Rebuild with `build_db.py` after.

---

# Completed

- Docs refreshed (DEVNOTES, TODO, app README); `build_db.py` now refuses to build while sentence readings are unrepaired; pubspec **1.0.6+15** (14 already uploaded) ✓ 2026-10-23
- Wrong word-practice answers fixed — source data stored only the target kanji's reading for some compounds (会議 → ぎ) and had sentences with shifted furigana. `tools/fix_compound_readings.py` repairs `sentences_v2.json` + asset (41 readings fixed, 540 misaligned sentences dropped, 皐/隻 demoted; idempotent); runtime guard `isPlausibleWordReading`; asset DB v11 ✓ 2026-10-23
- Practice sessions fill to the selected count: due first, then not-yet-due items soonest-first (kanji all modes, vocab, kana); kanji sentence/word modes pick one kanji per question; real `pickKanjiForSession` tests ✓ 2026-10-23
- **Leitner SRS rework of practice learning** (1.0.5+13): fixed learned vocab never leaving the target pool (endless repeats, frozen progression). One scheduler for kanji/vocab/kana — boxes 1–5, 1/2/4/9/21-day intervals, learned items excluded; daily new-item introducer; onboarding seeds box 1; one-time migration staggered existing items over 5 days; old points code removed; onboarding explainer rewritten ✓ 2026-10-21

- Quiz header consistency: kanji session shows `X / Y` count top-right (kept "I know this"); vocab practice switched to shared `QuizHeader` to match vocab-test format; `+%` practice delta badge moved down (top 84) so it clears the progress bar on kanji/kana/vocab ✓ 2026-09-05
- Speed reading (kanji) now excludes `usually_kana` loanwords (煙草/タバコ, etc.), matching the other kanji practice sessions ✓ 2026-09-05
- Session rotation: daily appearance counted once per kanji per session (repeats award points but don't re-bump the daily cap); session kanji stamped practiced-now + last-session exclusion so back-to-back sessions rotate to least-recently-practiced items ✓ 2026-09-05 — *superseded 2026-10 by the Leitner SRS rework*
- Test fixes: `settings_service_test` ambientVolume default 0.5 (was stale 1.0); `widget_test` smoke test no longer leaks the splash timer (seed empty prefs, pump past 2400ms splash, no pumpAndSettle) ✓ 2026-09-05
- pubspec 1.0.4+12 (asset DB rotation) ✓ 2026-09-05
- N4 JLPT question bank 4×: 132 → 529, keeping N4's own section mix; original + fairness-checked; N5 idx-41 fairness fix; asset DB v10 (progress-safe), pubspec 1.0.4+11 ✓ 2026-08-06
- Practice progress shown as % (points/20) on the end screen; per-page `PracticeDeltaBadge` (+25%/+5%/−5% with running total) on kanji/vocab/kana study pages ✓ 2026-08-06 — *superseded 2026-10 by the Leitner SRS rework* (badge now shows `Box N/5`)
- JLPT test result page midnight-theme readability fix (hardcoded white cards → `AppColors.surface`) ✓ 2026-08-06
- Fonts: 5 English fonts added ✓ 2026-06-10
- Background animations restored (snow, falling blocks, stars) ✓ 2026-06-10
- Kana test page added to test hub ✓ 2026-06-10
- All screens converted to KDesign (except stats_screen) ✓ 2026-06-10
- N1 sentence database complete (2230 kanji × 9 sentences) ✓ 2026-06-11
- Public DB export script (`tools/export_public_db.py`) ✓ 2026-06-11
- "Usually written in kana" system (JMdict `uk` tag, 695 words) ✓ 2026-06-11
- Vocab deduplication (8254 → 7173 entries) ✓ 2026-06-11
- Core 6k vocab filtering (N1: 3340 → 920 validated; 1794 → Other) ✓ 2026-06-11
- Nav bar + Progress screen: MainShell with 4 tabs (Study & Test, Progress, Dictionary, JLPT); ProgressScreen with kanji/vocab rings, by-level breakdown, tag groups bottom sheet ✓ 2026-06-11
- JLPT nav tab fixed to route to JlptTestScreen (was TestHubScreen) ✓ 2026-06-11
- KSetupHeader back button suppressed when Navigator.canPop is false (tab context) ✓ 2026-06-11
- Home screen UI polish: + hit area 44×44, tracker→hero and hero→nav bumpers screen-% matched, goal ring 100px, "Test Targets" → "Test", usually-kana label in dict ✓ 2026-06-11
- Test hub swipe indicators moved to top of each page ✓ 2026-06-11
- Daily goal default changed to 100 ✓ 2026-06-11
- Background animations: gentle_rain → Chou-chou Green, silver sparkle → Love Letter; aurora waves, fireflies, particle dust, shooting stars implemented but unused ✓ 2026-06-11
- All orphaned screens deleted ✓ 2026-06-11
- Credits page + study resources screen ✓ 2026-06-10
- Theme picker on onboarding + bg animations on onboarding ✓ 2026-06-10
- stats_screen deleted (never wired) ✓ 2026-06-12
- Hero redesign: Variant C outline card (white surface, border, divider; gradient on Start Studying button; accent-colored ring + stats) ✓ 2026-06-12
- Background overlays on all 4 nav tabs (Dictionary + JLPT now match Study & Test / Progress) ✓ 2026-06-12
- Sentence mode bugs fixed: compound display (庭園 shows full compound not just 園), period inconsistency (。filtered), furigana okurigana (食べる → た not たべる) ✓ 2026-06-12
- Theme palette pass 1: Simple Black, Simple Light, Starman redesigned ✓ 2026-06-12
- Practice session proportional kanji: 10q→4 kanji, 20q→5, 30q→6, 40q→8 (sentence/word modes); vocab selects count/2 words shown twice each ✓ 2026-06-12 — *superseded 2026-10 by the Leitner SRS rework* (sessions fill to count, each item once)
- Practice preview screen: descriptive text per item type (kanji/vocab/kana) ✓ 2026-06-12
- JLPT paragraph_reorder lockout fixed: now renders as multiple choice (was drag-and-drop with impossible 5-slot/4-chip N1 question) ✓ 2026-06-12
- JLPT translation UI + data: 568 questions + 35 passages translated, DB v7, installed ✓ 2026-06-12
- Home screen redesign: JLPT goal card with 3-state tap cycle (remaining/% /fraction), tracker bars removed, session card tightened (22/13px, bumpers 0.034/0.030), `jlptGoal` setting (0=off, 1–5), all 3 sections always shown in goal card with placeholders, result screen invalidates providers + navigates to MainShell ✓ 2026-06-14
- Parallel learned system: `learnedVia` test|practice; practice promotes via `practice_progress` counter (threshold 4, +1/−1), onboarding selector + settings row + "What is this?" sheet, Test button hidden in practice mode ✓ 2026-06-29 — *superseded 2026-10 by the Leitner SRS rework*
- Practice complete screens show per-item learning progress (Learned ✓ / "N more to learn") across kanji/vocab/kana; summary screens made scrollable to fix overflow ✓ 2026-06-29
- Repeat-gap fix: `spacedShuffle` util prevents back-to-back repeats; compounds appear once per test ✓ 2026-06-29
- Not-enough-targets popup at vocab/kana/kanji-wordpractice launch ✓ 2026-06-29 (all kanji modes since 2026-10)
- Progress totals bug fixed: `getProgressByLevel`/`getProgressByTag` LEFT JOIN so N3/N2/N1 denominators + top ring show full deck (was counting only targeted) ✓ 2026-06-29
