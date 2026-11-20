import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../evaluation/run_metrics_calculator.dart';
import '../../models/sound_pack.dart';
import '../../theme/stradio_theme.dart';
import '../sonic_ribbon_painter.dart';
import 'share_template_models.dart';

/// Renders one of the 3 `Transparent Sticker` P2 templates (`docs/DESIGN.md` §8):
/// - `Aura Wave` (Frosted Alabaster + 20 cadence stem bars + bottom ribbon)
/// - `Sonic Dial` (Smoked Obsidian + circular Cadence Resonance Dial)
/// - `Minimal Stride` (Smoked Obsidian + horizontal Cadence Lock-Zone range bar)
class TransparentStickerCard extends StatelessWidget {
  const TransparentStickerCard({
    super.key,
    required this.template,
    required this.metrics,
    required this.soundPack,
  });

  final StickerTemplateId template;
  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;

  @override
  Widget build(BuildContext context) {
    return switch (template) {
      StickerTemplateId.auraWave => _AuraWaveStickerCard(
        metrics: metrics,
        soundPack: soundPack,
      ),
      StickerTemplateId.sonicDial => _SonicDialStickerCard(
        metrics: metrics,
        soundPack: soundPack,
      ),
      StickerTemplateId.minimalStride => _MinimalStrideStickerCard(
        metrics: metrics,
        soundPack: soundPack,
      ),
    };
  }
}

class _AuraWaveStickerCard extends StatelessWidget {
  const _AuraWaveStickerCard({required this.metrics, required this.soundPack});

  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;

