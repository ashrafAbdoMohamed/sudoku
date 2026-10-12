import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/rank.dart';
import '../services/sound_service.dart';
import '../state/game_store.dart';
import 'cartoon_dialog.dart';
import 'fx.dart';
import 'rank_badge.dart';
import 'ui_kit.dart';

/// Celebrates a new rank if one is waiting, and pays its bonus. Safe to call
/// whenever; does nothing if there is no new rank.
Future<void> maybeShowRankUp(BuildContext context, GameStore store) async {
  final index = store.pendingRankUp;
  if (index == null) return;
  final reward = store.claimRankUp();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, _, _) => _RankUp(index: index, reward: reward),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _RankUp extends StatefulWidget {
  final int index;
  final int reward;
  const _RankUp({required this.index, required this.reward});

  @override
  State<_RankUp> createState() => _RankUpState();
}

class _RankUpState extends State<_RankUp> with SingleTickerProviderStateMixin {
  static const _seconds = 2.2;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_seconds * 1000).round()),
  )..forward();
  bool _confetti = false;

  @override
  void initState() {
    super.initState();
    SoundService().playAchievement();
    // The medal lands: boom, confetti.
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      SoundService().playWin();
      setState(() => _confetti = true);
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) SoundService().playCoin();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double start, double end, [Curve curve = Curves.linear]) {
    final s = _c.value * _seconds;
    return curve.transform(((s - start) / (end - start)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final rank = ranks[widget.index];
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final heading = _seg(0, 0.45, Curves.easeOutBack);
          final medal = _seg(0.25, 0.9, Curves.elasticOut);
          final spin = (1 - _seg(0.25, 0.75, Curves.easeOut)) * 2 * pi;
          final ribbon = _seg(0.6, 1.0, Curves.easeOutBack);
          final pop = _seg(0.55, 1.05, Curves.elasticOut);
          final title = _seg(0.85, 1.25, Curves.easeOutBack);
          final bottom = _seg(1.3, 1.8, Curves.easeOutBack);

          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: _seg(0.5, 1.0),
                  child: SunRays(color: rank.color),
                ),
              ),
              if (_confetti)
                const Positioned.fill(
                  child: IgnorePointer(child: ConfettiBurst()),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: heading,
                    child: Text(
                      'RANK UP!',
                      style: TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 44,
                        fontFamily: kTitleFont,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(
                            color: Color(0xFF8A5F17),
                            offset: Offset(0, 4),
                          ),
                          Shadow(color: Color(0x99000000), blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 340,
                    height: 190,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 52,
                          height: 110,
                          child: Opacity(
                            opacity: ribbon.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scaleX: ribbon,
                              child: const RankRibbon(),
                            ),
                          ),
                        ),
                        Transform.rotate(
                          angle: spin,
                          child: Transform.scale(
                            scale: medal,
                            child: Medallion(
                              rank: rank,
                              number: widget.index + 1,
                              size: 160,
                              animated: true,
                              characterScale: 0.3 + 0.7 * pop,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: title.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - title)),
                      child: Column(
                        children: [
                          Text(
                            'You are now',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RankTitle(rank: rank, size: 28),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Opacity(
                    opacity: bottom.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * bottom,
                      child: Column(
                        children: [
                          if (widget.reward > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '+${widget.reward}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontFamily: kTitleFont,
                                              ),
                                ),
                                const SizedBox(width: 8),
                                const GameIcon(GameIcons.coin, size: 32),
                              ],
                            ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: 230,
                            child: CartoonButton(
                              label: 'AWESOME!',
                              onTap: bottom < 1 ? null : () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
