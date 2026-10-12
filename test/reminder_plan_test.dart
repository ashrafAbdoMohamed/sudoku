import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/services/reminder_plan.dart';

void main() {
  List<PlannedReminder> plan({
    DateTime? now,
    bool dailyDoneToday = false,
    int streak = 0,
    bool canKeepStreak = true,
    int journeyNext = 5,
    int? playHour,
  }) =>
      planReminders(
        now: now ?? DateTime(2026, 10, 13, 10),
        dailyDoneToday: dailyDoneToday,
        streak: streak,
        canKeepStreak: canKeepStreak,
        journeyNext: journeyNext,
        playHour: playHour,
      );

  test('a new player gets tomorrow, day 3 and day 7, then nothing', () {
    final p = plan();
    expect(p.map((r) => r.kind), [ReminderKind.daily, ReminderKind.journey, ReminderKind.missYou]);
    expect(p.map((r) => r.at.day), [14, 16, 20]);
    expect(p.every((r) => r.at.hour == defaultReminderHour), isTrue);
  });

  test('at most one reminder per day', () {
    final p = plan(streak: 5);
    final days = p.map((r) => DateTime(r.at.year, r.at.month, r.at.day)).toList();
    expect(days.toSet().length, days.length);
  });

  test('a streak at risk gets a warning tonight at 20:00', () {
    final p = plan(streak: 4);
    expect(p.first.kind, ReminderKind.streakRisk);
    expect(p.first.count, 4);
    expect(p.first.at, DateTime(2026, 10, 13, 20));
  });

  test('no warning once today is done, or for a lost or tiny streak', () {
    expect(plan(streak: 4, dailyDoneToday: true).any((r) => r.kind == ReminderKind.streakRisk), isFalse);
    expect(plan(streak: 4, canKeepStreak: false).any((r) => r.kind == ReminderKind.streakRisk), isFalse);
    expect(plan(streak: 1).any((r) => r.kind == ReminderKind.streakRisk), isFalse);
  });

  test('tomorrow mentions the streak when today is done', () {
    final p = plan(streak: 3, dailyDoneToday: true);
    expect(p.first.kind, ReminderKind.dailyStreak);
    expect(p.first.count, 3);
  });

  test('the journey reminder names the next level', () {
    final r = plan(journeyNext: 27).firstWhere((r) => r.kind == ReminderKind.journey);
    expect(r.count, 27);
  });

  test("reminders follow the player's usual hour, kept to 9:00-21:00", () {
    expect(plan(playHour: 8).first.at.hour, 9);
    expect(plan(playHour: 13).first.at.hour, 13);
    expect(plan(playHour: 23).first.at.hour, 21);
  });

  test('nothing already due is scheduled', () {
    final late = plan(now: DateTime(2026, 10, 13, 22), streak: 4);
    expect(late.any((r) => r.kind == ReminderKind.streakRisk), isFalse);
    expect(late.every((r) => r.at.isAfter(DateTime(2026, 10, 13, 22))), isTrue);
  });
}
