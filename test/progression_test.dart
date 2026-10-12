import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/models/progression.dart';
import 'package:sudoku/models/rank.dart';
import 'package:sudoku/state/game_store.dart';

void main() {
  group('rules', () {
    test('stars: 3 clean, minus one for mistakes, minus one for help', () {
      expect(starsFor(mistakes: 0, usedHelp: false), 3);
      expect(starsFor(mistakes: 2, usedHelp: false), 2);
      expect(starsFor(mistakes: 0, usedHelp: true), 2);
      expect(starsFor(mistakes: 4, usedHelp: true), 1);
    });

    test('coins grow with difficulty and stars', () {
      expect(coinsForWin('easy', 1), 15);
      expect(coinsForWin('expert', 3), 45);
      expect(coinsForWin('hard', 3), greaterThan(coinsForWin('medium', 3)));
    });

    test('journey difficulty only ramps up, finales are a step harder', () {
      const order = ['easy', 'medium', 'hard', 'expert'];
      var lastStageStart = 0;
      for (var level = 1; level <= 100; level++) {
        final d = order.indexOf(difficultyForLevel(level));
        expect(d, isNonNegative);
        if ((level - 1) % levelsPerStage == 0) {
          expect(d, greaterThanOrEqualTo(lastStageStart), reason: 'level $level');
          lastStageStart = d;
        }
      }
      expect(difficultyForLevel(1), 'easy');
      expect(difficultyForLevel(10), 'medium');
      expect(difficultyForLevel(100), 'expert');
    });

    test('ranks climb with stars', () {
      expect(rankIndexFor(0), 0);
      expect(rankIndexFor(15), 1);
      expect(rankIndexFor(99999), ranks.length - 1);
      for (var i = 1; i < ranks.length; i++) {
        expect(ranks[i].stars, greaterThan(ranks[i - 1].stars));
      }
    });
  });

  group('GameStore', () {
    Future<GameStore> fresh([Map<String, Object>? prefs]) async {
      SharedPreferences.setMockInitialValues(prefs ?? {});
      final store = GameStore();
      await store.load();
      return store;
    }

    test('a new player starts with 200 coins, no stars, level 1', () async {
      final s = await fresh();
      expect(s.coins, startingCoins);
      expect(s.stars, 0);
      expect(s.journeyNext, 1);
      expect(s.pendingRankUp, isNull);
    });

    test('existing players keep their stats and get a fair start', () async {
      final saved = jsonEncode({'played': 30, 'won': 25, 'currentStreak': 3});
      final s = await fresh({'sudoku_v2': saved});
      expect(s.won, 25);
      expect(s.coins, startingCoins + 250);
      expect(s.stars, 50);
      // Their rank counts as already celebrated.
      expect(s.pendingRankUp, isNull);
    });

    test('journey: first clear pays and unlocks, replays pay only the improvement', () async {
      final s = await fresh();
      final first = s.completeJourneyLevel(1, 2);
      expect(first.coins, coinsForWin('easy', 2));
      expect(s.journeyNext, 2);
      expect(s.stars, 2);

      final same = s.completeJourneyLevel(1, 2);
      expect(same.coins, 0);
      expect(s.stars, 2);

      final better = s.completeJourneyLevel(1, 3);
      expect(better.coins, 5);
      expect(s.stars, 3);
      expect(s.journeyNext, 2);
    });

    test('the stage finale readies its chest, which pays once', () async {
      final s = await fresh();
      for (var l = 1; l < levelsPerStage; l++) {
        expect(s.completeJourneyLevel(l, 3).chestReady, isFalse);
      }
      expect(s.openChest(0), 0); // not finished yet
      expect(s.completeJourneyLevel(levelsPerStage, 3).chestReady, isTrue);
      final before = s.coins;
      expect(s.openChest(0), chestReward);
      expect(s.coins, before + chestReward);
      expect(s.openChest(0), 0);
    });

    test('spending fails without enough coins', () async {
      final s = await fresh();
      expect(s.spend(startingCoins + 1), isFalse);
      expect(s.coins, startingCoins);
      expect(s.spend(hintCost), isTrue);
      expect(s.coins, startingCoins - hintCost);
    });

    test('a new rank is celebrated and paid once', () async {
      final s = await fresh();
      s.rewardWin('easy', 3);
      s.stars = ranks[2].stars;
      expect(s.pendingRankUp, 2);
      final before = s.coins;
      expect(s.claimRankUp(), 2 * rankUpReward);
      expect(s.coins, before + 2 * rankUpReward);
      expect(s.pendingRankUp, isNull);
      expect(s.claimRankUp(), 0);
    });

    test('progress survives a reload', () async {
      final s = await fresh();
      s.completeJourneyLevel(1, 3);
      s.completeJourneyLevel(2, 1);
      s.spend(hintCost);
      await s.save();
      final reloaded = GameStore();
      await reloaded.load();
      expect(reloaded.journeyNext, 3);
      expect(reloaded.journeyStarsFor(1), 3);
      expect(reloaded.journeyStarsFor(2), 1);
      expect(reloaded.coins, s.coins);
      expect(reloaded.stars, s.stars);
    });
  });
}
