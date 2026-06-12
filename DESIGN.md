# Kanji App — Design System

Flutter / Dart. Material 3 (useMaterial3: true for Sakura; false for legacy themes). Riverpod state. Single-dev project targeting Android (primary) + Linux.

---

## 1. Fonts

| Role | Family | File |
|------|--------|------|
| UI / English | **Inter Variable** | `assets/fonts/InterVariable.ttf` |
| UI / English italic | Inter Variable Italic | `assets/fonts/InterVariable-Italic.ttf` |
| Japanese display | **NotoSerifCJKjp** | `assets/fonts/NotoSerifCJKjp-Regular.otf` |
| Fallback | system | user-configurable in settings |

**Rules:**
- All labels, headings, body copy → Inter.
- Any Japanese character being *studied* (kanji hero, test prompt, grid cell, option text, readings) → NotoSerifCJKjp.
- English translations and meanings → Inter even on Japanese screens.
- The font pair is configurable at runtime (`AppFonts`); always pass `fontFamilyFallback` alongside `fontFamily`.

---

## 2. Color System

### 2.1 Default Theme — Spring Sakura (`SakuraColors`)

The canonical palette. All other themes use the same semantic roles with different hex values.

| Token | Hex | Use |
|-------|-----|-----|
| `bg` | `#FAF4F0` | scaffold, app bar background |
| `surface` | `#FFFFFF` | cards, buttons, elevated containers |
| `surfaceHover` | `#F8F0F2` | pressed / hover surface |
| `fg` | `#3D1A26` | primary text, icons, kanji |
| `muted` | `#9E7585` | secondary text, hints, subtitles |
| `accent` | `#D4677E` | fills, active state, links, CTA |
| `accentLight` | `#FDEDF0` | hover bg, targeted-state cells, badge bg |
| `accentEnd` | `#E8899A` | progress gradient end |
| `correct` | `#2F7A50` | correct-answer text |
| `correctBg` | `#EDF7F2` | correct-answer cell background |
| `incorrect` | `#C93350` | wrong-answer text |
| `incorrectBg` | `#FCE8ED` | wrong-answer cell background |
| `progressTrack` | `#F5DDE4` | progress bar track |
| `progressFill` | `#D4677E` → `#E8899A` | progress bar gradient fill |
| `border` | `rgba(61,26,38,0.07)` | dividers, cell outlines |

### 2.2 All Themes

| Key | Display Name | bg | accent | Character | Animated bg |
|-----|-------------|-----|--------|-----------|-------------|
| `simpleDark` | Simple Black | `#13161C` | `#7D97FF` | dark, cool blue-purple | none |
| `simpleLight` | Simple Light | `#F4F5F8` | `#3258E8` | light, clean blue | none |
| `sakura` | Spring Sakura | `#FAF4F0` | `#D4677E` | warm cream, pink | sakura petals |
| `galaxy` | Starman | `#05060F` | `#3FE3EC` | deep space, teal | starfield + shooting star |
| `tetris` | Colorful Bricks | `#0A0C1C` | `#00E0E0` | retro dark, neon | grid + falling blocks + scanlines |
| `loveLetter` | Love Letter | `#F1F5FA` | `#6F97C4` | overexposed blue-white | snowfall + sparkles |
| `lily` | Chou-chou Green | `#EEF4EA` | `#5F9E7D` | paddy haze, sage | bloom + lens flares |
| `totoro` | Big Rabbit Green | `#EEF1DE` | `#6B9A52` | countryside warm green | sun shaft + falling leaves |
| `midnightCity` | Midnight City | `#070627` | `#35E0FF` | city pop deep violet | moon + skyline + neon signs |

Themes with animated backgrounds set `transparentScaffold: true` on their `buildTheme()` call and use `HomeBgLayer` / `ThemedBackground` as the first child of a `Stack`.

### 2.3 Contrast Modes

`appearanceSettings.getContrast()` → `'normal'` | `'high'` | `'ultra'`

High/ultra: adjusts `bg`, `surface`, `fg`, `muted` lightness via HSL ±5–15%. Accent, semantic, and pill colors are untouched.

---

## 3. Typography

All sizes in logical pixels. Weight uses Flutter `FontWeight` constants.

