/// What a reminder is about. Each kind has its own text (see
/// NotificationService).
enum ReminderKind {
  /// Today's daily isn't solved yet and a 2+ day streak ends tonight.
  streakRisk,

  /// Tomorrow continues a streak: today's daily is solved.
  dailyStreak,

  /// Tomorrow's daily puzzle is ready (no streak to talk about).
  daily,

  /// Three days away: their next Journey level is waiting.
  journey,

  /// A week away: the last reminder until they come back.
  missYou,
}

class PlannedReminder {
  /// Stable per kind of slot, so rescheduling replaces rather than adds.
  final int id;
  final DateTime at;
  final ReminderKind kind;

  /// The streak length or level number the text mentions.
  final int count;

  const PlannedReminder(this.id, this.at, this.kind, {this.count = 0});

  @override
  String toString() => '$kind@$at($count)';
}

/// Reminder slots: at most one per day.
const _riskId = 1, _tomorrowId = 2, _journeyId = 3, _missYouId = 4;

/// The hour reminders go out when the player's usual hour is unknown.
const defaultReminderHour = 19;

/// Plans the reminders to schedule from now.
///
/// Rules: at most one per day, at the player's usual play hour (kept
/// between 9:00 and 21:00); the streak warning goes out at 20:00. After the
/// one-week reminder nothing more is planned until the player comes back,
/// so someone who stopped playing gets at most four reminders in total.
List<PlannedReminder> planReminders({
  required DateTime now,
  required bool dailyDoneToday,
  required int streak,
  required bool canKeepStreak,
  required int journeyNext,
  int? playHour,
}) {
  final hour = (playHour ?? defaultReminderHour).clamp(9, 21);
  DateTime day(int offset, [int? atHour]) => DateTime(now.year, now.month, now.day + offset, atHour ?? hour);

  final plan = <PlannedReminder>[];

  // Tonight: a real streak ends unless today's daily gets solved.
  if (!dailyDoneToday && canKeepStreak && streak >= 2) {
    plan.add(PlannedReminder(_riskId, day(0, 20), ReminderKind.streakRisk, count: streak));
  }

  // Tomorrow: the next daily, mentioning the streak if there is one.
  if (dailyDoneToday && streak >= 1) {
    plan.add(PlannedReminder(_tomorrowId, day(1), ReminderKind.dailyStreak, count: streak));
  } else {
    plan.add(PlannedReminder(_tomorrowId, day(1), ReminderKind.daily));
  }

  plan.add(PlannedReminder(_journeyId, day(3), ReminderKind.journey, count: journeyNext));
  plan.add(PlannedReminder(_missYouId, day(7), ReminderKind.missYou));

  // Never schedule something that's already due (e.g. opened after 20:00).
  final soon = now.add(const Duration(minutes: 1));
  return [for (final r in plan) if (r.at.isAfter(soon)) r];
}
