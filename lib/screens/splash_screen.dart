import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/home_backdrop.dart';
import '../game/ui_kit.dart';

/// Opening screen: rainbow number tiles pop into a 3×3 grid, the logo
/// bounces in, and a short loading bar fills.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _seconds = 2.4;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_seconds * 1000).round()),
  )..forward();
  Timer? _done;

  static const _numbers = [5, 3, 7, 6, 1, 9, 8, 4, 2];
  static const _colors = [
    Color(0xFFF25A6B),
    Color(0xFFFF9F43),
    Color(0xFFF5C02B),
    Color(0xFF3FB26B),
    Color(0xFF1FB5A8),
    Color(0xFF4D9BFE),
    Color(0xFF4D7CFE),
    Color(0xFF8E5BEA),
    Color(0xFFE05BC4),
  ];

  @override
  void initState() {
    super.initState();
    _done = Timer(Duration(milliseconds: (_seconds * 1000).round() + 150), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _done?.cancel();
    _c.dispose();
    super.dispose();
  }

  double _seg(double start, double end, [Curve curve = Curves.linear]) {
    final s = _c.value * _seconds;
    return curve.transform(((s - start) / (end - start)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: HomeBackdrop()),
          Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _grid(),
                  const SizedBox(height: 30),
                  Transform.scale(
                    scale: _seg(0.9, 1.5, Curves.elasticOut),
                    child: const OutlinedText('SUDOKU', size: 64, color: Colors.white, stroke: Color(0xFF3D2B7A), strokeWidth: 10),
                  ),
                  const SizedBox(height: 4),
                  Opacity(
                    opacity: _seg(1.3, 1.7),
                    child: const Text(
                      'THINK · SOLVE · WIN',
                      style: TextStyle(fontFamily: kTitleFont, fontSize: 18, letterSpacing: 3, color: Color(0xFF2B4E7A)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Opacity(opacity: _seg(1.3, 1.6), child: _loadingBar(_seg(1.3, 2.35, Curves.easeInOut))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    return SizedBox(
      width: 3 * 72 + 2 * 10,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < 9; i++) _tile(i),
        ],
      ),
    );
  }

  Widget _tile(int i) {
    final t = _seg(i * 0.08, 0.6 + i * 0.08, Curves.elasticOut);
    final color = _colors[i];
    return Transform.scale(
      scale: t,
      child: Transform.rotate(
        angle: (1 - t.clamp(0.0, 1.0)) * -pi / 2,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(color, Colors.white, 0.3)!, color],
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Color.lerp(color, Colors.black, 0.4)!, offset: const Offset(0, 6))],
          ),
          alignment: Alignment.center,
          child: OutlinedText('${_numbers[i]}', size: 38, stroke: Color.lerp(color, Colors.black, 0.45)!),
        ),
      ),
    );
  }

  Widget _loadingBar(double progress) {
    return Container(
      width: 200,
      height: 18,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF2B4E7A).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress.clamp(0.04, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFC23D),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
