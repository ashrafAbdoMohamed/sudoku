import 'dart:math';

import 'package:flutter/material.dart';

/// A calm landscape behind the Home screen: a dawn sky with a soft low sun,
/// layered mountains and green hills dotted with trees. Only two clouds
/// move, very slowly, so the buttons stay the centre of attention.
class HomeBackdrop extends StatefulWidget {
  const HomeBackdrop({super.key});

  @override
  State<HomeBackdrop> createState() => _HomeBackdropState();
}

class _HomeBackdropState extends State<HomeBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _clouds = AnimationController(vsync: this, duration: const Duration(seconds: 120))
    ..repeat();

  @override
  void dispose() {
    _clouds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The landscape never changes, so it's painted once and cached.
        RepaintBoundary(child: CustomPaint(painter: _LandscapePainter())),
        RepaintBoundary(child: CustomPaint(painter: _CloudPainter(_clouds))),
      ],
    );
  }
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6FB9EE), Color(0xFFA9D8F5), Color(0xFFFFE2B8)],
          stops: [0, 0.42, 0.68],
        ).createShader(rect),
    );

    // Soft low sun with a wide glow, sitting just above the far mountains.
    final sun = Offset(w * 0.7, h * 0.62);
    canvas.drawCircle(
      sun,
      w * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFF1C9).withValues(alpha: 0.9), const Color(0xFFFFF1C9).withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: sun, radius: w * 0.45)),
    );
    canvas.drawCircle(sun, 34, Paint()..color = const Color(0xFFFFF4D6));

    // Far mountains with snowy peaks.
    final far = _ridge(w, h, base: h * 0.7, peaks: [0.08, 0.3, 0.52, 0.8, 1.02], heights: [60, 95, 70, 105, 60]);
    canvas.drawPath(far, Paint()..color = const Color(0xFFA9B9E3));
    _snowCaps(canvas, w, h, base: h * 0.7, peaks: [0.3, 0.8], heights: [95, 105]);

    // Nearer, bluer-green mountains.
    final mid = _ridge(w, h, base: h * 0.77, peaks: [-0.05, 0.18, 0.45, 0.68, 0.95], heights: [45, 70, 50, 65, 50]);
    canvas.drawPath(mid, Paint()..color = const Color(0xFF86AFC9));

    // Rolling green hills, back to front.
    _hill(canvas, w, h, top: h * 0.83, amp: 18, freq: 1.4, phase: 0.6, color: const Color(0xFF8ACB76));
    _trees(canvas, w, h, y: h * 0.84, count: 7, size: 13, color: const Color(0xFF5E9E4E), seed: 1);
    _hill(canvas, w, h, top: h * 0.89, amp: 14, freq: 1.1, phase: 2.2, color: const Color(0xFF6DBB5E));
    _trees(canvas, w, h, y: h * 0.9, count: 5, size: 18, color: const Color(0xFF4C8F3F), seed: 2);
    _hill(canvas, w, h, top: h * 0.95, amp: 10, freq: 0.9, phase: 4.0, color: const Color(0xFF58A84B));
  }

  /// A mountain range: straight-ish slopes between peaks.
  Path _ridge(double w, double h, {required double base, required List<double> peaks, required List<double> heights}) {
    final path = Path()..moveTo(0, h);
    path.lineTo(0, base);
    for (var i = 0; i < peaks.length; i++) {
      final x = peaks[i] * w;
      final prev = i == 0 ? 0.0 : peaks[i - 1] * w;
      // Valley halfway between peaks, then up to the next summit.
      path.lineTo((prev + x) / 2, base - 8);
      path.lineTo(x, base - heights[i]);
    }
    path
      ..lineTo(w, base)
      ..lineTo(w, h)
      ..close();
    return path;
  }

  void _snowCaps(
    Canvas canvas,
    double w,
    double h, {
    required double base,
    required List<double> peaks,
    required List<double> heights,
  }) {
    final snow = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < peaks.length; i++) {
      final tip = Offset(peaks[i] * w, base - heights[i]);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - 14, tip.dy + 22)
          ..lineTo(tip.dx - 5, tip.dy + 17)
          ..lineTo(tip.dx + 2, tip.dy + 24)
          ..lineTo(tip.dx + 8, tip.dy + 17)
          ..lineTo(tip.dx + 15, tip.dy + 22)
          ..close(),
        snow,
      );
    }
  }

  double _hillY(double x, double w, double top, double amp, double freq, double phase) =>
      top - amp * sin(x / w * freq * pi + phase);

  void _hill(
    Canvas canvas,
    double w,
    double h, {
    required double top,
    required double amp,
    required double freq,
    required double phase,
    required Color color,
  }) {
    final path = Path()..moveTo(0, h);
    for (double x = 0; x <= w; x += 6) {
      path.lineTo(x, _hillY(x, w, top, amp, freq, phase));
    }
    path
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    // Sunlit rim along the crest.
    final rim = Path()..moveTo(0, _hillY(0, w, top, amp, freq, phase));
    for (double x = 0; x <= w; x += 6) {
      rim.lineTo(x, _hillY(x, w, top, amp, freq, phase));
    }
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color.lerp(color, Colors.white, 0.3)!,
    );
  }

  /// Round little trees standing along a hill line.
  void _trees(
    Canvas canvas,
    double w,
    double h, {
    required double y,
    required int count,
    required double size,
    required Color color,
    required int seed,
  }) {
    final rnd = Random(seed);
    final trunk = Paint()..color = const Color(0xFF7A5534);
    final leaf = Paint()..color = color;
    final light = Paint()..color = Color.lerp(color, Colors.white, 0.25)!;
    for (var i = 0; i < count; i++) {
      final x = w * (0.04 + rnd.nextDouble() * 0.92);
      final s = size * (0.8 + rnd.nextDouble() * 0.4);
      final ground = y + rnd.nextDouble() * 10;
      canvas.drawRect(Rect.fromLTWH(x - s * 0.1, ground - s * 0.8, s * 0.2, s * 0.8), trunk);
      canvas.drawCircle(Offset(x, ground - s * 1.2), s * 0.7, leaf);
      canvas.drawCircle(Offset(x - s * 0.22, ground - s * 1.4), s * 0.28, light);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CloudPainter extends CustomPainter {
  final Animation<double> t;
  _CloudPainter(this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final span = w + 260;
    _cloud(canvas, Offset((t.value * span + 40) % span - 130, h * 0.1), 1.1);
    _cloud(canvas, Offset((t.value * span + span * 0.55) % span - 130, h * 0.5), 0.8);
  }

  void _cloud(Canvas canvas, Offset c, double s) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 110 * s, height: 30 * s), Radius.circular(15 * s)),
      paint,
    );
    canvas.drawCircle(c + Offset(-22 * s, -12 * s), 22 * s, paint);
    canvas.drawCircle(c + Offset(12 * s, -20 * s), 27 * s, paint);
  }

  @override
  bool shouldRepaint(covariant _CloudPainter old) => false;
}
