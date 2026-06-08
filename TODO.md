# Next Step: Delete orphaned screens + redesign remaining ⬜ screens

Exercise/session screens redesigned (2026-06-08). Remaining work:

- **Delete 9 orphaned screens** (❌ in DEVNOTES.md): `about_screen.dart`, `filter_screen.dart`, `review_screen.dart`, `result_screen.dart`, `test_intro_screen.dart`, `vocab_test_intro_screen.dart`, `untargeted_practice_screen.dart`, `word_session_screen.dart`, `session_config_screen.dart`
- **Remaining ⬜ screens** (~10): `select_target_kanji_screen`, `vocab_list_screen`, `select_target_kana_screen`, `word_result_screen`, `matching_game_config_screen`, `speed_read_config_screen`, `jlpt_test_session_screen`, `vocab_test_session_screen`, `vocab_test_result_screen`, `kanji_detail_screen`, `kanji_data_license_screen`, `stats_screen`, `onboarding_n5_screen`, `onboarding_welcome_back_screen`
- **Design patterns**: tokens in `theme.dart` → `KDesign`, shared widgets in `widgets/k_setup.dart`, nav = hub-and-spoke push/pop with `AppRoute.to()`, no bottom bar
- **Current `AppSettings` fields**: `difficultyMin/Max`, `sessionSize`, `autoNextDelaySeconds`, `ambientSfx`, `ambientVolume`, `sfxVolume`, `sfxEnabled`, `ambientEnabled`, `animationsEnabled`, `showTrackerPicker`, `englishFont`, `japaneseFont`, `homeTrackers: List<String>`, `dailyGoal`, `autoProgressionEnabled: bool`, `autoProgressionKanjiQuota: int`, `autoProgressionVocabQuota: int`, `completedKanjiLevels: List<int>`, `completedVocabLevels: List<int>`
- **Tracker ID format**: `kanji:all`, `vocab:all`, `hiragana:all`, `katakana:all`, `kanji:N5`–`kanji:N1`, `vocab:N5`–`vocab:N1`, `kanji:tag:<tag>`, `vocab:tag:<tag>`

---

# Future Implementations

- Complete Kanji Database (N1 sentences have 3/9 sentences complete. N5-N1 done.)

- Consider adding more fonts

- Publish a clean database of kanji/sentences/vocab to GitHub for public download

- ~~Add system to show vocab/kanji by frequency.~~

- ~~Add tags to vocabulary and kanji entries.~~

- ~~Implement JLPT practice tests and test result history~~

- ~~Add ambient royalty-free background sounds/music option in Settings~~ 

- ~~Add the ability to export data (kanji progress, vocab lists, test results)~~ 

- ~~Fill out About screen (button placeholder added to home screen)~~ 

- ~~Add a new app font and make it configurable in Settings~~ 

- ~~JLPT test result history~~ 

- ~~N4–N1 JLPT practice tests~~ 

- ~~Show 2 or 3 of the common meanings of words instead of just one~~

- **Story Mode** (future) — optional toggle in Settings. Locks kanji progression in-order within chosen JLPT level (N5→N1). Point economy: start 50pts, 10 target kanji; buy kanji 5pts each; practice/games free + reward points; tests cost 20pts, refund = correct answers count. Clear a level to unlock the next. Toggle on/off at any time (state persists). Key open questions: (1) what defines "clear" — all kanji learned, or pass rate on level test? (2) in-order criterion — DB order, stroke count, or frequency rank? (3) behaviour at 0pts — fully locked or can still practice? (4) kanji-only or affects vocab too? Implementation notes: add `StoryModeService` + new DB tables (don't touch existing progress tables); points logic touches all result screens; gating touches target selection + home screen.

---

# Google Play Pre-Launch Checklist

## Blocks submission

- [x] **Release signing keystore** — generate keystore, configure `android/app/build.gradle.kts` (replace debug signingConfig). Back up `.jks` file — losing it means no future updates.
  
  ```bash
  keytool -genkey -v -keystore ~/kanji-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias kanji-key
  ```

- [ ] **Host privacy policy** — convert `store_assets/privacy_policy.md` to a public URL (GitHub Pages). Paste URL into Play Console.

## Required assets (Play Console won't let you submit without these)

- [ ] **Feature graphic** (1024×500 PNG) → `store_assets/feature_graphic/`. Dark background, app logo/title centred, faint kanji in background.

## Play Console forms

- [ ] **Data Safety questionnaire** — answer "No" to all data collection/sharing questions.
- [ ] **IARC content rating** — fill questionnaire (expect "Everyone").
- [ ] **Play Store long description** — include JLPT disclaimer: *"JLPT® is a registered trademark of JEES. This app is not affiliated with or endorsed by JEES or the Japan Foundation."*

## Before final build

- [ ] **Clean up permissions** in `android/app/src/main/AndroidManifest.xml` — keep READ/WRITE_EXTERNAL_STORAGE (needed for export to external storage). Remove the 3 unused media permissions:
  
  ```xml
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
  <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
  <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
  ```

- [ ] **Build AAB** (not APK) for Play Store submission:
  
  ```bash
  cd kanji_app && flutter build appbundle --release
  ```

## Done (pre-launch prep completed)

- [x] Application ID changed: `com.example.kanji_app` → `com.rainmog.kanji_app`
- [x] Theme renamed: "Potential Copyright Lawsuit #01" → "Colorful Bricks"
- [x] Credits screen: KANJIDIC2 (CC BY-SA 4.0), JMdict (CC BY-SA 4.0), kanji-data (MIT full text on linked screen)
- [x] JLPT disclaimer added to About screen and Credits screen
- [x] App icon 512×512 exported → `store_assets/icon/icon_512x512.png`
- [x] Privacy policy draft → `store_assets/privacy_policy.md`
- [x] Asset DB version system — user_progress preserved across content updates (bump `_assetDbVersion` in `database_service.dart` when shipping N1 sentences)
- [x] **Screenshots** (min 2, phone) → `store_assets/screenshots/`. Capture from device or emulator.
