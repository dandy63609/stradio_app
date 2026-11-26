import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/stradio_strings.dart';
import '../models/sound_pack.dart';
import '../services/preferences_service.dart';
import '../theme/stradio_theme.dart';

/// Glassmorphism `Run & Rhythm Target` modal sheet opened from Pre-Run Ignition (Foto 3).
///
/// 4 cards:
/// 1. Target Pace slider (`Fast` -> `Easy` + live estimated cadence)
/// 2. Target Distance chips (`3.0 km`, `5.0 km`, `10.0 km`, `Custom` with expandable slider)
/// 3. Sync Integrity progress bar + tap-to-lock optimal harmonic pace
/// 4. Adaptive Tempo Scaling toggle (wired to `StradioPreferencesService` + `StradioAudioEngine`)
class TargetCalibrationSheet extends StatefulWidget {
  const TargetCalibrationSheet({
    super.key,
    required this.initialPaceSecondsPerKm,
    required this.initialDistanceKm,
    required this.activePack,
    required this.onApply,
    this.initialAdaptiveTempoScaling = true,
    this.onAdaptiveTempoScalingChanged,
    this.language = AppLanguage.en,
  });

  final int initialPaceSecondsPerKm;
  final double initialDistanceKm;
  final StradioSoundPack activePack;
  final void Function(int paceSecondsPerKm, double distanceKm) onApply;
  final bool initialAdaptiveTempoScaling;
  final void Function(bool enabled)? onAdaptiveTempoScalingChanged;
  final AppLanguage language;

  static Future<void> show(
    BuildContext context, {
    required int initialPaceSecondsPerKm,
    required double initialDistanceKm,
    required StradioSoundPack activePack,
    required void Function(int paceSecondsPerKm, double distanceKm) onApply,
    bool initialAdaptiveTempoScaling = true,
    void Function(bool enabled)? onAdaptiveTempoScalingChanged,
    AppLanguage language = AppLanguage.en,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (_) => TargetCalibrationSheet(
        initialPaceSecondsPerKm: initialPaceSecondsPerKm,
        initialDistanceKm: initialDistanceKm,
        activePack: activePack,
        onApply: onApply,
        initialAdaptiveTempoScaling: initialAdaptiveTempoScaling,
        onAdaptiveTempoScalingChanged: onAdaptiveTempoScalingChanged,
        language: language,
      ),
    );
  }

  @override
  State<TargetCalibrationSheet> createState() => _TargetCalibrationSheetState();
}

class _TargetCalibrationSheetState extends State<TargetCalibrationSheet> {
  static const _presetDistances = [3.0, 5.0, 10.0];

  late int _paceSec;
  late double _distanceKm;
  late bool _adaptiveTempoScaling;
  late bool _isCustomDistance;

  @override
  void initState() {
    super.initState();
    _paceSec = widget.initialPaceSecondsPerKm.clamp(210, 900);
    _distanceKm = widget.initialDistanceKm.clamp(1.0, 21.1);
    _adaptiveTempoScaling = widget.initialAdaptiveTempoScaling;
    _isCustomDistance = !_presetDistances.any(
      (d) => (d - _distanceKm).abs() < 0.05,
    );
  }

  void _resetDefaults() {
    HapticFeedback.selectionClick();
    setState(() {
      _paceSec = StradioPreferencesService.defaultTargetPaceSecondsPerKm;
      _distanceKm = StradioPreferencesService.defaultTargetDistanceKm;
      _adaptiveTempoScaling =
          StradioPreferencesService.defaultAdaptiveTempoScaling;
      _isCustomDistance = false;
    });
  }

