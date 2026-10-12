import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics wrapper. Collection is disabled in the native configs
/// (AndroidManifest / Info.plist) and only switched on after GDPR consent.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  bool _enabled = false;
  bool? _appliedAnalytics;
  bool? _appliedAds;

  /// Apply the user's consent. Safe to call often - only pushes changes.
  Future<void> applyConsent({required bool analytics, required bool ads}) async {
    if (analytics == _appliedAnalytics && ads == _appliedAds) return;
    _appliedAnalytics = analytics;
    _appliedAds = ads;
    try {
      _analytics ??= FirebaseAnalytics.instance;
      await _analytics!.setConsent(
        analyticsStorageConsentGranted: analytics,
        adStorageConsentGranted: ads,
        adUserDataConsentGranted: ads,
        adPersonalizationSignalsConsentGranted: ads,
      );
      await _analytics!.setAnalyticsCollectionEnabled(analytics);
      _enabled = analytics;
    } catch (e) {
      _enabled = false;
      debugPrint('AnalyticsService: Failed to apply consent - $e');
    }
  }

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_enabled) return;
    try {
      await _analytics!.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('AnalyticsService: Failed to log $name - $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GAME EVENTS
  // mode: 'classic' | 'daily' | 'challenge' | 'online'
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> logGameStart({required String difficulty, required String mode}) =>
      _log('game_start', {'difficulty': difficulty, 'mode': mode});

  Future<void> logGameResume({required String difficulty}) =>
      _log('game_resume', {'difficulty': difficulty});

  Future<void> logGameEnd({
    required bool won,
    required String difficulty,
    required String mode,
    required int seconds,
    required int mistakes,
    required int hints,
  }) =>
      _log(won ? 'game_won' : 'game_lost', {
        'difficulty': difficulty,
        'mode': mode,
        'seconds': seconds,
        'mistakes': mistakes,
        'hints': hints,
      });

  /// source: 'free' (no ad available / no ads consent) or 'rewarded_ad'
  Future<void> logHintUsed({required String source}) => _log('hint_used', {'source': source});

  // ═══════════════════════════════════════════════════════════════════════════
  // CHALLENGE A FRIEND
  // type: 'online' | 'offline'
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> logChallengeCreated({required String difficulty, required String type}) =>
      _log('challenge_created', {'difficulty': difficulty, 'type': type});

  /// fromLink: opened via a shared deep link rather than typing the code
  Future<void> logChallengeJoined({required String difficulty, required String type, required bool fromLink}) =>
      _log('challenge_joined', {'difficulty': difficulty, 'type': type, 'from_link': fromLink ? 1 : 0});

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARING & ENGAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// contentType: 'app' | 'challenge' | 'result'
  Future<void> logShare({required String contentType, String? itemId}) async {
    if (!_enabled) return;
    try {
      await _analytics!.logShare(contentType: contentType, itemId: itemId ?? contentType, method: 'system_sheet');
    } catch (e) {
      debugPrint('AnalyticsService: Failed to log share - $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DAILY REMINDERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> logRemindersChanged({required bool enabled, required String source}) =>
      _log(enabled ? 'reminders_enabled' : 'reminders_disabled', {'source': source});

  Future<void> logNotificationOpened() => _log('notification_open', {'type': 'daily_reminder'});

  Future<void> logAchievementUnlocked(String achievementId) async {
    if (!_enabled) return;
    try {
      await _analytics!.logUnlockAchievement(id: achievementId);
    } catch (e) {
      debugPrint('AnalyticsService: Failed to log achievement - $e');
    }
  }
}
