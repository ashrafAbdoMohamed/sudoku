import 'package:flutter/material.dart';
import '../game/cartoon_dialog.dart';
import '../game/ui_kit.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Coach marks overlay that highlights UI elements with tooltips
class CoachMarksOverlay extends StatefulWidget {
  final AppColorScheme colors;
  final VoidCallback onComplete;
  final List<CoachMark> marks;

  const CoachMarksOverlay({
    super.key,
    required this.colors,
    required this.onComplete,
    required this.marks,
  });

  @override
  State<CoachMarksOverlay> createState() => _CoachMarksOverlayState();
}

class _CoachMarksOverlayState extends State<CoachMarksOverlay>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  AppColorScheme get c => widget.colors;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.3, curve: Curves.easeOut),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_currentIndex < widget.marks.length - 1) {
      setState(() => _currentIndex++);
    } else {
      widget.onComplete();
    }
  }

  void _skip() {
    HapticFeedback.lightImpact();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final mark = widget.marks[_currentIndex];
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark overlay with spotlight - fill entire screen
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: SpotlightPainter(
                      spotlightRect: mark.targetRect,
                      opacity: 0.85,
                      pulseScale: _pulseAnimation.value,
                      spotlightPadding: mark.spotlightPadding,
                    ),
                  );
                },
              ),
            ),

          // Tooltip: on the preferred side of the target if it fits there,
          // otherwise the other side, otherwise over the target's middle.
          _placeTooltip(
            mark,
            MediaQuery.paddingOf(context),
            screenSize,
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) => Opacity(opacity: _fadeAnimation.value.clamp(0, 1), child: child),
              child: _buildTooltip(mark),
            ),
          ),

          // Skip button - account for safe area
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: GestureDetector(
              onTap: _skip,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Text('SKIP', style: TextStyle(fontFamily: kTitleFont, fontSize: 16, color: Colors.white)),
              ),
            ),
          ),

          ],
        ),
      ),
    );
  }

  double _getTooltipLeft(CoachMark mark, Size screenSize) {
    final tooltipWidth = 290.0;
    double left;

    switch (mark.position) {
      case TooltipPosition.below:
      case TooltipPosition.above:
        left = mark.targetRect.center.dx - tooltipWidth / 2;
        break;
      case TooltipPosition.left:
        left = mark.targetRect.left - tooltipWidth - 20;
        break;
      case TooltipPosition.right:
        left = mark.targetRect.right + 20;
        break;
    }

    // Keep tooltip on screen
    return left.clamp(16, screenSize.width - tooltipWidth - 16);
  }

  static const _tooltipHeight = 230.0;

  Widget _placeTooltip(CoachMark mark, EdgeInsets safe, Size screen, Widget child) {
    final left = _getTooltipLeft(mark, screen);
    final spaceAbove = mark.targetRect.top - safe.top - 16;
    final spaceBelow = screen.height - mark.targetRect.bottom - safe.bottom - 16;
    var above = mark.position == TooltipPosition.above;
    if (above && spaceAbove < _tooltipHeight && spaceBelow >= _tooltipHeight) above = false;
    if (!above && spaceBelow < _tooltipHeight && spaceAbove >= _tooltipHeight) above = true;
    final fits = above ? spaceAbove >= _tooltipHeight : spaceBelow >= _tooltipHeight;
    if (!fits) {
      return Positioned(left: left, top: (mark.targetRect.center.dy - _tooltipHeight / 2).clamp(safe.top + 60, screen.height), child: child);
    }
    return above
        ? Positioned(left: left, bottom: screen.height - mark.targetRect.top + 16, child: child)
        : Positioned(left: left, top: mark.targetRect.bottom + 16, child: child);
  }

  Widget _buildTooltip(CoachMark mark) {
    final last = _currentIndex >= widget.marks.length - 1;
    return Container(
      width: 290,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0xFF6A4FB0), offset: Offset(0, 5)),
          BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(mark.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(mark.title.toUpperCase(), style: const TextStyle(fontFamily: kTitleFont, fontSize: 19, color: Color(0xFF8E5BEA))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mark.description,
            style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 15, height: 1.3, color: Color(0xFF5B4B7A)),
          ),
          const SizedBox(height: 12),
          // Progress dots sit in their own row, clear of the button.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.marks.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _currentIndex ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _currentIndex ? const Color(0xFF8E5BEA) : const Color(0xFFE2D6F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          CartoonButton(label: last ? 'GOT IT!' : 'NEXT', height: 48, size: 19, onTap: _next),
        ],
      ),
    );
  }
}

