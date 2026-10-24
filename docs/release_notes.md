# Release notes

## 1.0.5 (build 5)

Google Play "What's new" (en-US, max 500):

```
Smoother games for everyone:
• Live Race fixed: your friend no longer sees "Opponent left" right after the race starts, and progress stays in sync until the finish
• The winner no longer gets a "keep going" message meant for the runner-up
• The Daily puzzle is now the same for every player worldwide
• Bigger game board on smaller phones, and the home screen always fits
```

Changes:
- Live race: the challenge popup started the race twice; the second start closed the new
  game screen, which left the room (opponent saw "Opponent left", sync stopped). It now
  starts once.
- Live race: no "opponent finished/left" popups once your own game is over.
- Daily challenge: difficulty is computed from the UTC day of year (daylight saving made it
  differ between timezones, giving different puzzles on the same day).
- Game screen: the keys and tools shrink (to 72%) before the board does; the in-game banner
  is the slim 320x50 strip and is skipped on phones where the board would drop below 85% of
  the width.
- Home: everything always fits; the rank badge shrinks on short screens instead of hiding
  the Journey and Daily cards below the banner.

Bundle: `release/sudoku-1.0.5+5.aab` (git-ignored), signed with the upload key
(`~/keys/sudoku-upload.jks`, SHA-256 F5:5C:50:CF:…:49:EF).
