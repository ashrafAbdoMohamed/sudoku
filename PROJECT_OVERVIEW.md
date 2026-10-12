# Sudoku: Challenge a Friend: Project Overview

> Snapshot written 2026-09-27 to restart work from a clean context.
> Repo: `/Volumes/Dev-SSD/sudoku` · GitHub: `ashrafabdomohamedd/sudoku` · branch `main`

## 1. At a glance

| | |
|---|---|
| App name (store) | **Sudoku: Challenge a Friend** (publisher: Rocket Game Station) |
| Tech | Flutter (Dart SDK `^3.10.4`), no state-management package, plain `ChangeNotifier` |
| Bundle / package id | `com.rocketgamestation.sudoku` (Android + iOS) |
| Version | `1.0.1+2` (`pubspec.yaml`) |
| Backend | Firebase Realtime Database (project `sudoku-96650`, region europe-west1), Firebase Hosting for legal pages |
| Monetization | Google AdMob: banner, interstitial, rewarded |
| Analytics | Firebase Analytics: events `game_start/resume/won/lost`, `hint_used`, `challenge_created/joined`, `share`, `unlock_achievement`. Play share links carry `utm_source=share_<app|challenge|result>` for install attribution |
| Orientation | Portrait only |
| Size | ~15.7k lines of Dart in `lib/` (39 files) |
| Tests | Only the default `test/widget_test.dart`, so effectively none |

## 2. Directory layout

```
lib/
  main.dart                     App root: Firebase init, splash → GDPR → Home, deep-link routing
  firebase_options.dart         FlutterFire generated (sudoku-96650)
  engine/sudoku_engine.dart     Puzzle generator/solver (seedable)
  state/
    game_state.dart             Live game (board, notes, undo, mistakes, timer, hints, mode callbacks)
    game_store.dart             Persistent profile/settings/stats/achievements (SharedPreferences)
  models/
    achievement.dart            ~35 achievements, rarity + category
    online_room.dart            OnlineRoom / PlayerState for 1v1 rooms
  screens/
    splash_screen.dart
    home_screen.dart            (~1.1k lines) main hub
    game_screen.dart            (~2.2k lines) board, numpad, dialogs, ads, coach marks
  services/                     All singletons
    ad_service.dart             AdMob (test IDs in debug via kDebugMode)
    analytics_service.dart      Firebase Analytics, off until GDPR analytics consent
    notification_service.dart   Local daily-challenge reminders (7 PM, next 7 days, streak-aware)
    deep_link_service.dart      app_links: sudoku://challenge/<pin> and https links
    leaderboard_service.dart    Global leaderboards + daily/weekly tournaments (RTDB)
    online_challenge_service.dart  Real-time 1v1 rooms (RTDB), presence heartbeat
    rate_app_service.dart       in_app_review after 3 perfect wins, 30-day cooldown
    share_service.dart          share_plus: share app / challenge / result
    sound_service.dart          Tones + haptics, respects settings
  theme/
    app_theme.dart              AppColorScheme (light/dark from a ColorTheme)
    board_themes.dart           6 BoardStyles + 7 ColorThemes
  utils/
    challenge_utils.dart        Offline 6-digit PIN encode/decode (difficulty + seed)
    daily_challenge.dart        Date → seed/difficulty, streak emoji/messages, countdown
  widgets/                      Modals & overlays (see §4)
legal/                          privacy-policy.html, terms-of-service.html (Firebase Hosting public dir)
store/                          Play Store assets (icon 512, feature 1024x500, SVG sources), SIGNING.md
keys/                           sudoku-upload.jks (also at ~/keys) — git-ignored
roadmap.md                      Pre-launch feature roadmap (see §7)
FIREBASE_SETUP.md               RTDB rules + data structure (URL there is outdated, see §8)
run2.sh                         Runs the app on two devices at once (Redmi + emulator) to test 1v1
```

## 3. Architecture

