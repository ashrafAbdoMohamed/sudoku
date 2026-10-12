import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../models/progression.dart';
import '../models/rank.dart';

class ScoreEntry {
  final String diff;
  final int time;
  final int mistakes;
  final String date;

  ScoreEntry({required this.diff, required this.time, required this.mistakes, required this.date});

  Map<String, dynamic> toJson() => {'diff': diff, 'time': time, 'mistakes': mistakes, 'date': date};
  factory ScoreEntry.fromJson(Map<String, dynamic> j) =>
      ScoreEntry(diff: j['diff'], time: j['time'], mistakes: j['mistakes'], date: j['date']);
}

/// Statistics for a specific difficulty level
class DifficultyStats {
  int played;
  int won;
  int totalTime; // Total seconds for completed games
  int fastestTime; // Fastest completion time (or 0 if none)

  DifficultyStats({
    this.played = 0,
    this.won = 0,
    this.totalTime = 0,
    this.fastestTime = 0,
  });

  double get winRate => played > 0 ? won / played : 0;
  int get averageTime => won > 0 ? totalTime ~/ won : 0;

  Map<String, dynamic> toJson() => {
    'played': played,
    'won': won,
    'totalTime': totalTime,
    'fastestTime': fastestTime,
  };

  factory DifficultyStats.fromJson(Map<String, dynamic> j) => DifficultyStats(
    played: j['played'] ?? 0,
    won: j['won'] ?? 0,
    totalTime: j['totalTime'] ?? 0,
    fastestTime: j['fastestTime'] ?? 0,
  );
}

class SavedGame {
  final List<List<int>> puzzle;
  final List<List<int>> solution;
  final List<List<int>> board;
  final List<List<bool>> isGiven;
  final List<List<List<int>>> notes;
  final String difficulty;
  final int seconds;
  final int mistakes;
  final List<String> hintCells;

  /// The Journey level this game belongs to (null outside the Journey).
  final int? journeyLevel;

  SavedGame({
    required this.puzzle,
    required this.solution,
    required this.board,
    required this.isGiven,
    required this.notes,
    required this.difficulty,
    required this.seconds,
    required this.mistakes,
    required this.hintCells,
    this.journeyLevel,
  });

  Map<String, dynamic> toJson() => {
    'puzzle': puzzle,
    'solution': solution,
    'board': board,
    'isGiven': isGiven,
    'notes': notes,
    'difficulty': difficulty,
    'seconds': seconds,
    'mistakes': mistakes,
    'hintCells': hintCells,
    if (journeyLevel != null) 'journeyLevel': journeyLevel,
  };

  factory SavedGame.fromJson(Map<String, dynamic> j) => SavedGame(
    puzzle: (j['puzzle'] as List).map((r) => List<int>.from(r)).toList(),
    solution: (j['solution'] as List).map((r) => List<int>.from(r)).toList(),
    board: (j['board'] as List).map((r) => List<int>.from(r)).toList(),
    isGiven: (j['isGiven'] as List).map((r) => List<bool>.from(r)).toList(),
    notes: (j['notes'] as List).map((r) => (r as List).map((c) => List<int>.from(c)).toList()).toList(),
    difficulty: j['difficulty'],
    seconds: j['seconds'],
    mistakes: j['mistakes'],
    hintCells: List<String>.from(j['hintCells'] ?? []),
    journeyLevel: j['journeyLevel'] as int?,
  );
}

class GameStore extends ChangeNotifier {
  static const _key = 'sudoku_v2';

  String name = 'Player';
  String avatarColor = '#4F6EF7';
  String theme = 'light';
  int played = 0;
  int won = 0;
  Map<String, int?> bestTimes = {'easy': null, 'medium': null, 'hard': null, 'expert': null};
  List<ScoreEntry> scores = [];
  SavedGame? savedGame;

  // Daily Challenge & Streaks
  String? lastDailyPlayed; // Date string "yyyy-MM-dd"
  int currentStreak = 0;
  int longestStreak = 0;
  Map<String, int> dailyBestTimes = {}; // date -> time in seconds

