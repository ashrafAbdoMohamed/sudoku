# Store listing

- **App / store title:** Sudoku - Play with friends (26 of 30 characters)
- **Name under the icon:** Sudoku
- Android `android:label` and iOS `CFBundleDisplayName` / `CFBundleName` are "Sudoku".
- **Package:** com.rocketgamestation.sudoku

## Google Play listing

### Short description (max 80)

```
Race your friends live, solve fun Sudoku levels, earn stars and climb the ranks!
```

### Full description (max 4000)

```
Sudoku - Play with friends is the classic number puzzle with a fun twist: challenge your friends to a live race, travel through a journey of levels, and earn stars, coins and ranks as you solve.

PLAY WITH FRIENDS
Challenge a friend to a live race: you both get the same puzzle and see each other's progress in real time. Prefer to play at your own pace? Share a 6-digit puzzle code and compare your times later.

A JOURNEY OF LEVELS
Play numbered levels in stages of 10. Puzzles start gentle and get harder as you go. Finish every level in a stage to open a treasure chest full of coins.

EARN STARS AND COINS
Solve with no mistakes and no help for 3 stars. Every solved puzzle pays coins, and harder puzzles pay more.

CLIMB 14 RANKS
Collect stars to rank up from Number Rookie all the way to Sudoku Emperor, each rank with its own character.

SMART HINTS AND MAGIC
Stuck? A Hint lights up the easiest cell to solve next, so you still find the number yourself. Magic fills in a cell for you. Notes let you pencil in the numbers a cell could be.

DAILY CHALLENGE
A new puzzle every day, the same for everyone. Keep your daily streak going!

4 LEVELS OF DIFFICULTY
Relax with Easy, warm up with Medium, think hard on Hard, or test yourself on Expert in Free Play.

FEATURES
• Live races and puzzle codes to play with friends
• A journey of levels with treasure chests
• Stars, coins and 14 ranks to climb
• Hints, Magic, Notes, Undo and Erase
• Daily Challenge and streaks
• Easy, Medium, Hard and Expert
• Awards to unlock and stats to track
• Bright, cheerful graphics and relaxing sounds
• Free to play

Perfect for a quick brain break or a friendly race. Download Sudoku - Play with friends and start solving!
```

### Graphics (store/google_play/)

- `icon_512.png`: 512×512 app icon
- `feature_graphic.png`: 1024×500 feature graphic
- `screenshots/01…08`: 1080×1920 phone screenshots, in upload order

### How the art is made

- App icon: drawn in code in `lib/game/app_logo.dart`, rendered with
  `flutter test tool/render_logo_test.dart` to `assets/branding/`, then resized into
  the Android mipmaps (plus adaptive background / foreground / monochrome layers),
  the iOS AppIcon set and `store/google_play/icon_512.png`.
- Screenshots and feature graphic: `flutter test tool/render_store_test.dart`
  frames the simulator captures in `store/raw/`.
