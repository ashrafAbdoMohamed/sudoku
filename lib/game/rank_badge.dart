import 'dart:math';

import 'package:flutter/material.dart';

import '../models/rank.dart';
import '../services/sound_service.dart';
import '../state/game_store.dart';
import 'fx.dart';
import 'ui_kit.dart';

/// The player's rank: a medallion with the rank's character, sitting on a
/// golden ribbon, with the two-tone title and progress to the next rank
/// underneath. Tapping it lists every rank.
class RankBadge extends StatelessWidget {
  final GameStore store;
  final VoidCallback? onStats;
  final VoidCallback? onAwards;
  const RankBadge({super.key, required this.store, this.onStats, this.onAwards});

  @override
  Widget build(BuildContext context) {
    final stars = store.stars;
    final index = rankIndexFor(stars);
    final rank = ranks[index];
    final next = index + 1 < ranks.length ? ranks[index + 1] : null;

    return PressScale(
      pressed: 0.95,
      child: GestureDetector(
        onTap: () {
          SoundService().playTap();
          showRanks(context, store, onStats: onStats, onAwards: onAwards);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 330,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 34,
                    height: 82,
                    child: RankRibbon(),
                  ),
                  Medallion(
                    rank: rank,
                    number: index + 1,
                    size: 120,
                    animated: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            RankTitle(rank: rank, size: 22),
            const SizedBox(height: 6),
            _NextRank(stars: stars, rank: rank, next: next),
          ],
        ),
      ),
    );
  }
}

/// A round medal in the rank's colour with its character art standing in
/// front (popping slightly out of the top) and its number on a gold badge.
///
/// With [animated] the character bobs and sways and a shine sweeps across
/// the medal every few seconds. [characterScale] lets a celebration spring
/// the character out separately from the medal. Locked ranks show the
/// character as a dark silhouette.
class Medallion extends StatefulWidget {
  final Rank rank;
  final int number;
  final double size;
  final bool locked;
  final bool animated;
  final double characterScale;
  const Medallion({
    super.key,
    required this.rank,
    required this.number,
    required this.size,
    this.locked = false,
    this.animated = false,
    this.characterScale = 1,
  });

  @override
  State<Medallion> createState() => _MedallionState();
}

