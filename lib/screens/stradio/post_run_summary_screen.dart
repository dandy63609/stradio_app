import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../evaluation/run_metrics_calculator.dart';
import '../../l10n/stradio_strings.dart';
import '../../models/experiment_models.dart';
import '../../models/sound_pack.dart';
import '../../services/posthog_service.dart';
import '../../services/recording_repository.dart';
import '../../theme/stradio_theme.dart';
import '../../widgets/liquid_glass_lens.dart';
import '../../widgets/sonic_ribbon_painter.dart';
import 'share_studio_screen.dart';

enum _StemFilter { all, active, walking }

/// Surface 3: Cadence Summary (`docs/DESIGN.md`, `docs/PRD-MVP.md` FR-5.4, & Mockup #11).
///
/// Renders:
/// - Dual-tone stacked header (`Cadence` / `Flow`) + `Export Story` pill button & `Active`/`Walking` stem filters.
/// - Top borderless Hero Metric (`156 spm` + `Average Stride Rhythm`).
/// - Recessed 12-14 Stem Visualizer Card (`min. spm · • • • · max. spm`).
/// - 2-Column Bento Cards: Left `TEMPO` breakdown (`Duration`, `Distance`, `Pace`, `CONSISTENCY`)
///   and Right `HARMONIC REFRACTION` featuring the 96px circular [LiquidGlassLens] refraction orb (`SYNC % Groove`).
/// - Midnight `56dp` bottom action capsule (`Start new run`) with white circular arrow disc.
class PostRunSummaryScreen extends StatefulWidget {
  const PostRunSummaryScreen({
    super.key,
    required this.recording,
    required this.metrics,
    required this.sensorHealth,
    required this.store,
    required this.postHogService,
    this.soundPackId = SoundPackId.breakbeatFvnky,
    this.language = AppLanguage.en,
    this.alreadySaved = false,
  });

  final SavedRecording recording;
  final RunSummaryMetrics metrics;
  final SensorHealthReport sensorHealth;
  final RecordingStore store;
  final PostHogTelemetryService postHogService;
  final SoundPackId soundPackId;
  final AppLanguage language;
  final bool alreadySaved;

  @override
  State<PostRunSummaryScreen> createState() => _PostRunSummaryScreenState();
}

