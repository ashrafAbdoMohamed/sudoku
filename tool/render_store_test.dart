// Renders the Google Play listing art into store/google_play/: eight framed
// 1080x1920 phone screenshots and the 1024x500 feature graphic.
// Raw screenshots come from store/raw/ (iPhone simulator captures).
// Run: flutter test tool/render_store_test.dart
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _title = 'LuckiestGuy';
const _body = 'Fredoka';
const _fallback = <String>[];
const _out = 'store/google_play';

final _images = <String, ui.Image>{};
ui.Image _img(String path) => _images[path]!;

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _loadImage(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  _images[path] = (await codec.getNextFrame()).image;
}

Future<void> _render(WidgetTester tester, Size size, Widget widget, String out) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: SizedBox.fromSize(size: size, child: widget),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

// ------------------------------------------------------------- building blocks

/// Big cartoon headline: white letters, thick dark outline, drop shadow.
Widget _headline(String text, double size, Color dark) {
  TextStyle style(Paint? fg, {Color? color, List<Shadow>? shadows}) => TextStyle(
    fontFamily: _title,
    fontFamilyFallback: _fallback,
    fontSize: size,
    height: 1.02,
    letterSpacing: 1,
    foreground: fg,
    color: color,
    shadows: shadows,
  );
  Paint stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..color = c;
  return Stack(
    children: [
      Transform.translate(
        offset: Offset(0, size * 0.09),
        child: Text(text, textAlign: TextAlign.center, style: style(stroke(dark.withValues(alpha: 0.55), size * 0.2))),
      ),
      Text(text, textAlign: TextAlign.center, style: style(stroke(dark, size * 0.2))),
      Text(text, textAlign: TextAlign.center, style: style(null, color: Colors.white)),
    ],
  );
}

Widget _pill(String text, Color color, {double size = 40}) => Container(
  padding: EdgeInsets.symmetric(horizontal: size * 0.8, vertical: size * 0.32),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(size * 2),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6))],
  ),
  child: Text(
    text,
    style: TextStyle(
      fontFamily: _body,
      fontFamilyFallback: _fallback,
      fontWeight: FontWeight.w700,
      fontSize: size,
      color: color,
      height: 1.1,
    ),
  ),
);

/// A screenshot inside a dark phone bezel.
Widget _phone(ui.Image shot, double width) {
  final height = width * shot.height / shot.width;
  final bezel = width * 0.022;
  final radius = width * 0.14;
  return Container(
    width: width + bezel * 2,
    height: height + bezel * 2,
    padding: EdgeInsets.all(bezel),
    decoration: BoxDecoration(
      color: const Color(0xFF15122B),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFF4A4380), width: bezel * 0.35),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: width * 0.07, offset: Offset(0, width * 0.035)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius - bezel),
      child: RawImage(image: shot, width: width, height: height, fit: BoxFit.fill),
    ),
  );
}

/// Game art (icons, ranks, themes) with a soft shadow in its own shape.
Widget _art(String path, double size, {double angle = 0}) {
  final image = RawImage(image: _img(path), width: size, height: size, fit: BoxFit.contain);
  return Transform.rotate(
    angle: angle,
    child: Stack(
      children: [
        Transform.translate(
          offset: Offset(0, size * 0.05),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: size * 0.04, sigmaY: size * 0.04),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.35), BlendMode.srcIn),
              child: image,
            ),
          ),
        ),
        image,
      ],
    ),
  );
}

/// Gradient backdrop with faint number tiles and sparkles.
class _Backdrop extends StatelessWidget {
  final Color top, bottom;
  final int seed;
  final bool horizontal;
  const _Backdrop(this.top, this.bottom, {required this.seed, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final rnd = Random(seed);
        const letters = '123456789';
        final unit = min(c.maxWidth, c.maxHeight) / 1080 * (horizontal ? 1.6 : 1);
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
                    end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
                    colors: [top, bottom],
                  ),
                ),
              ),
            ),
            // A soft glow behind the content.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: horizontal ? const Alignment(-0.4, -0.2) : const Alignment(0, -0.55),
                    radius: 0.9,
                    colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            for (var i = 0; i < 16; i++)
              Positioned(
                left: rnd.nextDouble() * c.maxWidth - 40 * unit,
                top: rnd.nextDouble() * c.maxHeight - 40 * unit,
                child: Transform.rotate(
                  angle: (rnd.nextDouble() - 0.5) * 0.9,
                  child: _tile(letters[rnd.nextInt(letters.length)], (70 + rnd.nextDouble() * 60) * unit),
                ),
              ),
            Positioned.fill(child: CustomPaint(painter: _Sparkles(seed + 1))),
          ],
        );
      },
    );
  }

  static Widget _tile(String letter, double size) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(size * 0.22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: size * 0.04),
    ),
    child: Text(
      letter,
      style: TextStyle(fontFamily: _title, fontSize: size * 0.6, color: Colors.white.withValues(alpha: 0.4), height: 1),
    ),
  );
}

