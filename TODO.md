# Next Steps

---

# Future Ideas

- **Story Mode** — progression lock with point economy. Toggle in Settings. Points: start 50, target kanji 5pts each, tests cost 20pts (refund = correct count). Open questions: (1) "clear" = all learned or pass rate? (2) ordering = DB/stroke/frequency? (3) 0pts = locked or practice-only? (4) kanji-only or also vocab? Needs `StoryModeService` + new DB tables; touches all result screens and target selection.
- **Vocab level reclassification** - 1794 "Other" words need proper JLPT levels. Candidates: jisho.org API scan of `#jlpt-n1`→`#jlpt-n5`, or jpdb.io data. Script: `tools/import_core6k.py` (presence filter), `tools/dedup_vocab.py`. Rebuild with `build_db.py` after.

---

# Completed

- N4 JLPT question bank 4×: 132 → 529, keeping N4's own section mix; original + fairness-checked; N5 idx-41 fairness fix; asset DB v10 (progress-safe), pubspec 1.0.4+11 ✓ 2026-08-06
- Practice progress shown as % (points/20) on the end screen; per-page `PracticeDeltaBadge` (+25%/+5%/−5% with running total) on kanji/vocab/kana study pages ✓ 2026-08-06
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
- Practice session proportional kanji: 10q→4 kanji, 20q→5, 30q→6, 40q→8 (sentence/word modes); vocab selects count/2 words shown twice each ✓ 2026-06-12
- Practice preview screen: descriptive text per item type (kanji/vocab/kana) ✓ 2026-06-12
- JLPT paragraph_reorder lockout fixed: now renders as multiple choice (was drag-and-drop with impossible 5-slot/4-chip N1 question) ✓ 2026-06-12
- JLPT translation UI + data: 568 questions + 35 passages translated, DB v7, installed ✓ 2026-06-12
- Home screen redesign: JLPT goal card with 3-state tap cycle (remaining/% /fraction), tracker bars removed, session card tightened (22/13px, bumpers 0.034/0.030), `jlptGoal` setting (0=off, 1–5), all 3 sections always shown in goal card with placeholders, result screen invalidates providers + navigates to MainShell ✓ 2026-06-14
- Parallel learned system: `learnedVia` test|practice; practice promotes via `practice_progress` counter (threshold 4, +1/−1), onboarding selector + settings row + "What is this?" sheet, Test button hidden in practice mode ✓ 2026-06-29
- Practice complete screens show per-item learning progress (Learned ✓ / "N more to learn") across kanji/vocab/kana; summary screens made scrollable to fix overflow ✓ 2026-06-29
- Repeat-gap fix: `spacedShuffle` util prevents back-to-back repeats; compounds appear once per test ✓ 2026-06-29
- Not-enough-targets popup at vocab/kana/kanji-wordpractice launch ✓ 2026-06-29
- Progress totals bug fixed: `getProgressByLevel`/`getProgressByTag` LEFT JOIN so N3/N2/N1 denominators + top ring show full deck (was counting only targeted) ✓ 2026-06-29