class _PostRunSummaryScreenState extends State<PostRunSummaryScreen> {
  _StemFilter _filter = _StemFilter.all;
  bool _saving = false;
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.alreadySaved;
  }

  String _formatPace(RunSummaryMetrics m) {
    if (m.distanceKm <= 0.01 || m.activeDurationSeconds <= 0) return '--';
    final secPerKm = (m.activeDurationSeconds / m.distanceKm).round();
    final mins = secPerKm ~/ 60;
    final secs = (secPerKm % 60).toString().padLeft(2, '0');
    return '$mins:$secs /km';
  }

  String _formatSteps(int value) {
    final raw = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buf.write(',');
      buf.write(raw[i]);
    }
    return buf.toString();
  }

  void _openShareStudio() {
    final pack = StradioSoundPack.byId(widget.soundPackId);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ShareStudioScreen(
          metrics: widget.metrics,
          soundPack: pack,
          language: widget.language,
        ),
      ),
    );
  }

  Future<void> _saveAndStartNewRun() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (!_saved) {
        await widget.store.save(widget.recording.toSummaryOnly());
        await widget.store.clearActiveSessionCache();
        unawaited(
          widget.postHogService.captureWorkoutAndBenchmarks(
            recording: widget.recording,
            metrics: widget.metrics,
            health: widget.sensorHealth,
          ),
        );
        _saved = true;
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save run locally: $error')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(widget.language);
    final m = widget.metrics;
    final pack = StradioSoundPack.byId(widget.soundPackId);
    final hasCadence = m.averageCadenceSpm > 0;
    final avgSpmText = hasCadence ? '${m.averageCadenceSpm.round()}' : '--';
    final buckets = m.cadenceBucketsSpm.where((v) => v > 0).toList();
    final minSpm = buckets.isEmpty ? null : buckets.reduce(math.min).round();
    final maxSpm = buckets.isEmpty ? null : buckets.reduce(math.max).round();
    final syncPercent = m.rhythmScorePercent.round();
    final resonanceLabel = !hasCadence
        ? s.noStepsRecorded
        : (m.averageCadenceSpm >= 130
              ? s.strideResonanceLock
              : s.steadyWalkingFlow);

    return Scaffold(
      backgroundColor: StradioColors.warmIvory,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Row: Dual-Tone Stacked Header (Cadence / Flow) + Export Story Pill Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.cadenceTitle,
                                    style: StradioTypography.titlePrimary(),
                                  ),
                                  Text(
                                    s.flowTitle,
                                    style: StradioTypography.titleMuted(),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const Key('export_ig_story_button'),
                              onPressed: _openShareStudio,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: StradioColors.surfaceCard,
                                foregroundColor: StradioColors.textPrimary,
                                minimumSize: const Size(48, 42),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                side: const BorderSide(
                                  color: StradioColors.borderSubtle,
                                ),
                              ),
                              icon: const Icon(
                                Icons.auto_stories_rounded,
                                size: 16,
                              ),
                              label: Text(
                                s.exportIgStoryAction,
                                style: StradioTypography.microCap(
                                  color: StradioColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Interactive Active / Walking Filter Chips + Step Count
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _LegendChip(
                                  key: const Key('summary_filter_active'),
                                  label: s.activeFilterLabel,
                                  dotColor: StradioColors.sonicCoral,
                                  selected: _filter == _StemFilter.active,
                                  onTap: () => setState(() {
                                    _filter = _filter == _StemFilter.active
                                        ? _StemFilter.all
                                        : _StemFilter.active;
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _LegendChip(
                                  key: const Key('summary_filter_walking'),
                                  label: s.walkingFilterLabel,
                                  dotColor: StradioColors.rhythmViolet,
                                  selected: _filter == _StemFilter.walking,
                                  onTap: () => setState(() {
                                    _filter = _filter == _StemFilter.walking
                                        ? _StemFilter.all
                                        : _StemFilter.walking;
                                  }),
                                ),
                              ],
                            ),
                            Text(
                              s.stepsCountLabel(_formatSteps(m.totalSteps)),
                              style: StradioTypography.pillBadge(
                                color: StradioColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Mockup 11 Top Hero Metric: 156 spm + Average Stride Rhythm
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  avgSpmText,
                                  key: const Key('summary_avg_spm_value'),
                                  style: StradioTypography.metricHero(
                                    fontSize: 48,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'spm',
                                  style: StradioTypography.titleMuted(
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              resonanceLabel,
                              style: StradioTypography.metricLabel(
                                color: StradioColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Mockup 11 Recessed 12-14 Stem Visualizer Card
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          decoration: BoxDecoration(
                            color: StradioColors.surfaceRecessed.withValues(
                              alpha: 0.85,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: StradioColors.borderSubtle,
                            ),
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 100,
                                child: buckets.isEmpty
                                    ? Center(
                                        child: Text(
                                          s.emptyCadenceChartHint,
                                          textAlign: TextAlign.center,
                                          style: StradioTypography.body(
                                            fontSize: 13,
                                          ),
                                        ),
                                      )
                                    : _CadenceStemChart(
                                        bucketsSpm: buckets,
                                        filter: _filter,
                                      ),
                              ),
                              const SizedBox(height: 10),
                              const Divider(
                                height: 1,
                                color: StradioColors.borderSubtle,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    s.minSpmLabel(minSpm?.toString() ?? '--'),
                                    style: StradioTypography.metricLabel(),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var i = 0; i < 3; i++)
                                        Container(
                                          width: 4,
                                          height: 4,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: StradioColors.textSecondary
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    s.maxSpmLabel(maxSpm?.toString() ?? '--'),
                                    style: StradioTypography.metricLabel(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Mockup 11 2-Column Bento Cards: Left TEMPO Breakdown | Right HARMONIC REFRACTION Orb
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left Bento Card: TEMPO (Duration, Distance, Pace, Stride Consistency)
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: StradioColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: StradioColors.borderSubtle,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  StradioColors.surfaceRecessed,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    StradioRadii.full,
                                                  ),
                                            ),
                                            child: Text(
                                              'TEMPO',
                                              style: StradioTypography.microCap(
                                                color:
                                                    StradioColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              hasCadence ? 'STABLE' : 'IDLE',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: StradioTypography.microCap(
                                                color:
                                                    StradioColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _TempoStackItem(
                                        label: s.durationLabel,
                                        value: m.formattedDuration,
                                      ),
                                      const SizedBox(height: 8),
                                      _TempoStackItem(
                                        label: s.distanceLabel,
                                        value:
                                            '${m.distanceKm.toStringAsFixed(2)} km',
                                      ),
                                      const SizedBox(height: 8),
                                      _TempoStackItem(
                                        label: s.paceLabel,
                                        value: _formatPace(m),
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(
                                        height: 1,
                                        color: StradioColors.borderSubtle,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'CONSISTENCY',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: StradioTypography.microCap(
                                                color:
                                                    StradioColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '$syncPercent%',
                                            style: StradioTypography.pillBadge(
                                              color: StradioColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Right Bento Card: HARMONIC REFRACTION + 96px Circular LiquidGlassLens Orb
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: StradioColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: StradioColors.borderSubtle,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'HARMONIC\nREFRACTION',
                                              style: StradioTypography.microCap(
                                                color:
                                                    StradioColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.blur_on_rounded,
                                            size: 16,
                                            color: StradioColors.textSecondary,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // 96px Circular Harmonic Refraction Orb (sole LiquidGlassLens on Surface 3)
                                      SizedBox(
                                        width: 104,
                                        height: 104,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Subsurface Chromatic Ribbon Orb Underlay
                                            Container(
                                              width: 98,
                                              height: 98,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: const LinearGradient(
                                                  begin: Alignment.bottomLeft,
                                                  end: Alignment.topRight,
                                                  colors: [
                                                    StradioColors.twilightPlum,
                                                    StradioColors.rhythmViolet,
                                                    StradioColors.sonicCoral,
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: StradioColors
                                                        .rhythmViolet
                                                        .withValues(
                                                          alpha: 0.36,
                                                        ),
                                                    blurRadius: 16,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: const CustomPaint(
                                                painter: SonicRibbonPainter(
                                                  phase: 1.15,
                                                  amplitude: 0.75,
                                                  strokeWidth: 4.5,
                                                ),
                                              ),
                                            ),

                                            // Foreground Specular Liquid Glass Lens
                                            LiquidGlassLens(
                                              key: const Key(
                                                'summary_hero_glass_circle',
                                              ),
                                              shape: LiquidGlassShape.circle,
                                              width: 96,
                                              height: 96,
                                              edgeIntensity: 0.055,
                                              rippleEffect: 0.16,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'SYNC',
                                                    style: StradioTypography.microCap(
                                                      color: StradioColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                  Text(
                                                    '$syncPercent%',
                                                    style: StradioTypography.headingSmall(
                                                      fontSize: 19,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Groove',
                                                    style:
                                                        StradioTypography.metricLabel(
                                                          color: StradioColors
                                                              .textSecondary,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(
                                        height: 1,
                                        color: StradioColors.borderSubtle,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.headphones_rounded,
                                            size: 14,
                                            color: StradioColors.twilightPlum,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              pack.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  StradioTypography.pillBadge(
                                                    color: StradioColors
                                                        .textPrimary,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Mockup 11 Bottom Action Capsule: Midnight Pill ("Start new run") with white circular arrow disc
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
                  child: Material(
                    color: StradioColors.midnight,
                    borderRadius: BorderRadius.circular(StradioRadii.full),
                    child: InkWell(
                      key: const Key('start_new_run_button'),
                      borderRadius: BorderRadius.circular(StradioRadii.full),
                      onTap: _saving ? null : _saveAndStartNewRun,
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                _saving
                                    ? s.savingRunAction
                                    : s.startNewRunAction,
                                style: StradioTypography.buttonLabel(
                                  color: StradioColors.textOnDark,
                                ),
                              ),
                            ),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: StradioColors.surfaceCard,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: StradioColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _TempoStackItem extends StatelessWidget {
  const _TempoStackItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: StradioTypography.metricLabel()),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: StradioTypography.headingSmall(fontSize: 19),
          ),
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    super.key,
    required this.label,
    required this.dotColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color dotColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? StradioColors.surfaceCard
          : StradioColors.surfaceRecessed,
      borderRadius: BorderRadius.circular(StradioRadii.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(StradioRadii.full),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StradioRadii.full),
            border: Border.all(
              color: selected ? StradioColors.midnight : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: StradioTypography.metricLabel(
                  color: StradioColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3.5px vertical cadence stems inside the recessed card (Mockup 11).
class _CadenceStemChart extends StatelessWidget {
  const _CadenceStemChart({required this.bucketsSpm, required this.filter});

  final List<double> bucketsSpm;
  final _StemFilter filter;

  @override
  Widget build(BuildContext context) {
    final display = _downsampleToMax(bucketsSpm, 12);
    final maxVal = math.max(180.0, display.reduce(math.max));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < display.length; i++)
          _buildStem(display[i], maxVal, i),
      ],
    );
  }

  List<double> _downsampleToMax(List<double> source, int maxBars) {
    if (source.length <= maxBars) return source;
    final step = source.length / maxBars;
    return [for (var i = 0; i < maxBars; i++) source[(i * step).floor()]];
  }

  Widget _buildStem(double spm, double maxVal, int index) {
    final isJog = spm >= 130.0;
    final dimmed =
        (filter == _StemFilter.active && !isJog) ||
        (filter == _StemFilter.walking && isJog);

    final color = dimmed
        ? StradioColors.borderSubtle
        : (isJog
              ? (index % 3 == 0
                    ? StradioColors.twilightPlum
                    : StradioColors.sonicCoral)
              : StradioColors.rhythmViolet);

    final norm = (spm / maxVal).clamp(0.22, 1.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 3.5,
      height: 92 * norm,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(StradioRadii.full),
      ),
    );
  }
}