  // Achievements
  Set<String> unlockedAchievements = {};
  int perfectGames = 0; // Games completed with 0 mistakes
  int noHintGames = 0; // Games completed without using hints
  int onlineWins = 0; // Online multiplayer wins
  Set<String> completedDifficulties = {}; // Difficulties completed at least once

  // Callback for newly unlocked achievements
  void Function(Achievement)? onAchievementUnlocked;

  // Detailed Statistics
  int totalPlayTime = 0; // Total seconds played across all games
  Map<String, DifficultyStats> difficultyStats = {
    'easy': DifficultyStats(),
    'medium': DifficultyStats(),
    'hard': DifficultyStats(),
    'expert': DifficultyStats(),
  };

  // Sound & Haptics Settings
  bool soundEnabled = true;
  bool hapticEnabled = true;

  // Learning Mode
  bool hasSeenTutorial = false;
  bool hasSeenCoachMarks = false;
  // Developer config - set to true to always show coach marks (for testing)
  bool alwaysShowCoachMarks = false;

  // Device ID for anonymous leaderboards
  String? deviceId;

  // GDPR/Privacy Consent
  bool gdprConsentGiven = false;
  bool analyticsConsent = false;
  bool adsConsent = false;

  // Daily challenge reminders (local notifications)
  /// Reminders are on by default (shown once the system allows them).
  bool dailyRemindersEnabled = true;
  bool reminderPromptShown = false;

  // Theme Settings
  // Coins, stars, Journey and ranks (cartoon redesign)
  int coins = startingCoins;

  /// Total stars earned; ranks climb with them.
  int stars = 0;

  /// The next Journey level to play (levels below it are cleared).
  int journeyNext = 1;

  /// Best stars per cleared Journey level.
  Map<int, int> journeyStars = {};

  /// Opened stage chests (0-based stage numbers).
  Set<int> journeyChests = {};

  /// The highest rank the player has been shown (and paid for).
  int rankSeen = 0;

  String colorThemeId = 'default'; // Color theme ID from ColorThemes
  String boardStyleId = 'classic'; // Board style ID from BoardStyles

  bool get isDark => theme == 'dark';
  bool get needsGdprConsent => !gdprConsentGiven;

  // Achievement helpers
  int get unlockedCount => unlockedAchievements.length;
  int get totalAchievements => Achievements.totalCount;
  double get achievementProgress => totalAchievements > 0 ? unlockedCount / totalAchievements : 0;

  bool hasAchievement(String id) => unlockedAchievements.contains(id);

  List<Achievement> get unlockedAchievementsList =>
      unlockedAchievements.map((id) => Achievements.getById(id)).whereType<Achievement>().toList();

  // ═══════════════════════════════════════════════════════════════════════════
  // STATISTICS HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get overall average completion time (for won games only)
  int get averageTime {
    int totalTime = 0;
    int totalWon = 0;
    for (final stats in difficultyStats.values) {
      totalTime += stats.totalTime;
      totalWon += stats.won;
    }
    return totalWon > 0 ? totalTime ~/ totalWon : 0;
  }

  /// Get total games for a specific difficulty
  DifficultyStats getStatsForDifficulty(String diff) {
    return difficultyStats[diff] ?? DifficultyStats();
  }

