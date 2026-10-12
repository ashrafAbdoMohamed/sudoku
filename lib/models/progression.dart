// Coins, stars and the Journey: the rules, as plain functions (no state) so
// they are easy to test. GameStore keeps the player's progress.

/// Coins a new player starts with.
const startingCoins = 200;

/// Price of a Hint (shows where a number goes) and of Magic (fills a cell).
const hintCost = 25;
const magicCost = 60;

/// Coins for opening a stage chest, and for each rank gained.
const chestReward = 100;
const rankUpReward = 100;

/// Coins for watching a rewarded "free coins" video.
const adReward = 50;

/// Stars for a solved puzzle: 3 for a clean solve, minus one for any
/// mistakes and minus one for any help (Hint or Magic). Never below 1.
int starsFor({required int mistakes, required bool usedHelp}) {
  var stars = 3;
  if (mistakes > 0) stars--;
  if (usedHelp) stars--;
  return stars < 1 ? 1 : stars;
}

/// Coins for a solved puzzle: a base by difficulty plus 5 per star.
int coinsForWin(String difficulty, int stars) {
  const base = {'easy': 10, 'medium': 15, 'hard': 20, 'expert': 30};
  return (base[difficulty] ?? 10) + 5 * stars;
}

// ---------------------------------------------------------------- journey
//
// Numbered levels in stages of [levelsPerStage]; each stage ends in a chest.
// Difficulty ramps up with the level, and a level is always the same puzzle.

const levelsPerStage = 10;

/// 0-based stage of a 1-based [level].
int stageOf(int level) => (level - 1) ~/ levelsPerStage;

bool isStageFinale(int level) => level % levelsPerStage == 0;

/// Difficulty of a Journey level: a gentle start, then harder stage by
/// stage, with the stage finale one step up.
String difficultyForLevel(int level) {
  const order = ['easy', 'medium', 'hard', 'expert'];
  final stage = stageOf(level);
  var step = switch (stage) {
    0 => 0,
    1 || 2 => 1,
    3 || 4 || 5 => 2,
    _ => 3,
  };
  if (isStageFinale(level) && step < 3) step++;
  return order[step];
}

/// Puzzle seed of a Journey level: fixed, so everyone gets the same level.
int seedForLevel(int level) => 7919 * level + 104729;
