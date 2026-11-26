import 'package:flutter_test/flutter_test.dart';
import 'package:stradio_app/evaluation/run_metrics_calculator.dart';
import 'package:stradio_app/models/experiment_models.dart';

void main() {
  group('RunMetricsCalculator', () {
    test('handles empty inputs and zero durations safely', () {
      expect(
        RunMetricsCalculator.estimateDistanceKm(
          steps: 0,
          activity: Activity.walking,
        ),
        0.0,
      );
      expect(
        RunMetricsCalculator.estimateSpeedKmh(
          distanceKm: 0.5,
          activeDurationSeconds: 0,
        ),
        0.0,
      );
      expect(
        RunMetricsCalculator.averageCadenceSpm(
          totalSteps: 100,
          activeDurationSeconds: 0,
        ),
        0.0,
      );
      expect(
        RunMetricsCalculator.calculateRhythmScore(
          actualSpm: 0,
          targetBpm: 165,
        ),
        0.0,
      );
      expect(
        RunMetricsCalculator.buildCadenceBuckets(
          detections: const [],
          startTimestampNs: null,
          endTimestampNs: null,
        ),
        isEmpty,
      );
    });

    test('computes accurate distance, speed, cadence, and rhythm score', () {
      final distanceWalk = RunMetricsCalculator.estimateDistanceKm(
        steps: 100,
        activity: Activity.walking,
      );
      expect(distanceWalk, closeTo(0.074, 1e-6));

      final distanceJog = RunMetricsCalculator.estimateDistanceKm(
        steps: 1000,
        activity: Activity.jogging,
      );
      expect(distanceJog, closeTo(0.95, 1e-6));

      // 0.95 km in 300 seconds (5 minutes) -> 11.4 km/h
      final speed = RunMetricsCalculator.estimateSpeedKmh(
        distanceKm: distanceJog,
        activeDurationSeconds: 300,
      );
      expect(speed, closeTo(11.4, 1e-4));

      // 165 steps in 60 seconds -> 165 SPM -> 100% Rhythm Score against 165 BPM
      final spm = RunMetricsCalculator.averageCadenceSpm(
        totalSteps: 165,
        activeDurationSeconds: 60,
      );
      expect(spm, closeTo(165.0, 1e-4));

      final perfectRhythm = RunMetricsCalculator.calculateRhythmScore(
        actualSpm: spm,
        targetBpm: 165,
      );
      expect(perfectRhythm, closeTo(100.0, 1e-4));

      // 158.4 SPM vs 165 BPM -> 4% deviation -> 96% Rhythm Score
      final nearRhythm = RunMetricsCalculator.calculateRhythmScore(
        actualSpm: 158.4,
        targetBpm: 165,
      );
      expect(nearRhythm, closeTo(96.0, 1e-2));
    });

    test('computes rolling cadence and time-bucketed consistency series', () {
      // 20 detections spaced 500ms apart (120 SPM)
      final detections = <DetectionEvent>[
        for (var i = 0; i < 20; i++)
          DetectionEvent(
            detectionId: i,
            sampleIndex: i * 50,
            peakTimestampNs: (i + 1) * 500000000,
            outputTimestampNs: (i + 1) * 500000000 + 10000000,
            thresholdMps2: 10.5,
          ),
      ];

      final liveSpm = RunMetricsCalculator.rollingCadenceSpm(
        detections: detections,
        currentTimestampNs: 10000000000,
      );
      expect(liveSpm, closeTo(120.0, 1e-2));

      final buckets = RunMetricsCalculator.buildCadenceBuckets(
        detections: detections,
        startTimestampNs: 0,
        endTimestampNs: 10000000000,
        bucketCount: 4,
      );
      expect(buckets.length, 4);
      for (final b in buckets) {
        expect(b, greaterThan(0));
      }
    });

    test('analyzes 100 Hz sensor health and detects dropped sample intervals', () {
      // 100 samples at exact 10ms (10,000,000 ns) intervals -> 100 Hz, 0 drops
      final cleanSamples = <SensorSample>[
        for (var i = 0; i < 100; i++)
          SensorSample(
            recordingId: 'REC_TEST',
            sampleIndex: i,
            timestampNs: i * 10000000,
            axMps2: 0.1,
            ayMps2: 0.2,
            azMps2: 9.8,
          ),
      ];

      final cleanHealth = RunMetricsCalculator.analyzeSensorHealth(
        samples: cleanSamples,
        requestedRateHz: 100.0,
      );
      expect(cleanHealth.sampleCount, 100);
      expect(cleanHealth.sampleDrops, 0);
      expect(cleanHealth.effectiveRateHz, closeTo(100.0, 0.5));
      expect(cleanHealth.isHealthy, isTrue);

      // Introduce a 50ms gap (4 missed samples at 100Hz)
      final gappedSamples = <SensorSample>[
        ...cleanSamples.take(50),
        SensorSample(
          recordingId: 'REC_TEST',
          sampleIndex: 50,
          timestampNs: 49 * 10000000 + 50000000,
          axMps2: 0.1,
          ayMps2: 0.2,
          azMps2: 9.8,
        ),
      ];

      final gappedHealth = RunMetricsCalculator.analyzeSensorHealth(
        samples: gappedSamples,
        requestedRateHz: 100.0,
      );
      expect(gappedHealth.sampleDrops, greaterThanOrEqualTo(3));
      expect(gappedHealth.isHealthy, isFalse);
    });

    test('estimates realistic live walking (10-11 /km) and running pace from rolling cadence', () {
      // Normal walking at ~108 SPM (~5.5-5.8 km/h -> ~10:20-10:55 /km)
      final walkSpeed = RunMetricsCalculator.estimateLiveSpeedKmh(
        liveCadenceSpm: 108.0,
        activity: Activity.walking,
      );
      final walkSecPerKm = 3600.0 / walkSpeed;
      expect(walkSecPerKm, inInclusiveRange(600.0, 660.0));

      // Jogging at 165 SPM (~11-12.5 km/h -> ~4:48-5:27 /km)
      final runSpeed = RunMetricsCalculator.estimateLiveSpeedKmh(
        liveCadenceSpm: 165.0,
        activity: Activity.jogging,
      );
      final runSecPerKm = 3600.0 / runSpeed;
      expect(runSecPerKm, inInclusiveRange(280.0, 340.0));
    });

    test('rollingCadenceSpm drops to 0.0 promptly when runner stops and decays on slowdown', () {
      // 10 jogging steps spaced 375ms apart (160 SPM), ending at t = 3.75s
      final detections = <DetectionEvent>[
        for (var i = 0; i < 10; i++)
          DetectionEvent(
            detectionId: i,
            sampleIndex: i * 37,
            peakTimestampNs: (i + 1) * 375000000,
            outputTimestampNs: (i + 1) * 375000000 + 10000000,
            thresholdMps2: 11.0,
          ),
      ];
      final lastTs = detections.last.peakTimestampNs;

      // Active jogging right at last step -> ~160 SPM
      expect(
        RunMetricsCalculator.rollingCadenceSpm(
          detections: detections,
          currentTimestampNs: lastTs,
        ),
        closeTo(160.0, 1.0),
      );

      // 1.0s after last step (slowing down) -> decays below 160 SPM
      final slowingSpm = RunMetricsCalculator.rollingCadenceSpm(
        detections: detections,
        currentTimestampNs: lastTs + 1000000000,
      );
      expect(slowingSpm, lessThan(150.0));
      expect(slowingSpm, greaterThan(0.0));

      // 2.5s after last step (stopped) -> drops to 0.0 (not stuck at 160 SPM!)
      expect(
        RunMetricsCalculator.rollingCadenceSpm(
          detections: detections,
          currentTimestampNs: lastTs + 2500000000,
        ),
        0.0,
      );
    });
  });
}