  void _applyAndClose() {
    HapticFeedback.mediumImpact();
    unawaited(StradioPreferencesService.saveTargetPaceSecondsPerKm(_paceSec));
    unawaited(StradioPreferencesService.saveTargetDistanceKm(_distanceKm));
    unawaited(
      StradioPreferencesService.saveAdaptiveTempoScaling(_adaptiveTempoScaling),
    );
    widget.onAdaptiveTempoScalingChanged?.call(_adaptiveTempoScaling);
    widget.onApply(_paceSec, _distanceKm);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(widget.language);
    final isId = widget.language == AppLanguage.id;
    final syncPct = widget.activePack.computeSyncIntegrity(
      targetPaceSecondsPerKm: _paceSec,
    );
    final estCadence = StradioSoundPack.estimateCadenceFromPace(_paceSec).round();
    final optimalPace = widget.activePack.optimalPaceSecondsPerKm;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      key: const Key('target_calibration_sheet'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            StradioColors.surfaceCard.withValues(alpha: 0.98),
            StradioColors.warmIvory.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: StradioColors.midnight.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: StradioColors.borderSubtle,
                      borderRadius: BorderRadius.circular(StradioRadii.full),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header: "Run & Rhythm Target" + "TEMPO MATCH" coral pill + Close X
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                isId
                                    ? 'Target Lari & Ritme'
                                    : 'Run & Rhythm Target',
                                style: StradioTypography.headingSmall(
                                  fontSize: 18,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: StradioColors.glowCoralSoft,
                                  borderRadius: BorderRadius.circular(
                                    StradioRadii.full,
                                  ),
                                ),
                                child: Text(
                                  'TEMPO MATCH',
                                  style: StradioTypography.microCap(
                                    color: StradioColors.textAccentDeep,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isId
                                ? 'Target pace & kecocokan ritme audio'
                                : 'Target pacing & audio rhythm compatibility',
                            style: StradioTypography.metricLabel(),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('target_calibration_close_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: s.closeLabel,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: StradioColors.borderSubtle),
                const SizedBox(height: 14),

                // Card 1: Target Pace
                _TargetGlassPod(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 17,
                                color: StradioColors.textAccentDeep,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isId ? 'Target Pace' : 'Target Pace',
                                style: StradioTypography.pillBadge(),
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                StradioSoundPack.formatPace(_paceSec),
                                style: StradioTypography.headingSmall(
                                  fontSize: 16,
                                  color: StradioColors.textAccentDeep,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '/km',
                                style: StradioTypography.metricLabel(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: StradioColors.sonicCoral,
                          inactiveTrackColor: StradioColors.borderSubtle,
                          thumbColor: StradioColors.surfaceCard,
                          overlayColor: StradioColors.glowCoralSoft,
                          trackHeight: 4.5,
                        ),
                        child: Slider(
                          key: const Key('target_pace_slider'),
                          value: _paceSec.toDouble(),
                          min: 210,
                          max: 900,
                          divisions: 138,
                          onChanged: (v) =>
                              setState(() => _paceSec = v.round()),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isId ? 'Cepat (3:30/km)' : 'Fast (3:30/km)',
                            style: StradioTypography.metricLabel(),
                          ),
                          Text(
                            'Cadence ~$estCadence SPM',
                            style: StradioTypography.metricLabel(
                              color: StradioColors.textPrimary,
                            ),
                          ),
                          Text(
                            isId ? 'Santai (15:00/km)' : 'Easy (15:00/km)',
                            style: StradioTypography.metricLabel(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Card 2: Target Distance (3.0 km / 5.0 km / 10.0 km / Custom)
                _TargetGlassPod(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.route_rounded,
                                size: 17,
                                color: StradioColors.twilightPlum,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isId ? 'Target Jarak' : 'Target Distance',
                                style: StradioTypography.pillBadge(),
                              ),
                            ],
                          ),
                          Text(
                            '${_distanceKm.toStringAsFixed(1)} km',
                            style: StradioTypography.headingSmall(
                              fontSize: 15,
                              color: StradioColors.twilightPlum,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final preset in _presetDistances) ...[
                            Expanded(
                              child: _DistancePresetChip(
                                chipKey: Key(
                                  'target_distance_chip_${preset.round()}',
                                ),
                                label: '${preset.toStringAsFixed(1)} km',
                                selected:
                                    !_isCustomDistance &&
                                    (_distanceKm - preset).abs() < 0.05,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _distanceKm = preset;
                                    _isCustomDistance = false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: _DistancePresetChip(
                              chipKey: const Key('target_distance_chip_custom'),
                              label: isId ? 'Kustom' : 'Custom',
                              selected: _isCustomDistance,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _isCustomDistance = true);
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_isCustomDistance) ...[
                        const SizedBox(height: 6),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: StradioColors.twilightPlum,
                            inactiveTrackColor: StradioColors.borderSubtle,
                            thumbColor: StradioColors.surfaceCard,
                            overlayColor: StradioColors.glowVioletSoft,
                            trackHeight: 4.5,
                          ),
                          child: Slider(
                            key: const Key('target_distance_slider'),
                            value: _distanceKm,
                            min: 1.0,
                            max: 21.1,
                            divisions: 201,
                            onChanged: (v) => setState(
                              () => _distanceKm = (v * 10).round() / 10.0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Card 3: Sync Integrity
                _TargetGlassPod(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.graphic_eq_rounded,
                                size: 17,
                                color: StradioColors.textPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                s.syncIntegrityLabel,
                                style: StradioTypography.pillBadge(),
                              ),
                            ],
                          ),
                          Text(
                            '${syncPct.toStringAsFixed(1)}% Match',
                            key: const Key('target_sync_integrity_readout'),
                            style: StradioTypography.headingSmall(
                              fontSize: 15,
                              color: StradioColors.textAccentDeep,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(StradioRadii.full),
                        child: LinearProgressIndicator(
                          value: (syncPct / 100.0).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: StradioColors.borderSubtle,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            StradioColors.sonicCoral,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        key: const Key('target_lock_optimal_pace_button'),
                        borderRadius: BorderRadius.circular(StradioRadii.sm),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _paceSec = optimalPace);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Optimal Harmonic Lock at ${StradioSoundPack.formatPace(optimalPace)} /km',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: StradioTypography.metricLabel(),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$estCadence BPM Ready',
                                style: StradioTypography.metricLabel(
                                  color: StradioColors.textAccentDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Card 4: Adaptive Tempo Scaling toggle
                _TargetGlassPod(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: StradioColors.glowCoralSoft,
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: StradioColors.textAccentDeep,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isId
                                  ? 'Skala Tempo Adaptif'
                                  : 'Adaptive Tempo Scaling',
                              style: StradioTypography.pillBadge(),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isId
                                  ? 'Penyesuaian BPM dinamis mengikuti perubahan pace'
                                  : 'Dynamic BPM micro-pitching to match pace shifts',
                              style: StradioTypography.metricLabel(),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        key: const Key('target_adaptive_tempo_switch'),
                        value: _adaptiveTempoScaling,
                        activeThumbColor: Colors.white,
                        activeTrackColor: StradioColors.sonicCoral,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _adaptiveTempoScaling = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Bottom Action Row: "Set Run Target" + "Reset"
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          key: const Key('target_calibration_apply_button'),
                          onPressed: _applyAndClose,
                          child: Text(
                            isId ? 'Simpan Target Lari' : 'Set Run Target',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        key: const Key('target_calibration_reset_button'),
                        onPressed: _resetDefaults,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: StradioColors.surfaceRecessed,
                          foregroundColor: StradioColors.textPrimary,
                          side: const BorderSide(
                            color: StradioColors.borderSubtle,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              StradioRadii.full,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: Text(
                          isId ? 'Reset' : 'Reset',
                          style: StradioTypography.pillBadge(
                            color: StradioColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
  }
}

class _DistancePresetChip extends StatelessWidget {
  const _DistancePresetChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? StradioColors.midnight : StradioColors.surfaceCard,
      borderRadius: BorderRadius.circular(StradioRadii.full),
      child: InkWell(
        key: chipKey,
        borderRadius: BorderRadius.circular(StradioRadii.full),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StradioRadii.full),
            border: Border.all(
              color: selected
                  ? StradioColors.midnight
                  : StradioColors.borderSubtle,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: StradioTypography.metricLabel(
                color: selected
                    ? StradioColors.textOnDark
                    : StradioColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetGlassPod extends StatelessWidget {
  const _TargetGlassPod({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StradioColors.surfaceCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: StradioColors.borderSubtle),
      ),
      child: child,
    );
  }
}
