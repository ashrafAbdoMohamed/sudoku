import 'dart:math';

import 'package:flutter/material.dart';

/// The game screen's background: mint to teal, a faint pattern of rounded
/// tiles (a nod to the grid), soft bubbles and a few faint number tiles.
/// Static: painted once into its own layer and never redrawn, so it costs
/// nothing while the player is solving.
class GameBackdrop extends StatelessWidget {
  const GameBackdrop({super.key});

  static const top = Color(0xFF5EDDC4);
  static const bottom = Color(0xFF1E9AB0);

  /// Dark teal for outlines, shadows and pills that sit on this backdrop.
  static const ink = Color(0xFF0B5E6B);

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(child: CustomPaint(painter: _BackdropPainter(), size: Size.infinite));
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GameBackdrop.top, GameBackdrop.bottom],
        ).createShader(rect),
    );

    // Rounded tile outlines across the whole screen.
    const cell = 52.0;
    final tile = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.13);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x + 3, y + 3, cell - 6, cell - 6), const Radius.circular(10)),
          tile,
        );
      }
    }

    // Soft bubbles near the edges.
    final rnd = Random(7);
    final bubble = Paint();
    for (var i = 0; i < 9; i++) {
      final left = rnd.nextBool();
      final c = Offset(
        left ? rnd.nextDouble() * size.width * 0.18 : size.width * (0.82 + rnd.nextDouble() * 0.18),
        rnd.nextDouble() * size.height,
      );
      bubble.color = Colors.white.withValues(alpha: 0.12 + rnd.nextDouble() * 0.1);
      canvas.drawCircle(c, 6 + rnd.nextDouble() * 16, bubble);
    }

    // A few faint number tiles, tilted, in the corners.
    const tiles = [(0.04, 0.72, '7', -0.25), (0.88, 0.70, '3', 0.2), (0.86, 0.94, '5', -0.14), (0.05, 0.95, '9', 0.17)];
    for (final (fx, fy, digit, angle) in tiles) {
      canvas.save();
      canvas.translate(size.width * fx, size.height * fy);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-18, -18, 36, 36), const Radius.circular(9)),
        Paint()..color = Colors.white.withValues(alpha: 0.12),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: digit,
          style: TextStyle(fontFamily: 'LuckiestGuy', fontSize: 22, color: Colors.white.withValues(alpha: 0.35)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2 + 2));
      tp.dispose();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}
