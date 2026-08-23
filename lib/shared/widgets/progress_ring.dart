import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../app/theme/app_colors.dart';

class ProgressRing extends StatelessWidget {
  final double value; // 0 to 100
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? trackColor;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64.0,
    this.strokeWidth = 7.0,
    this.color = AppColors.primary,
    this.trackColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTrackColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: value / 100,
              strokeWidth: strokeWidth,
              color: color,
              trackColor: trackColor ?? defaultTrackColor,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.trackColor != trackColor ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}