| Style token | Size | Weight | Family | Color | Extras |
|-------------|------|--------|--------|-------|--------|
| `kanjiHero` | 72 | w700 | NotoSerifCJKjp | fg | height 1.0 |
| `kanjiTest` | 90 | w700 | NotoSerifCJKjp | fg | height 1.0, letterSpacing −1.5 |
| `kanjiReading` | 13 | w400 | NotoSerifCJKjp | accent | letterSpacing 1.0 |
| `kanjiMeaning` | 13 | w400 | Inter | muted | — |
| `gridKanji` | 20 | w400 | NotoSerifCJKjp | fg | — |
| `optionText` | 16 | w400 | NotoSerifCJKjp | fg | — |
| `appBarTitle` | 16 | w700 | Inter | fg | — |
| `appBarSubtitle` | 11 | w400 | Inter | muted | — |
| `titleLarge` | 20 | w700 | Inter | fg | — |
| `titleMedium` | 16 | w600 | Inter | fg | — |
| `titleSmall` | 14 | w600 | Inter | fg | — |
| `sectionLabel` | 15 | w600 | Inter | fg | accordion headers |
| `buttonLabel` | 15 | w500 | Inter | fg | nav / accordion items |
| `bodyLarge` | 15 | w400 | Inter | fg | — |
| `bodyMedium` | 14 | w400 | Inter | fg | — |
| `bodySmall` | 12 | w400 | Inter | muted | — |
| `progressLabel` | 11 | w600 | Inter | muted | letterSpacing 0.8 |
| `progressCount` | 12 | w700 | Inter | fg | — |
| `labelSmall` | 11 | w500 | Inter | muted | letterSpacing 0.7 |
| `mutedLink` | 13 | w500 | Inter | accent | "Already know this" style links |

Section headers in settings use all-caps at 13px, muted, letterSpacing 1 — not a named token, inline pattern.

---

## 4. Shape & Spacing

### Border Radius

| Theme | Button radius | Container radius |
|-------|--------------|-----------------|
| Most themes | 12px | 10–12px |
| Totoro | 16px | 16px (rounder, softer) |
| Midnight City | 14px | 14px |
| Tetris | 2px | 2px (pixel-art sharp) |
| Progress bar | 99px pill | — |
| N-level badges | 7px | — |
| Kanji grid cells | 10px | — |
| Snackbar | 10px | — |
| Checkbox | 5px | — |

### Key Dimensions

| Token | Value |
|-------|-------|
| `screenPaddingH` | 18px |
| `buttonPaddingV` | 15px |
| `buttonPaddingH` | 18px |
| `itemGap` | 8px |
| `heroCircleSize` | 140px diameter |
| Screen padding (onboarding) | 32px |
| Settings body padding | 20px all |

---

## 5. Shadows

Two levels; both use the `fg` color base at low opacity.

| Name | Color | Blur | Offset |
|------|-------|------|--------|
| `card` (default) | `rgba(61,26,38,0.10)` | 6 | (0, 1) |
| `cardMd` (hover/active) | `rgba(61,26,38,0.12)` | 14 | (0, 2) |

Dark themes use the same shadow values — the dark surface colour provides enough perceived depth.

---

## 6. Component Patterns

### 6.1 AppBar

- No elevation, no scroll-under elevation, no surface tint.
- Background = `bg` (matches scaffold).
- Title: left-aligned (centerTitle: false), 16px w700 Inter, fg.
- Status bar: transparent, dark icons on light themes / light icons on dark.
- Back icon + actions: fg / muted respectively, 22px.

### 6.2 Buttons

**Primary (accent fill):** `SakuraButtonStyles.accent` / inline `ElevatedButton.styleFrom`.
- Background: accent. Foreground: white. Padding: 14×18px. Font: 15px w600, letterSpacing 0.3.

**Card / nav button (white fill):** default ElevatedButton.
- Background: surface. Shadow: card. Shape: btnBorderRadius. Padding: 15×18px. Font: 15px w500.

**Text / link:** `TextButton`, accent foreground, 13px w500.

**Scale feedback:** Wrap interactive elements in `ScaleOnPress` widget for press-down animation.

### 6.3 Option Buttons (Quiz)

Four decoration states managed by `SakuraDecorations`:

| State | Fill | Border |
|-------|------|--------|
| Idle | surface + card shadow | none |
| Correct | `correctBg` | `correct` @ 33% opacity, 1.5px |
| Wrong | `incorrectBg` | `incorrect` @ 33% opacity, 1.5px |
| Dim (other options after answer) | surface | none, no shadow |

### 6.4 Hero Kanji Circle

- Circular, 140px diameter.
- Fill: accent @ 7% opacity.
- Border: accent @ 18% opacity, 1.5px.
- Text: `kanjiHero` style (72px NotoSerifCJKjp w700).

### 6.5 Kanji Grid Cells