class _MedallionState extends State<Medallion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animated) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant Medallion old) {
    super.didUpdateWidget(old);
    if (widget.animated && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animated && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final color = widget.locked ? const Color(0xFF9E9E9E) : widget.rank.color;
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    final badge = size * 0.3;
    final art = size * 0.92;

    // Cached as a layer: the loop only moves it.
    Widget character = RepaintBoundary(
      child: Image.asset(
        widget.rank.image,
        width: art,
        height: art,
        filterQuality: FilterQuality.medium,
        // A locked rank is a mystery silhouette.
        color: widget.locked ? const Color(0xCC2B2B35) : null,
        colorBlendMode: widget.locked ? BlendMode.srcIn : null,
      ),
    );

    final disc = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.25)!, color, dark],
          stops: const [0, 0.6, 1],
        ),
        border: Border.all(color: dark, width: size * 0.05),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: size * 0.025,
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: size,
      height: size + badge * 0.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final bob = widget.animated ? sin(t * 4 * pi) * size * 0.025 : 0.0;
          final sway = widget.animated ? sin(t * 2 * pi) * 0.05 : 0.0;
          // The shine crosses the medal during the first quarter of each loop.
          final shine = widget.animated ? (t / 0.25).clamp(0.0, 1.0) : 1.0;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Static: cached so the loop doesn't redraw its shadow.
              RepaintBoundary(child: disc),
              if (shine < 1)
                ClipOval(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Transform.translate(
                      offset: Offset((shine * 2 - 1) * size * 1.2, 0),
                      child: Transform.rotate(
                        angle: 0.5,
                        child: Center(
                          child: Container(
                            width: size * 0.22,
                            height: size * 1.6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.45),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // The character stands in front of the medal, peeking over its rim.
              Positioned(
                top: (size - art) / 2 - size * 0.08 + bob,
                child: Transform.rotate(
                  angle: sway,
                  child: Transform.scale(
                    scale: widget.characterScale,
                    child: character,
                  ),
                ),
              ),
              if (widget.locked)
                Positioned(
                  top: size * 0.62,
                  right: size * 0.08,
                  child: GameIcon(GameIcons.lock, size: size * 0.3),
                ),
              Positioned(
                top: size - badge * 0.6,
                child: Container(
                  width: badge,
                  height: badge,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFE680), Color(0xFFF5B400)],
                    ),
                    border: Border.all(color: dark, width: 2.5),
                  ),
                  child: Text(
                    '${widget.number}',
                    style: TextStyle(
                      color: dark,
                      fontFamily: kTitleFont,
                                      fontSize: badge * 0.48,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "ADJECTIVE NOUN" in white then gold, with a dark outline.
class RankTitle extends StatelessWidget {
  final Rank rank;
  final double size;
  const RankTitle({super.key, required this.rank, required this.size});

  @override
  Widget build(BuildContext context) {
    TextStyle style(Color color) => TextStyle(
      color: color,
      fontSize: size,
      fontFamily: kTitleFont,
      letterSpacing: 1.5,
      shadows: const [
        Shadow(color: Color(0xAA3E2723), offset: Offset(0, 2), blurRadius: 0),
        Shadow(color: Color(0x88000000), blurRadius: 6),
      ],
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${rank.adjective.toUpperCase()} ', style: style(Colors.white)),
            TextSpan(
              text: rank.noun.toUpperCase(),
              style: style(const Color(0xFFFFD54F)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextRank extends StatelessWidget {
  final int stars;
  final Rank rank;
  final Rank? next;
  const _NextRank({
    required this.stars,
    required this.rank,
    required this.next,
  });

  @override
  Widget build(BuildContext context) {
    final next = this.next;
    if (next == null) {
      return Text(
        'Highest rank reached!',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      );
    }
    final progress = (stars - rank.stars) / (next.stars - rank.stars);
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const GameIcon(GameIcons.star, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                color: const Color(0xFFFFD54F),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$stars/${next.stars}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// A golden ribbon banner with folded swallow-tail ends, drawn in code.
class RankRibbon extends StatelessWidget {
  const RankRibbon({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _RibbonPainter());
}

class _RibbonPainter extends CustomPainter {
  static const _gold = Color(0xFFF2C44D);
  static const _light = Color(0xFFFFE08A);
  static const _dark = Color(0xFFB8862B);
  static const _shadow = Color(0xFF8A5F17);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final band = h * 0.5; // height of the front band
    final droop = h * 0.22; // how far the ends hang below the middle

    // Tails: behind the band at both ends, notched like a swallow's tail.
    for (final side in [-1.0, 1.0]) {
      final x0 = side < 0 ? w * 0.13 : w * 0.87; // where the band ends
      final xOut = side < 0 ? 0.0 : w; // outer tip of the tail
      final top = h * 0.2 + droop;
      final tail = Path()
        ..moveTo(x0 - side * w * 0.04, top)
        ..lineTo(xOut, top + h * 0.06)
        ..lineTo(xOut + side * -w * 0.06, top + band * 0.5 + h * 0.06)
        ..lineTo(xOut, top + band + h * 0.06)
        ..lineTo(x0 - side * w * 0.04, top + band)
        ..close();
      canvas.drawPath(
        tail.shift(const Offset(0, 3)),
        Paint()..color = _shadow.withValues(alpha: 0.5),
      );
      canvas.drawPath(tail, Paint()..color = _dark);
      // The fold where the tail tucks under the band.
      final fold = Path()
        ..moveTo(x0 - side * w * 0.04, top)
        ..lineTo(x0 + side * w * 0.015, top + band * 0.2)
        ..lineTo(x0 + side * w * 0.015, top + band)
        ..lineTo(x0 - side * w * 0.04, top + band)
        ..close();
      canvas.drawPath(fold, Paint()..color = _shadow);
    }

    // Front band: arches up in the middle, ends drooping.
    Path bandPath(double lift) {
      final left = w * 0.12, right = w * 0.88;
      final top = h * 0.2;
      return Path()
        ..moveTo(left, top + droop - lift)
        ..quadraticBezierTo(
          w / 2,
          top - droop - lift,
          right,
          top + droop - lift,
        )
        ..lineTo(right, top + droop + band - lift)
        ..quadraticBezierTo(
          w / 2,
          top - droop + band - lift,
          left,
          top + droop + band - lift,
        )
        ..close();
    }

    final front = bandPath(0);
    canvas.drawPath(
      front.shift(const Offset(0, 4)),
      Paint()..color = _shadow.withValues(alpha: 0.45),
    );
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_light, _gold, _dark],
          stops: [0, 0.5, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // Thin highlight along the top edge.
    final shine = Path()
      ..moveTo(w * 0.14, h * 0.2 + droop + 4)
      ..quadraticBezierTo(
        w / 2,
        h * 0.2 - droop + 4,
        w * 0.86,
        h * 0.2 + droop + 4,
      );
    canvas.drawPath(
      shine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    // Little stitched edge for a crafted look.
    final stitch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _shadow.withValues(alpha: 0.5);
    for (final m in front.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        final a = m.getTangentForOffset(d)!.position;
        final b = m.getTangentForOffset(min(d + 4, m.length))!.position;
        final inset = Offset(0, a.dy < h * 0.5 ? 4 : -4);
        canvas.drawLine(a + inset, b + inset, stitch);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Every rank, with the ones already earned in colour.
/// The ranks list, with buttons to the player's statistics and achievements.
Future<void> showRanks(
  BuildContext context,
  GameStore store, {
  VoidCallback? onStats,
  VoidCallback? onAwards,
}) {
  final stars = store.stars;
  final current = rankIndexFor(stars);
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: const Color(0xFF5D3A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: Color(0xFFF2C44D), width: 3),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'RANKS',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 26,
                  fontFamily: kTitleFont,
                              letterSpacing: 3,
                ),
              ),
            ),
            Text(
              'Earn stars to climb · ★ $stars · ${store.won} ${store.won == 1 ? 'puzzle' : 'puzzles'} solved',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ChunkyButton(
                      color: const Color(0xFF4D7CFE),
                      height: 44,
                      radius: 14,
                      depth: 5,
                      onTap: () {
                        SoundService().playTap();
                        Navigator.of(context).pop();
                        onStats?.call();
                      },
                      child: const OutlinedText('STATS', size: 18, stroke: Color(0xFF1F3E9A)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChunkyButton(
                      color: const Color(0xFFFF8A3D),
                      height: 44,
                      radius: 14,
                      depth: 5,
                      onTap: () {
                        SoundService().playTap();
                        Navigator.of(context).pop();
                        onAwards?.call();
                      },
                      child: const OutlinedText('AWARDS', size: 18, stroke: Color(0xFF9A3D08)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                itemCount: ranks.length,
                itemBuilder: (context, i) {
                  final rank = ranks[i];
                  final earned = i <= current;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                    decoration: BoxDecoration(
                      color: i == current
                          ? const Color(0x33FFD54F)
                          : Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: i == current
                          ? Border.all(color: const Color(0xFFFFD54F), width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Medallion(
                          rank: rank,
                          number: i + 1,
                          size: 44,
                          locked: !earned,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            rank.title,
                            style: TextStyle(
                              color: earned ? Colors.white : Colors.white54,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const GameIcon(GameIcons.star, size: 20),
                        Text(
                          ' ${rank.stars}',
                          style: TextStyle(
                            color: earned ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
