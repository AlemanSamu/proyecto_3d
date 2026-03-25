import 'dart:math';

import 'package:flutter/material.dart';

class CaptureGuidanceRing extends StatelessWidget {
  const CaptureGuidanceRing({
    super.key,
    required this.capturedSectors,
    required this.suggestedAngle,
    required this.highlightColor,
    this.objectOffset = Offset.zero,
  });

  final List<int> capturedSectors;
  final int suggestedAngle;
  final Color highlightColor;
  final Offset objectOffset;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CaptureGuidanceRingPainter(
        capturedSectors: capturedSectors,
        suggestedAngle: suggestedAngle,
        highlightColor: highlightColor,
        objectOffset: objectOffset,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CaptureGuidanceRingPainter extends CustomPainter {
  _CaptureGuidanceRingPainter({
    required this.capturedSectors,
    required this.suggestedAngle,
    required this.highlightColor,
    required this.objectOffset,
  });

  final List<int> capturedSectors;
  final int suggestedAngle;
  final Color highlightColor;
  final Offset objectOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = min(size.width, size.height) * 0.45;
    final innerRadius = outerRadius * 0.68;
    final ringRadius = (outerRadius + innerRadius) / 2;
    final ringWidth = outerRadius - innerRadius;
    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, ringRadius, basePaint);

    for (int sector = 0; sector < 360; sector += 30) {
      final normalizedSector = _normalize(sector);
      final isCaptured = capturedSectors.contains(normalizedSector);
      final isSuggested = _normalize(suggestedAngle) == normalizedSector;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = ringWidth + (isSuggested ? 2 : 0)
        ..color = isCaptured
            ? const Color(0xFF5ED3BF).withValues(alpha: 0.88)
            : isSuggested
            ? highlightColor.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.12);

      final startAngle = (-90 + sector) * pi / 180;
      const sweepAngle = (30 * pi / 180) - 0.035;
      canvas.drawArc(ringRect, startAngle, sweepAngle, false, paint);
    }

    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawCircle(center, innerRadius * 0.56, guidePaint);
    canvas.drawLine(
      Offset(center.dx - innerRadius * 0.18, center.dy),
      Offset(center.dx + innerRadius * 0.18, center.dy),
      guidePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - innerRadius * 0.18),
      Offset(center.dx, center.dy + innerRadius * 0.18),
      guidePaint,
    );

    final suggestedPoint = Offset(
      center.dx + cos((-90 + suggestedAngle) * pi / 180) * ringRadius,
      center.dy + sin((-90 + suggestedAngle) * pi / 180) * ringRadius,
    );
    final spokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = highlightColor.withValues(alpha: 0.44);
    canvas.drawLine(center, suggestedPoint, spokePaint);

    final clampedOffset = Offset(
      objectOffset.dx.clamp(-1.0, 1.0),
      objectOffset.dy.clamp(-1.0, 1.0),
    );
    final objectCenter = Offset(
      center.dx + clampedOffset.dx * innerRadius * 0.34,
      center.dy + clampedOffset.dy * innerRadius * 0.34,
    );
    final objectPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      objectCenter,
      7,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      objectCenter,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = highlightColor.withValues(alpha: 0.9),
    );
    canvas.drawCircle(objectCenter, 2.4, objectPaint);
  }

  int _normalize(int angle) => (((angle % 360) + 360) % 360) ~/ 30 * 30;

  @override
  bool shouldRepaint(covariant _CaptureGuidanceRingPainter oldDelegate) {
    return oldDelegate.suggestedAngle != suggestedAngle ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.objectOffset != objectOffset ||
        oldDelegate.capturedSectors.length != capturedSectors.length;
  }
}