Three states, 10px radius:

| State | Fill | Border |
|-------|------|--------|
| Unlearned | surface + shadow | none |
| Targeted | accentLight | accent @ 33%, 1px |
| Learned | correctBg | correct @ 27%, 1px |

Cell text: 20px NotoSerifCJKjp w400.

### 6.6 Progress Bar

`SakuraProgressBar` — not Flutter's `LinearProgressIndicator`. Pill-shaped (99px radius clip), 5px height (configurable), gradient fill from `progressFill` to `accentEnd`, `progressTrack` background. Always clamps fill to minimum 1.5% visible.

### 6.7 N-Level Badges

7px radius containers used for JLPT level selection (N5, N4, N3…):
- Active: accentLight fill + accent @ 28% border, 1.5px.
- Inactive: border only (at `border` token).

### 6.8 Home Screen Layout Elements

Four zones stacked vertically (5% top/bottom bumpers via `MediaQuery`):

1. **Top icon bar** — right-aligned row: SFX toggle, ambient toggle, Credits (ⓘ), Settings. Each is a 40×40 `AnimatedContainer` chip (`chipRadius`, surface bg, line border, small shadow).
2. **Tracker card** — surface card (`heroRadius`, line border, small shadow). Heading "CURRENT TOTAL TARGETS". Configurable progress rows driven by `homeTrackers: List<String>` in `AppSettings` (tracker IDs: `kanji:all`, `vocab:all`, `kanji:N5`–`N1`, `vocab:N5`–`N1`, `hiragana:all`, `katakana:all`, `kanji:tag:<tag>`, `vocab:tag:<tag>`). Small `+` button (14×14 accent circle) at bottom-right opens `_TrackerPickerSheet` modal; hidden when `showTrackerPicker = false`.
3. **Hero session block** — `Expanded`, accent→deep gradient (`heroRadius`, accent shadow). Shows target kanji count, target vocab count, `_GoalRing` (78px arc), and a white "Start studying" `ElevatedButton`.
4. **Quick-launch tiles** — `Row` of 3 `Expanded` tiles (`_QuickTile`): Set targets (accent border), Dictionary, JLPT test. Each has a 44×44 icon chip and a short label.

Animated backgrounds layer behind all content via `HomeBgLayer` + `SakuraPetalsOverlay` as `Positioned.fill` first children of the body `Stack`. Scaffold `backgroundColor` is `Colors.transparent` when `HomeBgLayer` is active (Galaxy, Tetris, Love Letter, Lily, Totoro, Midnight City); otherwise `colors.bg`.

### 6.9 Cards / Containers

`SakuraDecorations.card`: white surface, 12px radius, card shadow.
`SakuraDecorations.container`: white surface, 10px radius (containerRadius), card shadow.
CardTheme: margin zero, no elevation (shadow is via BoxDecoration, not Material elevation).

### 6.10 Checkboxes

Rounded (5px), accent fill when selected, white check, 1.5px accent border.

### 6.11 Snackbar

Dark bg (`fg` color), white text, floating behaviour, 10px radius.

### 6.12 ListTile / Nav Items

Surface fill, `btnBorderRadius` shape, horizontal padding 18px, vertical 4px.

---

## 7. Animated Backgrounds

All backgrounds are `CustomPainter`-based, driven by a single `AnimationController` via the shared `_Ticking` stateful wrapper (period varies by theme). Positioned as first child of a `Stack` behind all content; wrapped in `IgnorePointer` so they never intercept taps.

| Theme | Animation | Key details |
|-------|-----------|-------------|
| Sakura | Falling petals overlay | 14 petals, ticker-based, warm rose `#D4778F` / `#E8899A` / `#B85A72` / `#EDADB8` |
| Galaxy / Starman | Starfield + shooting star | 78 stars (seeded), twinkle via sin wave, 8s period; shooting star crosses every 25% of period |
| Tetris | Retro grid + falling blocks | 26px grid, 9 falling squares (tetro palette), scanlines every 3px at 16% black, 10s period |
| Love Letter | Snowfall + sparkle | 46 snowflakes + 22 sparkle points, white bloom from top, 13/6s periods |
| Lily | Bloom haze + lens flares | Radial bloom from top-right, 5 static ring flares, 18 floating dots, 16s period |
| Totoro | Sun shaft + falling leaves | Linear gradient shaft top-left, 16 rotating leaf shapes, 2 greens, 14s period |
| Midnight City | Skyline + moon + neon | Procedural buildings, 38 stars, purple moon with glow, 2 neon signs, 6s period |

