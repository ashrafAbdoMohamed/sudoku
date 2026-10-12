import 'dart:math';

import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// Alternative app icon designs, to compare with [AppLogo]. Each fills a
/// square of [size].
enum LogoOption {
  /// The real game board: cream grid, orange box lines, purple digits and a
  /// glowing selected cell, on the teal game backdrop.
  board,

  /// "Play with friends": two chunky player bubbles with a lightning bolt
  /// in front of a small Sudoku grid.
  versus,

  /// One big glossy number tile with a gold star, on a sunburst.
  bigNine,
}

class AppLogoOption extends StatelessWidget {
  final LogoOption option;
  final double size;
  const AppLogoOption(this.option, {super.key, required this.size});

  static const _teal = [Color(0xFF5EDDC4), Color(0xFF1E9AB0)];

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: switch (option) {
        LogoOption.board => _board(),
        LogoOption.versus => _versus(),
        LogoOption.bigNine => _bigNine(),
      },
    );
  }

  Widget _gradient(List<Color> colors) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
        ),
      );

  // ───────────────────────────────────────────── board

  Widget _board() {
    final s = size;
    return Stack(
      children: [
        Positioned.fill(child: _gradient(_teal)),
        Center(
          child: Container(
            width: s * 0.8,
            height: s * 0.8,
            padding: EdgeInsets.all(s * 0.022),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9F43),
              borderRadius: BorderRadius.circular(s * 0.1),
              border: Border.all(color: Colors.white, width: s * 0.022),
              boxShadow: [BoxShadow(color: const Color(0xFF0B5E6B), offset: Offset(0, s * 0.03))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(s * 0.06),
              child: CustomPaint(painter: _BoardPainter()),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────── versus

  Widget _versus() {
    final s = size;
    Widget bubble(Color color, IconData icon) => Container(
          width: s * 0.36,
          height: s * 0.36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(color, Colors.white, 0.3)!, color],
            ),
            border: Border.all(color: Colors.white, width: s * 0.025),
            boxShadow: [BoxShadow(color: Color.lerp(color, Colors.black, 0.4)!, offset: Offset(0, s * 0.02))],
          ),
          child: Icon(icon, color: Colors.white, size: s * 0.24),
        );
    return Stack(
      children: [
        Positioned.fill(child: _gradient(_teal)),
        // A faint grid behind the players.
        Positioned(
          left: s * 0.12,
          top: s * 0.08,
          width: s * 0.76,
          height: s * 0.76,
          child: Opacity(
            opacity: 0.35,
            child: CustomPaint(painter: _GridOnlyPainter()),
          ),
        ),
        Positioned(left: s * 0.08, top: s * 0.36, child: bubble(const Color(0xFFFF8A3D), Icons.person_rounded)),
        Positioned(right: s * 0.08, top: s * 0.36, child: bubble(const Color(0xFF8E5BEA), Icons.person_rounded)),
        Positioned(
          left: s * 0.39,
          top: s * 0.4,
          child: Transform.rotate(
            angle: -0.12,
            child: Container(
              width: s * 0.22,
              height: s * 0.28,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F),
                borderRadius: BorderRadius.circular(s * 0.06),
                border: Border.all(color: Colors.white, width: s * 0.018),
                boxShadow: [BoxShadow(color: const Color(0xFF9A6A00), offset: Offset(0, s * 0.015))],
              ),
              child: Icon(Icons.bolt_rounded, color: const Color(0xFFE5501B), size: s * 0.22),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: s * 0.1,
          child: Center(child: OutlinedText('VS', size: s * 0.2, color: Colors.white, stroke: const Color(0xFF0B5E6B), strokeWidth: s * 0.03)),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────── big nine

  Widget _bigNine() {
    final s = size;
    const color = Color(0xFF8E5BEA);
    final dark = Color.lerp(color, Colors.black, 0.4)!;
    return Stack(
      children: [
        Positioned.fill(child: _gradient(const [Color(0xFFFFCF4D), Color(0xFFFF8A3D)])),
        Positioned.fill(child: CustomPaint(painter: _RaysPainter())),
        Center(
          child: Transform.rotate(
            angle: -0.08,
            child: Container(
              width: s * 0.62,
              height: s * 0.62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(s * 0.15),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(color, Colors.white, 0.3)!, color],
                ),
                border: Border.all(color: Colors.white, width: s * 0.03),
                boxShadow: [BoxShadow(color: dark, offset: Offset(0, s * 0.04))],
              ),
              alignment: Alignment.center,
              child: OutlinedText('9', size: s * 0.46, stroke: dark, strokeWidth: s * 0.05),
            ),
          ),
        ),
        Positioned(right: s * 0.08, top: s * 0.08, child: Icon(Icons.star_rounded, color: Colors.white, size: s * 0.22)),
        Positioned(right: s * 0.1, top: s * 0.1, child: Icon(Icons.star_rounded, color: const Color(0xFFFFD54F), size: s * 0.18)),
      ],
    );
  }
}

/// A slice of a real puzzle: cream cells, light and orange lines, navy given
/// digits, purple player digits and one selected orange cell.
class _BoardPainter extends CustomPainter {
  static const _givens = [
    [5, 3, 0, 0, 7, 0, 0, 0, 0],
    [6, 0, 0, 1, 9, 5, 0, 0, 0],
    [0, 9, 8, 0, 0, 0, 0, 6, 0],
    [8, 0, 0, 0, 6, 0, 0, 0, 3],
    [4, 0, 0, 8, 0, 3, 0, 0, 1],
    [7, 0, 0, 0, 2, 0, 0, 0, 6],
    [0, 6, 0, 0, 0, 0, 2, 8, 0],
    [0, 0, 0, 4, 1, 9, 0, 0, 5],
    [0, 0, 0, 0, 8, 0, 0, 7, 9],
  ];
  static const _filled = {(0, 2): 4, (1, 1): 7, (2, 0): 1, (3, 1): 5, (4, 1): 2, (6, 0): 9};
  static const _selected = (4, 4);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFBF2));
    final sel = Rect.fromLTWH(_selected.$2 * cell, _selected.$1 * cell, cell, cell);
    // Row, column and box of the selected cell.
    final peer = Paint()..color = const Color(0xFFFFF0CF);
    canvas.drawRect(Rect.fromLTWH(0, sel.top, size.width, cell), peer);
    canvas.drawRect(Rect.fromLTWH(sel.left, 0, cell, size.height), peer);
    canvas.drawRect(Rect.fromLTWH(3 * cell, 3 * cell, 3 * cell, 3 * cell), peer);
    canvas.drawRect(sel, Paint()..color = const Color(0xFFFFC870));

    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final given = _givens[r][c];
        final user = _filled[(r, c)];
        final n = given != 0 ? given : user;
        if (n == null) continue;
        final tp = TextPainter(
          text: TextSpan(
            text: '$n',
            style: TextStyle(
              fontFamily: kBodyFont,
              fontWeight: FontWeight.w700,
              fontSize: cell * 0.68,
              height: 1,
              color: given != 0 ? const Color(0xFF2A3A6E) : const Color(0xFF8E3FD6),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(c * cell + (cell - tp.width) / 2, r * cell + (cell - tp.height) / 2));
      }
    }
    _GridOnlyPainter.drawLines(canvas, size, const Color(0xFFF2DDB8), const Color(0xFFFF9F43));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridOnlyPainter extends CustomPainter {
  static void drawLines(Canvas canvas, Size size, Color thin, Color thick) {
    final cell = size.width / 9;
    for (var i = 1; i < 9; i++) {
      final p = Paint()
        ..color = i % 3 == 0 ? thick : thin
        ..strokeWidth = i % 3 == 0 ? cell * 0.09 : cell * 0.03;
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), p);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.06)),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
    drawLines(canvas, size, Colors.white, Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * pi / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * cos(a - 0.11), c.dy + r * sin(a - 0.11))
        ..lineTo(c.dx + r * cos(a + 0.11), c.dy + r * sin(a + 0.11))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
