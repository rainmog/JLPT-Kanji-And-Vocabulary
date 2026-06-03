# Play Store Assets

## Folder Contents

| Folder | What goes here | Required size |
|---|---|---|
| `icon/icon_512x512.png` | App icon — DONE | 512×512 px |
| `feature_graphic/` | Banner shown on store listing | 1024×500 px |
| `screenshots/` | At least 2 phone screenshots | 1080×1920 or similar |

`privacy_policy.md` — draft policy, needs hosting before submission.

## Before Submitting

### CRITICAL (blocks submission)
- [x] ~~Change applicationId from com.example~~ → set to `com.rainmog.kanji_app`
- [ ] Set up release signing keystore (see below)
- [ ] Host privacy policy publicly (GitHub Pages) and paste URL into Play Console
- [x] ~~Credits screen~~ → updated with KANJIDIC2 (CC BY-SA), JMdict (CC BY-SA), kanji-data (MIT full text)

### Required for listing
- [x] App icon (512×512) → `icon/icon_512x512.png`
- [ ] Feature graphic (1024×500) → `feature_graphic/`
- [ ] At least 2 screenshots → `screenshots/`
- [ ] Fill Data Safety questionnaire in Play Console (answer "No" to everything)
- [ ] Complete IARC content rating questionnaire (should be "Everyone")

### Recommended
- [ ] Remove unused Android permissions from `AndroidManifest.xml` (see note below)
- [ ] Build as AAB: `flutter build appbundle --release`
- [ ] Run `flutter analyze` — fix any errors
- [ ] Add donation button (link to Ko-fi/PayPal URL — do NOT use in-app purchase API)

## Signing Keystore (required for release)

```bash
keytool -genkey -v -keystore ~/kanji-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias kanji-key
```

Then in `android/app/build.gradle.kts`, replace:
```kotlin
signingConfig = signingConfigs.getByName("debug")
```
With a proper `signingConfigs` block pointing to your `.jks`.

**Back up the .jks and password. Losing it = can never update the app on Play Store.**

## Unused Permissions to Remove

`AndroidManifest.xml` has these left over from the removed file picker — safe to delete all of them:
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
```

## Feature Graphic (1024×500)

Recommendation: dark background matching app's default theme (dark blue `#0A0A1A`), centred app logo or title text in white/accent colour, a few kanji characters (漢 字 語) styled large in the background at low opacity. Keep it simple — no screenshots, no promotional text Google might reject.

Tools: Figma (free), Canva, or GIMP.

## Donation Button

Linking out to Ko-fi, PayPal, or similar from within the app is **fine for free apps** — no Google billing API required. Google's policy only requires in-app billing for digital goods sold within the app. A link to an external donation page is treated the same as a website link.

Note: Google Play does not allow apps to explicitly mention that they're bypassing Google's billing system. Just label it "Support the developer" with a link — don't mention it avoids fees.

## JLPT Disclaimer Placement

Added to:
- `about_screen.dart` — under app description
- `credits_screen.dart` — top of page in a box

Also add to your **Play Store long description**, e.g.:
> "JLPT® is a registered trademark of the Japan Educational Exchanges and Services (JEES). This app is not affiliated with or endorsed by JEES or the Japan Foundation."

## Attributions (in-app credits screen — DONE)

| Source | License | Status |
|---|---|---|
| JMdict/EDICT | CC BY-SA 4.0 | ✓ In credits screen |
| KANJIDIC2 | CC BY-SA 4.0 | ✓ In credits screen |
| kanji-data (davidluzgouveia) | MIT | ✓ Full license text in linked screen |
| Pixabay SFX | Pixabay License | ✓ In credits screen |
