import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/stradio_strings.dart';
import '../models/sound_pack.dart';
import '../services/preferences_service.dart';
import '../theme/stradio_theme.dart';

/// Glassmorphism Target Calibration modal sheet opened from Pre-Run Ignition
/// (`Pace Target` & `Distance Target` inputs + live `Sync Integrity` readout).
class TargetCalibrationSheet extends StatefulWidget {
  const TargetCalibrationSheet({
    super.key,
    required this.initialPaceSecondsPerKm,
    required this.initialDistanceKm,
    required this.activePack,
    required this.onApply,
    this.language = AppLanguage.en,
  });

  final int initialPaceSecondsPerKm;
  final double initialDistanceKm;
  final StradioSoundPack activePack;
  final void Function(int paceSecondsPerKm, double distanceKm) onApply;
  final AppLanguage language;

  static Future<void> show(
    BuildContext context, {
    required int initialPaceSecondsPerKm,
    required double initialDistanceKm,
    required StradioSoundPack activePack,
    required void Function(int paceSecondsPerKm, double distanceKm) onApply,
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
        language: language,
      ),
    );
  }

  @override
  State<TargetCalibrationSheet> createState() => _TargetCalibrationSheetState();
}

class _TargetCalibrationSheetState extends State<TargetCalibrationSheet> {
  late int _paceSec;
  late double _distanceKm;

  @override
  void initState() {
    super.initState();
    _paceSec = widget.initialPaceSecondsPerKm.clamp(210, 900);
    _distanceKm = widget.initialDistanceKm.clamp(1.0, 21.1);
  }

  void _resetDefaults() {
    HapticFeedback.selectionClick();
    setState(() {
      _paceSec = StradioPreferencesService.defaultTargetPaceSecondsPerKm;
      _distanceKm = StradioPreferencesService.defaultTargetDistanceKm;
    });
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
    final optimalSync = widget.activePack.computeSyncIntegrity(
      targetPaceSecondsPerKm: optimalPace,
    );
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          key: const Key('target_calibration_sheet'),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
          decoration: BoxDecoration(
            color: StradioColors.surfaceCard.withValues(alpha: 0.86),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.90),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: StradioColors.midnight.withValues(alpha: 0.14),
                blurRadius: 28,
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
                                    ? 'Kalibrasi Target'
                                    : 'Target Calibration',
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
                                  '${syncPct.toStringAsFixed(1)}% Sync',
                                  style: StradioTypography.microCap(
                                    color: StradioColors.textAccentDeep,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.activePack.title} · ~$estCadence spm',
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
                const SizedBox(height: 14),

                // Card 1: Pace Target (3:30..15:00 /km)
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
                                Icons.speed_rounded,
                                size: 16,
                                color: StradioColors.textAccentDeep,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isId ? 'Target Pace' : 'Pace Target',
                                style: StradioTypography.pillBadge(),
                              ),
                            ],
                          ),
                          Text(
                            '${StradioSoundPack.formatPace(_paceSec)} /km',
                            style: StradioTypography.pillBadge(
                              color: StradioColors.textAccentDeep,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: StradioColors.sonicCoral,
                          inactiveTrackColor: StradioColors.borderSubtle,
                          thumbColor: StradioColors.surfaceCard,
                          overlayColor: StradioColors.glowCoralSoft,
                          trackHeight: 5.0,
                        ),
                        child: Slider(
                          key: const Key('target_pace_slider'),
                          value: _paceSec.toDouble(),
                          min: 210,
                          max: 900,
                          divisions: 138, // 5-second steps
                          onChanged: (v) =>
                              setState(() => _paceSec = v.round()),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '3:30 /km',
                            style: StradioTypography.metricLabel(),
                          ),
                          Text(
                            isId ? 'Seimbang (6:00)' : 'Balanced (6:00)',
                            style: StradioTypography.metricLabel(),
                          ),
                          Text(
                            '15:00 /km',
                            style: StradioTypography.metricLabel(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Card 2: Distance Target (1.0..21.1 km)
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
                                size: 16,
                                color: StradioColors.twilightPlum,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isId ? 'Target Jarak' : 'Distance Target',
                                style: StradioTypography.pillBadge(),
                              ),
                            ],
                          ),
                          Text(
                            '${_distanceKm.toStringAsFixed(1)} km',
                            style: StradioTypography.pillBadge(
                              color: StradioColors.twilightPlum,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: StradioColors.midnight,
                          inactiveTrackColor: StradioColors.borderSubtle,
                          thumbColor: StradioColors.surfaceCard,
                          overlayColor: StradioColors.glowVioletSoft,
                          trackHeight: 5.0,
                        ),
                        child: Slider(
                          key: const Key('target_distance_slider'),
                          value: _distanceKm,
                          min: 1.0,
                          max: 21.1,
                          divisions: 201, // 0.1 km steps
                          onChanged: (v) => setState(
                            () => _distanceKm = (v * 10).round() / 10.0,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1.0 km',
                            style: StradioTypography.metricLabel(),
                          ),
                          Text(
                            '5K · 10K',
                            style: StradioTypography.metricLabel(),
                          ),
                          Text(
                            '21.1 km',
                            style: StradioTypography.metricLabel(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Card 3: Sync Integrity + 1-Tap Lock Optimal Pace
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
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: StradioColors.rhythmViolet,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isId ? 'Sinkronisasi Lagu' : 'Sync Integrity',
                                style: StradioTypography.pillBadge(),
                              ),
                            ],
                          ),
                          Text(
                            '${syncPct.toStringAsFixed(1)}%',
                            key: const Key('target_sync_integrity_readout'),
                            style: StradioTypography.pillBadge(
                              color: StradioColors.twilightPlum,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(StradioRadii.full),
                        child: SizedBox(
                          height: 6,
                          child: Stack(
                            children: [
                              Container(color: StradioColors.borderSubtle),
                              FractionallySizedBox(
                                widthFactor: (syncPct / 100.0).clamp(0.1, 1.0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        StradioColors.sonicCoral,
                                        StradioColors.rhythmViolet,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 38,
                        child: OutlinedButton.icon(
                          key: const Key('target_lock_optimal_pace_button'),
                          onPressed: _paceSec == optimalPace
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _paceSec = optimalPace);
                                },
                          icon: const Icon(Icons.lock_clock_rounded, size: 15),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isId
                                  ? 'Kunci Pace Optimal (${StradioSoundPack.formatPace(optimalPace)} /km · ${optimalSync.toStringAsFixed(1)}%)'
                                  : 'Lock Optimal Pace (${StradioSoundPack.formatPace(optimalPace)} /km · ${optimalSync.toStringAsFixed(1)}%)',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          key: const Key('target_calibration_apply_button'),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            unawaited(
                              StradioPreferencesService
                                  .saveTargetPaceSecondsPerKm(_paceSec),
                            );
                            unawaited(
                              StradioPreferencesService
                                  .saveTargetDistanceKm(_distanceKm),
                            );
                            widget.onApply(_paceSec, _distanceKm);
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            isId ? 'Terapkan Target' : 'Apply Targets',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        key: const Key('target_calibration_reset_button'),
                        onPressed: _resetDefaults,
                        child: Text(s.resetAction),
                      ),
                    ),
                  ],
                ),
              ],
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
        color: StradioColors.warmIvory.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(StradioRadii.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
      ),
      child: child,
    );
  }
}