- **`main.dart`**: `SudokuApp` owns one `GameStore` and one `GameState`. The flow is Splash, then `store.load()`, then `SoundService.init`, then `AdService.initialize()` (only if GDPR + ads consent), then `DeepLinkService`, then Home. On first launch it shows the GDPR dialog with "Accept all" or "Essential only" (no ads).
- **State**: `GameStore` and `GameState` are `ChangeNotifier`s passed down through constructors. No Provider or Riverpod. `GameStore` holds everything persisted to `SharedPreferences`: stats, best times, per-difficulty stats, daily history and streak, achievements, the saved in-progress game, settings (dark mode, color theme, board style, sound, haptics), consent flags, tutorial/coach-mark flags, profile name/color, and `deviceId`.
- **Puzzle generation**: `SudokuEngine` fills the three diagonal boxes, solves with backtracking, then removes cells while keeping a unique solution (`_countSolutions(limit: 2)`). It runs in an isolate via `compute()`. Givens left per difficulty: **easy 32, medium 30, hard 26, expert 22**. Seeded `Random`, so the same seed gives the same puzzle, which is what makes challenges and dailies work.
- **Game modes** are all run by `GameState.newGame(diff, {seed, pin, online, isDaily})` plus callbacks:
  - *Normal*: random seed; progress auto-saves so "Continue" works.
  - *Challenge (offline)*: 6-digit PIN = `difficultyIndex*100000 + seed`. Both players get the same puzzle with no server involved.
  - *Online 1v1*: Firebase room under `rooms/<pin>`; the opponent's progress, mistakes and status stream live (`OpponentProgress` widget). Disconnects are detected server-side via `onDisconnect()` (no heartbeat); rooms are deleted when the match ends or the waiting host drops.
  - *Daily challenge*: the seed comes from the UTC date; difficulty rotates easy → medium → hard → expert by day of year. It tracks the streak.
- **Rules**: `GameState.maxMistakes = 5` (the loss reveals the solution). There are notes mode, undo (which also refunds mistakes), erase, and hints (fills a random empty cell). Hints are gated behind a rewarded ad. Keyboard input is supported (arrows, digits, shortcuts).

## 4. Features

