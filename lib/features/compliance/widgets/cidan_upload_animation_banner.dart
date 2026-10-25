import 'dart:math' as math;
import 'package:flutter/material.dart';

enum UploadProcessStep {
  initial,
  uploading,
  uploadCompleted,
  analyzing,
  generatingInsights,
  completed,
}

class CidanUploadAnimationBanner extends StatefulWidget {
  final UploadProcessStep step;
  final double progress; // 0.0 to 1.0
  final int analysisStepIndex; // 0 to 4

  const CidanUploadAnimationBanner({
    super.key,
    required this.step,
    required this.progress,
    required this.analysisStepIndex,
  });

  @override
  State<CidanUploadAnimationBanner> createState() =>
      _CidanUploadAnimationBannerState();
}

class _CidanUploadAnimationBannerState extends State<CidanUploadAnimationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _loopController;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6F5FE), Color(0xFFECE8FD)],
        ),
      ),
      child: AnimatedBuilder(
        animation: _loopController,
        builder: (context, child) {
          return CustomPaint(
            painter: _CidanSvgAnimationPainter(
              loopValue: _loopController.value,
              step: widget.step,
              progress: widget.progress,
              analysisStepIndex: widget.analysisStepIndex,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _CidanSvgAnimationPainter extends CustomPainter {
  final double loopValue;
  final UploadProcessStep step;
  final double progress;
  final int analysisStepIndex;

  _CidanSvgAnimationPainter({
    required this.loopValue,
    required this.step,
    required this.progress,
    required this.analysisStepIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 8;

    // 1. Soft glowing background orbs
    final glowPaint1 = Paint()
      ..color = const Color(0xFFD6D0FC).withAlpha(140)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.2),
      65,
      glowPaint1,
    );

    final glowPaint2 = Paint()
      ..color = const Color(0xFFDDD8FC).withAlpha(140)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.7),
      75,
      glowPaint2,
    );

    // 2. Left floating mini-document (-14 deg)
    final floatOffsetLeft = math.sin(loopValue * 2 * math.pi) * 4;
    canvas.save();
    canvas.translate(cx - 120, cy - 10 + floatOffsetLeft);
    canvas.rotate(-14 * math.pi / 180);
    final miniDocPaint = Paint()
      ..color = const Color(0xFFE4E0FB).withAlpha(220);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-24, -34, 48, 68),
        const Radius.circular(8),
      ),
      miniDocPaint,
    );
    canvas.restore();

    // 3. Right floating mini-document (+12 deg)
    final floatOffsetRight = math.sin((loopValue + 0.5) * 2 * math.pi) * 4;
    canvas.save();
    canvas.translate(cx + 120, cy - 25 + floatOffsetRight);
    canvas.rotate(12 * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-22, -32, 44, 64),
        const Radius.circular(8),
      ),
      miniDocPaint,
    );
    canvas.restore();

    // 4. Central main document (-5 deg tilted)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-5 * math.pi / 180);

    const docW = 126.0;
    const docH = 176.0;
    const docRect = Rect.fromLTWH(-docW / 2, -docH / 2, docW, docH);

    // Drop shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFF4F46E5).withAlpha(45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        docRect.shift(const Offset(0, 10)),
        const Radius.circular(14),
      ),
      shadowPaint,
    );

    // White document body
    final docBodyPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(docRect, const Radius.circular(14)),
      docBodyPaint,
    );

    // Document border (green glow if analysis completed / generating insights)
    if (step == UploadProcessStep.generatingInsights ||
        analysisStepIndex >= 4) {
      final borderPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(docRect, const Radius.circular(14)),
        borderPaint,
      );
    }

    // Header title lines
    final titleBarPaint = Paint()
      ..color = const Color(0xFF1B1850).withAlpha(210);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-44, -72, 58, 6.5),
        const Radius.circular(3.5),
      ),
      titleBarPaint,
    );

    final subBarPaint = Paint()..color = const Color(0xFFC9C4F5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-44, -58, 40, 5),
        const Radius.circular(2.5),
      ),
      subBarPaint,
    );

    // 4 checklist items on the document
    const rowYPositions = [-32.0, -8.0, 16.0, 40.0];
    final defaultBulletPaint = Paint()..color = const Color(0xFFEEEBFD);
    final rowLinePaint = Paint()..color = const Color(0xFFDAD6FA);
    final rowSubLinePaint = Paint()..color = const Color(0xFFEEEBFD);

    for (int i = 0; i < 4; i++) {
      final y = rowYPositions[i];
      final isItemDone =
          (step == UploadProcessStep.generatingInsights ||
          analysisStepIndex > i ||
          step == UploadProcessStep.completed);

      if (isItemDone) {
        // Teal/Green completed check bullet
        final greenBulletPaint = Paint()..color = const Color(0xFF10B981);
        canvas.drawCircle(Offset(-44, y), 6.5, greenBulletPaint);

        // White checkmark icon inside bullet
        final checkPath = Path();
        checkPath.moveTo(-47.5, y);
        checkPath.lineTo(-44.5, y + 3);
        checkPath.lineTo(-40.5, y - 3.5);
        final checkPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(checkPath, checkPaint);
      } else {
        canvas.drawCircle(Offset(-44, y), 6.5, defaultBulletPaint);
      }

      // Row horizontal bars
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-32, y - 4, 74, 5.5),
          const Radius.circular(3),
        ),
        rowLinePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-32, y + 5, i % 2 == 0 ? 52 : 44, 3.8),
          const Radius.circular(2),
        ),
        rowSubLinePaint,
      );
    }

    // 5. Dynamic stage-specific overlays
    if (step == UploadProcessStep.uploading) {
      _drawUploadingGraphic(canvas, loopValue);
    } else if (step == UploadProcessStep.uploadCompleted) {
      _drawUploadCompletedGraphic(canvas, loopValue);
    } else if (step == UploadProcessStep.analyzing) {
      _drawAnalyzingGraphic(canvas, loopValue, analysisStepIndex);
    } else if (step == UploadProcessStep.generatingInsights) {
      _drawInsightsGraphic(canvas, loopValue);
    }

    canvas.restore(); // Restore central document matrix
  }

  // Stage 1: Uploading Cloud + Arrow + Rising Particles + PDF badge
  void _drawUploadingGraphic(Canvas canvas, double loop) {
    canvas.save();
    canvas.translate(14, 20);

    // Rising particles
    final particlePaint = Paint()
      ..color = const Color(0xFF818CF8).withAlpha(180);
    for (int p = 0; p < 4; p++) {
      final pProg = (loop + p * 0.25) % 1.0;
      final py = 30 - pProg * 45;
      final px = (p - 1.5) * 16;
      final pAlpha = (1.0 - pProg) * 200;
      particlePaint.color = const Color(0xFF6366F1).withAlpha(pAlpha.toInt());
      canvas.drawCircle(Offset(px, py), 2.2, particlePaint);
    }

    // Cloud shadow
    final cloudShadow = Paint()
      ..color = const Color(0xFF4F46E5).withAlpha(55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final cloudPath = _getCloudPath();
    canvas.drawPath(cloudPath.shift(const Offset(0, 4)), cloudShadow);

    // Cloud gradient body
    final cloudPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(-26, -18, 52, 36));
    canvas.drawPath(cloudPath, cloudPaint);

    // Bouncing Up Arrow
    final arrowBounce = math.sin(loop * 2 * math.pi) * 3;
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final arrowPath = Path();
    arrowPath.moveTo(0, 10 + arrowBounce);
    arrowPath.lineTo(0, -8 + arrowBounce);
    arrowPath.moveTo(-6, -2 + arrowBounce);
    arrowPath.lineTo(0, -8 + arrowBounce);
    arrowPath.lineTo(6, -2 + arrowBounce);
    canvas.drawPath(arrowPath, arrowPaint);

    canvas.restore();
  }

  // Stage 2: Upload Completed Cloud Checkmark + Expanding Ripple
  void _drawUploadCompletedGraphic(Canvas canvas, double loop) {
    canvas.save();
    canvas.translate(14, 20);

    // Expanding green ripple ring
    final rippleRadius = 24.0 + (loop % 0.5) * 28;
    final rippleAlpha = ((0.5 - (loop % 0.5)) * 2 * 200).toInt().clamp(0, 255);
    final ripplePaint = Paint()
      ..color = const Color(0xFF10B981).withAlpha(rippleAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(Offset.zero, rippleRadius, ripplePaint);

    // Green completed cloud
    final greenCloudPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF34D399), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(-26, -18, 52, 36));
    canvas.drawPath(_getCloudPath(), greenCloudPaint);

    // White Checkmark
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path();
    checkPath.moveTo(-8, 0);
    checkPath.lineTo(-2, 6);
    checkPath.lineTo(9, -6);
    canvas.drawPath(checkPath, checkPaint);

    canvas.restore();
  }

  // Stage 3: Magnifying Glass Scanning & Translating over document lines
  void _drawAnalyzingGraphic(Canvas canvas, double loop, int stepIdx) {
    // Magnifying glass scanning motion
    final scanY =
        -34.0 + (stepIdx.clamp(0, 3) * 24.0) + math.sin(loop * 2 * math.pi) * 3;
    final scanX = -10.0 + math.cos(loop * 2 * math.pi) * 20;

    canvas.save();
    canvas.translate(scanX, scanY);

    // Lens translucent fill
    final lensFillPaint = Paint()
      ..color = const Color(0xFFC7D2FE).withAlpha(80);
    canvas.drawCircle(Offset.zero, 18, lensFillPaint);

    // Magnifying glass rim
    final rimPaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2;
    canvas.drawCircle(Offset.zero, 18, rimPaint);

    // Glass shine reflection arc
    final shinePaint = Paint()
      ..color = Colors.white.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      const Rect.fromLTWH(-14, -14, 28, 28),
      -2.4,
      1.2,
      false,
      shinePaint,
    );

    // Handle (45 deg angle)
    final handlePaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(13, 13), const Offset(26, 26), handlePaint);

    canvas.restore();
  }

  // Stage 4: Floating badges (Bar chart, Document, Bank pillars)
  void _drawInsightsGraphic(Canvas canvas, double loop) {
    final float1 = math.sin(loop * 2 * math.pi) * 4;
    final float2 = math.cos(loop * 2 * math.pi) * 4;

    // 1. Top-Left Badge: Bar chart
    _drawBadge(
      canvas: canvas,
      center: Offset(-68, -36 + float1),
      radius: 17,
      drawIcon: (c) {
        final barPaint = Paint()
          ..color = const Color(0xFF4F46E5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(-6, 6), const Offset(-6, -1), barPaint);
        c.drawLine(const Offset(-1, 6), const Offset(-1, -7), barPaint);
        c.drawLine(const Offset(4, 6), const Offset(4, 2), barPaint);
      },
    );

    // 2. Top-Right Badge: Document
    _drawBadge(
      canvas: canvas,
      center: Offset(66, -58 + float2),
      radius: 16,
      drawIcon: (c) {
        final docLinePaint = Paint()
          ..color = const Color(0xFF4F46E5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(-5, -5), const Offset(5, -5), docLinePaint);
        c.drawLine(const Offset(-5, 0), const Offset(5, 0), docLinePaint);
        c.drawLine(const Offset(-5, 5), const Offset(2, 5), docLinePaint);
      },
    );

    // 3. Bottom-Right Badge: Bank Pillars
    _drawBadge(
      canvas: canvas,
      center: Offset(70, 38 - float1),
      radius: 17,
      drawIcon: (c) {
        final bankPaint = Paint()
          ..color = const Color(0xFF4F46E5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        // Roof triangle
        final roof = Path();
        roof.moveTo(-7, -4);
        roof.lineTo(0, -9);
        roof.lineTo(7, -4);
        roof.close();
        c.drawPath(roof, bankPaint);
        // Pillars
        c.drawLine(const Offset(-5, -2), const Offset(-5, 5), bankPaint);
        c.drawLine(const Offset(0, -2), const Offset(0, 5), bankPaint);
        c.drawLine(const Offset(5, -2), const Offset(5, 5), bankPaint);
        c.drawLine(const Offset(-8, 6), const Offset(8, 6), bankPaint);
      },
    );
  }

  void _drawBadge({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required void Function(Canvas) drawIcon,
  }) {
    // Badge shadow
    final badgeShadow = Paint()
      ..color = const Color(0xFF4F46E5).withAlpha(40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center + const Offset(0, 3), radius, badgeShadow);

    // Badge white body
    final badgeBody = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius, badgeBody);

    // Border
    final badgeBorder = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, badgeBorder);

    // Icon inside badge
    canvas.save();
    canvas.translate(center.dx, center.dy);
    drawIcon(canvas);
    canvas.restore();
  }

  Path _getCloudPath() {
    final path = Path();
    path.moveTo(-18, 12);
    path.arcToPoint(const Offset(-22, -4), radius: const Radius.circular(12));
    path.arcToPoint(const Offset(2, -14), radius: const Radius.circular(18));
    path.arcToPoint(const Offset(22, -2), radius: const Radius.circular(14));
    path.arcToPoint(const Offset(18, 12), radius: const Radius.circular(12));
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _CidanSvgAnimationPainter oldDelegate) {
    return oldDelegate.loopValue != loopValue ||
        oldDelegate.step != step ||
        oldDelegate.progress != progress ||
        oldDelegate.analysisStepIndex != analysisStepIndex;
  }
}
