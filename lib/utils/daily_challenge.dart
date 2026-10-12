/// Daily Challenge utility functions.
/// Generates the same puzzle for all players worldwide on the same day.
class DailyChallenge {
  DailyChallenge._();

  /// Get today's date string in yyyy-MM-dd format (UTC for consistency worldwide)
  static String get todayString {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Generate a deterministic seed from a date string
  /// This ensures everyone gets the same puzzle on the same day
  static int seedFromDate(String dateString) {
    // Use a simple hash that produces consistent results
    int hash = 0;
    for (int i = 0; i < dateString.length; i++) {
      hash = ((hash << 5) - hash) + dateString.codeUnitAt(i);
      hash = hash & 0x7FFFFFFF; // Keep it positive
    }
    return hash;
  }

  /// Get today's seed
  static int get todaySeed => seedFromDate(todayString);

  /// Sequential puzzle number for sharing ("Daily #42"), counted from launch
  static int dayNumber(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return 1;
    return DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(2026, 9, 1)).inDays + 1;
  }

  static int get todayNumber => dayNumber(todayString);

  /// Get the difficulty for a given date
  /// Rotating schedule: Easy -> Medium -> Hard -> Expert -> repeat
  static String difficultyFromDate(String dateString) {
    final difficulties = ['easy', 'medium', 'hard', 'expert'];

    // Parse date to get day of year for rotation
    final date = DateTime.tryParse(dateString);
    if (date == null) return 'medium';

    // Use day of year for rotation
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    return difficulties[dayOfYear % difficulties.length];
  }

  /// Get today's difficulty
  static String get todayDifficulty => difficultyFromDate(todayString);

  /// Get display name for difficulty
  static String difficultyDisplayName(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Easy';
      case 'medium':
        return 'Medium';
      case 'hard':
        return 'Hard';
      case 'expert':
        return 'Expert';
      default:
        return difficulty;
    }
  }

  /// Get color for difficulty (as hex string)
  static String difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return '#4CAF50'; // Green
      case 'medium':
        return '#2196F3'; // Blue
      case 'hard':
        return '#FF9800'; // Orange
      case 'expert':
        return '#F44336'; // Red
      default:
        return '#9E9E9E'; // Grey
    }
  }

  /// Format time in mm:ss
  static String formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Get streak emoji based on streak length
  static String streakEmoji(int streak) {
    if (streak >= 30) return '🔥';
    if (streak >= 14) return '⚡';
    if (streak >= 7) return '✨';
    if (streak >= 3) return '🌟';
    if (streak >= 1) return '⭐';
    return '💫';
  }

  /// Get motivational message based on streak
  static String streakMessage(int streak) {
    if (streak >= 30) return 'Unstoppable!';
    if (streak >= 14) return 'On fire!';
    if (streak >= 7) return 'Week warrior!';
    if (streak >= 3) return 'Building momentum!';
    if (streak >= 1) return 'Keep it going!';
    return 'Start your streak!';
  }

  /// Calculate time until next daily challenge (midnight UTC)
  static Duration timeUntilNextDaily() {
    final now = DateTime.now().toUtc();
    final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  /// Format duration as HH:MM:SS
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
