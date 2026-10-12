import 'package:flutter/material.dart';

class BoardScannerLoader extends StatefulWidget {
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;

  const BoardScannerLoader({
    super.key,
    this.primaryColor = const Color(0xFF4F6EF7),
    this.backgroundColor = Colors.transparent,
    this.borderColor = const Color(0xFFE5E7EB),
  });

  @override
  State<BoardScannerLoader> createState() => _BoardScannerLoaderState();
}

class _BoardScannerLoaderState extends State<BoardScannerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.7, curve: Curves.easeInOut),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _ScannerPainter(
                scanProgress: _scanAnimation.value,
                pulseValue: _pulseAnimation.value,
                primaryColor: widget.primaryColor,
                backgroundColor: widget.backgroundColor,
                borderColor: widget.borderColor,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double scanProgress;
  final double pulseValue;
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;

  _ScannerPainter({
    required this.scanProgress,
    required this.pulseValue,
    required this.primaryColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 9;
    final boxBorderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final cellBorderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.2)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw grid cells
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final rect = Rect.fromLTWH(
          col * cellSize,
          row * cellSize,
          cellSize,
          cellSize,
        );
        canvas.drawRect(rect, cellBorderPaint);
      }
    }

    // Draw 3x3 box borders
    for (int i = 0; i <= 3; i++) {
      // Vertical lines
      canvas.drawLine(
        Offset(i * cellSize * 3, 0),
        Offset(i * cellSize * 3, size.height),
        boxBorderPaint,
      );
      // Horizontal lines
      canvas.drawLine(
        Offset(0, i * cellSize * 3),
        Offset(size.width, i * cellSize * 3),
        boxBorderPaint,
      );
    }

    // Calculate current scan position (row by row, like a scanner)
    final totalCells = 81;
    final currentCell = (scanProgress * totalCells).floor();

    // Draw scanned cells with gradient fade
    for (int i = 0; i <= currentCell && i < totalCells; i++) {
      final row = i ~/ 9;
      final col = i % 9;

      // Calculate opacity based on how recently this cell was scanned
      final cellAge = currentCell - i;
      final maxAge = 27; // Cells fade out over ~3 rows
      final opacity = (1 - (cellAge / maxAge)).clamp(0.0, 1.0) * 0.6;

      if (opacity > 0) {
        final cellPaint = Paint()
          ..color = primaryColor.withValues(alpha: opacity * pulseValue)
          ..style = PaintingStyle.fill;

        final rect = Rect.fromLTWH(
          col * cellSize + 1,
          row * cellSize + 1,
          cellSize - 2,
          cellSize - 2,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          cellPaint,
        );
      }
    }

    // Draw scan line (horizontal beam)
    if (currentCell < totalCells) {
      final scanRow = currentCell ~/ 9;
      final scanCol = currentCell % 9;
      final scanY = scanRow * cellSize + cellSize / 2;

      // Draw horizontal scan beam across current row
      final beamPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0),
            primaryColor.withValues(alpha: 0.8),
            primaryColor,
            primaryColor.withValues(alpha: 0.8),
            primaryColor.withValues(alpha: 0),
          ],
          stops: const [0, 0.3, 0.5, 0.7, 1],
        ).createShader(Rect.fromLTWH(0, scanY - 2, size.width, 4));

      // Draw beam up to current column
      canvas.drawRect(
        Rect.fromLTWH(0, scanY - 2, (scanCol + 1) * cellSize, 4),
        beamPaint,
      );

      // Draw scanning dot/cursor
      final cursorPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset((scanCol + 0.5) * cellSize, scanY),
        4 * pulseValue,
        cursorPaint,
      );

      // Draw glow around cursor
      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.3 * pulseValue)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset((scanCol + 0.5) * cellSize, scanY),
        8 * pulseValue,
        glowPaint,
      );
    }

    // Draw outer border
    final outerBorderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(4),
      ),
      outerBorderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter oldDelegate) {
    return oldDelegate.scanProgress != scanProgress ||
        oldDelegate.pulseValue != pulseValue;
  }
}
