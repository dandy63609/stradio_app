import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/stradio_strings.dart';
import '../theme/stradio_theme.dart';
import 'sonic_ribbon_painter.dart';

/// P0 First-Launch Audio Immersion Modal (`docs/PRD-MVP.md` FR-5.0 & `docs/DESIGN.md` §9).
///
/// Advises wearing earphones/headphones on cold first launch with a custom vector
/// headphones illustration + acoustic ribbons (`CustomPainter`), zero external image bloat.
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
            color: StradioColors.surfaceCard.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(StradioRadii.tray),
            border: Border.all(color: StradioColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: StradioColors.midnight.withValues(alpha: 0.14),
                blurRadius: 32,
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
                // 176px Daylight Recessed Header with CustomPainter Headphones & Ribbons
                SizedBox(
                  height: 176,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: StradioColors.surfaceRecessed),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: CustomPaint(
                          painter: SonicRibbonPainter(
                            phase: 0.7,
                            amplitude: 0.75,
                            strokeWidth: 2.4,
                          ),
                        ),
                      ),
                      const Center(
                        child: SizedBox(
                          width: 124,
                          height: 124,
                          child: CustomPaint(
                            painter: _MinimalHeadphonesPainter(),
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
                            tooltip: 'Close',
                            style: IconButton.styleFrom(
                              backgroundColor: StradioColors.midnight
                                  .withValues(alpha: 0.18),
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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

/// Crisp geometric Midnight over-ear headphones vector (zero raster bloat).
class _MinimalHeadphonesPainter extends CustomPainter {
  const _MinimalHeadphonesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.52;
    final r = size.width * 0.34;

    final bandPaint = Paint()
      ..color = StradioColors.midnight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Headband arc
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(arcRect, 3.14159, 3.14159, false, bandPaint);

    // Subtle inner cushion highlight
    final cushionPaint = Paint()
      ..color = StradioColors.surfaceCard
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r - 5),
      3.55,
      2.32,
      false,
      cushionPaint,
    );

    // Left & right ear cups
    final cupFill = Paint()
      ..color = StradioColors.midnight
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final coralRing = Paint()
      ..color = StradioColors.sonicCoral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..isAntiAlias = true;

    final leftCup = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - r, cy + 12), width: 18, height: 34),
      const Radius.circular(9),
    );
    final rightCup = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + r, cy + 12), width: 18, height: 34),
      const Radius.circular(9),
    );
    canvas.drawRRect(leftCup, cupFill);
    canvas.drawRRect(rightCup, cupFill);

    // Small acoustic coral accent inside each ear cup
    canvas.drawCircle(Offset(cx - r, cy + 12), 4.0, coralRing);
    canvas.drawCircle(Offset(cx + r, cy + 12), 4.0, coralRing);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
