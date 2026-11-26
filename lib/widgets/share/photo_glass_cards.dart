import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../evaluation/run_metrics_calculator.dart';
import '../../models/sound_pack.dart';
import '../../theme/stradio_theme.dart';
import 'share_template_models.dart';

/// Renders one of the 3 `Photo Glass` 9:16 P2 overlay templates (`docs/DESIGN.md` §8 & Mockups #01-#03):
/// - `Classic Wave`: Frosted 32px card + 4 outer corner anchor rings + Stradio header + 20 cadence stems
///   + 3 white frosted telemetry pods + bottom dual-layer filled acoustic ribbon crest.
/// - `Orbital Nexus`: Circular frosted orb with concentric dashed radar & 3D harmonic bell-curve mountain crest
///   interlocking with a 3-pod white frosted capsule dock + bottom ribbon wave.
/// - `Topo Shard`: Balanced architectural frosted matrix + 7-layer 3D topographic scanline ridge graph
///   + 3 icon-badged white frosted Bento pods (`DST`, `TIME`, `TEMPO`).
class PhotoGlassOverlayCard extends StatelessWidget {
  const PhotoGlassOverlayCard({
    super.key,
    required this.template,
    required this.metrics,
    required this.soundPack,
    required this.tintSeed,
  });

  final PhotoGlassTemplateId template;
  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;
  final Color tintSeed;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final fill = buildPhotoGlassFill(
      tintSeed: tintSeed,
      highContrast: highContrast,
    );

    return switch (template) {
      PhotoGlassTemplateId.classicWave => _ClassicWaveGlassCard(
        metrics: metrics,
        soundPack: soundPack,
        fill: fill,
        highContrast: highContrast,
      ),
      PhotoGlassTemplateId.orbitalNexus => _OrbitalNexusGlassCard(
        metrics: metrics,
        soundPack: soundPack,
        fill: fill,
        highContrast: highContrast,
      ),
      PhotoGlassTemplateId.topoShard => _TopoShardGlassCard(
        metrics: metrics,
        soundPack: soundPack,
        fill: fill,
        highContrast: highContrast,
      ),
    };
  }
}

class _FrostedSurface extends StatelessWidget {
  const _FrostedSurface({
    super.key,
    required this.borderRadius,
    required this.fill,
    required this.highContrast,
    required this.padding,
    required this.child,
    this.width,
    this.height,
  });

  final BorderRadius borderRadius;
  final Color fill;
  final bool highContrast;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (highContrast) {
      return Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: StradioColors.surfaceCard,
          borderRadius: borderRadius,
          border: Border.all(color: StradioColors.borderSubtle, width: 1.0),
        ),
        child: child,
      );
    }

    // Multi-layer transparent optical glassmorphism: lets the underlying photo glow
    // vividly through the pane with a directional sheen + diagonal specular highlight.
    final tint = Color.lerp(Colors.white, fill, 0.32) ?? Colors.white;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF080C16).withValues(alpha: 0.40),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.42, 0.72, 1.0],
                      colors: [
                        tint.withValues(alpha: 0.42),
                        tint.withValues(alpha: 0.16),
                        tint.withValues(alpha: 0.06),
                        tint.withValues(alpha: 0.24),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: const Alignment(0.4, 0.5),
                        stops: const [0.0, 0.45, 1.0],
                        colors: [
                          Colors.white.withValues(alpha: 0.40),
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.62),
                    width: 1.25,
                  ),
                ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1. Classic Wave (Mockup #01 - Streamlined):
/// Frosted 32px card + 4 corner anchor rings + Stradio Header + Hero SPM & status pill
/// + 20 colored cadence stems + 3 white frosted telemetry pods + bottom filled wave crest.
class _ClassicWaveGlassCard extends StatelessWidget {
  const _ClassicWaveGlassCard({
    required this.metrics,
    required this.soundPack,
    required this.fill,
    required this.highContrast,
  });

  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;
  final Color fill;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final stems = ShareMetricFormat.sampleStems(metrics, count: 20);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _FrostedSurface(
          key: const Key('photo_glass_classic_wave'),
          width: 282,
          borderRadius: BorderRadius.circular(32),
          fill: fill,
          highContrast: highContrast,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Lockup: Stradio Logo & Wordmark + Steps Pill
                    _GlassBrandHeader(
                      subtitle: 'Rhythm Biometrics',
                      badgeText: ShareMetricFormat.stepsPillLabel(metrics),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      color: StradioColors.midnight.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 10),

                    // Hero Metric Section: Big SPM + 1 Frosted Status Pill
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              ShareMetricFormat.avgSpm(metrics),
                              style: StradioTypography.metricHero(fontSize: 44),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'spm',
                              style: StradioTypography.titleMuted(fontSize: 18),
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
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(
                              StradioRadii.full,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.92),
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
                                    color: StradioColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 20 Colored Cadence Stems
                    SizedBox(
                      height: 48,
                      child: stems.isEmpty
                          ? Center(
                              child: Text(
                                'No cadence samples yet',
                                style: StradioTypography.metricLabel(),
                              ),
                            )
                          : _GlassStemBars(stems: stems),
                    ),
                    const SizedBox(height: 12),

                    // 3 White Frosted Telemetry Pods
                    Row(
                      children: [
                        Expanded(
                          child: _WhiteTelemetryPod(
                            value: ShareMetricFormat.distanceKm(metrics),
                            label: 'Distance',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _WhiteTelemetryPod(
                            value: metrics.formattedDuration,
                            label: 'Duration',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _WhiteTelemetryPod(
                            value: ShareMetricFormat.paceShort(metrics),
                            label: 'Pace (/km)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Footer: Adaptive Audio Mix + STRADIO Brand Tag
                    _GlassCardFooter(soundPack: soundPack),
                  ],
                ),
              ),

              // Bottom Dual-Layer Filled Acoustic Ribbon Wave
              const SizedBox(
                height: 22,
                child: CustomPaint(
                  painter: _BottomAcousticWaveCrestPainter(),
                ),
              ),
            ],
          ),
        ),
        const Positioned(top: -4, left: -4, child: _BoundingBoxCornerRing()),
        const Positioned(top: -4, right: -4, child: _BoundingBoxCornerRing()),
        const Positioned(bottom: -4, left: -4, child: _BoundingBoxCornerRing()),
        const Positioned(
          bottom: -4,
          right: -4,
          child: _BoundingBoxCornerRing(),
        ),
      ],
    );
  }
}

