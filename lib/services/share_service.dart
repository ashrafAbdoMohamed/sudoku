import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'analytics_service.dart';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  // ═══════════════════════════════════════════════════════════════════════════
  // APP STORE LINKS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Numeric App Store ID - set once the iOS app is published.
  /// While null, iOS users share the Play Store link.
  static const String? appStoreId = null;

  static const String _playStorePackage = 'com.rocketgamestation.sudoku';

  // Custom URL scheme for deep linking
  static const String _urlScheme = 'sudoku';

  // ═══════════════════════════════════════════════════════════════════════════
  // STORE LINKS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Play link tagged with an install referrer, so Firebase Analytics attributes
  /// installs to the share that produced them (First user source = share_<source>)
  String playStoreUrl({String source = 'app'}) =>
      'https://play.google.com/store/apps/details?id=$_playStorePackage'
      '&referrer=utm_source%3Dshare_$source%26utm_medium%3Dshare';

  String get appStoreUrl => 'https://apps.apple.com/app/id$appStoreId';

  String storeUrl({String source = 'app'}) {
    if (Platform.isIOS && appStoreId != null) return appStoreUrl;
    return playStoreUrl(source: source);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEEP LINKS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate a deep link to open the app
  String getAppLink() => '$_urlScheme://open';

  /// Generate a deep link for a challenge
  String getChallengeLink(String pin) => '$_urlScheme://challenge/$pin';

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARE FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Share the app with friends
  Future<void> shareApp() async {
    const message = '''
🧩 Play Sudoku with me!

Challenge yourself with daily puzzles, compete on leaderboards, and track your progress!

Download now:
''';

    await Share.share('$message${storeUrl()}');
    AnalyticsService().logShare(contentType: 'app');
    debugPrint('ShareService: Shared app link');
  }

  /// Share a challenge invite
  Future<void> shareChallenge({
    required String pin,
    required String difficulty,
  }) async {
    final message = '''
🎮 I challenge you to a Sudoku duel!

Difficulty: ${difficulty[0].toUpperCase()}${difficulty.substring(1)}
Challenge PIN: $pin

1. Download Sudoku: ${storeUrl(source: 'challenge')}
2. Open the app and tap "Challenge a Friend" → "Enter Code"
3. Enter code: $pin

Let's see who solves it faster! ⏱️
''';

    await Share.share(message);
    AnalyticsService().logShare(contentType: 'challenge', itemId: difficulty);
    debugPrint('ShareService: Shared challenge $pin');
  }

  /// Share a solved puzzle. The message adapts to the mode:
  /// - daily: puzzle number + streak, everyone can play the same puzzle today
  /// - offline challenge ([challengePin]): friend can replay the exact puzzle
  /// - online duel ([opponentName]): who won
  Future<void> shareResult({
    required String difficulty,
    required int time,
    required int mistakes,
    int streak = 0,
    bool isDaily = false,
    int? dayNumber,
    String? challengePin,
    String? opponentName,
    bool wonDuel = false,
  }) async {
    final timeStr = '${(time ~/ 60).toString().padLeft(2, '0')}:${(time % 60).toString().padLeft(2, '0')}';
    final diff = '${difficulty[0].toUpperCase()}${difficulty.substring(1)}';

    final String header;
    final String cta;
    final String kind;
    if (opponentName != null) {
      kind = 'online';
      header = wonDuel
          ? '⚔️ I beat $opponentName in a live Sudoku duel!'
          : '⚔️ Sudoku duel vs $opponentName - so close!';
      cta = 'Think you can beat me? Download and challenge me:';
    } else if (isDaily && dayNumber != null) {
      kind = 'daily';
      header = '🧩 Sudoku Daily #$dayNumber · $diff';
      cta = 'Everyone gets the same puzzle today - can you beat my time?';
    } else if (challengePin != null && challengePin.isNotEmpty) {
      kind = 'challenge';
      header = '🧩 Sudoku · $diff';
      cta = 'Play the exact same puzzle: tap "Challenge a Friend" → "Enter Code" → $challengePin';
    } else {
      kind = difficulty;
      header = '🧩 Sudoku · $diff';
      cta = 'Can you beat my time?';
    }

    final mistakesStr = mistakes == 0 ? '✨ No mistakes' : '❌ $mistakes mistake${mistakes == 1 ? '' : 's'}';
    final streakStr = isDaily && streak > 0 ? ' · 🔥 $streak-day streak' : '';

    final message = '''
$header
⏱️ $timeStr | $mistakesStr$streakStr

$cta
${storeUrl(source: 'result')}
''';

    await Share.share(message);
    AnalyticsService().logShare(contentType: 'result', itemId: kind);
    debugPrint('ShareService: Shared result');
  }

  /// Share with custom message
  Future<void> shareCustom(String message) async {
    await Share.share(message);
  }
}
