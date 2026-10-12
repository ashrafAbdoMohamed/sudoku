import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ad_service.dart';
import '../services/sound_service.dart';
import '../state/game_store.dart';
import 'cartoon_dialog.dart';
import 'fx.dart';
import 'ui_kit.dart';

/// The puzzle-solved celebration: rays, confetti, stars popping in one by
/// one, the time and mistakes, and the coin reward counting up (with an
/// optional "watch a video to double it").
///
/// Pops with true for [actionLabel], false for [secondaryLabel].
Future<bool?> showWinOverlay(
  BuildContext context, {
  required GameStore store,
  required String title,
  required String subtitle,
  required int stars,
  required int reward,
  required String time,
  required int mistakes,
  required String actionLabel,
  String? secondaryLabel = 'HOME',
  Widget? extra,
  VoidCallback? onShare,
  bool offerDouble = true,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (context, _, _) => _WinOverlay(
      store: store,
      title: title,
      subtitle: subtitle,
      stars: stars,
      reward: reward,
      time: time,
      mistakes: mistakes,
      actionLabel: actionLabel,
      secondaryLabel: secondaryLabel,
      extra: extra,
      onShare: onShare,
      offerDouble: offerDouble && reward > 0 && AdService().isRewardedAdReady,
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
  );
}

class _WinOverlay extends StatefulWidget {
  final GameStore store;
  final String title;
  final String subtitle;
  final int stars;
  final int reward;
  final String time;
  final int mistakes;
  final String actionLabel;
  final String? secondaryLabel;
  final Widget? extra;
  final VoidCallback? onShare;
  final bool offerDouble;
  const _WinOverlay({
    required this.store,
    required this.title,
    required this.subtitle,
    required this.stars,
    required this.reward,
    required this.time,
    required this.mistakes,
    required this.actionLabel,
    required this.secondaryLabel,
    required this.extra,
    required this.onShare,
    required this.offerDouble,
  });

  @override
  State<_WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<_WinOverlay> with SingleTickerProviderStateMixin {
  static const _seconds = 2.2;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_seconds * 1000).round()),
  )..forward();

  bool _doubled = false;
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.stars; i++) {
      Future.delayed(Duration(milliseconds: 520 + i * 260), () {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        SoundService().playStar(i + 1);
      });
    }
    if (widget.reward > 0) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) SoundService().playCoin();
      });
    }
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

  Future<void> _double() async {
    SoundService().playTap();
    setState(() => _watching = true);
    final shown = await AdService().showRewardedAd(
      onUserEarnedReward: () {
        widget.store.addCoins(widget.reward);
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        SoundService().playCoin();
        setState(() => _doubled = true);
      },
    );
    if (mounted) setState(() => _watching = false);
    if (!shown && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No video right now. Try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: IgnorePointer(child: SunRays(color: Color(0xFFFFE27A)))),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CartoonPanel(
            title: widget.title,
            color: const Color(0xFF3FB26B),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _starsRow(),
                Opacity(
                  opacity: _seg(1.1, 1.4),
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * _seg(1.1, 1.5, Curves.elasticOut),
                    child: OutlinedText(_cheer(widget.stars), size: 30, color: const Color(0xFFFFC23D), stroke: const Color(0xFF9A4A00)),
                  ),
                ),
                const SizedBox(height: 2),
                Opacity(opacity: _seg(1.2, 1.5), child: PanelText(widget.subtitle, size: 15)),
                const SizedBox(height: 12),
                Opacity(
                  opacity: _seg(1.2, 1.5),
                  child: StatRow([
                    StatTile(value: widget.time, label: 'Time', icon: const Icon(Icons.timer_rounded, color: Color(0xFF4D7CFE), size: 22)),
                    StatTile(
                      value: '${widget.mistakes}',
                      label: widget.mistakes == 1 ? 'Mistake' : 'Mistakes',
                      icon: const Icon(Icons.favorite_rounded, color: Color(0xFFF25A6B), size: 22),
                    ),
                  ]),
                ),
                if (widget.extra != null) ...[
                  const SizedBox(height: 10),
                  Opacity(opacity: _seg(1.3, 1.6), child: widget.extra!),
                ],
                const SizedBox(height: 14),
                Opacity(opacity: _seg(1.4, 1.6), child: _reward()),
                const SizedBox(height: 14),
                Opacity(
                  opacity: _seg(1.8, 2.1),
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - _seg(1.8, 2.2, Curves.easeOutBack))),
                    child: IgnorePointer(ignoring: _c.value < 0.85, child: _buttons()),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned.fill(child: IgnorePointer(child: ConfettiBurst())),
      ],
    );
  }

  static String _cheer(int stars) => switch (stars) {
        3 => 'PERFECT!',
        2 => 'GREAT JOB!',
        _ => 'SOLVED!',
      };

  Widget _starsRow() {
    Widget star(int i, double size, double lift) {
      final t = _seg(0.35 + i * 0.26, 0.85 + i * 0.26, Curves.elasticOut);
      return Transform.translate(
        offset: Offset(0, -lift),
        child: Transform.rotate(
          angle: (1 - t) * -0.8,
          child: Transform.scale(scale: t, child: GameIcon(GameIcons.star, size: size, greyed: i >= widget.stars)),
        ),
      );
    }

    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [star(0, 54, 0), star(1, 76, 10), star(2, 54, 0)],
      ),
    );
  }

  Widget _reward() {
    if (widget.reward == 0) {
      return const PanelText('Beat your best stars to earn coins', size: 14);
    }
    const style = TextStyle(fontFamily: kTitleFont, fontSize: 30, color: Color(0xFF2E9E35));
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _doubled
                ? Bump(
                    trigger: _doubled,
                    amount: 0.4,
                    child: AnimatedCount(value: widget.reward * 2, from: widget.reward, prefix: '+', style: style),
                  )
                : Text('+${(widget.reward * _seg(1.5, 2.1, Curves.easeOutCubic)).round()}', style: style),
            const SizedBox(width: 8),
            Transform.rotate(angle: _seg(1.5, 2.1) * 2 * pi, child: const GameIcon(GameIcons.coin, size: 34)),
          ],
        ),
        if (widget.offerDouble && !_doubled) ...[
          const SizedBox(height: 8),
          CartoonButton(
            label: _watching ? 'LOADING...' : 'DOUBLE IT',
            color: const Color(0xFFFF9F43),
            height: 48,
            size: 19,
            icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 24),
            onTap: _watching ? null : _double,
          ),
        ],
        if (_doubled) const Padding(padding: EdgeInsets.only(top: 6), child: OutlinedText('COINS DOUBLED!', size: 17, color: Color(0xFF7CE08A), stroke: Color(0xFF1F6E3F))),
      ],
    );
  }

  Widget _buttons() {
    return Column(
      children: [
        Breathing(
          amount: 0.03,
          child: CartoonButton(label: widget.actionLabel, onTap: () => Navigator.of(context).pop(true)),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (widget.secondaryLabel != null)
              Expanded(
                child: CartoonButton.secondary(
                  label: widget.secondaryLabel!,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ),
            if (widget.secondaryLabel != null && widget.onShare != null) const SizedBox(width: 8),
            if (widget.onShare != null)
              Expanded(
                child: CartoonButton(
                  label: 'SHARE',
                  color: const Color(0xFF4D7CFE),
                  height: 50,
                  size: 19,
                  icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  onTap: widget.onShare,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
