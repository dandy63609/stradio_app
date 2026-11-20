import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../evaluation/run_metrics_calculator.dart';
import '../../models/sound_pack.dart';
import '../../theme/stradio_theme.dart';
import '../sonic_ribbon_painter.dart';
import 'share_template_models.dart';

/// Renders one of the 3 `Photo Glass` 9:16 P2 overlay templates (`docs/DESIGN.md` §8):
/// - `Classic Wave`: 36px frosted card + 4 corner anchor dots + 20 cadence stems + ribbon
/// - `Orbital Nexus`: canonical Stitch circular orb + interlocking 3-pod capsule dock
/// - `Topo Shard`: sharp architectural frosted matrix + faceted topographic ridge graph
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
    final inner = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(
          color: highContrast
              ? StradioColors.borderSubtle
              : StradioColors.surfaceGlassRim,
          width: 1.2,
        ),
      ),
      child: child,
    );

    if (highContrast) return inner;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: inner,
      ),
    );
  }
}

/// 1. Classic Wave: Rounded 36px frosted card with 4 corner anchor dots, 20 cadence stems, and bottom ribbon.
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
    return _FrostedSurface(
      key: const Key('photo_glass_classic_wave'),
      width: 248,
      borderRadius: BorderRadius.circular(32),
      fill: fill,
      highContrast: highContrast,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [_AnchorDot(), _AnchorDot()],
          ),
          const SizedBox(height: 6),
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
                        ShareMetricFormat.avgSpm(metrics),
                        style: StradioTypography.metricHero(fontSize: 34),
                      ),
                      const SizedBox(width: 5),
                      Text('spm', style: StradioTypography.metricLabel()),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                metrics.formattedDuration,
                style: StradioTypography.pillBadge(
                  color: StradioColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SlateMetric(
                label: 'Distance',
                value: ShareMetricFormat.distanceKm(metrics),
              ),
              _SlateMetric(
                label: 'Pace',
                value: ShareMetricFormat.pace(metrics),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SizedBox(
            height: 22,
            child: CustomPaint(
              painter: SonicRibbonPainter(
                phase: 1.2,
                amplitude: 0.8,
                strokeWidth: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _AnchorDot(),
              Flexible(
                child: Text(
                  soundPack.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StradioTypography.metricLabel(
                    color: StradioColors.textPrimary,
                  ),
                ),
              ),
              const _AnchorDot(),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2. Orbital Nexus (Canonical Stitch Hero): Circular frosted orb + interlocking 3-pod capsule dock.
/// Strictly excludes extraneous timestamps or header logos inside the hero circle (`PRD-MVP.md` FR-5.4).
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
      width: 256,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FrostedSurface(
            width: 184,
            height: 184,
            borderRadius: BorderRadius.circular(StradioRadii.full),
            fill: fill,
            highContrast: highContrast,
            padding: EdgeInsets.zero,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: CustomPaint(
                      painter: SonicRibbonPainter(
                        phase: 0.85,
                        amplitude: 0.66,
                        strokeWidth: 2.2,
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ShareMetricFormat.avgSpm(metrics),
                      style: StradioTypography.metricHero(fontSize: 40),
                    ),
                    Text('spm', style: StradioTypography.metricLabel()),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: StradioColors.midnight.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(StradioRadii.full),
                      ),
                      child: Text(
                        ShareMetricFormat.resonanceLabel(metrics),
                        style: StradioTypography.microCap(
                          color: StradioColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Interlocking 3-Pod Frosted Capsule Dock
          _FrostedSurface(
            width: 256,
            borderRadius: BorderRadius.circular(24),
            fill: fill,
            highContrast: highContrast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SlateMetric(
                        label: 'Distance',
                        value: ShareMetricFormat.distanceKm(metrics),
                        centered: true,
                      ),
                    ),
                    Expanded(
                      child: _SlateMetric(
                        label: 'Duration',
                        value: metrics.formattedDuration,
                        centered: true,
                      ),
                    ),
                    Expanded(
                      child: _SlateMetric(
                        label: 'Pace',
                        value: ShareMetricFormat.paceShort(metrics),
                        centered: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.headphones_rounded,
                      size: 13,
                      color: StradioColors.twilightPlum,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        soundPack.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StradioTypography.metricLabel(
                          color: StradioColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. Topo Shard: Architectural frosted glass matrix with faceted topographic ridge graph and 3 tiles.
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
    final series = ShareMetricFormat.sampleStems(metrics, count: 10);

    return _FrostedSurface(
      key: const Key('photo_glass_topo_shard'),
      width: 252,
      borderRadius: BorderRadius.circular(12),
      fill: fill,
      highContrast: highContrast,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOPO SHARD',
                style: StradioTypography.microCap(
                  color: StradioColors.textPrimary,
                ),
              ),
              Text(
                '${ShareMetricFormat.avgSpm(metrics)} spm',
                style: StradioTypography.pillBadge(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Faceted Topographic Ridge Graph
          SizedBox(
            height: 64,
            child: CustomPaint(
              painter: _TopoRidgePainter(series: series),
            ),
          ),
          const SizedBox(height: 12),

          // 3 Architectural Metric Tiles (DST, TIME, TEMPO)
          Row(
            children: [
              Expanded(
                child: _TopoTile(
                  code: 'DST',
                  value: ShareMetricFormat.distanceShort(metrics),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TopoTile(
                  code: 'TIME',
                  value: metrics.formattedDuration,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TopoTile(
                  code: 'TEMPO',
                  value: ShareMetricFormat.paceShort(metrics),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.headphones_rounded,
                size: 13,
                color: StradioColors.twilightPlum,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  soundPack.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StradioTypography.metricLabel(
                    color: StradioColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopoRidgePainter extends CustomPainter {
  const _TopoRidgePainter({required this.series});

  final List<double> series;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final values = series.isEmpty
        ? const [0.35, 0.42, 0.38, 0.44, 0.40, 0.45, 0.39]
        : [
            for (final v in series) (v / 190.0).clamp(0.18, 0.95),
          ];

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = (i / math.max(1, values.length - 1)) * size.width;
      final y = size.height * (1.0 - values[i]);
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(0, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(size.width, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          StradioColors.twilightPlum.withValues(alpha: 0.28),
          StradioColors.sonicCoral.withValues(alpha: 0.06),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final strokePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      strokePath.lineTo(points[i].dx, points[i].dy);
    }
    final strokePaint = Paint()
      ..color = StradioColors.midnight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..isAntiAlias = true;
    canvas.drawPath(strokePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TopoRidgePainter oldDelegate) =>
      oldDelegate.series != series;
}

class _TopoTile extends StatelessWidget {
  const _TopoTile({required this.code, required this.value});

  final String code;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: StradioColors.midnight.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            code,
            style: StradioTypography.microCap(
              color: const Color(0xFF4A4658),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: StradioTypography.pillBadge()),
          ),
        ],
      ),
    );
  }
}

class _AnchorDot extends StatelessWidget {
  const _AnchorDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: StradioColors.midnight,
      ),
    );
  }
}

class _SlateMetric extends StatelessWidget {
  const _SlateMetric({
    required this.label,
    required this.value,
    this.centered = false,
  });

  final String label;
  final String value;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: StradioTypography.metricLabel(
            color: const Color(0xFF4A4658),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: StradioTypography.pillBadge()),
        ),
      ],
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
            height: 44 * (stems[i] / maxVal).clamp(0.18, 1.0),
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
