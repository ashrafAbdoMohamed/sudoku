import 'package:flutter/material.dart';

import '../models/progression.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import '../state/game_store.dart';
import 'fx.dart';
import 'ui_kit.dart';

/// "Watch a short video for free coins". [title] says why it opened, e.g.
/// "Not enough coins".
Future<void> showFreeCoins(BuildContext context, GameStore store, {String title = 'FREE COINS'}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, _, _) => _FreeCoinsDialog(store: store, title: title),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
  );
}

class _FreeCoinsDialog extends StatefulWidget {
  final GameStore store;
  final String title;
  const _FreeCoinsDialog({required this.store, required this.title});

  @override
  State<_FreeCoinsDialog> createState() => _FreeCoinsDialogState();
}

class _FreeCoinsDialogState extends State<_FreeCoinsDialog> {
  bool _earned = false;

  Future<void> _watch() async {
    SoundService().playTap();
    final shown = await AdService().showRewardedAd(
      // The reward callback is the reliable signal that the video was
      // watched (showRewardedAd returns before the player finishes).
      onUserEarnedReward: () {
        if (!mounted) return;
        widget.store.addCoins(adReward);
        SoundService().playCoin();
        setState(() => _earned = true);
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) Navigator.of(context).pop();
        });
      },
    );
    if (!shown && !_earned && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('No video right now. Check your connection and try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = AdService().isRewardedAdReady;
    return Stack(
      children: [
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFC23D), Color(0xFFF08A1C)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedText(widget.title, size: 28, stroke: const Color(0xFF9A4A00)),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 84,
                    width: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(left: 14, bottom: 4, child: Transform.rotate(angle: -0.3, child: const GameIcon(GameIcons.coin, size: 46))),
                        Positioned(right: 14, bottom: 4, child: Transform.rotate(angle: 0.3, child: const GameIcon(GameIcons.coin, size: 46))),
                        Bump(trigger: _earned, amount: 0.4, child: const GameIcon(GameIcons.coin, size: 70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedText('+$adReward', size: 38, stroke: const Color(0xFF9A4A00)),
                  const SizedBox(height: 4),
                  Text(
                    _earned ? 'Enjoy!' : 'Watch a short video to get them',
                    style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  if (!_earned)
                    ChunkyButton(
                      color: ready ? const Color(0xFF3FB26B) : const Color(0xFF9E9E9E),
                      height: 56,
                      onTap: ready ? _watch : null,
                      child: OutlinedText(
                        ready ? 'WATCH VIDEO' : 'NO VIDEO YET',
                        size: 22,
                        stroke: ready ? const Color(0xFF1F6E3F) : const Color(0xFF5E5E5E),
                      ),
                    ),
                  if (!_earned)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'No thanks',
                        style: TextStyle(fontFamily: kBodyFont, color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_earned) const Positioned.fill(child: IgnorePointer(child: ConfettiBurst(count: 80))),
      ],
    );
  }
}