/// 2. Orbital Nexus (Mockup #02):
/// Circular frosted orb with dashed radar & 3D harmonic bell-curve mountain crest
/// interlocking with a 3-pod white frosted capsule dock + bottom ribbon wave.
class _OrbitalNexusGlassCard extends StatelessWidget {
  const _OrbitalNexusGlassCard({
    required this.metrics,
    required this.soundPack,
    required this.fill,
    required this.highContrast,
  });

  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;
  final Color fill;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('photo_glass_orbital_nexus'),
      width: 282,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Circular Frosted Orb (204x204)
          _FrostedSurface(
            width: 204,
            height: 204,
            borderRadius: BorderRadius.circular(StradioRadii.full),
            fill: fill,
            highContrast: highContrast,
            padding: EdgeInsets.zero,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Concentric Dashed Radar Ring + 3D Harmonic Bell-Curve Mountain Crest
                const Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: CustomPaint(
                      painter: _OrbitalMountainCrestPainter(),
                    ),
                  ),
                ),

                // Soft Radial Frosted Pillow behind SPM digits for crisp contrast
                Container(
                  width: 132,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        StradioColors.surfaceCard.withValues(alpha: 0.90),
                        StradioColors.surfaceCard.withValues(alpha: 0.55),
                        StradioColors.surfaceCard.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            ShareMetricFormat.avgSpm(metrics),
                            style: StradioTypography.metricHero(fontSize: 42),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'spm',
                            style: StradioTypography.titleMuted(fontSize: 16),
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
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(
                            StradioRadii.full,
                          ),
                          border: Border.all(color: Colors.white),
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
                ),
              ],
            ),
          ),

          // Interlocking Lower Capsule Dock (subtle 8px overlap with Orb)
          Transform.translate(
            offset: const Offset(0, -8),
            child: _FrostedSurface(
              width: 282,
              borderRadius: BorderRadius.circular(28),
              fill: fill,
              highContrast: highContrast,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _WhiteTelemetryPod(
                          value: ShareMetricFormat.distanceKm(metrics),
                          label: 'Distance',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _WhiteTelemetryPod(
                          value: metrics.formattedDuration,
                          label: 'Duration',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _WhiteTelemetryPod(
                          value: ShareMetricFormat.paceShort(metrics),
                          label: 'Pace (/km)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _GlassCardFooter(soundPack: soundPack),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(StradioRadii.full),
                    child: const SizedBox(
                      height: 10,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _BottomAcousticWaveCrestPainter(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. Topo Shard (Mockup #03 - Balanced Architectural):
/// Architectural frosted card + Stradio Rhythm Matrix header + Hero SPM + 7-layer 3D Topographic Scanline
/// Ridge Graph (without cluttered Z-INDEX text boxes) + 3 icon-badged white frosted Bento pods (`DST`, `TIME`, `TEMPO`).
class _TopoShardGlassCard extends StatelessWidget {
  const _TopoShardGlassCard({
    required this.metrics,
    required this.soundPack,
    required this.fill,
    required this.highContrast,
  });

  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;
  final Color fill;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final series = ShareMetricFormat.sampleStems(metrics, count: 9);

    return _FrostedSurface(
      key: const Key('photo_glass_topo_shard'),
      width: 284,
      borderRadius: BorderRadius.zero,
      fill: fill,
      highContrast: highContrast,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Lockup: Stradio + TOPO SHARD subtitle + 100 HZ IMU pill
          _GlassBrandHeader(
            subtitle: 'TOPO SHARD',
            badgeText: '100 HZ IMU',
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: StradioColors.midnight.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 8),

          // Hero Row: Big SPM on left + 1 clean resonance badge on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    ShareMetricFormat.avgSpm(metrics),
                    style: StradioTypography.metricHero(fontSize: 36),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SPM',
                    style: StradioTypography.microCap(
                      color: StradioColors.textAccentDeep,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: StradioColors.glowVioletSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: StradioColors.twilightPlum.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    ShareMetricFormat.resonanceLabel(metrics),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StradioTypography.microCap(
                      color: StradioColors.twilightPlum,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 7-Layer 3D Topographic Scanline Ridge Graph (clean, no floating Z-INDEX text boxes)
          Container(
            height: 88,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            child: CustomPaint(
              painter: _TopoScanlineRidgePainter(series: series),
            ),
          ),
          const SizedBox(height: 10),

          // 3 Icon-Badged White Frosted Bento Metric Pods (DST, TIME, TEMPO)
          Row(
            children: [
              Expanded(
                child: _TopoBentoPod(
                  code: 'DST',
                  codeColor: StradioColors.textAccentDeep,
                  icon: Icons.trending_up_rounded,
                  value: ShareMetricFormat.distanceShort(metrics),
                  subtitle: 'Distance (km)',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TopoBentoPod(
                  code: 'TIME',
                  codeColor: StradioColors.twilightPlum,
                  icon: Icons.timer_outlined,
                  value: metrics.formattedDuration,
                  subtitle: 'Duration',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TopoBentoPod(
                  code: 'TEMPO',
                  codeColor: StradioColors.rhythmViolet,
                  icon: Icons.speed_rounded,
                  value: ShareMetricFormat.paceShort(metrics),
                  subtitle: 'Pace (/km)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: StradioColors.midnight.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 8),
          _GlassCardFooter(soundPack: soundPack),
        ],
      ),
    );
  }
}

class _GlassBrandHeader extends StatelessWidget {
  const _GlassBrandHeader({required this.subtitle, required this.badgeText});

  final String subtitle;
  final String badgeText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/stradio-logo.png',
                height: 22,
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
                      style: StradioTypography.headingSmall(fontSize: 16),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.microCap(
                        color: StradioColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(StradioRadii.full),
            border: Border.all(color: Colors.white),
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
                style: StradioTypography.microCap(
                  color: StradioColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhiteTelemetryPod extends StatelessWidget {
  const _WhiteTelemetryPod({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.46),
            Colors.white.withValues(alpha: 0.22),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: StradioTypography.headingSmall(fontSize: 17),
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
      ),
    );
  }
}

class _TopoBentoPod extends StatelessWidget {
  const _TopoBentoPod({
    required this.code,
    required this.codeColor,
    required this.icon,
    required this.value,
    required this.subtitle,
  });

  final String code;
  final Color codeColor;
  final IconData icon;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.46),
            Colors.white.withValues(alpha: 0.22),
          ],
        ),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StradioTypography.microCap(color: codeColor),
                ),
              ),
              Icon(icon, size: 12, color: StradioColors.textSecondary),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: StradioTypography.headingSmall(fontSize: 16),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: StradioTypography.metricLabel(
                color: const Color(0xFF4A4658),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCardFooter extends StatelessWidget {
  const _GlassCardFooter({required this.soundPack});

  final StradioSoundPack soundPack;

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.white.withValues(alpha: 0.82),
                  border: Border.all(color: Colors.white),
                ),
                child: const Icon(
                  Icons.headphones_rounded,
                  size: 13,
                  color: StradioColors.twilightPlum,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adaptive Audio Mix',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.microCap(
                        color: const Color(0xFF4A4658),
                      ),
                    ),
                    Text(
                      soundPack.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.pillBadge(
                        color: StradioColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const _StradioBrandWatermark(),
      ],
    );
  }
}

/// 4 outer bounding-box corner rings shown in Mockups #01 & #02.
class _BoundingBoxCornerRing extends StatelessWidget {
  const _BoundingBoxCornerRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: StradioColors.midnight, width: 2.2),
      ),
    );
  }
}

/// Dual-layer filled coral-violet wave crest along the bottom edge of Classic Wave & Orbital Nexus.
class _BottomAcousticWaveCrestPainter extends CustomPainter {
  const _BottomAcousticWaveCrestPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final pathA = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.58)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.15,
        size.width * 0.48,
        size.height * 0.82,
        size.width * 0.72,
        size.height * 0.30,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.05,
        size.width,
        size.height * 0.22,
      )
      ..lineTo(size.width, size.height)
      ..close();

    final paintA = Paint()
      ..shader = const LinearGradient(
        colors: [
          StradioColors.sonicCoral,
          Color(0xFFFC745D),
          StradioColors.rhythmViolet,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(pathA, paintA);

    final pathB = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.74)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.42,
        size.width * 0.56,
        size.height * 0.92,
        size.width * 0.80,
        size.height * 0.50,
      )
      ..quadraticBezierTo(
        size.width * 0.92,
        size.height * 0.32,
        size.width,
        size.height * 0.46,
      )
      ..lineTo(size.width, size.height)
      ..close();

    final paintB = Paint()
      ..shader = LinearGradient(
        colors: [
          StradioColors.twilightPlum.withValues(alpha: 0.82),
          StradioColors.rhythmViolet.withValues(alpha: 0.78),
          StradioColors.sonicCoral.withValues(alpha: 0.85),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(pathB, paintB);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints the concentric dashed radar ring & 3D harmonic bell-curve mountain crest inside Orbital Nexus (Mockup #02).
class _OrbitalMountainCrestPainter extends CustomPainter {
  const _OrbitalMountainCrestPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width * 0.5, size.height * 0.48);
    final radarR = size.width * 0.36;

    // 1. Dashed concentric radar ring
    const dashCount = 36;
    final dashPaint = Paint()
      ..color = StradioColors.twilightPlum.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final radarRect = Rect.fromCircle(center: center, radius: radarR);
    for (var i = 0; i < dashCount; i++) {
      final angle = (i * 2 * math.pi) / dashCount;
      canvas.drawArc(
        radarRect,
        angle,
        (math.pi / dashCount) * 0.85,
        false,
        dashPaint,
      );
    }

    // 2. Layered Gaussian bell-curve mountain ridges rising in the upper hemisphere
    for (var layer = 4; layer >= 0; layer--) {
      final isMainCrest = layer == 1;
      final isTopEcho = layer == 0;
      final baseY = size.height * (0.37 + layer * 0.065);
      final peakLift = size.height * (0.23 - layer * 0.025);

      final path = Path();
      const steps = 40;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final x = size.width * (0.14 + t * 0.72);
        final u = (t - 0.5) * 3.8;
        final bell = math.exp(-u * u);
        final y = baseY - bell * peakLift;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final paint = Paint()
        ..color = isMainCrest
            ? StradioColors.sonicCoral
            : (isTopEcho
                  ? StradioColors.sonicCoral.withValues(alpha: 0.55)
                  : StradioColors.twilightPlum.withValues(
                      alpha: (0.45 - layer * 0.07).clamp(0.15, 0.45),
                    ))
        ..style = PaintingStyle.stroke
        ..strokeWidth = isMainCrest ? 2.4 : 1.1
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      canvas.drawPath(path, paint);
    }

    // 3. Glowing apex node at the summit of the bell curve
    final apex = Offset(size.width * 0.5, size.height * 0.16);
    canvas.drawCircle(
      apex,
      4.2,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      apex,
      4.2,
      Paint()
        ..color = StradioColors.sonicCoral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints the 7-layer 3D Topographic Scanline Ridge Graph over a subtle technical grid (Mockup #03).
class _TopoScanlineRidgePainter extends CustomPainter {
  const _TopoScanlineRidgePainter({required this.series});

  final List<double> series;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // 1. Subtle technical background grid
    final gridPaint = Paint()
      ..color = StradioColors.textSecondary.withValues(alpha: 0.14)
      ..strokeWidth = 0.7;
    for (var c = 1; c < 6; c++) {
      final x = (c / 6) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var r = 1; r < 5; r++) {
      final y = (r / 5) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Normalize cadence profile with a prominent center ridge peak
    final profile = series.isEmpty
        ? const [0.12, 0.15, 0.34, 0.68, 0.96, 0.74, 0.42, 0.18, 0.14]
        : [
            for (var i = 0; i < series.length; i++)
              ((series[i] - 90.0) / 100.0).clamp(0.15, 0.96),
          ];

    var apexIndex = 0;
    var maxVal = -1.0;
    for (var i = 0; i < profile.length; i++) {
      if (profile[i] > maxVal) {
        maxVal = profile[i];
        apexIndex = i;
      }
    }

    // 2. Draw 7 stacked topographic ridge lines
    const ridgeCount = 7;
    const mainRidge = 3;
    Offset? mainApexPoint;

    for (var r = 0; r < ridgeCount; r++) {
      final baseY = size.height * (0.20 + r * 0.115);
      final liftScale = size.height * (0.18 + (1.0 - (r - mainRidge).abs() * 0.18) * 0.16);
      final path = Path();
      final points = <Offset>[];

      for (var i = 0; i < profile.length; i++) {
        final t = i / math.max(1, profile.length - 1);
        final x = t * size.width;
        final bellWeight = math.sin(t * math.pi);
        final y = (baseY - profile[i] * liftScale * bellWeight).clamp(
          4.0,
          size.height - 3.0,
        );
        final pt = Offset(x, y);
        points.add(pt);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      if (r == mainRidge) {
        mainApexPoint = points[apexIndex];
        // Shaded gradient underbody beneath dominant coral ridge
        final fillPath = Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                StradioColors.sonicCoral.withValues(alpha: 0.22),
                StradioColors.rhythmViolet.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ).createShader(Offset.zero & size),
        );
      }

      final isMain = r == mainRidge;
      final strokePaint = Paint()
        ..color = isMain
            ? StradioColors.sonicCoral
            : StradioColors.twilightPlum.withValues(
                alpha: (0.68 - (r - mainRidge).abs() * 0.14).clamp(0.24, 0.68),
              )
        ..style = PaintingStyle.stroke
        ..strokeWidth = isMain ? 2.3 : 1.1
        ..strokeJoin = StrokeJoin.miter
        ..isAntiAlias = true;
      canvas.drawPath(path, strokePaint);
    }

    // 3. Dashed vertical drop-line & apex coordinate dot
    if (mainApexPoint != null) {
      final dropPaint = Paint()
        ..color = StradioColors.sonicCoral.withValues(alpha: 0.75)
        ..strokeWidth = 1.0;
      var y = mainApexPoint.dy + 4;
      while (y < size.height - 2) {
        canvas.drawLine(
          Offset(mainApexPoint.dx, y),
          Offset(mainApexPoint.dx, math.min(y + 3, size.height - 2)),
          dropPaint,
        );
        y += 6;
      }

      canvas.drawCircle(
        mainApexPoint,
        3.5,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        mainApexPoint,
        3.5,
        Paint()
          ..color = StradioColors.sonicCoral
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TopoScanlineRidgePainter oldDelegate) =>
      oldDelegate.series != series;
}

/// Promotional STRADIO logo & wordmark stamp embedded on exported Photo Glass cards.
class _StradioBrandWatermark extends StatelessWidget {
  const _StradioBrandWatermark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(StradioRadii.full),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.90),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/stradio-logo.png',
            height: 11,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: StradioColors.sonicCoral,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'STRADIO',
            style: StradioTypography.microCap(
              color: StradioColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassStemBars extends StatelessWidget {
  const _GlassStemBars({required this.stems});

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
            width: 3.0,
            height: 44 * (stems[i] / maxVal).clamp(0.20, 1.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: stems[i] >= 150
                    ? [
                        StradioColors.sonicCoral,
                        StradioColors.sonicCoral.withValues(alpha: 0.45),
                      ]
                    : (stems[i] >= 130
                          ? [
                              StradioColors.rhythmViolet,
                              StradioColors.rhythmViolet.withValues(
                                alpha: 0.45,
                              ),
                            ]
                          : [
                              const Color(0xFF3C3947).withValues(alpha: 0.32),
                              const Color(0xFF3C3947).withValues(alpha: 0.16),
                            ]),
              ),
              borderRadius: BorderRadius.circular(StradioRadii.full),
            ),
          ),
      ],
    );
  }
}
