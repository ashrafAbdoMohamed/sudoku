import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'share_service.dart';

class RateAppService {
  static const String _hasRatedKey = 'has_rated_app';
  static const String _perfectWinsKey = 'perfect_wins_count';
  static const String _lastPromptKey = 'last_rate_prompt_time';

  // Trigger after 3 perfect wins (no mistakes)
  static const int _requiredPerfectWins = 3;
  // Don't prompt again for 30 days if dismissed
  static const int _promptCooldownDays = 30;

  final InAppReview _inAppReview = InAppReview.instance;

  /// Records a perfect win (0 mistakes) and checks if we should prompt for review
  Future<bool> recordPerfectWin() async {
    final prefs = await SharedPreferences.getInstance();

    // Don't track if already rated
    if (prefs.getBool(_hasRatedKey) ?? false) {
      return false;
    }

    // Check cooldown
    final lastPrompt = prefs.getInt(_lastPromptKey) ?? 0;
    final daysSinceLastPrompt = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastPrompt))
        .inDays;

    if (lastPrompt > 0 && daysSinceLastPrompt < _promptCooldownDays) {
      return false;
    }

    // Increment perfect wins
    final perfectWins = (prefs.getInt(_perfectWinsKey) ?? 0) + 1;
    await prefs.setInt(_perfectWinsKey, perfectWins);

    // Check if we should prompt
    return perfectWins >= _requiredPerfectWins;
  }

  /// Shows the native in-app review dialog
  Future<void> requestReview() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        // Mark as rated (we can't know if they actually rated, but we tried)
        await prefs.setBool(_hasRatedKey, true);
      } else {
        // Fallback: open store listing
        await _inAppReview.openStoreListing(appStoreId: ShareService.appStoreId);
      }
    } catch (e) {
      // Update last prompt time so we don't spam
      await prefs.setInt(_lastPromptKey, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Records that user dismissed the rate prompt
  Future<void> dismissPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPromptKey, DateTime.now().millisecondsSinceEpoch);
    // Reset perfect wins counter so they need another 3
    await prefs.setInt(_perfectWinsKey, 0);
  }

  /// Check if user has already rated
  Future<bool> hasRated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasRatedKey) ?? false;
  }

  /// Manually open store listing (for settings menu)
  Future<void> openStoreListing() async {
    await _inAppReview.openStoreListing(appStoreId: ShareService.appStoreId);
  }
}
