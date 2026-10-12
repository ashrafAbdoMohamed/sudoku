import 'package:flutter/material.dart';

/// A player rank, earned by total stars.
class Rank {
  /// Shown white, then [noun] in gold on the rank badge.
  final String adjective;
  final String noun;

  /// The rank's character art (transparent PNG).
  final String image;
  final Color color;

  /// Total stars needed to reach this rank.
  final int stars;

  const Rank(this.adjective, this.noun, this.image, this.color, this.stars);

  String get title => '$adjective $noun';
}

/// The 14 ranks, lowest first. Art is temporary (Word Search's characters)
/// until Sudoku's own set is made.
const ranks = [
  Rank('Number', 'Rookie', 'assets/ranks/rank_01.png', Color(0xFF7CB342), 0),
  Rank('Grid', 'Explorer', 'assets/ranks/rank_02.png', Color(0xFFFFA000), 15),
  Rank('Digit', 'Seeker', 'assets/ranks/rank_03.png', Color(0xFF26A69A), 40),
  Rank('Number', 'Sprout', 'assets/ranks/rank_04.png', Color(0xFF8BC34A), 80),
  Rank('Puzzle', 'Pupil', 'assets/ranks/rank_05.png', Color(0xFF43A047), 140),
  Rank('Box', 'Hunter', 'assets/ranks/rank_06.png', Color(0xFFF4511E), 220),
  Rank('Pattern', 'Spotter', 'assets/ranks/rank_07.png', Color(0xFF039BE5), 330),
  Rank('Logic', 'Ace', 'assets/ranks/rank_08.png', Color(0xFF8D6E63), 470),
  Rank('Grid', 'Guru', 'assets/ranks/rank_09.png', Color(0xFF5E35B1), 650),
  Rank('Sudoku', 'Master', 'assets/ranks/rank_10.png', Color(0xFF546E7A), 900),
  Rank('Number', 'Wizard', 'assets/ranks/rank_11.png', Color(0xFFAB47BC), 1250),
  Rank('Logic', 'Legend', 'assets/ranks/rank_12.png', Color(0xFFC2185B), 1700),
  Rank('Grand', 'Solver', 'assets/ranks/rank_13.png', Color(0xFF283593), 2300),
  Rank('Sudoku', 'Emperor', 'assets/ranks/rank_14.png', Color(0xFFD32F2F), 3000),
];

/// Index into [ranks] for a star total.
int rankIndexFor(int stars) {
  var i = 0;
  while (i + 1 < ranks.length && stars >= ranks[i + 1].stars) {
    i++;
  }
  return i;
}
