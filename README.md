# Baht-Kyat Exchange (Flutter app)

Android app mirroring the THB/MMK exchange website
(https://baht-kyat-exchange.vercel.app/). Same Supabase project, same
tables, same RLS policies, same storage buckets (`slips`, `proofs`) —
the app and the website read and write the same live data.

- Package: `com.tryo.exchange`, version 1.0.0+1
- Backend: Supabase only (via `supabase_flutter`). **No Firebase.**
- UI: Burmese, blue + amber theme (no green), Noto Sans Myanmar font.
  All strings are copied exactly from the website's `STRINGS` object.
- No ads in v1 (AdMob comes later).
- Sideloaded APK via GitHub releases (no Play Store; see install notes
  below). The launcher icon is the default Flutter icon for now.

## Features (mirrors the website)

- Email/password sign in / sign up / forgot password, session restore,
  blocked accounts signed out with the blocked message.
- Google sign-in (see setup below — currently a placeholder).
- Home: rate card (both legs + last-updated), calculator, shop
  open/closed + announcement, floating Telegram/Viber buttons from
  shop settings.
- Dashboard, orders list + detail (timeline, slip/proof zoom, cancel
  while pending), profile + saved receivers.
- 3-step order wizard: direction + amount + live quote, shop payment
  accounts with QR, receiver + slip upload (camera/gallery, compressed
  to max 1200px JPEG 0.82, rate locked at creation).
- Admin (6 tabs): overview, orders queue, rates + history chart,
  users (block/unblock), settings (payment editors, receive-method
  toggles, shop info, admin management), ledger. Live updates via
  Supabase Realtime + 20s polling (skipped while typing).
- Bottom navigation on user pages, hidden on admin pages.

## Build locally

Requires Flutter 3.47.9 + JDK 17.

```sh
flutter pub get
flutter analyze   # must report no issues
flutter test      # 42 tests: quote math, settings merge, strings, compression, icons
```

Do **not** build release APKs locally for distribution — CI is the
build route (it restores the release keystore from secrets). A local
`flutter build apk --release` falls back to the debug key when
`android/key.properties` is absent, which signs with the wrong key.

## CI / releases

`.github/workflows/build-apk.yml`:

- Push to `main`: analyze + test + release APK build (no publish).
- Push a tag `v*` (e.g. `v1.0.0`): same checks, then publishes a
  GitHub release with the split-per-ABI APKs.
- `workflow_dispatch`: manual run.

Binary build assets (gradle wrapper jar, `gradlew`, launcher icons)
are **not** committed; CI regenerates them with `flutter create`
(same approach as the health-assistant-apk repo).

### GitHub secrets (repository Settings → Secrets and variables → Actions)

| Secret | Value |
|---|---|
| `RELEASE_KEYSTORE_BASE64` | Base64 of `android/app/release.keystore` (single line, no wrapping). Backup copy lives outside this repo (see below). |
| `RELEASE_KEYSTORE_PASSWORD` | The keystore password (backup copy outside this repo). |
| `RELEASE_KEY_ALIAS` | `exchange` |
| `RELEASE_KEY_PASSWORD` | Same value as the keystore password (PKCS12 uses one password). |

Keystore backups (chmod 600, outside this repo, never committed):

- `~/workspace/goals/baht-kyat-exchange-website/release-keystore-password.txt`
- `~/workspace/goals/baht-kyat-exchange-website/release-keystore.b64`

The debug keystore (`android/app/debug.keystore`, standard debug
credentials) **is** committed on purpose so every debug build signs
with the same key.

### Key fingerprints (for Google Cloud Console registration)

Release keystore (alias `exchange`, PKCS12, RSA 2048, valid to 2054):

- SHA-1: `EC:9F:79:31:EC:C8:78:73:3F:B5:7E:23:50:C7:5B:14:90:10:C4:1D`
- SHA-256: `71:11:F4:1A:79:C1:BB:6E:DF:49:B0:3D:55:AE:92:CE:28:F5:8C:CD:01:4A:54:BE:49:84:A6:68:13:37:02:3E`

Debug keystore (alias `androiddebugkey`):

- SHA-1: `5E:B4:9E:D6:50:F2:F1:63:E9:A2:02:F0:7F:DD:60:17:D8:42:3C:BB`
- SHA-256: `61:B5:5E:E8:85:FA:B8:3E:FB:0A:A0:45:63:58:05:13:72:19:A4:A1:63:D8:E9:8C:F9:A6:BC:9E:E4:BB:C5:74`

## Google sign-in setup (still to do)

The app is fully wired; only the OAuth configuration is missing.
`GOOGLE_WEB_CLIENT_ID` in `lib/config.dart` is an empty placeholder —
while empty, the Google button is hidden and email/password sign-in
works normally. Nothing crashes.

1. **Google Cloud Console** (project of your choice — any project works
   since Supabase validates the token):
   - APIs & Services → Credentials → Create Credentials → OAuth client
     ID → **Web application**. Copy the client ID
     (`...apps.googleusercontent.com`).
   - Create a second OAuth client ID → **Android**, package
     `com.tryo.exchange`, SHA-1 = the **release** SHA-1 above. Repeat
     for the **debug** SHA-1 if you want Google sign-in on debug
     builds too. (The Android clients authorize the app with Google
     Play services; the Web client ID is what the app + Supabase use
     to verify the ID token.)
   - Configure the OAuth consent screen if prompted (external, app
     name "Baht-Kyat Exchange").
2. **Supabase Dashboard** → Authentication → Providers → Google →
   Enable, paste the **Web** client ID and its client secret.
3. **This repo**: set `googleWebClientId` in `lib/config.dart` to the
   Web client ID, commit, tag a release (`v1.0.1` or similar).
4. **Test on the phone**: the Google button appears on the login
   screen; signing in creates/links the Supabase account (same email =
   same account) and grants admin automatically for seed-admin emails,
   exactly like the website.

Notes:

- The app passes only the ID token to
  `supabase.auth.signInWithIdToken` (google_sign_in v7 exposes no
  access token on the authentication object; Supabase accepts the ID
  token alone).
- The `google_sign_in` Android flow needs Google Play services on the
  phone (present on the Redmi Note 12).

## Password-reset links

The reset email currently links to the website's login page (the same
redirect the website itself uses), where the recovery session is
picked up in the browser. A future improvement is an app deep link
(e.g. `com.tryo.exchange://reset`) registered in Supabase's redirect
URLs + an Android intent filter; the app has no recovery handler yet.

