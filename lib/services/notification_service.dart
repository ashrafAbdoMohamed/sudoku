import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../state/game_store.dart';
import 'analytics_service.dart';
import '../utils/daily_challenge.dart';

/// Local daily-challenge reminders. No server: the next week of reminders is
/// scheduled on-device and rebuilt whenever the app opens or a daily is played,
/// so the text can reflect the player's streak and today's result.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const int reminderHour = 19; // 7 PM local time
  static const int _daysAhead = 7; // Reminders stop if the app isn't opened for a week
  static const int _baseId = 100; // ids 100..106

  static const _channelId = 'daily_challenge';
  static const _channelName = 'Daily Challenge reminders';
  static const _channelDescription = "Reminds you when today's puzzle is waiting";

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (_initialized || !_supported) return;
    try {
      tz.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));

      await _plugin.initialize(
        onDidReceiveNotificationResponse: (_) => AnalyticsService().logNotificationOpened(),
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          // Permission is requested later, at a meaningful moment
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;

      // App cold-started from a reminder tap
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        AnalyticsService().logNotificationOpened();
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to initialize - $e');
    }
  }

  /// Turn reminders on (asking for OS permission). Returns false if the
  /// user blocked notifications, in which case reminders stay off.
  /// source: where the user opted in, for analytics ('prompt' | 'settings')
  Future<bool> enableReminders(GameStore store, {required String source}) async {
    final granted = await requestPermission();
    store.setDailyReminders(granted);
    await reschedule(store);
    AnalyticsService().logRemindersChanged(enabled: granted, source: source);
    return granted;
  }

  Future<void> disableReminders(GameStore store) async {
    store.setDailyReminders(false);
    await reschedule(store);
    AnalyticsService().logRemindersChanged(enabled: false, source: 'settings');
  }

  /// Ask the OS for permission. Returns true if notifications may be shown.
  Future<bool> requestPermission() async {
    await initialize();
    if (!_initialized) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('NotificationService: Permission request failed - $e');
      return false;
    }
  }

  /// Rebuild the upcoming reminders from the store's current state.
  Future<void> reschedule(GameStore store) async {
    await initialize();
    if (!_initialized) return;

    try {
      for (int i = 0; i < _daysAhead; i++) {
        await _plugin.cancel(id: _baseId + i);
      }
      if (!store.dailyRemindersEnabled) return;

      final now = tz.TZDateTime.now(tz.local);
      bool first = true;
      for (int i = 0; i < _daysAhead; i++) {
        final fireAt = tz.TZDateTime(tz.local, now.year, now.month, now.day + i, reminderHour);
        if (!fireAt.isAfter(now)) continue;
        // Today's reminder is pointless once today's daily is done
        if (i == 0 && store.hasCompletedDailyToday) continue;

        final text = _message(store, fireAt, isNext: first);
        first = false;

        await _plugin.zonedSchedule(
          id: _baseId + i,
          scheduledDate: fireAt,
          title: text.title,
          body: text.body,
          payload: 'daily',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          // Inexact is fine for a reminder and needs no exact-alarm permission
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule reminders - $e');
    }
  }

  /// Only the next reminder mentions the streak - later days can't know
  /// whether the streak survived, so they stay generic.
  ({String title, String body}) _message(GameStore store, tz.TZDateTime fireAt, {required bool isNext}) {
    final streak = store.currentStreak;
    if (isNext && streak > 0 && (store.hasCompletedDailyToday || store.canMaintainStreak)) {
      return (
        title: '🔥 Keep your $streak-day streak alive!',
        body: "Today's Daily Challenge is waiting. Solve it to make it ${streak + 1} days.",
      );
    }

    final utc = fireAt.toUtc();
    final date = '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
    final difficulty = DailyChallenge.difficultyDisplayName(DailyChallenge.difficultyFromDate(date));
    return (
      title: "🧩 Today's Daily Challenge is ready",
      body: 'A fresh $difficulty puzzle - same one for every player. Can you set a great time?',
    );
  }
}
