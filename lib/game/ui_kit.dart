import 'package:flutter/material.dart';

import 'fx.dart';

// Building blocks of the cartoon look (ported from Word Search): fonts, the
// chunky 3D button, outlined title text, icon art and the top-bar pills.

/// Luckiest Guy: titles, buttons and numbers. Fredoka: body text.
const kTitleFont = 'LuckiestGuy';
const kBodyFont = 'Fredoka';

/// The game's icon art: glossy 3D PNGs (Canva), transparent backgrounds.
abstract final class GameIcons {
  static const coin = 'assets/icons/coin.png';
  static const star = 'assets/icons/star.png';
  static const hint = 'assets/icons/hint.png';
  static const wand = 'assets/icons/wand.png';
  static const flame = 'assets/icons/flame.png';
  static const trophy = 'assets/icons/trophy.png';
  static const chestClosed = 'assets/icons/chest_closed.png';
  static const chestOpen = 'assets/icons/chest_open.png';
  static const gift = 'assets/icons/gift.png';
  static const back = 'assets/icons/back.png';
  static const lock = 'assets/icons/lock.png';
  static const soundOn = 'assets/icons/sound_on.png';
  static const soundOff = 'assets/icons/sound_off.png';

  static const all = [
    coin, star, hint, wand, flame, trophy, chestClosed, chestOpen, gift, //
    back, lock, soundOn, soundOff,
  ];
}

/// One icon from [GameIcons]. [greyed] shows it washed out (not earned yet).
class GameIcon extends StatelessWidget {
  final String asset;
  final double size;
  final bool greyed;
  final bool flipForRtl;
  const GameIcon(this.asset, {super.key, this.size = 24, this.greyed = false, this.flipForRtl = false});

  static const _grey = ColorFilter.matrix([
    0.3, 0.45, 0.1, 0, 30, //
    0.3, 0.45, 0.1, 0, 30,
    0.3, 0.45, 0.1, 0, 30,
    0, 0, 0, 0.55, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(asset, width: size, height: size, filterQuality: FilterQuality.medium);
    if (flipForRtl && Directionality.of(context) == TextDirection.rtl) {
      image = Transform.flip(flipX: true, child: image);
    }
    return greyed ? ColorFiltered(colorFilter: _grey, child: image) : image;
  }
}

/// Luckiest Guy text with a thick dark outline, the cartoon title style.
class OutlinedText extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final Color stroke;
  final double strokeWidth;
  final TextAlign align;
  const OutlinedText(
    this.text, {
    super.key,
    required this.size,
    this.color = Colors.white,
    this.stroke = const Color(0xFF2B2B5A),
    double? strokeWidth,
    this.align = TextAlign.center,
  }) : strokeWidth = strokeWidth ?? size * 0.16;

  @override
  Widget build(BuildContext context) {
    TextStyle style([Paint? fg]) => TextStyle(
      fontFamily: kTitleFont,
      fontSize: size,
      height: 1.1,
      letterSpacing: 0.5,
      color: fg == null ? color : null,
      foreground: fg,
    );
    return Stack(
      children: [
        Text(
          text,
          textAlign: align,
          style: style(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(text, textAlign: align, style: style()),
      ],
    );
  }
}

/// A big glossy 3D button: a darker base underneath that the face sinks
/// into while pressed, a soft top highlight and a thin light rim. A pill by
/// default; pass [radius] for a rounded rectangle.
class ChunkyButton extends StatefulWidget {
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final double height;
  final double? radius;
  final double depth;
  final bool border;
  const ChunkyButton({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
    this.height = 68,
    this.radius,
    this.depth = 7,
    this.border = false,
  });

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap != null && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final depth = widget.depth;
    final radius = BorderRadius.circular(widget.radius ?? widget.height / 2);
    final sink = _down ? depth - 2 : 0.0;

    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: SizedBox(
        height: widget.height + depth,
        child: Stack(
          children: [
            Positioned.fill(
              top: depth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(color, Colors.black, 0.35),
                  borderRadius: radius,
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 4))],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              left: 0,
              right: 0,
              top: sink,
              height: widget.height,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(color, Colors.white, 0.28)!,
                      color,
                      Color.lerp(color, Colors.black, 0.08)!,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                  border: Border.all(
                    color: widget.border ? Colors.white : Color.lerp(color, Colors.white, 0.45)!,
                    width: widget.border ? 3 : 2,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: widget.height * 0.3,
                      right: widget.height * 0.3,
                      top: 4,
                      height: widget.height * 0.26,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(widget.height),
                        ),
                      ),
                    ),
                    Center(child: widget.child),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The coin counter in the top bar, with an optional "+" (get more).
class CoinPill extends StatelessWidget {
  final int coins;
  final VoidCallback? onAdd;
  final Color background;
  const CoinPill({super.key, required this.coins, this.onAdd, this.background = const Color(0xFF3E6FA8)});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: EdgeInsetsDirectional.only(start: 12, end: onAdd == null ? 12 : 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(21)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Bump(
            trigger: coins,
            amount: 0.25,
            child: Text(
              _format(coins),
              style: const TextStyle(fontFamily: kTitleFont, fontSize: 19, color: Colors.white, height: 1.25),
            ),
          ),
          const SizedBox(width: 6),
          const GameIcon(GameIcons.coin, size: 28),
          if (onAdd != null) ...[
            const SizedBox(width: 6),
            PressScale(
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF36B37E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _format(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }
}

/// The streak counter (flame + days).
class StreakPill extends StatelessWidget {
  final int days;
  final VoidCallback? onTap;
  final Color background;
  const StreakPill({super.key, required this.days, this.onTap, this.background = const Color(0xFF3E6FA8)});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsetsDirectional.only(start: 6, end: 14),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(21)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameIcon(GameIcons.flame, size: 30),
            const SizedBox(width: 2),
            Text(
              '$days',
              style: const TextStyle(fontFamily: kTitleFont, fontSize: 19, color: Colors.white, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
