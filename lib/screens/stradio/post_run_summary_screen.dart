import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../evaluation/run_metrics_calculator.dart';
import '../../models/experiment_models.dart';
import '../../models/sound_pack.dart';
import '../../services/posthog_service.dart';
import '../../services/recording_repository.dart';
import '../../theme/stradio_theme.dart';
import '../../widgets/liquid_glass_lens.dart';
import '../../widgets/sonic_ribbon_painter.dart';
import 'share_studio_screen.dart';

enum _StemFilter { all, active, walking }

/// Surface 3: Cadence Summary (`docs/DESIGN.md` & `docs/PRD-MVP.md` FR-5.4).
///
/// Renders:
/// - Dual-tone stacked header (`Cadence` / `Flow`) + interactive `Active` / `Walking` stem filters.
/// - Hero Glass Circle ([LiquidGlassLens], 1 glass element per `R-10`) showing average SPM & stride ribbons.
/// - 3 Frosted/Alabaster Metric Pills (Distance, Duration, Pace: honest real-data values only).
/// - Minimal 3.5px vertical cadence stems (`14px` spacing) with min/max SPM.
/// - Audio Footer Pill + `Export IG Story` (`ShareRhythmModal`) & solid Midnight `Start new run`.
class PostRunSummaryScreen extends StatefulWidget {
  const PostRunSummaryScreen({
    super.key,
    required this.recording,
    required this.metrics,
    required this.sensorHealth,
    required this.store,
    required this.postHogService,
    this.soundPackId = SoundPackId.breakbeatFvnky,
    this.alreadySaved = false,
  });

