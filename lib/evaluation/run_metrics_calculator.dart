import 'dart:math' as math;

import '../models/experiment_models.dart';

/// Sensor health diagnostics computed from actual recorded [SensorSample]s.
class SensorHealthReport {
  const SensorHealthReport({
    required this.sampleCount,
    required this.requestedRateHz,
    required this.effectiveRateHz,
    required this.sampleDrops,
    required this.latestTimestampNs,
  });

  final int sampleCount;
  final double requestedRateHz;
  final double effectiveRateHz;
  final int sampleDrops;
  final int latestTimestampNs;

  bool get isHealthy => sampleDrops == 0 && sampleCount > 0;
}

/// Complete user-facing and research metrics for an active or completed run.
class RunSummaryMetrics {
  const RunSummaryMetrics({
    required this.totalSteps,
    required this.activeDurationSeconds,
    required this.liveCadenceSpm,
    required this.averageCadenceSpm,
    required this.distanceKm,
    required this.speedKmh,
    required this.targetBpm,
    required this.rhythmScorePercent,
    required this.cadenceBucketsSpm,
  });

  final int totalSteps;
  final double activeDurationSeconds;
  final double liveCadenceSpm;
  final double averageCadenceSpm;
  final double distanceKm;
  final double speedKmh;
  final int targetBpm;
  final double rhythmScorePercent;

  /// Time-bucketed cadence series (in SPM) for the Post-Run consistency chart.
  final List<double> cadenceBucketsSpm;

