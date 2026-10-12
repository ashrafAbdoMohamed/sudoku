import 'package:flutter/material.dart';

import '../game/cartoon_dialog.dart';
import '../game/fx.dart';
import '../game/ui_kit.dart';
import '../theme/app_theme.dart';

class RateAppDialog extends StatelessWidget {
  final AppColorScheme colors;
  final VoidCallback onRate;
  final VoidCallback onLater;
  final VoidCallback onNever;

  const RateAppDialog({
    super.key,
    required this.colors,
    required this.onRate,
    required this.onLater,
    required this.onNever,
  });

  @override
  Widget build(BuildContext context) {
    return CartoonPanel(
      title: 'ENJOYING IT?',
      color: const Color(0xFFFFB020),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                Entrance(
                  delay: Duration(milliseconds: 120 * i),
                  from: const Offset(0, 0.6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GameIcon(GameIcons.star, size: i == 2 ? 50 : 40),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const PanelText('A flawless solve! If you like the game, a quick rating really helps us.'),
          const SizedBox(height: 18),
          CartoonButton(label: 'RATE 5 STARS', onTap: onRate),
          const SizedBox(height: 4),
          CartoonButton.secondary(label: 'MAYBE LATER', onTap: onLater),
          TextButton(
            onPressed: onNever,
            child: const Text(
              "Don't ask again",
              style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF8A7A9E)),
            ),
          ),
        ],
      ),
    );
  }
}
