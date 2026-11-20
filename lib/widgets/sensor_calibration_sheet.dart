import 'package:flutter/material.dart';

import '../evaluation/run_metrics_calculator.dart';
import '../theme/stradio_theme.dart';

/// Honest state of the 100 Hz smartphone accelerometer pipeline.
enum SensorPipelineState { ready, calibrating, active, unavailable }

/// P1 Sensor Calibration & Fallback Sheet (`docs/EXPERIENCE.md` State Patterns).
///
/// Surfaces real sensor diagnostics, pocket-mode battery guidance, retry action,
/// and an explicit simulation fallback when hardware sensors are unavailable.
class SensorCalibrationSheet extends StatelessWidget {
  const SensorCalibrationSheet({
    super.key,
    required this.state,
    this.healthReport,
    this.errorMessage,
    this.onRetrySensor,
    this.onSimulateStride,
  });

  final SensorPipelineState state;
  final SensorHealthReport? healthReport;
  final String? errorMessage;
  final VoidCallback? onRetrySensor;
  final VoidCallback? onSimulateStride;

  static Future<void> show(
    BuildContext context, {
    required SensorPipelineState state,
    SensorHealthReport? healthReport,
    String? errorMessage,
    VoidCallback? onRetrySensor,
    VoidCallback? onSimulateStride,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (statusTitle, statusBody, dotColor) = switch (state) {
      SensorPipelineState.active => (
        'Motion sensor active',
        'Streaming raw 3-axis acceleration (A1 Adaptive Midpoint + Gravity).',
        StradioColors.statusLive,
      ),
      SensorPipelineState.ready => (
        'Motion sensor ready',
        '100 Hz accelerometer ready. Stationary noise gate keeps idle steps at zero.',
        StradioColors.twilightPlum,
      ),
      SensorPipelineState.calibrating => (
        'Calibrating motion sensor...',
        'Waiting for initial accelerometer samples to establish dynamic midpoint.',
        StradioColors.statusPaused,
      ),
      SensorPipelineState.unavailable => (
        'Motion sensor unavailable',
        errorMessage ??
            'Accelerometer stream could not start. Check motion permissions or test with simulated steps.',
        StradioColors.textAccentDeep,
      ),
    };

    final report = healthReport;
    final hasRealSamples = report != null && report.sampleCount > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusTitle,
                        style: StradioTypography.headingSmall(fontSize: 18),
                      ),
                    ),
                    IconButton(
                      key: const Key('sensor_calibration_close_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(statusBody, style: StradioTypography.body(fontSize: 13)),
                const SizedBox(height: 16),

                // Honest Real-Data Telemetry Readout
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: StradioColors.warmIvory,
                    borderRadius: BorderRadius.circular(StradioRadii.lg),
                    border: Border.all(color: StradioColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SensorStat(
                          label: 'Sampling rate',
                          value: hasRealSamples
                              ? '${report.effectiveRateHz.toStringAsFixed(1)} Hz'
                              : '-- Hz',
                        ),
                      ),
                      Expanded(
                        child: _SensorStat(
                          label: 'Samples',
                          value: hasRealSamples
                              ? '${report.sampleCount}'
                              : '0',
                        ),
                      ),
                      Expanded(
                        child: _SensorStat(
                          label: 'Dropped',
                          value: hasRealSamples
                              ? '${report.sampleDrops}'
                              : '0',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Pocket Mode Guidance
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: StradioColors.surfaceRecessed,
                    borderRadius: BorderRadius.circular(StradioRadii.lg),
                  ),
                  child: Text(
                    'Pocket mode tip: keep Stradio battery optimization set to Unrestricted in Android settings so step audio continues with the screen locked.',
                    style: StradioTypography.body(
                      fontSize: 12,
                      color: StradioColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (onRetrySensor != null)
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      key: const Key('sensor_retry_button'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRetrySensor?.call();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reconnect motion sensor'),
                    ),
                  ),
                if (onSimulateStride != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      key: const Key('sensor_sheet_simulate_stride_button'),
                      onPressed: () {
                        onSimulateStride?.call();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.directions_run_rounded, size: 18),
                      label: const Text('Simulate stride (+1)'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SensorStat extends StatelessWidget {
  const _SensorStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: StradioTypography.metricLabel()),
        const SizedBox(height: 4),
        Text(value, style: StradioTypography.pillBadge()),
      ],
    );
  }
}