## Installing the APK on the phone (sideload)

1. Download the `app-arm64-v8a-release.apk` from the GitHub release.
2. Tap it → allow "Install unknown apps" for the browser when asked.
3. Play Protect may warn about an unknown developer → "Install anyway".
4. Updates install over the old version (same release key keeps the
   data and login).

## Differences from the website (deliberate)

- No demo/localStorage mode — Supabase only.
- Admin auto-refresh (realtime + 20s polling) reloads the overview,
  orders, users and ledger tabs only; the rates/settings tabs (forms)
  load once, so unsaved edits are never wiped. The website re-renders
  every tab but skips refresh while a field is focused; the app keeps
  the same focus guard for the tabs it refreshes.
- Telegram/Viber icons use the website's exact brand SVGs
  (flutter_svg); the Google button uses a plain "G" badge (no brand
  asset bundled).
- Native dialogs replace the browser `confirm()` prompts; the
  confirm/cancel labels are the only hand-written Burmese strings
  (codepoint-verified, no Zawgyi-only codepoints).
- The wizard's slip picker is a camera/gallery bottom sheet instead of
  a file input; compression matches the website (1200px / JPEG 0.82).

## Project layout

```
lib/
  main.dart            App init (Supabase + Google) + shell (header,
                       bottom nav, page routing, blocked-session notice)
  config.dart          Supabase URL/anon key + Google client ID placeholder
  strings.dart         All Burmese strings (generated from the website)
  contact_icons.dart   Telegram/Viber brand SVGs (copied from the website)
  models.dart          Profile/Order/settings models + mergeSettings()
  quote.dart           Quote math, limits, formatting, contact links
  store.dart           Supabase data layer (mirror of js/store.js)
  app_state.dart       User/profile/admin/settings state
  theme.dart           Blue + amber theme
  widgets.dart         Cards, pills, order rows, slip images, contact
                       float, photo picking + compression
  screens/             home, auth, dashboard, orders, order detail,
                       profile, new order wizard, admin + 6 tabs
test/                  quote, settings-merge, strings + compression tests
android/app/           Signing config (debug key committed, release key
                       from CI secrets), INTERNET permission
```