  final SavedRecording recording;
  final RunSummaryMetrics metrics;
  final SensorHealthReport sensorHealth;
  final RecordingStore store;
  final PostHogTelemetryService postHogService;
  final SoundPackId soundPackId;
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
    final m = widget.metrics;
    final pack = StradioSoundPack.byId(widget.soundPackId);
    final hasCadence = m.averageCadenceSpm > 0;
    final avgSpmText = hasCadence ? '${m.averageCadenceSpm.round()}' : '--';
    final buckets = m.cadenceBucketsSpm.where((v) => v > 0).toList();
    final minSpm = buckets.isEmpty ? null : buckets.reduce(math.min).round();
    final maxSpm = buckets.isEmpty ? null : buckets.reduce(math.max).round();
    final resonanceLabel = !hasCadence
        ? 'No steps recorded'
        : (m.averageCadenceSpm >= 130
              ? 'Stride Resonance Lock'
              : 'Steady Walking Flow');

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
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dual-Tone Stacked Header (Cadence / Flow)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cadence',
                                    style: StradioTypography.titlePrimary(),
                                  ),
                                  Text(
                                    'Flow',
                                    style: StradioTypography.titleMuted(),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              hasCadence
                                  ? 'Avg. ${m.averageCadenceSpm.round()} spm'
                                  : 'Avg. -- spm',
                              style: StradioTypography.pillBadge(
                                color: StradioColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Hero Glass Circle (sole LiquidGlassLens on Surface 3 per R-10)
                        Center(
                          child: SizedBox(
                            width: 212,
                            height: 212,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 212,
                                  height: 212,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: StradioColors.surfaceRecessed,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: const CustomPaint(
                                    painter: SonicRibbonPainter(
                                      phase: 1.0,
                                      amplitude: 0.72,
                                      strokeWidth: 2.6,
                                    ),
                                  ),
                                ),
                                LiquidGlassLens(
                                  key: const Key('summary_hero_glass_circle'),
                                  shape: LiquidGlassShape.circle,
                                  width: 176,
                                  height: 176,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        avgSpmText,
                                        key: const Key('summary_avg_spm_value'),
                                        style: StradioTypography.metricHero(
                                          fontSize: 44,
                                        ),
                                      ),
                                      Text(
                                        'spm',
                                        style: StradioTypography.metricLabel(),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: StradioColors.midnight
                                              .withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                            StradioRadii.full,
                                          ),
                                        ),
                                        child: Text(
                                          resonanceLabel,
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
                        ),
                        const SizedBox(height: 20),

                        // 3 Frosted Metric Pills: Distance, Duration, Pace
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryMetricPill(
                                label: 'Distance',
                                value: '${m.distanceKm.toStringAsFixed(2)} km',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryMetricPill(
                                label: 'Duration',
                                value: m.formattedDuration,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryMetricPill(
                                label: 'Pace',
                                value: _formatPace(m),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Interactive Active / Walking Stem Filter Legend
                        Row(
                          children: [
                            _LegendChip(
                              key: const Key('summary_filter_active'),
                              label: 'Active',
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
                              label: 'Walking',
                              dotColor: StradioColors.rhythmViolet,
                              selected: _filter == _StemFilter.walking,
                              onTap: () => setState(() {
                                _filter = _filter == _StemFilter.walking
                                    ? _StemFilter.all
                                    : _StemFilter.walking;
                              }),
                            ),
                            const Spacer(),
                            Text(
                              '${_formatSteps(m.totalSteps)} steps',
                              style: StradioTypography.pillBadge(
                                color: StradioColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Minimal 3.5px Vertical Cadence Stems directly on Warm Ivory
                        SizedBox(
                          height: 108,
                          child: buckets.isEmpty
                              ? Center(
                                  child: Text(
                                    'Complete a few steps to chart cadence rhythm.',
                                    style: StradioTypography.body(fontSize: 13),
                                  ),
                                )
                              : _CadenceStemChart(
                                  bucketsSpm: buckets,
                                  filter: _filter,
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              minSpm != null
                                  ? 'min. $minSpm spm'
                                  : 'min. -- spm',
                              style: StradioTypography.metricLabel(),
                            ),
                            Text(
                              maxSpm != null
                                  ? 'max. $maxSpm spm'
                                  : 'max. -- spm',
                              style: StradioTypography.metricLabel(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Audio Footer Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: StradioColors.surfaceCard,
                            borderRadius: BorderRadius.circular(
                              StradioRadii.full,
                            ),
                            border: Border.all(
                              color: StradioColors.borderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.headphones_rounded,
                                size: 18,
                                color: StradioColors.twilightPlum,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  pack.title,
                                  style: StradioTypography.pillBadge(),
                                ),
                              ),
                              Text(
                                '${m.rhythmScorePercent.round()}% sync',
                                style: StradioTypography.metricLabel(
                                  color: StradioColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Thumb Actions: Export IG Story + Start new run
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          key: const Key('export_ig_story_button'),
                          onPressed: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => ShareStudioScreen(
                                  metrics: m,
                                  soundPack: pack,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: const Text('Export IG Story'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          key: const Key('start_new_run_button'),
                          onPressed: _saving ? null : _saveAndStartNewRun,
                          child: Text(
                            _saving ? 'Saving run...' : 'Start new run',
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
      ),
    );
  }
}

class _SummaryMetricPill extends StatelessWidget {
  const _SummaryMetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: StradioColors.surfaceCard,
        borderRadius: BorderRadius.circular(StradioRadii.lg),
        border: Border.all(color: StradioColors.borderSubtle),
      ),
      child: Column(
        children: [
          Text(label, style: StradioTypography.metricLabel()),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: StradioTypography.pillBadge()),
          ),
        ],
      ),
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
          constraints: const BoxConstraints(minHeight: 36),
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
              Text(label, style: StradioTypography.metricLabel(
                color: StradioColors.textPrimary,
              )),
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

/// 3.5px vertical cadence stems spaced cleanly on Warm Ivory (`docs/DESIGN.md` §5).
class _CadenceStemChart extends StatelessWidget {
  const _CadenceStemChart({required this.bucketsSpm, required this.filter});

  final List<double> bucketsSpm;
  final _StemFilter filter;

  @override
  Widget build(BuildContext context) {
    final display = _downsampleToMax(bucketsSpm, 14);
    final maxVal = math.max(180.0, display.reduce(math.max));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
    return [
      for (var i = 0; i < maxBars; i++) source[(i * step).floor()],
    ];
  }

  Widget _buildStem(double spm, double maxVal, int index) {
    final isJog = spm >= 130.0;
    final dimmed =
        (filter == _StemFilter.active && !isJog) ||
        (filter == _StemFilter.walking && isJog);

    final color = dimmed
        ? StradioColors.borderSubtle
        : (isJog
              ? (index.isEven
                    ? StradioColors.twilightPlum
                    : StradioColors.sonicCoral)
              : StradioColors.rhythmViolet);

    final norm = (spm / maxVal).clamp(0.18, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 3.5,
          height: 86 * norm,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(StradioRadii.full),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 3.5,
          height: 3.5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ],
    );
  }
}