/// Four-pointed twinkles.
class _Sparkles extends CustomPainter {
  final int seed;
  _Sparkles(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final unit = min(size.width, size.height) / 1080;
    for (var i = 0; i < 18; i++) {
      final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = (10 + rnd.nextDouble() * 26) * unit;
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.5 + rnd.nextDouble() * 0.4);
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ------------------------------------------------------------- slides

class _Deco {
  final String path;
  final double size, angle;
  final double? left, right, top;
  const _Deco(this.path, this.size, {this.left, this.right, required this.top, this.angle = 0});
}

class _Slide {
  final String file, shot, headline, sub;
  final Color top, bottom, dark;
  final List<_Deco> deco;
  const _Slide(this.file, this.shot, this.headline, this.sub, this.top, this.bottom, this.dark, this.deco);
}

const _r = 'store/raw';
const _ic = 'assets/icons';
const _rk = 'assets/ranks';

const _slides = [
  _Slide('01_play_with_friends', '$_r/challenge.png', 'PLAY WITH\nFRIENDS', 'Race live or share a puzzle code',
      Color(0xFF4FE3CF), Color(0xFF0E8C9A), Color(0xFF05444C), [
        _Deco('$_ic/trophy.png', 230, right: -20, top: 1440, angle: 0.12),
        _Deco('$_rk/rank_01.png', 280, left: -40, top: 1460, angle: -0.14),
        _Deco('$_ic/star.png', 130, left: 20, top: 560, angle: -0.2),
      ]),
  _Slide('02_classic_sudoku', '$_r/game.png', 'CLASSIC\nSUDOKU', 'Fresh puzzles from Easy to Expert',
      Color(0xFF39B6FF), Color(0xFF1C55D6), Color(0xFF0B2A78), [
        _Deco('$_ic/star.png', 140, right: 20, top: 520, angle: 0.2),
        _Deco('$_rk/rank_03.png', 270, left: -40, top: 1480, angle: -0.12),
      ]),
  _Slide('03_journey', '$_r/journey.png', 'A JOURNEY\nOF LEVELS', 'Clear stages and open treasure chests',
      Color(0xFFFFB63F), Color(0xFFF0601B), Color(0xFF7E2804), [
        _Deco('$_ic/chest_open.png', 270, right: -30, top: 1470, angle: 0.1),
        _Deco('$_ic/star.png', 130, left: 20, top: 620, angle: -0.25),
        _Deco('$_ic/lock.png', 120, left: 10, top: 1250, angle: 0.15),
      ]),
  _Slide('04_stars_coins', '$_r/win.png', 'EARN STARS\n& COINS', 'Solve with no mistakes for 3 stars',
      Color(0xFFFF77AE), Color(0xFFD12B76), Color(0xFF660A35), [
        _Deco('$_ic/star.png', 190, left: 0, top: 540, angle: -0.25),
        _Deco('$_ic/coin.png', 170, left: -10, top: 1450, angle: -0.1),
        _Deco('$_ic/coin.png', 130, right: 10, top: 1570, angle: 0.2),
        _Deco('$_ic/trophy.png', 220, right: -30, top: 1220, angle: 0.12),
      ]),
  _Slide('05_hints', '$_r/hint.png', 'SMART HINTS\n& MAGIC', 'Stuck? Light up the next easy cell',
      Color(0xFFB58BFF), Color(0xFF6A3BD8), Color(0xFF2E1475), [
        _Deco('$_ic/hint.png', 210, right: -20, top: 1420, angle: 0.15),
        _Deco('$_ic/wand.png', 200, left: -20, top: 1480, angle: -0.2),
      ]),
  _Slide('06_ranks', '$_r/ranks.png', 'CLIMB 14\nRANKS', 'From Number Rookie to Sudoku Emperor',
      Color(0xFFFFCF4D), Color(0xFFDD8210), Color(0xFF6E3F02), [
        _Deco('$_rk/rank_14.png', 320, right: -40, top: 1440, angle: 0.1),
        _Deco('$_rk/rank_06.png', 230, left: -40, top: 600, angle: -0.15),
        _Deco('$_rk/rank_10.png', 220, left: -30, top: 1500, angle: -0.08),
      ]),
  _Slide('07_daily', '$_r/home.png', 'DAILY\nCHALLENGE', 'A new puzzle every day. Keep your streak!',
      Color(0xFF8466FF), Color(0xFF3A27B4), Color(0xFF1B1263), [
        _Deco('$_ic/flame.png', 190, right: 0, top: 560, angle: 0.15),
        _Deco('$_ic/chest_closed.png', 260, left: -40, top: 1470, angle: -0.1),
        _Deco('$_ic/gift.png', 180, right: -20, top: 1400, angle: 0.15),
      ]),
  _Slide('08_difficulty', '$_r/freeplay.png', '4 LEVELS OF\nDIFFICULTY', 'Relax on Easy or test yourself on Expert',
      Color(0xFF63D966), Color(0xFF229638), Color(0xFF0D4F1C), [
        _Deco('$_rk/rank_02.png', 250, left: -40, top: 1480, angle: -0.12),
        _Deco('$_ic/coin.png', 150, right: 20, top: 560, angle: 0.2),
        _Deco('$_ic/star.png', 150, right: -10, top: 1520, angle: 0.1),
      ]),
];

Widget _slide(_Slide s, int seed) {
  return Stack(
    clipBehavior: Clip.hardEdge,
    children: [
      Positioned.fill(child: _Backdrop(s.top, s.bottom, seed: seed)),
      Positioned(top: 470, left: 0, right: 0, child: Center(child: _phone(_img(s.shot), 700))),
      for (final d in s.deco)
        Positioned(left: d.left, right: d.right, top: d.top, child: _art(d.path, d.size, angle: d.angle)),
      Positioned(
        top: 80,
        left: 30,
        right: 30,
        child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _headline(s.headline, 112, s.dark))),
      ),
      Positioned(
        top: 345,
        left: 40,
        right: 40,
        child: Center(
          child: FittedBox(fit: BoxFit.scaleDown, child: _pill(s.sub, s.dark)),
        ),
      ),
    ],
  );
}

