import 'package:flutter/material.dart';

import '../game/free_coins.dart';
import '../game/fx.dart';
import '../game/home_backdrop.dart';
import '../game/ui_kit.dart';
import '../models/progression.dart';
import '../services/sound_service.dart';
import '../state/game_store.dart';

/// Picking what to play, in as few taps as possible.
///
/// Journey: the stage's ten levels in a grid that fits on one screen, its
/// chest, and a big PLAY button for the next level. Free play: one big card
/// per difficulty; a tap starts a puzzle.
class JourneyScreen extends StatefulWidget {
  final GameStore store;
  final void Function(int level) onPlayLevel;
  final void Function(String difficulty) onFreePlay;
  final bool startOnFreePlay;
  const JourneyScreen({
    super.key,
    required this.store,
    required this.onPlayLevel,
    required this.onFreePlay,
    this.startOnFreePlay = false,
  });

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  late int _stage = widget.store.journeyStage;
  late bool _freePlay = widget.startOnFreePlay;
  int _chestBursts = 0;

  GameStore get store => widget.store;

  static const _ink = Color(0xFF2B4E7A);

  void _openChest() {
    final coins = store.openChest(_stage);
    if (coins == 0) return;
    SoundService().playCoin();
    setState(() => _chestBursts++);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('+$coins coins from the Stage ${_stage + 1} chest!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: HomeBackdrop()),
          SafeArea(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      _topBar(),
                      const SizedBox(height: 10),
                      _tabs(),
                      const SizedBox(height: 14),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _freePlay ? _freePlayTab() : _journeyTab(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_chestBursts > 0) Positioned.fill(child: IgnorePointer(child: ConfettiBurst(key: ValueKey(_chestBursts), count: 90))),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          PressScale(
            child: GestureDetector(
              onTap: () {
                SoundService().playTap();
                Navigator.of(context).pop();
              },
              child: const GameIcon(GameIcons.back, size: 52, flipForRtl: true),
            ),
          ),
          const Expanded(child: Center(child: OutlinedText('PLAY', size: 32, stroke: _ink))),
          CoinPill(coins: store.coins, onAdd: () => showFreeCoins(context, store)),
        ],
      ),
    );
  }

  /// JOURNEY | FREE PLAY switch.
  Widget _tabs() {
    Widget tab(String label, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: () {
              if (selected) return;
              SoundService().playTap();
              onTap();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 46,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFF8A3D) : Colors.transparent,
                borderRadius: BorderRadius.circular(23),
                boxShadow: selected ? const [BoxShadow(color: Color(0xFFB4561A), offset: Offset(0, 4))] : null,
              ),
              alignment: Alignment.center,
              child: OutlinedText(
                label,
                size: 20,
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                stroke: selected ? const Color(0xFF9A3F00) : _ink,
              ),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF3E6FA8).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Row(
        children: [
          tab('JOURNEY', !_freePlay, () => setState(() => _freePlay = false)),
          tab('FREE PLAY', _freePlay, () => setState(() => _freePlay = true)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────── journey

  Widget _journeyTab() {
    final next = store.journeyNext;
    final onCurrentStage = stageOf(next) == _stage;
    return Padding(
      key: const ValueKey('journey'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Column(
        children: [
          _stageHeader(),
          const SizedBox(height: 14),
          _grid(),
          const SizedBox(height: 14),
          _chestCard(),
          const Spacer(),
          Breathing(
            amount: 0.03,
            child: ChunkyButton(
              color: const Color(0xFF3FB26B),
              height: 74,
              radius: 24,
              border: true,
              onTap: () {
                SoundService().playTap();
                widget.onPlayLevel(next);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedText('PLAY LEVEL $next', size: 30, stroke: const Color(0xFF1F6E3F)),
                  Text(
                    onCurrentStage
                        ? _difficultyLabel(difficultyForLevel(next))
                        : 'Stage ${stageOf(next) + 1} · ${_difficultyLabel(difficultyForLevel(next))}',
                    style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageHeader() {
    final unlockedStages = store.journeyStage;
    final done = List.generate(levelsPerStage, (i) => _stage * levelsPerStage + i + 1).where(store.isJourneyCleared).length;
    Widget arrow(IconData icon, bool enabled, int delta) => Opacity(
          opacity: enabled ? 1 : 0.3,
          child: PressScale(
            child: GestureDetector(
              onTap: enabled
                  ? () {
                      SoundService().playTap();
                      setState(() => _stage += delta);
                    }
                  : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF3E6FA8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
            ),
          ),
        );
    return Row(
      children: [
        arrow(Icons.chevron_left_rounded, _stage > 0, -1),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              OutlinedText('STAGE ${_stage + 1}', size: 26, stroke: const Color(0xFF3D2B7A)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: done / levelsPerStage,
                    child: Container(color: const Color(0xFFFFC23D)),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$done/$levelsPerStage levels',
                style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 13, color: _ink),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        arrow(Icons.chevron_right_rounded, _stage < unlockedStages, 1),
      ],
    );
  }

  /// The stage's ten levels, five to a row.
  Widget _grid() {
    final first = _stage * levelsPerStage + 1;
    Widget row(int from) => Row(
          children: [
            for (var l = from; l < from + 5; l++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _LevelTile(
                    level: l,
                    stars: store.journeyStarsFor(l),
                    cleared: store.isJourneyCleared(l),
                    current: l == store.journeyNext,
                    finale: isStageFinale(l),
                    onTap: () {
                      SoundService().playTap();
                      widget.onPlayLevel(l);
                    },
                  ),
                ),
              ),
          ],
        );
    return Column(children: [row(first), row(first + 5)]);
  }

  Widget _chestCard() {
    final opened = store.journeyChests.contains(_stage);
    final ready = store.isStageComplete(_stage) && !opened;
    Widget chest = GameIcon(opened ? GameIcons.chestOpen : GameIcons.chestClosed, size: 58, greyed: !ready && !opened);
    if (ready) chest = Breathing(amount: 0.1, child: chest);
    final text = opened
        ? 'Chest collected!'
        : ready
            ? 'Tap to open your chest!'
            : 'Finish all 10 levels to open';
    return GestureDetector(
      onTap: ready ? _openChest : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
        decoration: BoxDecoration(
          color: ready ? const Color(0xFFFFE9B0) : Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ready ? const Color(0xFFFFC23D) : Colors.white, width: 3),
        ),
        child: Row(
          children: [
            chest,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STAGE CHEST', style: TextStyle(fontFamily: kTitleFont, fontSize: 18, color: Color(0xFF9A4A00))),
                  Text(text, style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 14, color: _ink)),
                ],
              ),
            ),
            if (!opened) ...[
              const GameIcon(GameIcons.coin, size: 24),
              const SizedBox(width: 3),
              Text('$chestReward', style: const TextStyle(fontFamily: kTitleFont, fontSize: 20, color: Color(0xFF9A4A00))),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────── free play

  static String _difficultyLabel(String d) => d[0].toUpperCase() + d.substring(1);

  Widget _freePlayTab() {
    const diffs = [
      ('easy', 'EASY', 'Relaxed · lots of numbers given', Color(0xFF3FB26B), Color(0xFF1F6E3F)),
      ('medium', 'MEDIUM', 'A bit of thinking', Color(0xFFFF9F43), Color(0xFF9A4A00)),
      ('hard', 'HARD', 'For sharp minds', Color(0xFFF25A6B), Color(0xFF9A2B2B)),
      ('expert', 'EXPERT', 'The real deal', Color(0xFF8E5BEA), Color(0xFF4A2896)),
    ];
    return ListView(
      key: const ValueKey('free'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      children: [
        const Center(
          child: Text(
            'A brand-new puzzle every time. Tap to start!',
            style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 15, color: _ink),
          ),
        ),
        const SizedBox(height: 12),
        for (final (id, label, blurb, color, ink) in diffs) ...[
          ChunkyButton(
            color: color,
            height: 84,
            radius: 24,
            border: true,
            onTap: () {
              SoundService().playTap();
              widget.onFreePlay(id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedText(label, size: 28, stroke: ink),
                        Text(
                          '$blurb\n${_best(id)}',
                          style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: ink, offset: const Offset(0, 3))],
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: color, size: 34),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _best(String diff) {
    final t = store.bestTimes[diff];
    if (t == null) return 'No best time yet';
    return 'Best ${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
  }
}

/// One level in the grid: its number and stars, a lock if not reached yet,
/// pulsing if it is the next one to play.
class _LevelTile extends StatelessWidget {
  final int level;
  final int stars;
  final bool cleared;
  final bool current;
  final bool finale;
  final VoidCallback onTap;
  const _LevelTile({
    required this.level,
    required this.stars,
    required this.cleared,
    required this.current,
    required this.finale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = !cleared && !current;
    final color = current
        ? const Color(0xFFFF8A3D)
        : cleared
            ? const Color(0xFF4D7CFE)
            : const Color(0xFFB0B7C9);
    final dark = Color.lerp(color, Colors.black, 0.4)!;
    Widget tile = AspectRatio(
      aspectRatio: 0.82,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.3)!, color],
          ),
          border: Border.all(color: finale && !locked ? const Color(0xFFFFC23D) : Colors.white, width: 3),
          boxShadow: [BoxShadow(color: dark, offset: const Offset(0, 5))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              const GameIcon(GameIcons.lock, size: 30)
            else
              FittedBox(child: OutlinedText('$level', size: 28, stroke: Color.lerp(color, Colors.black, 0.5)!)),
            const SizedBox(height: 4),
            if (cleared)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [for (var i = 0; i < 3; i++) GameIcon(GameIcons.star, size: 14, greyed: i >= stars)],
              )
            else if (current)
              const Text('PLAY', style: TextStyle(fontFamily: kTitleFont, fontSize: 13, color: Colors.white))
            else
              Text('$level', style: TextStyle(fontFamily: kTitleFont, fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
    if (current) tile = Breathing(amount: 0.06, child: tile);
    return PressScale(child: GestureDetector(onTap: locked ? null : onTap, child: tile));
  }
}
