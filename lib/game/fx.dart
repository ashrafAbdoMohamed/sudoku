// Game-feel effects shared by the cartoon screens (ported from Word Search):
// PressScale, Entrance, Breathing, Bump, Shake, AnimatedCount,
// FadeScaleRoute, ConfettiBurst and SunRays.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';


/// Shrinks its child slightly while a finger is down. Does not consume taps,
/// so it can wrap buttons that have their own InkWell.
class PressScale extends StatefulWidget {
  final Widget child;
  final double pressed;
  const PressScale({super.key, required this.child, this.pressed = 0.9});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressed : 1,
        duration: Duration(milliseconds: _down ? 80 : 220),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades and slides its child in after [delay].
class Entrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Offset from;
  final Duration duration;
  final Curve curve;
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.from = const Offset(0, 0.25),
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutBack,
  });

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = widget.curve.transform(_c.value);
        return Opacity(
          opacity: _c.value.clamp(0, 1),
          child: FractionalTranslation(
            translation: widget.from * (1 - t),
            child: child,
          ),
        );
      },
    );
  }
}

/// Gently pulses its child forever, to draw the eye to a main action.
class Breathing extends StatefulWidget {
  final Widget child;
  final double amount;
  final Duration period;
  const Breathing({
    super.key,
    required this.child,
    this.amount = 0.04,
    this.period = const Duration(milliseconds: 1400),
  });

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 1 + widget.amount,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      // Cached as a layer: the pulse rescales it instead of repainting it.
      child: RepaintBoundary(child: widget.child),
    );
  }
}

/// Plays a one-shot animation every time [trigger] changes.
abstract class _Triggered extends StatefulWidget {
  final Object? trigger;
  final Widget child;
  final Duration duration;
  const _Triggered({
    super.key,
    required this.trigger,
    required this.child,
    required this.duration,
  });

  Widget transform(double t, Widget child);

  @override
  State<_Triggered> createState() => _TriggeredState();
}

class _TriggeredState extends State<_Triggered>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _Triggered old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => widget.transform(_c.value, child!),
  );
}

/// Scales up and back when [trigger] changes.
class Bump extends _Triggered {
  final double amount;
  const Bump({
    super.key,
    required super.trigger,
    required super.child,
    this.amount = 0.25,
  }) : super(duration: const Duration(milliseconds: 380));

  @override
  Widget transform(double t, Widget child) =>
      Transform.scale(scale: 1 + amount * sin(pi * t), child: child);
}

/// Shakes side to side when [trigger] changes, for "no" feedback.
class Shake extends _Triggered {
  final double distance;
  const Shake({
    super.key,
    required super.trigger,
    required super.child,
    this.distance = 10,
  }) : super(duration: const Duration(milliseconds: 420));

  @override
  Widget transform(double t, Widget child) => Transform.translate(
    offset: Offset(sin(t * pi * 6) * distance * (1 - t), 0),
    child: child,
  );
}

/// A number that rolls to its new value instead of jumping.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle style;
  final int? from;
  final Duration duration;
  final String prefix;
  const AnimatedCount({
    super.key,
    required this.value,
    required this.style,
    this.from,
    this.prefix = '',
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from?.toDouble(), end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefix${v.round()}', style: style),
    );
  }
}

/// Fade + zoom page transition used between screens.
class FadeScaleRoute<T> extends PageRouteBuilder<T> {
  FadeScaleRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
}

/// Two confetti cannons firing up from the bottom corners. Plays once.
class ConfettiBurst extends StatefulWidget {
  final int count;
  final Duration duration;
  const ConfettiBurst({
    super.key,
    this.count = 140,
    this.duration = const Duration(milliseconds: 3200),
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();
  late final List<_Confetto> _pieces;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _pieces = List.generate(widget.count, (i) {
      final fromLeft = i.isEven;
      // Aim up and inward, with spread.
      final angle =
          (fromLeft ? -pi / 2 + 0.55 : -pi / 2 - 0.55) +
          (rnd.nextDouble() - 0.5) * 0.7;
      final speed = 1.6 + rnd.nextDouble() * 1.2; // screen heights per second
      return _Confetto(
        fromLeft: fromLeft,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        spin: (rnd.nextDouble() - 0.5) * 18,
        wobble: rnd.nextDouble() * pi * 2,
        color: _confettiColors[rnd.nextInt(_confettiColors.length)],
        size: 6 + rnd.nextDouble() * 6,
        round: rnd.nextInt(4) == 0,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            _pieces,
            _c.value * widget.duration.inMilliseconds / 1000,
            _c.value,
          ),
        ),
      ),
    );
  }
}

class _Confetto {
  final bool fromLeft;
  final double vx, vy, spin, wobble, size;
  final Color color;
  final bool round;
  const _Confetto({
    required this.fromLeft,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.wobble,
    required this.color,
    required this.size,
    required this.round,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Confetto> pieces;
  final double seconds;
  final double progress;
  _ConfettiPainter(this.pieces, this.seconds, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 0.7; // screen heights / s^2
    const drag = 1.6;
    final h = size.height;
    // Velocity decays with air drag; integrate analytically.
    final decay = (1 - exp(-drag * seconds)) / drag;
    final opacity = progress < 0.8 ? 1.0 : (1 - (progress - 0.8) / 0.2);
    final paint = Paint();

    for (final p in pieces) {
      final x0 = p.fromLeft ? 0.0 : size.width;
      final x = x0 + p.vx * h * decay + sin(seconds * 5 + p.wobble) * 12;
      final y = h + p.vy * h * decay + 0.5 * gravity * h * seconds * seconds;
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * seconds);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        // Flip vertically over time so pieces look like they tumble.
        final flip = cos(seconds * 8 + p.wobble).abs();
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6 * flip + 1,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

/// Slowly rotating light rays, drawn behind the win card.
class SunRays extends StatefulWidget {
  final Color color;
  const SunRays({super.key, this.color = Colors.white});

  @override
  State<SunRays> createState() => _SunRaysState();
}

class _SunRaysState extends State<SunRays> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RotationTransition(
        turns: _c,
        child: CustomPaint(
          size: Size.infinite,
          painter: _RaysPainter(widget.color),
        ),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  final Color color;
  _RaysPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide;
    const rays = 14;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.6));
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * pi / rays;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + cos(a - 0.09) * radius,
          center.dy + sin(a - 0.09) * radius,
        )
        ..lineTo(
          center.dx + cos(a + 0.09) * radius,
          center.dy + sin(a + 0.09) * radius,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => old.color != color;
}

/// Letters drifting up behind the home screen.

const _confettiColors = [
  Color(0xFFFF6B6B),
  Color(0xFFFF9F43),
  Color(0xFFF7C64A),
  Color(0xFF3FB26B),
  Color(0xFF22B8CF),
  Color(0xFF4D7CFE),
  Color(0xFF8E5BEA),
  Color(0xFFE8467C),
];