// ------------------------------------------------------------- feature graphic

Widget _featureGraphic() {
  const dark = Color(0xFF0B2A78);
  return Stack(
    clipBehavior: Clip.hardEdge,
    children: [
      const Positioned.fill(child: _Backdrop(Color(0xFF7B4DFF), Color(0xFFFF5D9E), seed: 99, horizontal: true)),
      // Tilted phone on the right, running off the bottom edge.
      Positioned(
        right: 60,
        top: 34,
        child: Transform.rotate(angle: 0.12, child: _phone(_img('$_r/game.png'), 250)),
      ),
      Positioned(right: 268, top: 285, child: _art('$_rk/rank_01.png', 190, angle: -0.12)),
      Positioned(right: 18, top: 330, child: _art('$_ic/star.png', 90, angle: 0.25)),
      // Logo, title and tagline on the left.
      Positioned(
        left: 46,
        top: 48,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: RawImage(image: _img('assets/branding/icon.png'), width: 140, height: 140),
          ),
        ),
      ),
      Positioned(left: 214, top: 44, child: _headline('SUDOKU', 92, dark)),
      Positioned(
        left: 46,
        top: 236,
        child: Transform.rotate(
          angle: -0.03,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: const Text(
              'PLAY WITH FRIENDS',
              style: TextStyle(fontFamily: _title, fontSize: 40, color: dark, height: 1.1, letterSpacing: 1),
            ),
          ),
        ),
      ),
      Positioned(
        left: 46,
        top: 372,
        child: Row(
          children: [
            _pill('Live races', dark, size: 24),
            const SizedBox(width: 10),
            _pill('Level journey', dark, size: 24),
            const SizedBox(width: 10),
            _pill('Daily puzzle', dark, size: 24),
          ],
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('render Google Play art', (tester) async {
    await tester.runAsync(() async {
      await _loadFont(_title, ['assets/fonts/LuckiestGuy-Regular.ttf']);
      await _loadFont(_body, ['assets/fonts/Fredoka-SemiBold.ttf', 'assets/fonts/Fredoka-Bold.ttf']);
      final paths = <String>{
        for (final s in _slides) ...[s.shot, for (final d in s.deco) d.path],
        '$_r/game.png', '$_rk/rank_01.png', '$_ic/star.png', 'assets/branding/icon.png',
      };
      for (final p in paths) {
        await _loadImage(p);
      }
    });
    Directory('$_out/screenshots').createSync(recursive: true);
    for (final (i, s) in _slides.indexed) {
      await _render(tester, const Size(1080, 1920), _slide(s, i * 7 + 3), '$_out/screenshots/${s.file}.png');
    }
    await _render(tester, const Size(1024, 500), _featureGraphic(), '$_out/feature_graphic.png');
  });
}
