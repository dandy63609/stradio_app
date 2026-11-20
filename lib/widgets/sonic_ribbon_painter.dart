import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/stradio_theme.dart';

/// Multi-layered acoustic ribbon wave (`Sonic Coral`, `Rhythm Violet`, `Twilight Plum`)
/// rendered underneath [LiquidGlassLens] surfaces so SDF edge refraction bends real chromatic contours.
class SonicRibbonPainter extends CustomPainter {
  const SonicRibbonPainter({
    this.phase = 0.0,
    this.amplitude = 0.5,
    this.pulseBoost = 0.0,
    this.strokeWidth = 2.6,
  });

  final double phase;
  final double amplitude;
  final double pulseBoost;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final midY = size.height * 0.5;
    final amp = (size.height * 0.28 * amplitude.clamp(0.15, 1.0)) *
        (1.0 + pulseBoost * 0.45);

    _drawWave(
      canvas: canvas,
      size: size,
      midY: midY,
      amp: amp * 0.92,
      freq: 2.0,
      phaseShift: phase,
      color: StradioColors.twilightPlum,
      width: strokeWidth,
    );
    _drawWave(
      canvas: canvas,
      size: size,
      midY: midY + 4,
      amp: amp * 0.78,
      freq: 2.4,
      phaseShift: phase + 1.3,
      color: StradioColors.rhythmViolet,
      width: strokeWidth * 0.95,
    );
    _drawWave(
      canvas: canvas,
      size: size,
      midY: midY - 2,
      amp: amp * (0.85 + pulseBoost * 0.25),
      freq: 1.85,
      phaseShift: phase + 2.5,
      color: StradioColors.sonicCoral,
      width: strokeWidth * (1.0 + pulseBoost * 0.35),
    );
  }

  void _drawWave({
    required Canvas canvas,
    required Size size,
    required double midY,
    required double amp,
    required double freq,
    required double phaseShift,
    required Color color,
    required double width,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final path = Path();
    const steps = 64;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * size.width;
      // Taper cleanly at horizontal edges so ribbons sit harmoniously inside dials & cards.
      final envelope = math.sin(t * math.pi);
      final y = midY +
          math.sin(t * math.pi * 2 * freq + phaseShift) * amp * envelope;
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
      oldDelegate.strokeWidth != strokeWidth;
}