class SpotlightPainter extends CustomPainter {
  final Rect spotlightRect;
  final double opacity;
  final double pulseScale;
  final double spotlightPadding;

  SpotlightPainter({
    required this.spotlightRect,
    required this.opacity,
    required this.pulseScale,
    this.spotlightPadding = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: opacity);

    // Calculate the spotlight rect with padding and pulse
    final scaledPadding = spotlightPadding * pulseScale;
    final spotlight = Rect.fromLTRB(
      spotlightRect.left - scaledPadding,
      spotlightRect.top - scaledPadding,
      spotlightRect.right + scaledPadding,
      spotlightRect.bottom + scaledPadding,
    );

    // Create path with hole
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(spotlight, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw spotlight border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlight, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) {
    return oldDelegate.spotlightRect != spotlightRect ||
        oldDelegate.opacity != opacity ||
        oldDelegate.pulseScale != pulseScale;
  }
}

class CoachMark {
  final String icon;
  final String title;
  final String description;
  final Rect targetRect;
  final TooltipPosition position;
  final double spotlightPadding;

  const CoachMark({
    required this.icon,
    required this.title,
    required this.description,
    required this.targetRect,
    this.position = TooltipPosition.below,
    this.spotlightPadding = 8,
  });
}

enum TooltipPosition { above, below, left, right }

/// Helper to create default game screen coach marks
class GameCoachMarks {
  static List<CoachMark> getMarks({
    required Rect boardRect,
    required Rect numpadRect,
    required Rect statsRect,
    required Rect undoRect,
    required Rect eraseRect,
    required Rect notesRect,
    required Rect hintRect,
  }) {
    return [
      CoachMark(
        icon: '🎯',
        title: 'The Sudoku Board',
        description: 'Tap any empty cell to select it. Fill in numbers 1-9 so each row, column, and 3x3 box contains all digits.',
        targetRect: boardRect,
        position: TooltipPosition.below,
        spotlightPadding: 4,
      ),
      CoachMark(
        icon: '🔢',
        title: 'Number Pad',
        description: 'After selecting a cell, tap a number to fill it in. The count shows how many of each number remain.',
        targetRect: numpadRect,
        position: TooltipPosition.above,
        spotlightPadding: 4,
      ),
      CoachMark(
        icon: '⏱️',
        title: 'Game Stats',
        description: 'Track your time and mistakes. Three mistakes and it\'s game over! Tap the pause button to take a break.',
        targetRect: statsRect,
        position: TooltipPosition.below,
      ),
      CoachMark(
        icon: '✏️',
        title: 'Notes Mode',
        description: 'Toggle notes to mark possible numbers in cells. Great for keeping track of your deductions!',
        targetRect: notesRect,
        position: TooltipPosition.above,
      ),
      CoachMark(
        icon: '💡',
        title: 'Need Help?',
        description: 'Stuck? Use hints sparingly - they\'ll reveal a correct number but use them wisely!',
        targetRect: hintRect,
        position: TooltipPosition.above,
      ),
      CoachMark(
        icon: '↩️',
        title: 'Made a Mistake?',
        description: 'Use Undo to go back, or Erase to clear a cell. Don\'t worry, everyone makes mistakes!',
        targetRect: undoRect,
        position: TooltipPosition.above,
        spotlightPadding: 12,
      ),
    ];
  }
}
