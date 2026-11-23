import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../evaluation/run_metrics_calculator.dart';
import '../l10n/stradio_strings.dart';
import '../services/preferences_service.dart';
import '../theme/stradio_theme.dart';

/// Honest state of the 100 Hz smartphone accelerometer pipeline.
enum SensorPipelineState { ready, calibrating, active, unavailable }

/// Audio sync latency profiles shown in Mockup 09 (`Sensor Calibration`).
enum AudioLatencyPreset {
  ultraLow(label: 'Ultra-Low', ms: 24),
  balanced(label: 'Balanced', ms: 28),
  energySaver(label: 'Energy Saver', ms: 36);

  const AudioLatencyPreset({required this.label, required this.ms});
  final String label;
  final int ms;
}

/// Mockup 09 Sensor Calibration & Stride/Audio Engine Parameters Sheet
/// (`daylight-minimal-screens.html` #09 & `docs/EXPERIENCE.md`).
///
/// Features the 4 interactive instrument cards from Mockup 09:
/// 1. `Stride Sensitivity (IMU)` slider (`0.8x` to `2.4x`, default `1.68x`)
/// 2. `Audio Sync Latency` 3-pill selector (`Ultra-Low 24ms` | `Balanced 28ms` | `Energy Saver 36ms`)
/// 3. `Cadence Lock Window` slider (`±2 SPM` to `±12 SPM`, default `±5 SPM`)
/// 4. `Adaptive Spatial EQ` switch (`Dynamic binaural pulse depth`)
/// Plus `Apply & Calibrate` + `Reset` actions, while preserving honest sensor fallback
/// diagnostics (`Motion sensor unavailable` & `Simulate stride (+1)`) when needed.
class SensorCalibrationSheet extends StatefulWidget {
  const SensorCalibrationSheet({
    super.key,
    required this.state,
    this.healthReport,
    this.errorMessage,
    this.onRetrySensor,
    this.onSimulateStride,
    this.initialSensitivity,
    this.onApplyCalibration,
    this.language = AppLanguage.en,
  });

  final SensorPipelineState state;
  final SensorHealthReport? healthReport;
  final String? errorMessage;
  final VoidCallback? onRetrySensor;
  final VoidCallback? onSimulateStride;
  final double? initialSensitivity;
  final ValueChanged<double>? onApplyCalibration;
  final AppLanguage language;

  static Future<void> show(
    BuildContext context, {
    required SensorPipelineState state,
    SensorHealthReport? healthReport,
    String? errorMessage,
    VoidCallback? onRetrySensor,
    VoidCallback? onSimulateStride,
    double? initialSensitivity,
    ValueChanged<double>? onApplyCalibration,
    AppLanguage language = AppLanguage.en,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SensorCalibrationSheet(
        state: state,
        healthReport: healthReport,
        errorMessage: errorMessage,
        onRetrySensor: onRetrySensor,
        onSimulateStride: onSimulateStride,
        initialSensitivity: initialSensitivity,
        onApplyCalibration: onApplyCalibration,
        language: language,
      ),
    );
  }

  @override
  State<SensorCalibrationSheet> createState() => _SensorCalibrationSheetState();
}

class _SensorCalibrationSheetState extends State<SensorCalibrationSheet> {
  static const double _defaultSensitivity = 1.68;
  static const AudioLatencyPreset _defaultLatency = AudioLatencyPreset.balanced;
  static const int _defaultLockWindowSpm = 5;
  static const bool _defaultSpatialEq = true;

  late double _strideSensitivity;
  AudioLatencyPreset _latencyPreset = _defaultLatency;
  int _cadenceLockWindowSpm = _defaultLockWindowSpm;
  bool _spatialEqEnabled = _defaultSpatialEq;

  @override
  void initState() {
    super.initState();
    _strideSensitivity = (widget.initialSensitivity ?? _defaultSensitivity)
        .clamp(0.8, 2.4);
  }

  void _resetDefaults() {
    HapticFeedback.selectionClick();
    setState(() {
      _strideSensitivity = _defaultSensitivity;
      _latencyPreset = _defaultLatency;
      _cadenceLockWindowSpm = _defaultLockWindowSpm;
      _spatialEqEnabled = _defaultSpatialEq;
    });
  }

