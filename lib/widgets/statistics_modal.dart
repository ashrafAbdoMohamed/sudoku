import 'package:flutter/material.dart';

import '../game/cartoon_dialog.dart';
import '../game/ui_kit.dart';
import '../state/game_store.dart';
import '../theme/app_theme.dart';

class StatisticsModal extends StatelessWidget {
  final GameStore store;
  final AppColorScheme colors;

  const StatisticsModal({super.key, required this.store, required this.colors});

  static const _difficulties = [
    ('easy', 'Easy', Color(0xFF3FB26B)),
    ('medium', 'Medium', Color(0xFFFF9F43)),
    ('hard', 'Hard', Color(0xFFF25A6B)),
    ('expert', 'Expert', Color(0xFF8E5BEA)),
  ];

  @override
  Widget build(BuildContext context) {
    return CartoonPanel(
      title: 'STATS',
      color: const Color(0xFF1FB5A8),
      onClose: () => Navigator.pop(context),
      width: 420,
      scrollable: true,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelSection('Overview'),
          StatRow([
            StatTile(value: '${store.played}', label: 'Played', icon: const Icon(Icons.grid_on_rounded, color: Color(0xFF4D7CFE), size: 22)),
            StatTile(value: '${store.won}', label: 'Solved', icon: const GameIcon(GameIcons.trophy, size: 24)),
            StatTile(value: store.winRate, label: 'Win rate', icon: const Icon(Icons.percent_rounded, color: Color(0xFF3FB26B), size: 22)),
          ]),
          const SizedBox(height: 8),
          StatRow([
            StatTile(value: '${store.stars}', label: 'Stars', icon: const GameIcon(GameIcons.star, size: 24), color: const Color(0xFFB07A2A)),
            StatTile(value: '${store.journeyNext - 1}', label: 'Levels done', icon: const GameIcon(GameIcons.chestClosed, size: 24)),
            StatTile(value: store.formatTime(store.averageTime), label: 'Avg time', icon: const Icon(Icons.timer_rounded, color: Color(0xFF8E5BEA), size: 22)),
          ]),
          const PanelSection('Daily streak'),
          StatRow([
            StatTile(value: '${store.currentStreak}', label: 'Current', icon: const GameIcon(GameIcons.flame, size: 24), color: const Color(0xFFF25A6B)),
            StatTile(value: '${store.longestStreak}', label: 'Longest', icon: const GameIcon(GameIcons.trophy, size: 24)),
            StatTile(value: '${store.dailyBestTimes.length}', label: 'Dailies', icon: const Text('📅', style: TextStyle(fontSize: 20))),
          ]),
          const PanelSection('By difficulty'),
          for (final (id, name, color) in _difficulties) _difficultyCard(id, name, color),
          const PanelSection('More'),
          PanelRow.emoji('💎', iconColor: const Color(0xFF4D9BFE), title: 'Perfect games', subtitle: 'No mistakes', trailing: _value('${store.perfectGames}')),
          PanelRow.emoji('🧠', iconColor: const Color(0xFFE05BC4), title: 'Solved without help', trailing: _value('${store.noHintGames}')),
          PanelRow.emoji('⚡', iconColor: const Color(0xFF1FB5A8), title: 'Live races won', trailing: _value('${store.onlineWins}')),
          PanelRow.emoji('🏅', iconColor: const Color(0xFFFFC23D), title: 'Awards', trailing: _value('${store.unlockedCount}/${store.totalAchievements}')),
          PanelRow.emoji('⏱️', iconColor: const Color(0xFF8E5BEA), title: 'Total time played', trailing: _value(store.formatLongTime(store.totalPlayTime))),
        ],
      ),
    );
  }

  Widget _value(String text) => Text(text, style: const TextStyle(fontFamily: kTitleFont, fontSize: 20, color: Color(0xFF8E5BEA)));

  Widget _difficultyCard(String id, String name, Color color) {
    final stats = store.getStatsForDifficulty(id);
    final dark = Color.lerp(color, Colors.black, 0.4)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                child: OutlinedText(name.toUpperCase(), size: 15, stroke: dark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${stats.played} played · ${stats.won} solved',
                  style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF8A7A9E)),
                ),
              ),
              Text('${(stats.winRate * 100).toInt()}%', style: TextStyle(fontFamily: kTitleFont, fontSize: 20, color: dark)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stats.winRate,
              minHeight: 10,
              backgroundColor: const Color(0xFFF3EBDD),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _mini('Best', stats.fastestTime == 0 ? '--:--' : store.formatTime(stats.fastestTime)),
              _mini('Average', store.formatTime(stats.averageTime)),
              _mini('Total', store.formatTime(stats.totalTime)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) => Column(
        children: [
          Text(label, style: const TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8A7A9E))),
          Text(value, style: const TextStyle(fontFamily: kBodyFont, fontSize: 15, fontWeight: FontWeight.w700, color: CartoonPanel.ink)),
        ],
      );
}
