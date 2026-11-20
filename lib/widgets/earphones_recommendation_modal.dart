import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/stradio_strings.dart';
import '../theme/stradio_theme.dart';
import 'sonic_ribbon_painter.dart';

/// P0 First-Launch Audio Immersion Modal (`docs/PRD-MVP.md` FR-5.0 & Mockup #08).
///
/// Renders a 3D-shaded Warm Ivory / Alabaster Over-Ear Headphones vector illustration
/// floating over sunlit window bokeh and glowing multi-layer acoustic ribbons.
class EarphonesRecommendationModal extends StatelessWidget {
  const EarphonesRecommendationModal({
    super.key,
    required this.onDismiss,
    this.language = AppLanguage.en,
  });

  final VoidCallback onDismiss;
  final AppLanguage language;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onDismissed,
    AppLanguage language = AppLanguage.en,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: StradioStrings.of(language).closeLabel,
      barrierColor: StradioColors.midnight.withValues(alpha: 0.30),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, _) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: EarphonesRecommendationModal(
                language: language,
                onDismiss: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
    onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(language);
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          key: const Key('earphones_recommendation_modal'),
          decoration: BoxDecoration(
            color: StradioColors.surfaceCard.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(StradioRadii.tray),
            border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
            boxShadow: [
              BoxShadow(
                color: StradioColors.midnight.withValues(alpha: 0.16),
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 184px Mockup 08 Warm Studio Header: Window-Light Bokeh + Acoustic Ribbons + 3D Ivory Headphones SVG
                SizedBox(
                  height: 184,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const CustomPaint(
                        painter: _Mockup08StudioBackdropPainter(),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: CustomPaint(
                          painter: SonicRibbonPainter(
                            phase: 0.95,
                            amplitude: 0.86,
                            strokeWidth: 2.3,
                            fillGradientArea: true,
                          ),
                        ),
                      ),
                      const Center(
                        child: SizedBox(
                          width: 156,
                          height: 156,
                          child: CustomPaint(
                            painter: _Alabaster3DHeadphonesPainter(),
                          ),
                        ),
                      ),
                      // Subtle bottom fade into card surface
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 28,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                StradioColors.surfaceCard.withValues(
                                  alpha: 0.0,
                                ),
                                StradioColors.surfaceCard,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Semantics(
                          button: true,
                          label: 'Close modal',
                          child: IconButton(
                            key: const Key('earphones_modal_close_button'),
                            onPressed: onDismiss,
                            tooltip: s.closeLabel,
                            style: IconButton.styleFrom(
                              backgroundColor: StradioColors.midnight
                                  .withValues(alpha: 0.22),
                              foregroundColor: StradioColors.surfaceCard,
                              minimumSize: const Size(44, 44),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: StradioColors.glowCoralSoft,
                          borderRadius: BorderRadius.circular(StradioRadii.full),
                        ),
                        child: Text(
                          s.earphonesBadge,
                          style: StradioTypography.microCap(
                            color: StradioColors.textAccentDeep,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.earphonesTitle,
                        style: StradioTypography.headingSmall(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.earphonesBody,
                        style: StradioTypography.body(fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              key: const Key('earphones_modal_primary_button'),
                              onPressed: onDismiss,
                              child: Text(s.earphonesPrimaryAction),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: TextButton(
                              key: const Key('earphones_modal_later_button'),
                              onPressed: onDismiss,
                              style: TextButton.styleFrom(
                                foregroundColor: StradioColors.textSecondary,
                                textStyle: StradioTypography.buttonLabel(
                                  color: StradioColors.textSecondary,
                                ),
                              ),
                              child: Text(s.earphonesLaterAction),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the warm sunlit architectural window bokeh & soft acoustic glow from Mockup 08.
class _Mockup08StudioBackdropPainter extends CustomPainter {
  const _Mockup08StudioBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF6F1E7),
          Color(0xFFDDCBB7),
          Color(0xFFEDE5D8),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Soft window sunlight panels on the left
    final windowLight = Paint()
      ..color = const Color(0xFFFFFBF4).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 12, size.width * 0.18, size.height * 0.36),
        const Radius.circular(6),
      ),
      windowLight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, size.height * 0.54, size.width * 0.18, size.height * 0.34),
        const Radius.circular(6),
      ),
      windowLight,
    );

    // Warm coral-violet acoustic aura behind the headphones
    final auraPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.08, 0.04),
        radius: 0.55,
        colors: [
          StradioColors.sonicCoral.withValues(alpha: 0.24),
          StradioColors.rhythmViolet.withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, auraPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3/4-perspective Warm Ivory / Alabaster Over-Ear Headphones vector matching Mockup 08.
class _Alabaster3DHeadphonesPainter extends CustomPainter {
  const _Alabaster3DHeadphonesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.50;
    final cy = size.height * 0.52;

    // Soft ambient drop shadow beneath floating headphones
    final shadowPaint = Paint()
      ..color = const Color(0xFF6B5847).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + 4, cy + 52),
        width: 78,
        height: 16,
      ),
      shadowPaint,
    );

    // 1. 3D Sculpted Headband Arc (Warm Ivory outer shell + soft bronze inner cushion)
    final arcRect = Rect.fromCenter(
      center: Offset(cx, cy - 6),
      width: 78,
      height: 88,
    );
    final innerShadowArc = Paint()
      ..color = const Color(0xFFC4B5A2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(arcRect.shift(const Offset(2, 2)), math.pi * 0.92, math.pi * 1.12, false, innerShadowArc);

    final outerBandPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFDFBF7),
          Color(0xFFE7DECF),
          Color(0xFFD4C6B4),
        ],
      ).createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(arcRect, math.pi * 0.92, math.pi * 1.12, false, outerBandPaint);

    // Metallic champagne hinge stems
    final hingePaint = Paint()
      ..color = const Color(0xFFB5A592)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 38, cy - 2), Offset(cx - 34, cy + 12), hingePaint);
    canvas.drawLine(Offset(cx + 37, cy - 1), Offset(cx + 34, cy + 14), hingePaint);

    // 2. Right Ear Cup (angled three-quarter back cup with inner cushion cavity)
    canvas.save();
    canvas.translate(cx + 24, cy + 24);
    canvas.rotate(0.24);
    final rightCupRect = Rect.fromCenter(center: Offset.zero, width: 34, height: 48);
    final rightShellPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5EFE6), Color(0xFFD6C8B6)],
      ).createShader(rightCupRect);
    canvas.drawOval(rightCupRect, rightShellPaint);

    final rightCushionRect = Rect.fromCenter(
      center: const Offset(-3, 0),
      width: 24,
      height: 38,
    );
    canvas.drawOval(
      rightCushionRect,
      Paint()..color = const Color(0xFFEAE1D5),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-4, 0), width: 13, height: 24),
      Paint()..color = const Color(0xFFC2B29F),
    );
    canvas.restore();

    // 3. Left Ear Cup (prominent foreground sculpted Alabaster shell)
    canvas.save();
    canvas.translate(cx - 18, cy + 20);
    canvas.rotate(-0.18);

    // Back cushion ring
    final leftCushionRect = Rect.fromCenter(
      center: const Offset(5, 1),
      width: 38,
      height: 54,
    );
    canvas.drawOval(
      leftCushionRect,
      Paint()..color = const Color(0xFFD9CBB9),
    );

    // Main outer 3D dome
    final leftDomeRect = Rect.fromCenter(
      center: Offset.zero,
      width: 38,
      height: 54,
    );
    final leftDomePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFDF9),
          Color(0xFFEEE6DA),
          Color(0xFFD7C9B8),
        ],
      ).createShader(leftDomeRect);
    canvas.drawOval(leftDomeRect, leftDomePaint);

    // Specular rim & subtle acoustic wave emblem on left earcup
    canvas.drawOval(
      leftDomeRect.deflate(1.2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Tiny acoustic wave mark + sensor port on the dome (matching Mockup 08)
    final emblemPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(-3, 2), width: 8, height: 8),
      0.2,
      2.4,
      false,
      emblemPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(11, 10), width: 2.2, height: 6.5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF7B736B),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