  String _lockTightnessLabel(int windowSpm) {
    if (windowSpm <= 5) return 'Lock: Tight';
    if (windowSpm <= 8) return 'Lock: Balanced';
    return 'Lock: Wide';
  }

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(widget.language);
    final isUnavailable = widget.state == SensorPipelineState.unavailable;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Container(
          key: const Key('sensor_calibration_sheet'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: StradioColors.surfaceCard,
            borderRadius: BorderRadius.circular(StradioRadii.tray),
            border: Border.all(color: StradioColors.borderSubtle),
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

                // Mockup 09 Header: Sensor Calibration + 100 HZ SYNCED badge + Close button
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
                                s.sensorCalibrationTitle,
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
                                  isUnavailable
                                      ? s.sensorUnavailableTitle
                                      : s.sensorSyncedBadge,
                                  style: StradioTypography.microCap(
                                    color: StradioColors.textAccentDeep,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s.sensorCalibrationSubtitle,
                            style: StradioTypography.metricLabel(),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('sensor_calibration_close_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: s.closeLabel,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Honest hardware unavailable banner & fallback actions if accelerometer stream failed
                if (isUnavailable) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: StradioColors.glowCoralSoft,
                      borderRadius: BorderRadius.circular(StradioRadii.lg),
                      border: Border.all(
                        color: StradioColors.sonicCoral.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.errorMessage ?? s.sensorUnavailableBody,
                          style: StradioTypography.body(
                            fontSize: 12,
                            color: StradioColors.textPrimary,
                          ),
                        ),
                        if (widget.onSimulateStride != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              key: const Key(
                                'sensor_sheet_simulate_stride_button',
                              ),
                              onPressed: () {
                                widget.onSimulateStride?.call();
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(
                                Icons.directions_run_rounded,
                                size: 17,
                              ),
                              label: Text(s.simulateStrideAction),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Card 1: Stride Sensitivity (IMU) Slider (0.8x .. 2.4x)
                _ParameterCard(
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
                                s.strideSensitivityLabel,
                                style: StradioTypography.pillBadge(),
                              ),
                            ],
                          ),
                          Text(
                            '${_strideSensitivity.toStringAsFixed(2)}x',
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
                          key: const Key('sensor_sensitivity_slider'),
                          value: _strideSensitivity,
                          min: 0.80,
                          max: 2.40,
                          onChanged: (v) =>
                              setState(() => _strideSensitivity = v),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Low (0.8x)',
                            style: StradioTypography.metricLabel(),
                          ),
                          Text(
                            'Balanced',
                            style: StradioTypography.metricLabel(),
                          ),
                          Text(
                            'High (2.4x)',
                            style: StradioTypography.metricLabel(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Card 2: Audio Sync Latency (Ultra-Low 24ms | Balanced 28ms | Energy Saver 36ms)
                _ParameterCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.headphones_rounded,
                                size: 16,
                                color: StradioColors.twilightPlum,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s.audioSyncLatencyLabel,
                                style: StradioTypography.pillBadge(),
                              ),
                            ],
                          ),
                          Text(
                            '${_latencyPreset.ms} ms',
                            style: StradioTypography.pillBadge(
                              color: StradioColors.twilightPlum,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var i = 0; i < AudioLatencyPreset.values.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _LatencyChoicePill(
                                preset: AudioLatencyPreset.values[i],
                                selected:
                                    _latencyPreset ==
                                    AudioLatencyPreset.values[i],
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(
                                    () => _latencyPreset =
                                        AudioLatencyPreset.values[i],
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Card 3: Cadence Lock Window (±2..±12 SPM)
                _ParameterCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.tune_rounded,
                                size: 16,
                                color: StradioColors.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s.cadenceLockWindowLabel,
                                style: StradioTypography.pillBadge(),
                              ),
                            ],
                          ),
                          Text(
                            '+/-$_cadenceLockWindowSpm SPM',
                            style: StradioTypography.pillBadge(),
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
                          key: const Key('sensor_cadence_window_slider'),
                          value: _cadenceLockWindowSpm.toDouble(),
                          min: 2,
                          max: 12,
                          divisions: 10,
                          onChanged: (v) => setState(
                            () => _cadenceLockWindowSpm = v.round(),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Target: 172 SPM',
                            style: StradioTypography.metricLabel(),
                          ),
                          Text(
                            _lockTightnessLabel(_cadenceLockWindowSpm),
                            style: StradioTypography.metricLabel(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Card 4: Adaptive Spatial EQ Toggle
                _ParameterCard(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: StradioColors.twilightPlum.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        child: const Icon(
                          Icons.surround_sound_rounded,
                          size: 17,
                          color: StradioColors.twilightPlum,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.adaptiveSpatialEqTitle,
                              style: StradioTypography.pillBadge(),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.adaptiveSpatialEqSubtitle,
                              style: StradioTypography.metricLabel(),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        key: const Key('sensor_spatial_eq_switch'),
                        value: _spatialEqEnabled,
                        activeThumbColor: StradioColors.surfaceCard,
                        activeTrackColor: StradioColors.sonicCoral,
                        onChanged: (v) =>
                            setState(() => _spatialEqEnabled = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Footer Buttons: Apply & Calibrate + Reset
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          key: const Key('sensor_apply_calibrate_button'),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            unawaited(
                              StradioPreferencesService.saveStrideSensitivity(
                                _strideSensitivity,
                              ),
                            );
                            widget.onApplyCalibration?.call(
                              _strideSensitivity,
                            );
                            Navigator.of(context).pop();
                            widget.onRetrySensor?.call();
                          },
                          child: Text(s.applyAndCalibrateAction),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        key: const Key('sensor_reset_button'),
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

class _ParameterCard extends StatelessWidget {
  const _ParameterCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StradioColors.warmIvory.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(StradioRadii.lg),
        border: Border.all(color: StradioColors.borderSubtle),
      ),
      child: child,
    );
  }
}

class _LatencyChoicePill extends StatelessWidget {
  const _LatencyChoicePill({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AudioLatencyPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? StradioColors.textOnDark : StradioColors.textPrimary;
    final subFg = selected
        ? StradioColors.warmIvory.withValues(alpha: 0.85)
        : StradioColors.textSecondary;

    return Material(
      color: selected ? StradioColors.midnight : StradioColors.surfaceCard,
      borderRadius: BorderRadius.circular(StradioRadii.lg),
      child: InkWell(
        key: Key('sensor_latency_${preset.name}'),
        borderRadius: BorderRadius.circular(StradioRadii.lg),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StradioRadii.lg),
            border: Border.all(
              color: selected
                  ? StradioColors.midnight
                  : StradioColors.borderSubtle,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  preset.label,
                  style: StradioTypography.metricLabel(color: subFg),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${preset.ms}ms',
                style: StradioTypography.pillBadge(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