| Feature | Where |
|---|---|
| 4 difficulties + "Continue" saved game | `home_screen.dart` `_buildPlaySection`, `_buildDifficultyGrid` |
| Daily Challenge card with countdown and streak | `_buildDailyChallengeCard`, `utils/daily_challenge.dart` |
| Challenge a Friend (highlighted card, tabs "Host Game" / "Enter Code", share code, QR via `qr_flutter`) | `_buildChallengeFriendCard`, `widgets/challenge_modal.dart` |
| Online 1v1 with live opponent progress | `online_challenge_service.dart`, `widgets/opponent_progress.dart` |
| Deep links `sudoku://challenge/<pin>` open the challenge modal pre-filled | `deep_link_service.dart`, `main.dart` |
| Statistics (win rate, averages, 7-day wins, per-difficulty) + rank (Beginner → Master) | `widgets/statistics_modal.dart`, `GameStore` |
| Achievements (~35: wins, perfect, speed, streaks, difficulty, no-hints, online, time-of-day) with unlock toasts | `models/achievement.dart`, `widgets/achievements_modal.dart` |
| Themes: 7 color themes × light/dark, 6 board styles | `theme/board_themes.dart`, `widgets/theme_picker.dart` |
| Learning mode + interactive tutorial + in-game coach marks | `learning_modal.dart`, `interactive_tutorial.dart`, `coach_marks_overlay.dart` |
| Settings (sound, haptics, theme, consent, legal, share app) | `widgets/settings_modal.dart` |
| Sound & haptics | `services/sound_service.dart` |
| Ads (for everyone after the consent dialog; personalized only with consent, otherwise non-personalized): adaptive banner on Home and pinned under the game screen, interstitial every 3 finished non-online games (counter persisted across screens and launches, shown after result dialogs and awaited until closed), rewarded for hints | `ad_service.dart`, `banner_ad_widget.dart`, `game_screen.dart` |
| Rate-us prompt after 3rd perfect win | `rate_app_service.dart`, `rate_app_dialog.dart` |
| GDPR consent + Privacy Policy / ToS (in-app and hosted) | `gdpr_consent_dialog.dart`, `legal_modal.dart`, `legal/` |
| Share Result button on every win dialog (classic, daily #N + streak, offline challenge with replay code, online duel) | `ShareService.shareResult`, `game_screen.dart` dialogs |
| Daily challenge reminders: local notifications at 7 PM, offered after the first solved daily, toggle in Settings → Reminders | `notification_service.dart`, `home_screen.dart` `_afterDailyChallenge` |
| Confetti on win, "board scanner" loading animation | `confetti_overlay.dart`, `board_scanner_loader.dart` |

**Built but not wired into any screen:** `LeaderboardModal`, `TournamentModal` (the `LeaderboardService` global leaderboards and daily/weekly tournaments), `ProfileEditModal`, and `_buildProfileCard` in Home.

## 5. Home screen order (current)

Header, then Daily Challenge, then **Challenge a Friend** (its own highlighted card), then New Puzzle (difficulty grid + play), then Quick Stats, then Recent Scores, then Banner Ad.

## 6. Firebase Realtime Database structure

```
rooms/<pin>          difficulty, seed, status(waiting|playing|finished), createdAt, startedAt, winner,
                     players/<uid>: name, progress(0-81), mistakes, status, finishTime, lastSeen
leaderboards/<diff>  push-id: name, deviceId, time, mistakes, timestamp   (pruned to top N)
tournaments/<id>     info{difficulty, seed, startTime, endTime, status}, entries/<deviceId>{...}
```
Rules (in `FIREBASE_SETUP.md`) are fully open read/write. There is no Firebase Auth; identity is a random `deviceId` or session uid.

## 7. History & status

Commits (oldest → newest): initial app, home design, **online session**, daily challenge + streaks + achievements, statistics UI, sound/haptics + polish + learning mode, achievement feature, **AdMob**, **deep links + sharing + more themes** (HEAD `4599e30`).

**Uncommitted work from the 2026-09-25 session** (15 files, not yet committed):
1. Challenge a Friend moved into its own highlighted card; order changed to Daily, then Challenge, then New Puzzle.
2. New `BoardScannerLoader` replaces the spinner while generating a puzzle.
3. Easy givens reduced 36 → 32 (Easy was about 44% filled).
4. Max mistakes 3 → 5 (UI dots and coach-mark text updated).
5. Banner ad at bottom of Home verified.
6. Challenge modal wording: "Create/Join" renamed to "Host Game" / "Enter Code" / "Create Game Code →", with the flow simplified.
7. Also: release signing config in `android/app/build.gradle.kts` (reads `android/key.properties`), new adaptive launcher icons, Firebase Hosting config for `legal/`, `.gitignore` updates.

**Roadmap (`roadmap.md`) still open:** daily login reward/coins, streak shield (rewarded ad), push notifications, shareable Wordle-style result card, smart tiered hints, friends leaderboard, ASO/localization (EN/AR/ES), offline graceful fallback, and v2 ideas (variants, seasonal events, clubs, subscription, accessibility, puzzle editor).

## 8. Known issues / loose ends

- `ShareService.appStoreId` is `null` until the iOS app is published (iOS shares the Play link meanwhile). The https App Links intent filter is commented out (no domain yet).
- **iOS ad unit IDs are copies of the Android ones** in `ad_service.dart`. iOS needs its own AdMob app and units (the iOS `GADApplicationIdentifier` is set).
- `FIREBASE_SETUP.md` references the old DB `sudoku-challenge-98e4d`; the app now uses `sudoku-96650`. RTDB exports of both are in `~/Downloads`.
- RTDB rules are world-writable with no auth, so leaderboards and rooms can be spoofed.
- The Android label is lowercase `sudoku`, and `pubspec` has the default description / `README.md`.
- `GameState.loadFromSaved` resets challenge and daily flags, so only normal games resume.
- There are no automated tests.

## 9. Build & run

```bash
flutter pub get
flutter run                                  # single device
./run2.sh                                    # two devices for 1v1 testing (edit device IDs)
flutter build appbundle --release            # needs android/key.properties → see store/SIGNING.md
firebase deploy --only hosting               # publishes legal/ pages
```
Remember to bump the `+build` number in `pubspec.yaml` before every Play upload.
