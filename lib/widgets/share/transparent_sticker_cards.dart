import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../evaluation/run_metrics_calculator.dart';
import '../../models/sound_pack.dart';
import '../../theme/stradio_theme.dart';
import 'share_template_models.dart';

/// Renders one of the 3 `Transparent Sticker` P2 templates (`docs/DESIGN.md` §8 & Mockups #04-#06):
/// - `Aura Wave` (Frosted Alabaster Glass + 20 cadence stems + unified white metric capsule
///   + native `assets/design/ribbon_tight_corner.png` 3D corner ribbon wave)
/// - `Sonic Dial` (Smoked Obsidian Glassmorphism + circular Cadence Resonance Dial + 15 mini glowing stems
///   + 3-column dark glass telemetry pod)
/// - `Minimal Stride` (Smoked Obsidian Glassmorphism + horizontal Cadence Range Consistency bar
///   with white average marker tick + 2-row dark glass telemetry bento)
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

/// 1. Aura Wave (Mockup #04):
/// Frosted Alabaster Glass + Stradio header + Average Stride Rhythm & Resonance pills
/// + 20 cadence stems + unified white metric capsule + `assets/design/ribbon_tight_corner.png` corner wave.
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFCF9F4).withValues(alpha: 0.92),
            const Color(0xFFF5EFE6).withValues(alpha: 0.86),
            const Color(0xFFFAF7F2).withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.92),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Top-left diagonal specular glass highlight (.lg-specular-arc)
          Positioned(
            top: -36,
            left: -28,
            child: Transform.rotate(
              angle: -0.32,
              child: Container(
                width: 180,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(StradioRadii.full),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.72),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom-Right 3D Layered Corner Ribbon Wave (assets/design/ribbon_tight_corner.png)
          Positioned(
            right: 0,
            bottom: 0,
            width: 176,
            height: 54,
            child: IgnorePointer(
              child: Image.asset(
                'assets/design/ribbon_tight_corner.png',
                key: const Key('aura_wave_corner_ribbon_image'),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Lockup: Stradio Logo & Wordmark + Steps Pill
                _StickerBrandHeader(
                  dark: false,
                  badgeText: ShareMetricFormat.stepsPillLabel(metrics),
                ),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  color: StradioColors.borderSubtle.withValues(alpha: 0.75),
                ),
                const SizedBox(height: 12),

                // Hero Metric Section: Category Pill + Big SPM + Resonance Lock Pill
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: StradioColors.surfaceCard,
                        borderRadius: BorderRadius.circular(StradioRadii.full),
                        border: Border.all(color: StradioColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.graphic_eq_rounded,
                            size: 13,
                            color: StradioColors.textAccentDeep,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Average Stride Rhythm',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: StradioTypography.metricLabel(
                                color: StradioColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          avgSpm,
                          style: StradioTypography.metricHero(fontSize: 48),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'spm',
                          style: StradioTypography.titleMuted(fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: StradioColors.surfaceCard,
                        borderRadius: BorderRadius.circular(StradioRadii.full),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: StradioColors.rhythmViolet,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              ShareMetricFormat.resonanceLabel(metrics),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: StradioTypography.microCap(
                                color: StradioColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 20 Cadence Stem Bars
                SizedBox(
                  height: 56,
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

                // Unified White Frosted 3-Column Telemetry Capsule
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _LightStatItem(
                          label: 'Distance (km)',
                          value: ShareMetricFormat.distanceShort(metrics),
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
                          label: 'Pace (/km)',
                          value: ShareMetricFormat.paceShort(metrics),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Footer above corner ribbon wave
                _AudioStickerFooter(soundPack: soundPack, dark: false),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. Sonic Dial (Mockup #05 - Smoked Obsidian Glassmorphism):
/// Smoked Obsidian Glass surface + Stradio header + Cadence Resonance Dial with 4 cardinal nodes
/// + 15 mini glowing stems + 3-column dark glass telemetry pod + audio footer.
class _SonicDialStickerCard extends StatelessWidget {
  const _SonicDialStickerCard({required this.metrics, required this.soundPack});

  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;

  @override
  Widget build(BuildContext context) {
    final avgSpm = ShareMetricFormat.avgSpm(metrics);
    final progress = (metrics.averageCadenceSpm / 200.0).clamp(0.0, 1.0);
    final miniStems = ShareMetricFormat.sampleStems(metrics, count: 15);

    return _ObsidianGlassStickerSurface(
      cardKey: const Key('sticker_card_sonic_dial'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StickerBrandHeader(
            dark: true,
            badgeText: ShareMetricFormat.stepsPillLabel(metrics),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 10),

          // Top Pill: Cadence Resonance Dial
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(StradioRadii.full),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    size: 13,
                    color: StradioColors.sonicCoral,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Cadence Resonance Dial',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.metricLabel(
                        color: StradioColors.textOnDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Circular Cadence Resonance Dial (156x156)
          Center(
            child: SizedBox(
              width: 158,
              height: 158,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(158, 158),
                    painter: _ObsidianDialPainter(progress: progress),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CADENCE',
                        style: StradioTypography.microCap(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        avgSpm,
                        style: StradioTypography.metricHero(
                          fontSize: 42,
                          color: StradioColors.textOnDark,
                        ),
                      ),
                      Text(
                        'SPM',
                        style: StradioTypography.microCap(
                          color: Colors.white.withValues(alpha: 0.80),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'LOCKED CADENCE',
                        style: StradioTypography.microCap(
                          color: StradioColors.sonicCoral,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Bottom Resonance Pill
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(StradioRadii.full),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: StradioColors.rhythmViolet,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      ShareMetricFormat.resonanceLabel(metrics),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.microCap(
                        color: StradioColors.textOnDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 15 Mini Glowing Stem Bars
          if (miniStems.isNotEmpty) ...[
            SizedBox(
              height: 28,
              child: _ObsidianMiniStemRow(stems: miniStems),
            ),
            const SizedBox(height: 12),
          ],

          // Dark Glass 3-Column Telemetry Pod
          _ObsidianTelemetryThreeColBox(metrics: metrics),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 10),
          _AudioStickerFooter(soundPack: soundPack, dark: true),
        ],
      ),
    );
  }
}

/// 3. Minimal Stride (Mockup #06 - Smoked Obsidian Glassmorphism):
/// Smoked Obsidian Glass surface + Stradio header + Hero SPM + Cadence Range Consistency Box
/// (with white average marker tick) + 2-row dark glass telemetry bento (`Distance/Duration/Pace` + `Stride Length/Sync Integrity`).
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
        ? ((minSpm - 80) / 140.0).clamp(0.08, 0.72)
        : 0.25;
    final rightFrac = maxSpm != null
        ? ((maxSpm - 80) / 140.0).clamp(leftFrac + 0.16, 0.92)
        : 0.68;
    final avgFrac = ((leftFrac + rightFrac) * 0.5).clamp(0.12, 0.88);

    return _ObsidianGlassStickerSurface(
      cardKey: const Key('sticker_card_minimal_stride'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StickerBrandHeader(
            dark: true,
            badgeText: ShareMetricFormat.stepsPillLabel(metrics),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 10),

          // Top Pill: Minimal Stride Cadence
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(StradioRadii.full),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.linear_scale_rounded,
                    size: 13,
                    color: StradioColors.sonicCoral,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Minimal Stride Cadence',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.metricLabel(
                        color: StradioColors.textOnDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Hero SPM + Average Cadence Lock Line
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    ShareMetricFormat.avgSpm(metrics),
                    style: StradioTypography.metricHero(
                      fontSize: 48,
                      color: StradioColors.textOnDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SPM',
                    style: StradioTypography.pillBadge(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: StradioColors.sonicCoral,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'AVERAGE CADENCE LOCK · ${ShareMetricFormat.syncPercentText(metrics)} SYNC',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.microCap(
                        color: StradioColors.sonicCoral,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cadence Range Consistency Glass Pod
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'CADENCE RANGE CONSISTENCY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StradioTypography.microCap(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ShareMetricFormat.cadenceDeltaSpm(metrics),
                      style: StradioTypography.microCap(
                        color: StradioColors.textOnDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 12,
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final w = constraints.maxWidth;
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(
                                StradioRadii.full,
                              ),
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
                                    StradioColors.sonicCoral,
                                    StradioColors.rhythmViolet,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  StradioRadii.full,
                                ),
                              ),
                            ),
                          ),
                          // White average cadence marker tick inside Lock Zone bar
                          Positioned(
                            left: (w * avgFrac) - 2.5,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 5,
                              decoration: BoxDecoration(
                                color: Colors.white,
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
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      minSpm != null ? '$minSpm' : '--',
                      style: StradioTypography.microCap(
                        color: Colors.white.withValues(alpha: 0.50),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        rangeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: StradioTypography.microCap(
                          color: StradioColors.sonicCoral,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      maxSpm != null ? '$maxSpm' : '--',
                      style: StradioTypography.microCap(
                        color: Colors.white.withValues(alpha: 0.50),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2-Row Dark Glass Telemetry Bento (Distance/Duration/Pace + Stride Length/Sync Integrity)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DarkStatItem(
                        label: 'Distance (km)',
                        value: ShareMetricFormat.distanceShort(metrics),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    Expanded(
                      child: _DarkStatItem(
                        label: 'Duration',
                        value: metrics.formattedDuration,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    Expanded(
                      child: _DarkStatItem(
                        label: 'Pace (/km)',
                        value: ShareMetricFormat.paceShort(metrics),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DarkStatItem(
                        label: 'Stride Length',
                        value: ShareMetricFormat.strideLengthMeters(metrics),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    Expanded(
                      child: _DarkStatItem(
                        label: 'Sync Integrity',
                        value: ShareMetricFormat.syncPercentText(metrics),
                        valueColor: StradioColors.rhythmViolet,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 10),
          _AudioStickerFooter(soundPack: soundPack, dark: true),
        ],
      ),
    );
  }
}

/// Reusable Smoked Obsidian Glassmorphism container (`.lg-obsidian-surface` in Mockups #05 & #06).
class _ObsidianGlassStickerSurface extends StatelessWidget {
  const _ObsidianGlassStickerSurface({
    required this.cardKey,
    required this.child,
  });

  final Key cardKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      width: 304,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF262638).withValues(alpha: 0.88),
            const Color(0xFF171723).withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Top-left diagonal specular glass highlight (.lg-specular-arc)
          Positioned(
            top: -40,
            left: -28,
            child: Transform.rotate(
              angle: -0.32,
              child: Container(
                width: 196,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(StradioRadii.full),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Subtle bottom-right Twilight Plum glass refraction glow
          Positioned(
            right: -30,
            bottom: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    StradioColors.twilightPlum.withValues(alpha: 0.24),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _StickerBrandHeader extends StatelessWidget {
  const _StickerBrandHeader({required this.dark, required this.badgeText});

  final bool dark;
  final String badgeText;

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? StradioColors.textOnDark : StradioColors.textPrimary;
    final subColor = dark
        ? Colors.white.withValues(alpha: 0.68)
        : StradioColors.textSecondary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/stradio-logo.png',
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: StradioColors.sonicCoral,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stradio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.headingSmall(
                        fontSize: 17,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      'Rhythm Biometrics',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.metricLabel(color: subColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : StradioColors.surfaceRecessed,
            borderRadius: BorderRadius.circular(StradioRadii.full),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.20)
                  : StradioColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: StradioColors.sonicCoral,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                badgeText,
                style: StradioTypography.microCap(color: titleColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ObsidianTelemetryThreeColBox extends StatelessWidget {
  const _ObsidianTelemetryThreeColBox({required this.metrics});

  final RunSummaryMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DarkStatItem(
              label: 'Distance (km)',
              value: ShareMetricFormat.distanceShort(metrics),
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          Expanded(
            child: _DarkStatItem(
              label: 'Duration',
              value: metrics.formattedDuration,
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          Expanded(
            child: _DarkStatItem(
              label: 'Pace (/km)',
              value: ShareMetricFormat.paceShort(metrics),
            ),
          ),
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
            height: 54 * (stems[i] / maxVal).clamp(0.20, 1.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: stems[i] >= 150
                    ? [
                        StradioColors.sonicCoral,
                        StradioColors.sonicCoral.withValues(alpha: 0.38),
                      ]
                    : (stems[i] >= 130
                          ? [
                              StradioColors.rhythmViolet,
                              StradioColors.rhythmViolet.withValues(
                                alpha: 0.38,
                              ),
                            ]
                          : [
                              StradioColors.borderSubtle,
                              StradioColors.borderSubtle.withValues(
                                alpha: 0.65,
                              ),
                            ]),
              ),
              borderRadius: BorderRadius.circular(StradioRadii.full),
            ),
          ),
      ],
    );
  }
}

class _ObsidianMiniStemRow extends StatelessWidget {
  const _ObsidianMiniStemRow({required this.stems});

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
            height: 26 * (stems[i] / maxVal).clamp(0.24, 1.0),
            decoration: BoxDecoration(
              color: stems[i] >= 152
                  ? StradioColors.sonicCoral
                  : (stems[i] >= 130
                        ? StradioColors.rhythmViolet
                        : Colors.white.withValues(alpha: 0.22)),
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
    final outerRadius = size.width * 0.48;
    final radius = size.width * 0.41;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Outer dashed ring
    const dashCount = 36;
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    for (var i = 0; i < dashCount; i++) {
      final start = (i * 2 * math.pi) / dashCount;
      canvas.drawArc(
        outerRect,
        start,
        (math.pi / dashCount) * 0.8,
        false,
        dashPaint,
      );
    }

    // 2. Base dial track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, trackPaint);

    // 3. Glowing coral-to-violet resonance arc
    if (progress > 0) {
      final sweep = (progress * math.pi * 2).clamp(0.35, math.pi * 1.78);
      final arcPaint = Paint()
        ..shader = const SweepGradient(
          colors: [
            StradioColors.sonicCoral,
            StradioColors.rhythmViolet,
            StradioColors.sonicCoral,
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      canvas.drawArc(rect, -math.pi / 2, sweep, false, arcPaint);
    }

    // 4. 4 Cardinal Node Dots (Top Coral, Right Violet, Bottom/Left White)
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius),
      4.0,
      Paint()..color = StradioColors.sonicCoral,
    );
    canvas.drawCircle(
      Offset(center.dx + radius, center.dy),
      3.2,
      Paint()..color = StradioColors.rhythmViolet,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + radius),
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      Offset(center.dx - radius, center.dy),
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
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
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: StradioTypography.headingSmall(fontSize: 19),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: StradioTypography.metricLabel(
              color: const Color(0xFF4A4658),
            ),
          ),
        ),
      ],
    );
  }
}

class _DarkStatItem extends StatelessWidget {
  const _DarkStatItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: StradioTypography.headingSmall(
              fontSize: 18,
              color: valueColor ?? StradioColors.textOnDark,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: StradioTypography.metricLabel(
              color: Colors.white.withValues(alpha: 0.68),
            ),
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
    final fg = dark ? StradioColors.textOnDark : StradioColors.textPrimary;
    final subFg = dark
        ? Colors.white.withValues(alpha: 0.62)
        : const Color(0xFF4A4658);
    final iconColor = dark
        ? Colors.white.withValues(alpha: 0.85)
        : StradioColors.twilightPlum;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? Colors.white.withValues(alpha: 0.10)
                      : StradioColors.surfaceRecessed,
                  border: Border.all(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.16)
                        : StradioColors.borderSubtle,
                  ),
                ),
                child: Icon(Icons.headphones_rounded, size: 13, color: iconColor),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adaptive Audio Mix',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.microCap(color: subFg),
                    ),
                    Text(
                      soundPack.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.pillBadge(color: fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(StradioRadii.full),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.16)
                  : StradioColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? StradioColors.sonicCoral
                      : StradioColors.midnight,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'STRADIO',
                style: StradioTypography.microCap(color: fg),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