  @override
  Widget build(BuildContext context) {
    final stems = ShareMetricFormat.sampleStems(metrics, count: 20);
    final avgSpm = ShareMetricFormat.avgSpm(metrics);

    return Container(
      key: const Key('sticker_card_aura_wave'),
      width: 304,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: StradioColors.surfaceCard.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: StradioColors.surfaceGlassRim, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        avgSpm,
                        style: StradioTypography.metricHero(fontSize: 38),
                      ),
                      const SizedBox(width: 6),
                      Text('spm', style: StradioTypography.metricLabel()),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                  'AURA WAVE',
                  style: StradioTypography.microCap(
                    color: StradioColors.textAccentDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 20 Cadence Stem Bars
          SizedBox(
            height: 62,
            child: stems.isEmpty
                ? Center(
                    child: Text(
                      'No cadence samples yet',
                      style: StradioTypography.metricLabel(),
                    ),
                  )
                : _StickerStemRow(stems: stems),
          ),
          const SizedBox(height: 14),

          // Metric Row
          Row(
            children: [
              Expanded(
                child: _LightStatItem(
                  label: 'Distance',
                  value: ShareMetricFormat.distanceKm(metrics),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LightStatItem(
                  label: 'Duration',
                  value: metrics.formattedDuration,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LightStatItem(
                  label: 'Pace',
                  value: ShareMetricFormat.pace(metrics),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bottom Acoustic Ribbon Wave
          const SizedBox(
            height: 28,
            child: CustomPaint(
              painter: SonicRibbonPainter(
                phase: 0.9,
                amplitude: 0.85,
                strokeWidth: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _AudioStickerFooter(soundPack: soundPack, dark: false),
        ],
      ),
    );
  }
}

class _SonicDialStickerCard extends StatelessWidget {
  const _SonicDialStickerCard({required this.metrics, required this.soundPack});

  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;

  @override
  Widget build(BuildContext context) {
    final avgSpm = ShareMetricFormat.avgSpm(metrics);
    final progress = (metrics.averageCadenceSpm / 200.0).clamp(0.0, 1.0);

    return Container(
      key: const Key('sticker_card_sonic_dial'),
      width: 280,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: StradioColors.midnight.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: StradioColors.warmIvory.withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Cadence Resonance Dial
          SizedBox(
            width: 156,
            height: 156,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(156, 156),
                  painter: _ObsidianDialPainter(progress: progress),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      avgSpm,
                      style: StradioTypography.metricHero(
                        fontSize: 38,
                        color: StradioColors.textOnDark,
                      ),
                    ),
                    Text(
                      'spm',
                      style: StradioTypography.metricLabel(
                        color: StradioColors.warmIvory.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DarkStatItem(
                  label: 'Distance',
                  value: ShareMetricFormat.distanceKm(metrics),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DarkStatItem(
                  label: 'Duration',
                  value: metrics.formattedDuration,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DarkStatItem(
                  label: 'Pace',
                  value: ShareMetricFormat.paceShort(metrics),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AudioStickerFooter(soundPack: soundPack, dark: true),
        ],
      ),
    );
  }
}

class _MinimalStrideStickerCard extends StatelessWidget {
  const _MinimalStrideStickerCard({
    required this.metrics,
    required this.soundPack,
  });

  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;

  @override
  Widget build(BuildContext context) {
    final (minSpm, maxSpm) = ShareMetricFormat.cadenceRange(metrics);
    final rangeText = (minSpm != null && maxSpm != null)
        ? '$minSpm-$maxSpm spm Lock Zone'
        : 'No lock zone yet';
    final leftFrac = minSpm != null
        ? ((minSpm - 80) / 140.0).clamp(0.05, 0.75)
        : 0.25;
    final rightFrac = maxSpm != null
        ? ((maxSpm - 80) / 140.0).clamp(leftFrac + 0.12, 0.95)
        : 0.65;

    return Container(
      key: const Key('sticker_card_minimal_stride'),
      width: 288,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: StradioColors.midnight.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: StradioColors.warmIvory.withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Cadence Lock',
                  overflow: TextOverflow.ellipsis,
                  style: StradioTypography.pillBadge(
                    color: StradioColors.textOnDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${ShareMetricFormat.avgSpm(metrics)} spm',
                    style: StradioTypography.metricValue(
                      fontSize: 22,
                      color: StradioColors.sonicCoral,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Horizontal Cadence Range Consistency Bar
          SizedBox(
            height: 12,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth;
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: StradioColors.warmIvory.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(StradioRadii.full),
                      ),
                    ),
                    Positioned(
                      left: w * leftFrac,
                      width: math.max(24, w * (rightFrac - leftFrac)),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              StradioColors.rhythmViolet,
                              StradioColors.sonicCoral,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            StradioRadii.full,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rangeText,
            style: StradioTypography.metricLabel(
              color: StradioColors.warmIvory.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DarkStatItem(
                  label: 'Distance',
                  value: ShareMetricFormat.distanceKm(metrics),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DarkStatItem(
                  label: 'Duration',
                  value: metrics.formattedDuration,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DarkStatItem(
                  label: 'Pace',
                  value: ShareMetricFormat.paceShort(metrics),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AudioStickerFooter(soundPack: soundPack, dark: true),
        ],
      ),
    );
  }
}

class _StickerStemRow extends StatelessWidget {
  const _StickerStemRow({required this.stems});

  final List<double> stems;

  @override
  Widget build(BuildContext context) {
    final maxVal = math.max(180.0, stems.reduce(math.max));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < stems.length; i++)
          Container(
            width: 3.5,
            height: 56 * (stems[i] / maxVal).clamp(0.18, 1.0),
            decoration: BoxDecoration(
              color: stems[i] >= 130
                  ? (i.isEven
                        ? StradioColors.twilightPlum
                        : StradioColors.sonicCoral)
                  : StradioColors.rhythmViolet,
              borderRadius: BorderRadius.circular(StradioRadii.full),
            ),
          ),
      ],
    );
  }
}

class _ObsidianDialPainter extends CustomPainter {
  const _ObsidianDialPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = StradioColors.warmIvory.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final sweep = (progress * math.pi * 2).clamp(0.2, math.pi * 2);
    final arcPaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          StradioColors.rhythmViolet,
          StradioColors.sonicCoral,
          StradioColors.rhythmViolet,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(rect, -math.pi / 2, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _ObsidianDialPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LightStatItem extends StatelessWidget {
  const _LightStatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: StradioTypography.metricLabel(),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: StradioTypography.pillBadge()),
        ),
      ],
    );
  }
}

class _DarkStatItem extends StatelessWidget {
  const _DarkStatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: StradioTypography.metricLabel(
            color: StradioColors.warmIvory.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: StradioTypography.pillBadge(color: StradioColors.textOnDark),
          ),
        ),
      ],
    );
  }
}

class _AudioStickerFooter extends StatelessWidget {
  const _AudioStickerFooter({required this.soundPack, required this.dark});

  final StradioSoundPack soundPack;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark
        ? StradioColors.warmIvory.withValues(alpha: 0.12)
        : StradioColors.surfaceRecessed;
    final fg = dark ? StradioColors.textOnDark : StradioColors.textPrimary;
    final iconColor = dark
        ? StradioColors.rhythmViolet
        : StradioColors.twilightPlum;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(StradioRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.headphones_rounded, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              soundPack.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StradioTypography.pillBadge(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
