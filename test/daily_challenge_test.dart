import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/utils/daily_challenge.dart';

void main() {
  test('daily difficulty rotates by UTC day of year, independent of timezone', () {
    // 2026-10-24 is day 296 of the year (0-based), 296 % 4 = 0 -> easy.
    expect(DailyChallenge.difficultyFromDate('2026-10-24'), 'easy');
    expect(DailyChallenge.difficultyFromDate('2026-10-25'), 'medium');
    expect(DailyChallenge.difficultyFromDate('2026-01-01'), 'easy');
  });
}
