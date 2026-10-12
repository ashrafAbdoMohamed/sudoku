import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// Which part of the app icon to draw.
enum LogoLayer {
  /// The finished icon: backdrop and tiles.
  full,

  /// Android adaptive-icon background: just the backdrop.
  background,

  /// Android adaptive-icon foreground: the tiles shrunk into the safe zone
  /// on a transparent canvas.
  foreground,

  /// Android 13 themed icon: the tiles as one flat colour (digits cut out).
  monochrome,
}

/// The app icon art: a 3×3 box of glossy rainbow number tiles, like the
/// splash screen, on the mint-to-teal game backdrop.
class AppLogo extends StatelessWidget {
  final double size;
  final LogoLayer layer;
  const AppLogo({super.key, required this.size, this.layer = LogoLayer.full});

  static const top = Color(0xFF5EDDC4);
  static const bottom = Color(0xFF1E9AB0);

  static const _numbers = [5, 3, 7, 6, 1, 9, 8, 4, 2];
  static const _colors = [
    Color(0xFFF25A6B),
    Color(0xFFFF9F43),
    Color(0xFFF5C02B),
    Color(0xFF3FB26B),
    Color(0xFF8E5BEA),
    Color(0xFF4D9BFE),
    Color(0xFF4D7CFE),
    Color(0xFFE05BC4),
    Color(0xFF1FB5A8),
  ];

  @override
  Widget build(BuildContext context) {
    final showBackdrop = layer == LogoLayer.full || layer == LogoLayer.background;
    final showTiles = layer != LogoLayer.background;
    // Adaptive icons crop to roughly the middle two thirds.
    final tilesScale = layer == LogoLayer.full ? 0.84 : 0.62;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          if (showBackdrop) Positioned.fill(child: _backdrop()),
          if (showTiles)
            Center(
              child: SizedBox.square(
                dimension: size * tilesScale,
                child: _tiles(size * tilesScale, mono: layer == LogoLayer.monochrome),
              ),
            ),
        ],
      ),
    );
  }

  Widget _backdrop() {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.35),
                radius: 0.75,
                colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tiles(double box, {required bool mono}) {
    final gap = box * 0.045;
    final tile = (box - gap * 2) / 3;
    return Stack(
      children: [
        for (var i = 0; i < 9; i++)
          Positioned(
            left: (i % 3) * (tile + gap),
            top: (i ~/ 3) * (tile + gap),
            child: mono ? _monoTile(i, tile) : _tile(i, tile),
          ),
      ],
    );
  }

  Widget _tile(int i, double t) {
    final color = _colors[i];
    final dark = Color.lerp(color, Colors.black, 0.4)!;
    final depth = t * 0.08;
    return SizedBox(
      width: t,
      height: t,
      child: Stack(
        children: [
          // Darker base that gives the tile its chunky depth.
          Positioned(
            left: 0,
            right: 0,
            top: depth,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(t * 0.26)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: depth,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t * 0.26),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(color, Colors.white, 0.3)!, color],
                ),
                border: Border.all(color: Colors.white, width: t * 0.055),
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gloss highlight.
                  Positioned(
                    top: t * 0.07,
                    left: t * 0.16,
                    right: t * 0.16,
                    height: t * 0.16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(t),
                      ),
                    ),
                  ),
                  OutlinedText('${_numbers[i]}', size: t * 0.6, stroke: dark, strokeWidth: t * 0.09),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monoTile(int i, double t) => CustomPaint(size: Size.square(t), painter: _MonoTilePainter('${_numbers[i]}'));
}

/// A flat white tile with its digit cut out, for the themed icon.
class _MonoTilePainter extends CustomPainter {
  final String digit;
  _MonoTilePainter(this.digit);

  @override
  void paint(Canvas canvas, Size size) {
    final t = size.width;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(t * 0.26)),
      Paint()..color = Colors.white,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: digit,
        style: TextStyle(
          fontFamily: kTitleFont,
          fontSize: t * 0.6,
          height: 1,
          foreground: Paint()..blendMode = BlendMode.clear,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((t - tp.width) / 2, (t - tp.height) / 2 + t * 0.03));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MonoTilePainter old) => old.digit != digit;
}