  /// Format time as MM:SS
  String formatTime(int seconds) {
    if (seconds <= 0) return '--:--';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Format time as HH:MM:SS for longer durations
  String formatLongTime(int seconds) {
    if (seconds <= 0) return '0:00:00';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Get win count for last 7 days from scores
  int get winsLast7Days {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    int count = 0;
    for (final score in scores) {
      final parts = score.date.split('/');
      if (parts.length == 3) {
        final month = int.tryParse(parts[0]) ?? 0;
        final day = int.tryParse(parts[1]) ?? 0;
        final year = int.tryParse(parts[2]) ?? 0;
        final scoreDate = DateTime(year, month, day);
        if (scoreDate.isAfter(weekAgo) && score.mistakes < 3) {
          count++;
        }
      }
    }
    return count;
  }

  /// Get best difficulty based on win rate (minimum 3 games played)
  String? get bestDifficulty {
    String? best;
    double bestRate = 0;
    for (final entry in difficultyStats.entries) {
      if (entry.value.played >= 3 && entry.value.winRate > bestRate) {
        bestRate = entry.value.winRate;
        best = entry.key;
      }
    }
    return best;
  }

  /// Get most played difficulty
  String? get mostPlayedDifficulty {
    String? most;
    int mostPlayed = 0;
    for (final entry in difficultyStats.entries) {
      if (entry.value.played > mostPlayed) {
        mostPlayed = entry.value.played;
        most = entry.key;
      }
    }
    return most;
  }

  // Daily challenge helpers
  String get _todayString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool get hasCompletedDailyToday => lastDailyPlayed == _todayString;

  int? get todayDailyTime => dailyBestTimes[_todayString];

  bool get canMaintainStreak {
    if (lastDailyPlayed == null) return true;
    final lastDate = DateTime.tryParse(lastDailyPlayed!);
    if (lastDate == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
    return lastDay == yesterday || lastDay == today;
  }

  String get rankName {
    if (won >= 100) return 'Master';
    if (won >= 50) return 'Expert';
    if (won >= 20) return 'Advanced';
    if (won >= 10) return 'Intermediate';
    if (won >= 3) return 'Novice';
    return 'Beginner';
  }

  String get rankIcon {
    if (won >= 100) return '👑';
    if (won >= 50) return '🏆';
    if (won >= 20) return '⭐';
    if (won >= 10) return '🎯';
    if (won >= 3) return '🌱';
    return '🔰';
  }

  String get winRate => played > 0 ? '${(won / played * 100).round()}%' : '—';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        name = j['name'] ?? 'Player';
        avatarColor = j['avatarColor'] ?? '#4F6EF7';
        theme = j['theme'] ?? 'light';
        played = j['played'] ?? 0;
        won = j['won'] ?? 0;
        if (j['bestTimes'] != null) {
          bestTimes = Map<String, int?>.from(
            (j['bestTimes'] as Map).map((k, v) => MapEntry(k.toString(), v as int?)),
          );
        }
        if (j['scores'] != null) {
          scores = (j['scores'] as List).map((e) => ScoreEntry.fromJson(e)).toList();
        }
        if (j['savedGame'] != null) {
          savedGame = SavedGame.fromJson(j['savedGame']);
        }
        // Daily challenge data
        lastDailyPlayed = j['lastDailyPlayed'];
        currentStreak = j['currentStreak'] ?? 0;
        longestStreak = j['longestStreak'] ?? 0;
        if (j['dailyBestTimes'] != null) {
          dailyBestTimes = Map<String, int>.from(
            (j['dailyBestTimes'] as Map).map((k, v) => MapEntry(k.toString(), v as int)),
          );
        }
        // Check if streak is broken (missed a day)
        _checkStreakStatus();

        // Achievement data
        if (j['unlockedAchievements'] != null) {
          unlockedAchievements = Set<String>.from(j['unlockedAchievements'] as List);
        }
        perfectGames = j['perfectGames'] ?? 0;
        noHintGames = j['noHintGames'] ?? 0;
        onlineWins = j['onlineWins'] ?? 0;
        if (j['completedDifficulties'] != null) {
          completedDifficulties = Set<String>.from(j['completedDifficulties'] as List);
        }

        // Statistics data
        totalPlayTime = j['totalPlayTime'] ?? 0;
        if (j['difficultyStats'] != null) {
          final statsMap = j['difficultyStats'] as Map;
          for (final key in ['easy', 'medium', 'hard', 'expert']) {
            if (statsMap[key] != null) {
              difficultyStats[key] = DifficultyStats.fromJson(statsMap[key] as Map<String, dynamic>);
            }
          }
        }

        // Sound & Haptics
        soundEnabled = j['soundEnabled'] ?? true;
        hapticEnabled = j['hapticEnabled'] ?? true;

        // Learning Mode
        hasSeenTutorial = j['hasSeenTutorial'] ?? false;
        hasSeenCoachMarks = j['hasSeenCoachMarks'] ?? false;
        alwaysShowCoachMarks = j['alwaysShowCoachMarks'] ?? false;

        // Device ID
        deviceId = j['deviceId'];

        // GDPR Consent
        gdprConsentGiven = j['gdprConsentGiven'] ?? false;
        analyticsConsent = j['analyticsConsent'] ?? false;
        adsConsent = j['adsConsent'] ?? false;

        // Reminders
        // Stored under a new key: the old one defaulted to off, so every
        // existing player gets the on-by-default reminders once.
        dailyRemindersEnabled = j['remindersOn'] ?? true;
        reminderPromptShown = j['reminderPromptShown'] ?? false;

        // Theme Settings
        colorThemeId = j['colorThemeId'] ?? 'default';
        boardStyleId = j['boardStyleId'] ?? 'classic';

        // Coins, stars, Journey and ranks. Players from before the redesign
        // start with coins and stars for the puzzles they already solved.
        coins = j['coins'] ?? startingCoins + min(won * 10, 800);
        stars = j['stars'] ?? min(won * 2, 600);
        journeyNext = j['journeyNext'] ?? 1;
        if (j['journeyStars'] != null) {
          journeyStars = (j['journeyStars'] as Map).map((k, v) => MapEntry(int.parse(k.toString()), v as int));
        }
        if (j['journeyChests'] != null) {
          journeyChests = Set<int>.from(j['journeyChests'] as List);
        }
        // Their current rank counts as already celebrated, so they don't get
        // a pile of rank-up popups on first launch.
        rankSeen = j['rankSeen'] ?? rankIndex;
      } catch (_) {}
    }

    // Generate device ID if not exists
    if (deviceId == null || deviceId!.isEmpty) {
      deviceId = _generateDeviceId();
      save();
    }

    notifyListeners();
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _checkStreakStatus() {
    if (lastDailyPlayed == null) return;
    final lastDate = DateTime.tryParse(lastDailyPlayed!);
    if (lastDate == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final difference = today.difference(lastDay).inDays;

    // If more than 1 day has passed, streak is broken
    if (difference > 1) {
      currentStreak = 0;
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({
      'name': name,
      'avatarColor': avatarColor,
      'theme': theme,
      'played': played,
      'won': won,
      'bestTimes': bestTimes,
      'scores': scores.map((s) => s.toJson()).toList(),
      'savedGame': savedGame?.toJson(),
      // Daily challenge data
      'lastDailyPlayed': lastDailyPlayed,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'dailyBestTimes': dailyBestTimes,
      // Achievement data
      'unlockedAchievements': unlockedAchievements.toList(),
      'perfectGames': perfectGames,
      'noHintGames': noHintGames,
      'onlineWins': onlineWins,
      'completedDifficulties': completedDifficulties.toList(),
      // Statistics data
      'totalPlayTime': totalPlayTime,
      'difficultyStats': difficultyStats.map((k, v) => MapEntry(k, v.toJson())),
      // Sound & Haptics
      'soundEnabled': soundEnabled,
      'hapticEnabled': hapticEnabled,
      // Learning Mode
      'hasSeenTutorial': hasSeenTutorial,
      'hasSeenCoachMarks': hasSeenCoachMarks,
      'alwaysShowCoachMarks': alwaysShowCoachMarks,
      // Device ID
      'deviceId': deviceId,
      // GDPR Consent
      'gdprConsentGiven': gdprConsentGiven,
      'analyticsConsent': analyticsConsent,
      'adsConsent': adsConsent,
      // Reminders
      'remindersOn': dailyRemindersEnabled,
      'reminderPromptShown': reminderPromptShown,
      // Theme Settings
      'colorThemeId': colorThemeId,
      'boardStyleId': boardStyleId,
      // Coins, stars, Journey and ranks
      'coins': coins,
      'stars': stars,
      'journeyNext': journeyNext,
      'journeyStars': journeyStars.map((k, v) => MapEntry('$k', v)),
      'journeyChests': journeyChests.toList(),
      'rankSeen': rankSeen,
    }));
  }

  void toggleTheme() {
    theme = isDark ? 'light' : 'dark';
    save();
    notifyListeners();
  }

  void setColorTheme(String themeId) {
    colorThemeId = themeId;
    save();
    notifyListeners();
  }

  void setBoardStyle(String styleId) {
    boardStyleId = styleId;
    save();
    notifyListeners();
  }

  void toggleSound() {
    soundEnabled = !soundEnabled;
    save();
    notifyListeners();
  }

  void toggleHaptic() {
    hapticEnabled = !hapticEnabled;
    save();
    notifyListeners();
  }

  /// Set GDPR consent with the options the user left ticked
  void acceptConsent({required bool analytics, required bool ads}) {
    gdprConsentGiven = true;
    analyticsConsent = analytics;
    adsConsent = ads;
    save();
    notifyListeners();
  }

  /// Set GDPR consent with only essential (no analytics/ads)
  void acceptEssentialOnly() {
    gdprConsentGiven = true;
    analyticsConsent = false;
    adsConsent = false;
    save();
    notifyListeners();
  }

  /// Update specific consent settings
  void updateConsent({bool? analytics, bool? ads}) {
    if (analytics != null) analyticsConsent = analytics;
    if (ads != null) adsConsent = ads;
    save();
    notifyListeners();
  }

  void markTutorialSeen() {
    hasSeenTutorial = true;
    save();
    notifyListeners();
  }

  void setDailyReminders(bool enabled) {
    dailyRemindersEnabled = enabled;
    save();
    notifyListeners();
  }

  void markReminderPromptShown() {
    reminderPromptShown = true;
    save();
    notifyListeners();
  }

  void markCoachMarksSeen() {
    hasSeenCoachMarks = true;
    save();
    notifyListeners();
  }

  /// Check if coach marks should be shown (TODO: remove)
  bool get shouldShowCoachMarks => alwaysShowCoachMarks || !hasSeenCoachMarks;
  // bool get shouldShowCoachMarks => true;

  void updateProfile(String newName, String newColor) {
    name = newName.isNotEmpty ? newName : name;
    avatarColor = newColor;
    save();
    notifyListeners();
  }

  void recordWin(String difficulty, int time, int mistakes) {
    played++;
    won++;
    totalPlayTime += time;

    // Update best time
    final bt = bestTimes[difficulty];
    if (bt == null || time < bt) bestTimes[difficulty] = time;

    // Update difficulty stats
    final stats = difficultyStats[difficulty];
    if (stats != null) {
      stats.played++;
      stats.won++;
      stats.totalTime += time;
      if (stats.fastestTime == 0 || time < stats.fastestTime) {
        stats.fastestTime = time;
      }
    }

    scores.insert(0, ScoreEntry(
      diff: difficulty,
      time: time,
      mistakes: mistakes,
      date: _formatDate(DateTime.now()),
    ));
    if (scores.length > 20) scores.removeLast();
    savedGame = null;
    save();
    notifyListeners();
  }

  void recordLoss(String difficulty, int time, int mistakes) {
    played++;
    totalPlayTime += time;

    // Update difficulty stats (played only, not won)
    final stats = difficultyStats[difficulty];
    if (stats != null) {
      stats.played++;
    }

    scores.insert(0, ScoreEntry(
      diff: difficulty,
      time: time,
      mistakes: mistakes,
      date: _formatDate(DateTime.now()),
    ));
    if (scores.length > 20) scores.removeLast();
    savedGame = null;
    save();
    notifyListeners();
  }

  void saveGame(SavedGame game) {
    savedGame = game;
    save();
  }

  void clearSavedGame() {
    savedGame = null;
    save();
    notifyListeners();
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  /// Record completion of daily challenge
  void recordDailyWin(int time, int mistakes) {
    final today = _todayString;

    // Don't record if already completed today
    if (lastDailyPlayed == today) return;

    // Update streak
    if (canMaintainStreak) {
      currentStreak++;
    } else {
      currentStreak = 1; // Start new streak
    }

    // Update longest streak
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    // Record time
    dailyBestTimes[today] = time;
    lastDailyPlayed = today;

    // Also count as a regular win
    played++;
    won++;
    totalPlayTime += time;

    // Add to scores with "daily" marker
    scores.insert(0, ScoreEntry(
      diff: 'daily',
      time: time,
      mistakes: mistakes,
      date: _formatDate(DateTime.now()),
    ));
    if (scores.length > 20) scores.removeLast();

    save();
    notifyListeners();
  }

  /// Record daily challenge loss (made 3 mistakes)
  void recordDailyLoss(int time, int mistakes) {
    // Daily loss doesn't break streak, but doesn't extend it either
    // Player can try again tomorrow
    played++;

    scores.insert(0, ScoreEntry(
      diff: 'daily',
      time: time,
      mistakes: mistakes,
      date: _formatDate(DateTime.now()),
    ));
    if (scores.length > 20) scores.removeLast();

    save();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COINS, STARS, JOURNEY & RANKS
  // ═══════════════════════════════════════════════════════════════════════════

  void addCoins(int amount) {
    coins += amount;
    save();
    notifyListeners();
  }

  /// Spends [amount] coins; false (and nothing spent) if there aren't enough.
  bool spend(int amount) {
    if (coins < amount) return false;
    coins -= amount;
    save();
    notifyListeners();
    return true;
  }

  int get rankIndex => rankIndexFor(stars);
  Rank get rank => ranks[rankIndex];

  /// The rank still waiting for its celebration, if any.
  int? get pendingRankUp => rankIndex > rankSeen ? rankIndex : null;

  /// Marks the current rank as celebrated and pays its bonus once (once per
  /// rank when several were gained at once). Returns the coins paid.
  int claimRankUp() {
    final gained = rankIndex - rankSeen;
    if (gained <= 0) return 0;
    rankSeen = rankIndex;
    final reward = gained * rankUpReward;
    coins += reward;
    save();
    notifyListeners();
    return reward;
  }

  /// Rewards a solved puzzle outside the Journey (free play, daily,
  /// challenges): its stars and coins. Returns the coins given.
  int rewardWin(String difficulty, int earnedStars) {
    final reward = coinsForWin(difficulty, earnedStars);
    stars += earnedStars;
    coins += reward;
    save();
    notifyListeners();
    return reward;
  }

  int journeyStarsFor(int level) => journeyStars[level] ?? 0;
  bool isJourneyCleared(int level) => level < journeyNext;
  int get journeyStage => stageOf(journeyNext);

  /// Records a solved Journey [level]. The first clear pays in full and
  /// unlocks the next level; replays only pay for beating the best stars.
  /// Returns the coins given and whether a stage chest is now ready.
  ({int coins, bool chestReady}) completeJourneyLevel(int level, int earnedStars) {
    final best = journeyStarsFor(level);
    final firstClear = !isJourneyCleared(level);
    var reward = 0;
    if (firstClear) {
      reward = coinsForWin(difficultyForLevel(level), earnedStars);
      if (level == journeyNext) journeyNext++;
    } else if (earnedStars > best) {
      reward = 5 * (earnedStars - best);
    }
    if (earnedStars > best) {
      stars += earnedStars - best;
      journeyStars[level] = earnedStars;
    }
    coins += reward;
    final chestReady = firstClear && isStageFinale(level) && !journeyChests.contains(stageOf(level));
    save();
    notifyListeners();
    return (coins: reward, chestReady: chestReady);
  }

  bool isStageComplete(int stage) => isJourneyCleared((stage + 1) * levelsPerStage);

  /// Opens a finished stage's chest, once. Returns the coins given.
  int openChest(int stage) {
    if (!isStageComplete(stage) || !journeyChests.add(stage)) return 0;
    coins += chestReward;
    save();
    notifyListeners();
    return chestReward;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACHIEVEMENT METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Unlock an achievement if not already unlocked
  void _unlockAchievement(Achievement achievement) {
    if (unlockedAchievements.contains(achievement.id)) return;
    unlockedAchievements.add(achievement.id);
    onAchievementUnlocked?.call(achievement);
  }

  /// Check and unlock achievements after a win
  void checkAchievements({
    required String difficulty,
    required int time,
    required int mistakes,
    required int hintsUsed,
    bool isChallenge = false,
    bool isOnline = false,
    bool isDaily = false,
    bool isOnlineWinner = false,
  }) {
    final newlyUnlocked = <Achievement>[];

    // Helper to track and unlock
    void tryUnlock(Achievement a) {
      if (!unlockedAchievements.contains(a.id)) {
        unlockedAchievements.add(a.id);
        newlyUnlocked.add(a);
      }
    }

    // ── Milestone achievements ──
    if (won >= 1) tryUnlock(Achievements.firstWin);
    if (won >= 10) tryUnlock(Achievements.wins10);
    if (won >= 25) tryUnlock(Achievements.wins25);
    if (won >= 50) tryUnlock(Achievements.wins50);
    if (won >= 100) tryUnlock(Achievements.wins100);
    if (won >= 250) tryUnlock(Achievements.wins250);

    // ── Perfection achievements ──
    if (mistakes == 0) {
      perfectGames++;
      tryUnlock(Achievements.perfectGame);
      if (perfectGames >= 5) tryUnlock(Achievements.perfect5);
      if (perfectGames >= 10) tryUnlock(Achievements.perfect10);
      if (perfectGames >= 25) tryUnlock(Achievements.perfect25);
    }

    // ── Comeback achievement ──
    if (mistakes == 2) {
      tryUnlock(Achievements.comeback);
    }

    // ── Speed achievements ──
    if (time < 300) tryUnlock(Achievements.speedDemon); // Under 5 min
    if (time < 180) tryUnlock(Achievements.lightningFast); // Under 3 min
    if (difficulty == 'easy' && time < 120) tryUnlock(Achievements.speedsterEasy);
    if (difficulty == 'medium' && time < 240) tryUnlock(Achievements.speedsterMedium);
    if (difficulty == 'hard' && time < 360) tryUnlock(Achievements.speedsterHard);
    if (difficulty == 'expert' && time < 600) tryUnlock(Achievements.speedsterExpert);

    // ── Difficulty achievements ──
    completedDifficulties.add(difficulty);
    if (difficulty == 'easy') tryUnlock(Achievements.completeEasy);
    if (difficulty == 'medium') tryUnlock(Achievements.completeMedium);
    if (difficulty == 'hard') tryUnlock(Achievements.completeHard);
    if (difficulty == 'expert') tryUnlock(Achievements.completeExpert);

    // Jack of All Trades - completed all difficulties
    if (completedDifficulties.containsAll(['easy', 'medium', 'hard', 'expert'])) {
      tryUnlock(Achievements.masterAllDifficulties);
    }

    // ── No hints achievements ──
    if (hintsUsed == 0) {
      noHintGames++;
      tryUnlock(Achievements.noHints);
      if (noHintGames >= 10) tryUnlock(Achievements.noHints10);
    }

    // ── Challenge achievement ──
    if (isChallenge) {
      tryUnlock(Achievements.challengeWin);
    }

    // ── Online achievements ──
    if (isOnline && isOnlineWinner) {
      onlineWins++;
      tryUnlock(Achievements.onlineWin);
      if (onlineWins >= 5) tryUnlock(Achievements.onlineWin5);
    }

    // ── Daily achievements ──
    if (isDaily) {
      tryUnlock(Achievements.dailyFirst);
    }

    // ── Streak achievements ──
    if (currentStreak >= 3) tryUnlock(Achievements.streak3);
    if (currentStreak >= 7) tryUnlock(Achievements.streak7);
    if (currentStreak >= 14) tryUnlock(Achievements.streak14);
    if (currentStreak >= 30) tryUnlock(Achievements.streak30);

    // ── Time-based achievements ──
    final now = DateTime.now();
    final hour = now.hour;
    if (hour >= 0 && hour < 5) tryUnlock(Achievements.nightOwl);
    if (hour >= 5 && hour < 7) tryUnlock(Achievements.earlyBird);

    // Notify for each newly unlocked achievement
    for (final achievement in newlyUnlocked) {
      onAchievementUnlocked?.call(achievement);
    }

    save();
  }
}

