import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/stradio_theme.dart';

/// Multi-layered organic acoustic ribbon wave (`Sonic Coral`, `Rhythm Violet`, `Twilight Plum`)
/// rendered across Pre-Run Ignition, Active Run Instrument, and Share Studio cards.
class SonicRibbonPainter extends CustomPainter {
  const SonicRibbonPainter({
    this.phase = 0.0,
    this.amplitude = 0.5,
    this.pulseBoost = 0.0,
    this.strokeWidth = 2.6,
    this.fillGradientArea = false,
    this.verticalCenterFactor = 0.5,
  });

  final double phase;
  final double amplitude;
  final double pulseBoost;
  final double strokeWidth;
  final bool fillGradientArea;
  final double verticalCenterFactor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final midY = size.height * verticalCenterFactor.clamp(0.25, 0.75);
    final amp = (size.height * 0.28 * amplitude.clamp(0.15, 1.0)) *
        (1.0 + pulseBoost * 0.42);

    if (fillGradientArea) {
      _drawAreaGlow(
        canvas: canvas,
        size: size,
        midY: midY,
        amp: amp * 0.95,
        freq: 1.75,
        phaseShift: phase + 0.4,
      );
    }

    _drawWave(
      canvas: canvas,
      size: size,
      midY: midY + 2,
      amp: amp * 0.88,
      freq: 1.65,
      harmonicFreq: 3.1,
      phaseShift: phase,
      color: StradioColors.twilightPlum.withValues(alpha: 0.82),
      width: strokeWidth * 0.92,
    );
    _drawWave(
      canvas: canvas,
      size: size,
      midY: midY + 4,
      amp: amp * 0.78,
      freq: 2.05,
      harmonicFreq: 3.6,
      phaseShift: -phase + 1.4,
      color: StradioColors.rhythmViolet.withValues(alpha: 0.90),
      width: strokeWidth * 0.96,
    );
    _drawWave(
      canvas: canvas,
      size: size,
      midY: midY - 2,
      amp: amp * (0.90 + pulseBoost * 0.25),
      freq: 1.80,
      harmonicFreq: 2.9,
      phaseShift: phase + 2.4,
      color: StradioColors.sonicCoral,
      width: strokeWidth * (1.05 + pulseBoost * 0.30),
    );
  }

  void _drawAreaGlow({
    required Canvas canvas,
    required Size size,
    required double midY,
    required double amp,
    required double freq,
    required double phaseShift,
  }) {
    final path = Path();
    const steps = 72;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * size.width;
      final envelope = math.sin(t * math.pi);
      final primary = math.sin(t * math.pi * 2 * freq + phaseShift);
      final sub = math.cos(t * math.pi * 3.2 - phaseShift) * 0.28;
      final y = midY + (primary + sub) * amp * envelope;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          StradioColors.sonicCoral.withValues(alpha: 0.14),
          StradioColors.rhythmViolet.withValues(alpha: 0.08),
          StradioColors.warmIvory.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fillPaint);
  }

  void _drawWave({
    required Canvas canvas,
    required Size size,
    required double midY,
    required double amp,
    required double freq,
    required double harmonicFreq,
    required double phaseShift,
    required Color color,
    required double width,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final path = Path();
    const steps = 80;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * size.width;
      // Smooth bell-shaped windowing at horizontal edges for organic instrument contours.
      final envelope = math.pow(math.sin(t * math.pi), 0.85).toDouble();
      final primary = math.sin(t * math.pi * 2 * freq + phaseShift);
      final secondary =
          math.cos(t * math.pi * harmonicFreq - phaseShift) * 0.26;
      final tertiary =
          math.sin(t * math.pi * (freq * 0.5) + phaseShift) * 0.16;
      final y = midY + (primary + secondary + tertiary) * amp * envelope;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SonicRibbonPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.amplitude != amplitude ||
      oldDelegate.pulseBoost != pulseBoost ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.fillGradientArea != fillGradientArea ||
      oldDelegate.verticalCenterFactor != verticalCenterFactor;
}