  String get formattedDuration {
    final totalSecs = activeDurationSeconds.round();
    final mins = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSecs % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

/// Computes real-time and post-run athletic metrics directly from sensor samples
/// and confirmed step detections (R-17 & R-38: zero fabricated numbers).
class RunMetricsCalculator {
  const RunMetricsCalculator._();

  /// Standardized, height-calibrated, or cadence-adaptive stride length estimate in meters.
  static double strideLengthMeters(
    Activity activity, {
    double? heightCm,
    double? cadenceSpm,
  }) {
    if (cadenceSpm != null && cadenceSpm > 0) {
      final heightScale =
          (heightCm != null && heightCm >= 100.0 && heightCm <= 240.0)
          ? (heightCm / 170.0)
          : 1.0;
      final double baseStride;
      if (cadenceSpm < 130.0) {
        // Walking (~80..130 SPM) -> 0.80m..0.92m (~10:00–11:00 /km around 105–115 SPM)
        final t = ((cadenceSpm - 80.0) / 50.0).clamp(0.0, 1.0);
        baseStride = 0.80 + t * 0.12;
      } else {
        // Running (130..185+ SPM) -> 0.96m..1.30m
        final t = ((cadenceSpm - 130.0) / 55.0).clamp(0.0, 1.0);
        baseStride = 0.96 + t * 0.34;
      }
      return baseStride * heightScale;
    }

    if (heightCm != null && heightCm >= 100.0 && heightCm <= 240.0) {
      return switch (activity) {
        Activity.walking => heightCm * 0.00415,
        Activity.jogging => heightCm * 0.0055,
      };
    }
    return switch (activity) {
      Activity.walking => 0.74,
      Activity.jogging => 0.95,
    };
  }

  /// Estimates real-time instantaneous speed (km/h) from live rolling [liveCadenceSpm]
  /// so initial stationary seconds do not distort active walking/running pace.
  static double estimateLiveSpeedKmh({
    required double liveCadenceSpm,
    required Activity activity,
    double? heightCm,
    double fallbackSpeedKmh = 0.0,
  }) {
    if (liveCadenceSpm > 0) {
      final strideM = strideLengthMeters(
        activity,
        heightCm: heightCm,
        cadenceSpm: liveCadenceSpm,
      );
      final raw = (liveCadenceSpm * strideM * 60.0) / 1000.0;
      return raw.isFinite ? math.min(raw, 35.0) : fallbackSpeedKmh;
    }
    return fallbackSpeedKmh;
  }

  /// Default target tempo BPM for reactive rhythm matching.
  static int defaultTargetBpm(Activity activity) => switch (activity) {
    Activity.walking => 118,
    Activity.jogging => 165,
  };

  /// Distance in kilometers from confirmed step count, activity, and optional [heightCm].
  static double estimateDistanceKm({
    required int steps,
    required Activity activity,
    double? heightCm,
  }) {
    if (steps <= 0) return 0.0;
    return (steps * strideLengthMeters(activity, heightCm: heightCm)) / 1000.0;
  }

  /// Speed in km/h from distance (km) and active elapsed duration (seconds).
  static double estimateSpeedKmh({
    required double distanceKm,
    required double activeDurationSeconds,
  }) {
    if (distanceKm <= 0 || activeDurationSeconds <= 0) return 0.0;
    final hours = activeDurationSeconds / 3600.0;
    final raw = distanceKm / hours;
    return raw.isFinite ? math.min(raw, 35.0) : 0.0;
  }

  /// Session-wide average cadence in steps per minute (SPM).
  static double averageCadenceSpm({
    required int totalSteps,
    required double activeDurationSeconds,
  }) {
    if (totalSteps <= 0 || activeDurationSeconds <= 0) return 0.0;
    final minutes = activeDurationSeconds / 60.0;
    final spm = totalSteps / minutes;
    return spm.isFinite ? math.min(spm, 260.0) : 0.0;
  }

  /// Rolling cadence (SPM) over the most recent [windowSeconds] up to
  /// [currentTimestampNs], scanning backward in O(1) window time.
  /// Decays smoothly when the runner slows down and returns `0.0` once no step
  /// has arrived for more than ~2s (preventing stale jogging SPM after stopping).
  static double rollingCadenceSpm({
    required List<DetectionEvent> detections,
    required int currentTimestampNs,
    int windowSeconds = 5,
  }) {
    if (detections.isEmpty) return 0.0;
    final windowNs = windowSeconds * 1000000000;
    final cutoffNs = currentTimestampNs - windowNs;

    var count = 0;
    int? firstTs;
    int? lastTs;
    for (var i = detections.length - 1; i >= 0; i--) {
      final ts = detections[i].peakTimestampNs;
      if (ts < cutoffNs) break;
      if (ts > currentTimestampNs) continue;
      count++;
      lastTs ??= ts;
      firstTs = ts;
    }

    if (count == 0 || lastTs == null) return 0.0;

    final silenceSinceLastSec = (currentTimestampNs - lastTs) / 1e9;
    if (count == 1) {
      if (silenceSinceLastSec > 2.0) return 0.0;
      return (1.0 / windowSeconds) * 60.0;
    }

    final spanNs = lastTs - (firstTs ?? 0);
    if (spanNs <= 0) {
      return silenceSinceLastSec > 2.0 ? 0.0 : (count / windowSeconds) * 60.0;
    }
    final intervals = count - 1;
    final avgIntervalSeconds = (spanNs / 1e9) / intervals;
    if (avgIntervalSeconds <= 0) return 0.0;

    // Runner stopped: no new step for > max(2.0s, 2.2x recent step interval).
    final stopCutoffSec = math.max(2.0, avgIntervalSeconds * 2.2);
    if (silenceSinceLastSec > stopCutoffSec) return 0.0;

    // Runner slowing down: include elapsed silence since last step so SPM decays promptly.
    final effectiveIntervalSec = silenceSinceLastSec > avgIntervalSeconds * 1.5
        ? ((currentTimestampNs - (firstTs ?? 0)) / 1e9) / count
        : avgIntervalSeconds;
    if (effectiveIntervalSec <= 0) return 0.0;
    final spm = 60.0 / effectiveIntervalSec;
    return spm.isFinite ? math.min(spm, 260.0) : 0.0;
  }

  /// Rhythm Score (0% to 100%) measuring how closely the runner's cadence
  /// matches the target soundscape tempo [targetBpm].
  static double calculateRhythmScore({
    required double actualSpm,
    required int targetBpm,
  }) {
    if (actualSpm <= 0 || targetBpm <= 0) return 0.0;
    final relativeDeviation = (actualSpm - targetBpm).abs() / targetBpm;
    final score = (1.0 - relativeDeviation) * 100.0;
    return score.clamp(0.0, 100.0);
  }

  /// Builds a time-bucketed cadence series (in SPM) across the recording
  /// duration for the Post-Run Pace & Cadence consistency chart.
  static List<double> buildCadenceBuckets({
    required List<DetectionEvent> detections,
    required int? startTimestampNs,
    required int? endTimestampNs,
    int bucketCount = 8,
  }) {
    if (bucketCount <= 0 ||
        detections.isEmpty ||
        startTimestampNs == null ||
        endTimestampNs == null ||
        endTimestampNs <= startTimestampNs) {
      return const [];
    }

    final totalSpanNs = endTimestampNs - startTimestampNs;
    final bucketSpanNs = totalSpanNs / bucketCount;
    if (bucketSpanNs <= 0) return const [];
    final bucketDurationMinutes = (bucketSpanNs / 1e9) / 60.0;
    if (bucketDurationMinutes <= 0) return const [];

    final counts = List<int>.filled(bucketCount, 0);
    for (final d in detections) {
      final offset = d.peakTimestampNs - startTimestampNs;
      if (offset < 0) continue;
      var index = (offset / bucketSpanNs).floor();
      if (index >= bucketCount) index = bucketCount - 1;
      counts[index]++;
    }

    return [
      for (final c in counts)
        (c / bucketDurationMinutes).clamp(0.0, 260.0),
    ];
  }

  /// Evaluates complete [RunSummaryMetrics] for live display or post-run summary.
  static RunSummaryMetrics computeSummary({
    required List<DetectionEvent> detections,
    required List<SensorSample> samples,
    required Activity activity,
    required double activeDurationSeconds,
    int? targetBpm,
    int bucketCount = 8,
    double? heightCm,
    int? overrideStepCount,
    List<double>? fallbackCadenceBucketsSpm,
  }) {
    final resolvedBpm = targetBpm ?? defaultTargetBpm(activity);
    final totalSteps = overrideStepCount ?? detections.length;
    final latestTs = samples.isNotEmpty
        ? samples.last.timestampNs
        : (detections.isNotEmpty ? detections.last.outputTimestampNs : 0);
    final startTs = samples.isNotEmpty
        ? samples.first.timestampNs
        : (detections.isNotEmpty ? detections.first.peakTimestampNs : null);
    final endTs = samples.isNotEmpty
        ? samples.last.timestampNs
        : (detections.isNotEmpty ? detections.last.outputTimestampNs : null);

    final durationSec = activeDurationSeconds > 0
        ? activeDurationSeconds
        : (startTs != null && endTs != null && endTs > startTs
              ? (endTs - startTs) / 1e9
              : 0.0);

    final distanceKm = estimateDistanceKm(
      steps: totalSteps,
      activity: activity,
      heightCm: heightCm,
    );
    final speedKmh = estimateSpeedKmh(
      distanceKm: distanceKm,
      activeDurationSeconds: durationSec,
    );
    final avgSpm = averageCadenceSpm(
      totalSteps: totalSteps,
      activeDurationSeconds: durationSec,
    );
    final liveSpm = latestTs > 0
        ? rollingCadenceSpm(
            detections: detections,
            currentTimestampNs: latestTs,
          )
        : avgSpm;
    final effectiveSpmForRhythm = avgSpm > 0 ? avgSpm : liveSpm;
    final rhythmScore = calculateRhythmScore(
      actualSpm: effectiveSpmForRhythm,
      targetBpm: resolvedBpm,
    );
    final computedBuckets = buildCadenceBuckets(
      detections: detections,
      startTimestampNs: startTs,
      endTimestampNs: endTs,
      bucketCount: bucketCount,
    );
    final buckets = computedBuckets.isNotEmpty
        ? computedBuckets
        : (fallbackCadenceBucketsSpm ?? const []);

    return RunSummaryMetrics(
      totalSteps: totalSteps,
      activeDurationSeconds: durationSec,
      liveCadenceSpm: liveSpm,
      averageCadenceSpm: avgSpm,
      distanceKm: distanceKm,
      speedKmh: speedKmh,
      targetBpm: resolvedBpm,
      rhythmScorePercent: rhythmScore,
      cadenceBucketsSpm: buckets,
    );
  }

  /// Evaluates 100 Hz sensor stream health and counts dropped sample intervals.
  static SensorHealthReport analyzeSensorHealth({
    required List<SensorSample> samples,
    double requestedRateHz = 100.0,
  }) {
    if (samples.isEmpty) {
      return SensorHealthReport(
        sampleCount: 0,
        requestedRateHz: requestedRateHz,
        effectiveRateHz: 0.0,
        sampleDrops: 0,
        latestTimestampNs: 0,
      );
    }

    if (samples.length == 1) {
      return SensorHealthReport(
        sampleCount: 1,
        requestedRateHz: requestedRateHz,
        effectiveRateHz: requestedRateHz,
        sampleDrops: 0,
        latestTimestampNs: samples.last.timestampNs,
      );
    }

    final expectedPeriodNs = (1e9 / requestedRateHz).round();
    final dropThresholdNs = (expectedPeriodNs * 2.5).round();
    var drops = 0;

    for (var i = 1; i < samples.length; i++) {
      final deltaNs = samples[i].timestampNs - samples[i - 1].timestampNs;
      if (deltaNs > dropThresholdNs) {
        final missed = (deltaNs / expectedPeriodNs).round() - 1;
        if (missed > 0) drops += missed;
      }
    }

    final totalSpanNs = samples.last.timestampNs - samples.first.timestampNs;
    final effectiveRateHz = totalSpanNs > 0
        ? ((samples.length - 1) / (totalSpanNs / 1e9))
        : requestedRateHz;

    return SensorHealthReport(
      sampleCount: samples.length,
      requestedRateHz: requestedRateHz,
      effectiveRateHz: effectiveRateHz,
      sampleDrops: drops,
      latestTimestampNs: samples.last.timestampNs,
    );
  }
}

