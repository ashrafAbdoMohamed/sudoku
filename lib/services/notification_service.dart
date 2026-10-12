import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../state/game_store.dart';
import 'analytics_service.dart';
import 'reminder_plan.dart';

/// Daily-puzzle, streak and come-back reminders, as local notifications:
/// scheduled on the device, no server or push setup involved.
///
/// The schedule is rebuilt from the player's progress whenever the app opens
/// or returns to the foreground and after every daily, so a reminder never
/// covers something they already did. [planReminders] decides what to send.
///
/// On by default. Where the system needs the player's permission (iOS,
/// Android 13+) we ask once, with our own popup first, after their second
/// solved puzzle (see [maybeAskPermission]); until then nothing is shown.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  SharedPreferences? _prefs;
  bool _initialized = false;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Daily puzzle and streak reminders',
      icon: 'ic_notification',
      color: Color(0xFF1FB5A8),
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> initialize() async {
    if (_initialized || !_supported) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      tz.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));

      await _plugin.initialize(
        onDidReceiveNotificationResponse: (_) => AnalyticsService().logNotificationOpened(),
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          // Never ask on launch: we ask at a good moment (maybeAskPermission).
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
      onResumed();

      // App cold-started from a reminder tap
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        AnalyticsService().logNotificationOpened();
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to initialize - $e');
    }
  }

  /// The game came to the foreground: remember when the player plays, so
  /// reminders arrive at their usual time.
  void onResumed() {
    _prefs?.setInt('playHour', DateTime.now().hour);
  }

  /// Cancels everything pending and schedules a fresh plan (if enabled).
  Future<void> reschedule(GameStore store) async {
    await initialize();
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
      // Without the system permission these are simply not shown until it's
      // granted.
      if (!store.dailyRemindersEnabled) return;
      final plan = _testSchedule
          ? _testPlan(store)
          : planReminders(
              now: DateTime.now(),
              dailyDoneToday: store.hasCompletedDailyToday,
              streak: store.currentStreak,
              canKeepStreak: store.canMaintainStreak,
              journeyNext: store.journeyNext,
              playHour: _prefs?.getInt('playHour'),
            );
      if (kDebugMode) debugPrint('Reminders scheduled: $plan');
      for (final r in plan) {
        await _schedule(r, r.at);
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule reminders - $e');
    }
  }

  Future<void> _schedule(PlannedReminder r, DateTime at) {
    final (title, body) = _text(r);
    return _plugin.zonedSchedule(
      id: r.id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details,
      // Inexact: may arrive a few minutes late, but needs no special
      // "exact alarm" permission (which Play restricts).
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: r.kind.name,
    );
  }

  static (String, String) _text(PlannedReminder r) => switch (r.kind) {
        ReminderKind.streakRisk => (
          '🔥 Your ${r.count}-day streak ends tonight!',
          "Solve today's Daily Challenge to keep it going.",
        ),
        ReminderKind.dailyStreak => (
          '🔥 Day ${r.count + 1} of your streak',
          "Today's Daily Challenge is ready. Keep the streak alive!",
        ),
        ReminderKind.daily => (
          "🧩 Today's Daily Challenge is ready",
          'A fresh puzzle, the same one for every player. Can you set a great time?',
        ),
        ReminderKind.journey => (
          '⭐ Level ${r.count} is waiting',
          'Your Journey continues. Earn 3 stars and get closer to the next chest!',
        ),
        ReminderKind.missYou => (
          '👋 We miss you!',
          'Your puzzles are waiting. Challenge a friend or play a quick Easy game.',
        ),
      };

  /// Test builds (`--dart-define=REMINDER_TEST=true`): instead of the real
  /// plan, a reminder every 2.5 hours for the next day, cycling through
  /// every kind, to check delivery over a day. Never set for store builds.
  static const _testSchedule = bool.fromEnvironment('REMINDER_TEST');

  List<PlannedReminder> _testPlan(GameStore store) {
    final now = DateTime.now();
    const kinds = ReminderKind.values;
    return [
      for (var i = 1; i <= 10; i++)
        PlannedReminder(200 + i, now.add(Duration(minutes: 150 * i)), kinds[(i - 1) % kinds.length], count: 4),
    ];
  }

  /// Debug builds only: sends every kind of reminder, 5 seconds apart, so
  /// texts and icons can be checked without waiting days. (Long-press the
  /// reminder row in Settings.) Leave the app to see them.
  Future<void> debugPreview() async {
    await initialize();
    if (!kDebugMode || !_initialized) return;
    final now = DateTime.now();
    for (final (i, kind) in ReminderKind.values.indexed) {
      await _schedule(PlannedReminder(100 + i, now, kind, count: 4), now.add(Duration(seconds: 5 * (i + 1))));
    }
  }

  /// Turn reminders on (asking for OS permission). Returns false if the
  /// user blocked notifications, in which case reminders stay off.
  /// source: where the user opted in, for analytics ('prompt' | 'settings')
  Future<bool> enableReminders(GameStore store, {required String source}) async {
    final granted = await requestPermission();
    store.setDailyReminders(granted);
    store.markReminderPromptShown();
    await reschedule(store);
    AnalyticsService().logRemindersChanged(enabled: granted, source: source);
    return granted;
  }

  Future<void> disableReminders(GameStore store, {String source = 'settings'}) async {
    store.setDailyReminders(false);
    store.markReminderPromptShown();
    await reschedule(store);
    AnalyticsService().logRemindersChanged(enabled: false, source: source);
  }

  /// Whether the system already lets the app show notifications.
  Future<bool> hasPermission() async {
    await initialize();
    if (!_initialized) return false;
    try {
      if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        return (await ios?.checkPermissions())?.isEnabled ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    } catch (e) {
      debugPrint('NotificationService: Permission check failed - $e');
      return false;
    }
  }

  /// Ask the OS for permission. Returns true if notifications may be shown.
  Future<bool> requestPermission() async {
    await initialize();
    if (!_initialized) return false;
    try {
      if (Platform.isAndroid) {
        // Below Android 13 there's no runtime prompt: this reports whether
        // notifications are allowed for the app.
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

  /// Called after a game. From the second solved puzzle on, if reminders are
  /// on but the system still needs the player's permission, asks once with
  /// [prompt] (our own popup, true = yes) so the system dialog only appears
  /// for players who want reminders. Always refreshes the schedule.
  Future<void> maybeAskPermission(GameStore store, Future<bool> Function() prompt) async {
    if (store.won >= 2 && !store.reminderPromptShown && store.dailyRemindersEnabled) {
      if (await hasPermission()) {
        // Already allowed (e.g. Android 12 and older): nothing to ask.
        store.markReminderPromptShown();
      } else if (await prompt()) {
        await enableReminders(store, source: 'prompt');
        return;
      } else {
        // Not asked again; the Settings switch can still turn them on.
        await disableReminders(store, source: 'prompt');
        return;
      }
    }
    await reschedule(store);
  }
}