Simple Dark, Simple Light, Love Letter, Lily, Totoro have static gradient as base layer; animated elements layer on top.

---

## 8. Graphical Style

- **Flat-ish, warm.** No heavy drop shadows, no gradients on UI chrome. Depth only through subtle card shadows and colour fills.
- **Japanese aesthetic references** in theming: sakura, Ghibli-coded greens (Totoro, Lily), city-pop purple (Midnight City), retro-game pixel (Tetris).
- **No illustration or icon sheets.** UI relies on text, colour, geometry, and logo SVGs. Icon usage is Material symbols at 22px.
- **Logos:** 5 SVG variants (`logo.svg`, `logo_jlpt.svg`, `logo_torii.svg`, `logo_brush.svg`, `logo_fuji.svg`, `logo_book.svg`) — situationally applied; splash uses `splash_logo.png`.
- **Kanji is the visual hero.** Every study screen leads with large serif kanji. Other chrome is subordinate to it.
- **Furigana** rendered via `FuriganaWidget` / `RubyText` as inline ruby text, accent colour on the reading.

---

## 9. Motion & Interaction

| Pattern | Details |
|---------|---------|
| Press feedback | `ScaleOnPress`: wraps any tappable; slight shrink on down |
| Answer feedback | `AnimationController` 300ms, scale 0.93→1.0, `Curves.elasticOut` |
| Theme backgrounds | `AnimationController.repeat()` — runs continuously; paused when `animate: false` |
| Accordion expand/collapse | `setState` toggle, implicit AnimatedSize/AnimatedContainer expected |
| Page transitions | `AppRoute.to()` — wraps `MaterialPageRoute`, no custom transitions documented |
| Sakura petals | `Ticker`-driven at ~60fps; stops when theme ≠ Sakura |
| Animation opt-out | `settings.animationsEnabled` — passed into background widgets as `animate:` flag |

---

## 10. Audio Feedback

Audio complements interaction, not decoration. All SFX are short, distinct, non-intrusive.

| Event | File |
|-------|------|
| Correct answer | `Sparkle.mp3` |
| Wrong answer | `Wrong.mp3` |
| Button select / nav | `select_button.wav` |
| Navigate back | `go_back.wav` |
| Session/test start | `test_practice_start.wav` |
| Session/test complete | `test_practice_complete.wav` |

Ambient tracks (optional, user-controlled volume): By The Ocean, Chimes and Rain, Light Rain, Storm, Dentist Drill For Peaceful Dreams. Designed to mix with music/podcasts — low-volume background only.

---

## 11. Layout Conventions

- **Scaffold > Stack** — background layer (animated or plain) first, content second. Required for themes with decorative backgrounds.
- **Body scroll:** `ListView` with `padding: EdgeInsets.all(20)` for settings-style screens; custom `Column`/`SingleChildScrollView` for study screens.
- **Horizontal padding:** 18px (`screenPaddingH`) in study/home screens; 20px in settings; 32px in onboarding.
- **AppBar:** always present on navigation screens, absent or custom on session/onboarding screens.
- **SafeArea:** used on onboarding and full-bleed screens.
- **Home structure:** top icon bar + configurable tracker card (with optional `+` picker button) + expanded hero session block + 3 quick-launch tiles. No AppBar — icons sit in a padded row at the top of the body.
- **Config screens:** options list in the body, single full-width primary action button pinned or near bottom.
- **Session screens:** large kanji prompt centred, progress bar at top, option buttons or text field below, skip/already-know link at bottom.
- **Section labels** in settings: all-caps, 13px, muted, letterSpacing 1 — acts as a non-interactive group header above settings rows.

---

## 12. Tone & Copy

- **Functional, direct.** No marketing language. Labels describe what the action does: "Practice", "Test", "Review Mistakes".
- **JLPT framing.** Content is always anchored to N-levels (N5 → N1). Progress is expressed as counts: "89 learned · 4 targeted".
- **Onboarding is brief.** "Welcome to JLPT Kanji & Vocabulary. A few notes on how to get started." — no feature-sell, just orientation.
- **Help text in settings** is one plain sentence in muted style below each control. e.g. "Plays in the background. Mixes with other audio (music, podcasts)."
- **Japanese text is not translated in UI chrome** — readings appear as-is in accent colour; meanings appear in muted Inter.
- **Error / empty states:** not documented in sources — assume the same muted + fg palette; no illustration.
- **App identity:** "JLPT Kanji & Vocabulary" — formal name. Internal code uses `kanji_app`. Store: `com.rainmog.kanji_app`.
