import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../algorithms/step_detector.dart';
import '../../evaluation/run_metrics_calculator.dart';
import '../../l10n/stradio_strings.dart';
import '../../models/experiment_models.dart';
import '../../models/sound_pack.dart';
import '../../services/audio_engine_service.dart';
import '../../services/foreground_notification_service.dart';
import '../../services/posthog_service.dart';
import '../../services/preferences_service.dart';
import '../../services/recording_repository.dart';
import '../../services/recording_service.dart';
import '../../theme/stradio_theme.dart';
import '../../widgets/sensor_calibration_sheet.dart';
import '../../widgets/sonic_ribbon_painter.dart';
import 'post_run_summary_screen.dart';

enum _RunStreamState { connecting, running, paused, sensorError }

enum _RecoveryAction { reviewAndSave, discard }

Map<AlgorithmVariant, List<DetectionEvent>> _replayAllFourIsolate(
  Map<String, Object?> payload,
) {
  final samples = payload['samples'] as List<SensorSample>;
  final params = payload['params'] as AlgorithmParameters;
  return StepDetector.replayAllFour(samples, params);
}

/// Surface 2: Active Run Instrument (`docs/DESIGN.md` & `docs/EXPERIENCE.md`).
///
/// Combines the real-time 100 Hz A1 step-detection pipeline, decoupled 2-layer
/// [StradioAudioEngine], Pocket Mode [ForegroundNotificationService], and
/// crash-recovery session cache behind the Daylight Instrument UI:
/// - Dual-tone stacked header (`Stride` / `Rhythm`) + sensor calibration button
/// - 256px Circular Acoustic Dial + central 136px [LiquidGlassLens] (glass 1 of 2)
/// - 2 borderless tabular metrics (`Steps`, `Cadence`) directly on Warm Ivory
/// - Recessed [LiquidGlassLens] bottom dock (glass 2 of 2) with 6-pack hot-swap,
///   Midnight pause/resume pill, and `Hold 1.5s to end` progress ring.
class ActiveRunScreen extends StatefulWidget {
  const ActiveRunScreen({
    super.key,
    this.store,
    this.recordingService,
    this.postHogService,
    this.foregroundService,
    this.audioEngine,
    this.initialSoundPackId = SoundPackId.breakbeatFvnky,
    this.initialLabSettings = const StradioLabSettings(),
    this.userHeightCm,
    this.language = AppLanguage.en,
    this.autoStart = false,
  });

  final RecordingStore? store;
  final RecordingService? recordingService;
  final PostHogTelemetryService? postHogService;
  final ForegroundNotificationService? foregroundService;
  final StradioAudioEngine? audioEngine;
  final SoundPackId initialSoundPackId;
  final StradioLabSettings initialLabSettings;
  final double? userHeightCm;
  final AppLanguage language;
  final bool autoStart;

  @override
  State<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends State<ActiveRunScreen>
    with TickerProviderStateMixin {
  static const Duration _holdToEndDuration = Duration(milliseconds: 1500);
  static const int _healthRingCapacity = 300;

  late final RecordingStore _store;
  late final RecordingService _recordingService;
  late final PostHogTelemetryService _postHogService;
  late final ForegroundNotificationService _foregroundService;
  late final StradioAudioEngine _audioEngine;
  late final bool _ownsAudioEngine;
  late StradioLabSettings _labSettings;
  late double _strideSensitivity;
  late bool _isDeveloperMode;

  late final AnimationController _ribbonController;
  late final AnimationController _continuousWaveController;
  late final AnimationController _holdController;

  bool get _isTestBinding =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  _RunStreamState _streamState = _RunStreamState.connecting;
  String _recordingId = 'REC_LIVE_001';
  String? _sensorErrorText;
  String? _holdHintText;
  bool _stepPulseActive = false;
  bool _hasStartedRun = false;
  bool _isFinishing = false;
  bool _isFlushingCache = false;
  int _lastHapticBucket = -1;

  late Map<AlgorithmVariant, StepDetector> _detectors;
  late Map<AlgorithmVariant, List<DetectionEvent>> _liveDetections;
  final List<SensorSample> _activeSamples = [];
  final ListQueue<SensorSample> _recentHealthSamples = ListQueue<SensorSample>();
  SensorSample? _latestSample;

  Timer? _elapsedTimer;
  Timer? _stepPulseTimer;
  Timer? _holdHintTimer;
  double _activeDurationSeconds = 0.0;

  AlgorithmVariant get _primaryVariant => AlgorithmVariant.a1MidpointRaw;
  List<DetectionEvent> get _primaryDetections =>
      _liveDetections[_primaryVariant] ?? const [];
  AlgorithmParameters get _detectorParams =>
      AlgorithmParameters.forSensitivity(_strideSensitivity);

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? FileRecordingStore();
    _recordingService = widget.recordingService ?? RecordingService();
    _postHogService = widget.postHogService ?? PostHogTelemetryService();
    _foregroundService =
        widget.foregroundService ?? FlutterForegroundNotificationService();
    _ownsAudioEngine = widget.audioEngine == null;
    _audioEngine =
        widget.audioEngine ??
        StradioAudioEngine(initialPack: widget.initialSoundPackId);
    _labSettings = widget.initialLabSettings;
    _strideSensitivity = StradioPreferencesService.loadStrideSensitivity();
    _isDeveloperMode =
        StradioPreferencesService.loadUserProfile().developerModeEnabled ||
        _labSettings.developerOverlayEnabled;

    if (widget.audioEngine != null &&
        _audioEngine.activePackId != widget.initialSoundPackId) {
      unawaited(_audioEngine.switchPack(widget.initialSoundPackId));
    }
    unawaited(_audioEngine.preloadActivePack());

    _ribbonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _continuousWaveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _holdController = AnimationController(
      vsync: this,
      duration: _holdToEndDuration,
    )..addListener(_onHoldTick);

    _foregroundService.addActionListener(_handleNotificationAction);
    _resetDetectors();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }

  void _resetDetectors() {
    final params = _detectorParams;
    final activeVariants = _isDeveloperMode
        ? AlgorithmVariant.values
        : [_primaryVariant];
    _detectors = {
      for (final variant in activeVariants)
        variant: StepDetector(
          algorithm: variant.thresholdAlgorithm,
          parameters: params,
          useLinearAcceleration: variant.usesLinearAcceleration,
        ),
    };
    _liveDetections = {
      for (final variant in AlgorithmVariant.values) variant: [],
    };
  }

  void _applyCalibrationSensitivity(double sensitivity) {
    final clamped = sensitivity.clamp(0.8, 2.4);
    if ((clamped - _strideSensitivity).abs() < 0.005) return;
    _strideSensitivity = clamped;
    unawaited(StradioPreferencesService.saveStrideSensitivity(clamped));
    final params = _detectorParams;
    final activeVariants = _isDeveloperMode
        ? AlgorithmVariant.values
        : [_primaryVariant];
    _detectors = {
      for (final variant in activeVariants)
        variant: StepDetector(
          algorithm: variant.thresholdAlgorithm,
          parameters: params,
          useLinearAcceleration: variant.usesLinearAcceleration,
        ),
    };
  }

  void _syncRibbonAnimation() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context) ||
        _streamState != _RunStreamState.running) {
      _ribbonController.stop();
      _continuousWaveController.stop();
    } else if (!_isTestBinding && !_continuousWaveController.isAnimating) {
      _continuousWaveController.repeat();
    }
  }

  Future<void> _initializeSession() async {
    if (!mounted) return;
    final cached = await _store.loadActiveSessionCache();
    if (!mounted) return;

    if (cached != null &&
        (cached.samples.isNotEmpty || cached.liveStepCount > 0)) {
      final action = await _showCrashRecoveryDialog(cached);
      if (!mounted) return;
      if (action == _RecoveryAction.reviewAndSave) {
        await _openRecoveredSummary(cached);
        if (!mounted) return;
      } else {
        await _store.clearActiveSessionCache();
      }
    }

    await _startSensorStream();
    if (!mounted) return;
    if (widget.autoStart && _streamState != _RunStreamState.sensorError) {
      await _startRunning();
    }
  }

  Future<_RecoveryAction?> _showCrashRecoveryDialog(
    ActiveSessionSnapshot snapshot,
  ) {
    final s = StradioStrings.of(widget.language);
    final samplesCount = snapshot.samples.length;
    return showDialog<_RecoveryAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: StradioColors.surfaceCard,
        title: Text(
          s.recoverRunTitle,
          style: StradioTypography.headingSmall(),
        ),
        content: Text(
          s.recoverRunBody(
            samplesCount,
            snapshot.activeDurationSeconds.round(),
            stepCount: snapshot.liveStepCount,
          ),
          style: StradioTypography.body(),
        ),
        actions: [
          TextButton(
            key: const Key('recovery_discard_button'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_RecoveryAction.discard),
            child: Text(s.discardAction),
          ),
          FilledButton(
            key: const Key('recovery_review_button'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_RecoveryAction.reviewAndSave),
            child: Text(s.reviewAndSaveAction),
          ),
        ],
      ),
    );
  }

  Future<void> _openRecoveredSummary(ActiveSessionSnapshot snapshot) async {
    final hasRaw = snapshot.samples.isNotEmpty;
    final replay = hasRaw
        ? (snapshot.samples.length > 500
              ? await compute(_replayAllFourIsolate, {
                  'samples': snapshot.samples,
                  'params': _detectorParams,
                })
              : StepDetector.replayAllFour(snapshot.samples, _detectorParams))
        : const <AlgorithmVariant, List<DetectionEvent>>{};
    final primaryDetections = hasRaw
        ? (replay[AlgorithmVariant.a1MidpointRaw] ?? const <DetectionEvent>[])
        : snapshot.detections;
    final stepCount = hasRaw
        ? primaryDetections.length
        : math.max(snapshot.liveStepCount, primaryDetections.length);
    final recording = SavedRecording(
      recordingId: snapshot.recordingId,
      createdAt: snapshot.createdAt,
      config: snapshot.config,
      samples: snapshot.samples,
      liveStepCount: stepCount,
      replayDetections: hasRaw
          ? {
              ThresholdAlgorithm.adaptiveMidpoint: primaryDetections,
              ThresholdAlgorithm.meanStd:
                  replay[AlgorithmVariant.b1MeanSdRaw] ?? const [],
            }
          : const {},
      replayVariantDetections: replay,
      summaryDurationSeconds: snapshot.activeDurationSeconds,
      targetBpm: snapshot.targetBpm,
      includeRawSamples: hasRaw,
    );
    final metrics = RunMetricsCalculator.computeSummary(
      detections: primaryDetections,
      samples: snapshot.samples,
      activity: snapshot.config.activity,
      activeDurationSeconds: snapshot.activeDurationSeconds,
      targetBpm: snapshot.targetBpm,
      heightCm: widget.userHeightCm,
      overrideStepCount: stepCount,
    );
    final health = RunMetricsCalculator.analyzeSensorHealth(
      samples: snapshot.samples,
    );

    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PostRunSummaryScreen(
          recording: recording,
          metrics: metrics,
          sensorHealth: health,
          store: _store,
          postHogService: _postHogService,
          soundPackId: _audioEngine.activePackId,
          language: widget.language,
        ),
      ),
    );
  }

  Future<void> _startSensorStream() async {
    setState(() {
      _streamState = _RunStreamState.connecting;
      _sensorErrorText = null;
    });

    try {
      _recordingId = await _store.nextId(DateTime.now());
      final available = await _recordingService.isAccelerometerAvailable(
        timeout: const Duration(milliseconds: 800),
      );
      if (!mounted) return;

      if (!available) {
        setState(() {
          _streamState = _RunStreamState.sensorError;
          _sensorErrorText =
              'Motion sensor unavailable. Check permissions or use simulated steps.';
        });
        _syncRibbonAnimation();
        return;
      }

      if (_recordingService.isRecording) {
        await _recordingService.stop();
      }
      _recordingService.start(
        _recordingId,
        samplingRateHz: 100.0,
        retainSamples: _isDeveloperMode,
        includeLinearStream: _isDeveloperMode,
        onSample: _handleIncomingSample,
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _streamState = _RunStreamState.sensorError;
            _sensorErrorText = 'Accelerometer error: $err';
          });
          _syncRibbonAnimation();
        },
      );

      if (!mounted) return;
      setState(() {
        _streamState = _RunStreamState.paused;
        _sensorErrorText = null;
      });
      _syncRibbonAnimation();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _streamState = _RunStreamState.sensorError;
        _sensorErrorText = 'Could not start motion sensor: $error';
      });
      _syncRibbonAnimation();
    }
  }

  void _startElapsedTicker() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _streamState != _RunStreamState.running) return;
      setState(() => _activeDurationSeconds += 1.0);
      _audioEngine.updateCadence(_currentLiveCadenceSpm());
      _syncForegroundNotification(isRunning: true);
      if (_activeDurationSeconds.round() % 10 == 0) {
        unawaited(_flushActiveSessionCache());
      }
    });
  }

  double _currentLiveCadenceSpm() {
    if (_primaryDetections.length < 2) return 0.0;
    final nowNs =
        _latestSample?.timestampNs ??
        DateTime.now().microsecondsSinceEpoch * 1000;
    return RunMetricsCalculator.rollingCadenceSpm(
      detections: _primaryDetections,
      currentTimestampNs: nowNs,
    );
  }

  Future<void> _flushActiveSessionCache() async {
    if (_isFlushingCache) return;
    if (_activeSamples.isEmpty && _primaryDetections.isEmpty) return;
    _isFlushingCache = true;
    try {
      final cachedDetections =
          (_isDeveloperMode || _primaryDetections.length <= 60)
          ? List.of(_primaryDetections)
          : _primaryDetections.sublist(_primaryDetections.length - 60);
      final snapshot = ActiveSessionSnapshot(
        recordingId: _recordingId,
        createdAt: DateTime.now(),
        config: _labSettings.toExperimentConfig(),
        samples: _isDeveloperMode ? List.of(_activeSamples) : const [],
        liveStepCount: _primaryDetections.length,
        detections: cachedDetections,
        activeDurationSeconds: _activeDurationSeconds,
        targetBpm: _labSettings.targetBpm,
      );
      await _store.saveActiveSessionCache(snapshot);
    } finally {
      _isFlushingCache = false;
    }
  }

  void _handleIncomingSample(SensorSample sample) {
    if (!mounted || _streamState != _RunStreamState.running) return;

    if (_recentHealthSamples.length >= _healthRingCapacity) {
      _recentHealthSamples.removeFirst();
    }
    _recentHealthSamples.addLast(sample);
    if (_isDeveloperMode) {
      _activeSamples.add(sample);
    }
    _latestSample = sample;

    DetectorOutput? primaryOut;
    for (final entry in _detectors.entries) {
      final out = entry.value.addSample(sample);
      if (out.step != null) {
        _liveDetections[entry.key]!.add(out.step!);
      }
      if (entry.key == _primaryVariant) {
        primaryOut = out;
      }
    }

    if (primaryOut?.step != null) {
      final liveSpm = _currentLiveCadenceSpm();
      unawaited(_audioEngine.onStepDetected(cadenceSpm: liveSpm));
      _triggerStepRefractionPulse();
      _syncForegroundNotification(isRunning: true);
      setState(() {});
    }
  }

  void _triggerStepRefractionPulse() {
    _stepPulseActive = true;
    if (mounted && !MediaQuery.disableAnimationsOf(context)) {
      _ribbonController.forward(from: 0.0);
    }
    _stepPulseTimer?.cancel();
    _stepPulseTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) {
        setState(() => _stepPulseActive = false);
      }
    });
  }

  /// Explicit fallback for emulator/testing when hardware accelerometer is unavailable.
  void _simulateSingleStride() {
    final baseTs = _latestSample == null
        ? DateTime.now().microsecondsSinceEpoch * 1000
        : _latestSample!.timestampNs + 350000000;

    const rawAzWave = [
      9.5,
      9.5,
      9.5,
      9.5,
      9.5,
      9.5,
      14.2,
      16.8,
      13.8,
      9.1,
      9.1,
      9.1,
      9.1,
      9.1,
      9.1,
    ];
    const linearUzWave = [
      0.1,
      0.1,
      0.1,
      0.1,
      0.1,
      0.1,
      3.5,
      6.8,
      3.2,
      0.1,
      0.1,
      0.1,
      0.1,
      0.1,
      0.1,
    ];

    final prevState = _streamState;
    _streamState = _RunStreamState.running;
    if (!_audioEngine.isSessionActive) {
      unawaited(_audioEngine.startSession());
    }

    final baseIdx = _latestSample?.sampleIndex ?? -1;
    for (var i = 0; i < rawAzWave.length; i++) {
      _handleIncomingSample(
        SensorSample(
          recordingId: _recordingId,
          sampleIndex: baseIdx + 1 + i,
          timestampNs: baseTs + i * 25000000,
          axMps2: 0.3,
          ayMps2: 1.2,
          azMps2: rawAzWave[i],
          uxMps2: 0.1,
          uyMps2: 0.3,
          uzMps2: linearUzWave[i],
        ),
      );
    }

    if (_activeDurationSeconds < 1.0) {
      _activeDurationSeconds = 1.0;
    }
    if (prevState == _RunStreamState.sensorError) {
      _streamState = _RunStreamState.sensorError;
    }
    setState(() {});
  }

  Future<void> _startRunning() async {
    if (!_recordingService.isRecording &&
        _streamState != _RunStreamState.sensorError) {
      await _startSensorStream();
    }
    final isFirstStart = !_hasStartedRun;
    _hasStartedRun = true;
    setState(() {
      _streamState = _RunStreamState.running;
      _sensorErrorText = null;
    });
    _syncRibbonAnimation();
    _startElapsedTicker();

    if (_audioEngine.isSessionActive) {
      unawaited(_audioEngine.resumeSession());
    } else {
      unawaited(_audioEngine.startSession());
    }

    unawaited(_foregroundService.requestNotificationPermission());
    unawaited(
      _foregroundService.startWorkoutService(
        steps: _primaryDetections.length,
        targetSteps: _labSettings.targetSteps,
        activeDurationSeconds: _activeDurationSeconds,
        targetBpm: _labSettings.targetBpm,
        algorithmName: _labSettings.primaryAlgorithm.displayName,
        isRunning: true,
        soundPackTitle: _audioEngine.activePack.title,
      ),
    );

    if (isFirstStart) {
      unawaited(
        _postHogService.captureRunStarted(
          recordingId: _recordingId,
          config: _labSettings.toExperimentConfig(),
          targetBpm: _labSettings.targetBpm,
          soundPackCode: _audioEngine.activePack.code,
        ),
      );
    } else {
      unawaited(
        _postHogService.captureRunResumed(
          recordingId: _recordingId,
          participantId: _labSettings.participantId,
          elapsedSeconds: _activeDurationSeconds,
          currentSteps: _primaryDetections.length,
        ),
      );
    }
  }

  Future<void> _pauseRunning() async {
    unawaited(_flushActiveSessionCache());
    setState(() => _streamState = _RunStreamState.paused);
    _syncRibbonAnimation();
    unawaited(_audioEngine.pauseSession());
    _syncForegroundNotification(isRunning: false);
    unawaited(
      _postHogService.captureRunPaused(
        recordingId: _recordingId,
        participantId: _labSettings.participantId,
        elapsedSeconds: _activeDurationSeconds,
        currentSteps: _primaryDetections.length,
      ),
    );
  }

  Future<void> _togglePauseResume() async {
    HapticFeedback.selectionClick();
    if (_streamState == _RunStreamState.running) {
      await _pauseRunning();
    } else {
      await _startRunning();
    }
  }

  void _syncForegroundNotification({required bool isRunning}) {
    if (!_foregroundService.isServiceActive) return;
    unawaited(
      _foregroundService.updateWorkoutService(
        steps: _primaryDetections.length,
        targetSteps: _labSettings.targetSteps,
        activeDurationSeconds: _activeDurationSeconds,
        targetBpm: _labSettings.targetBpm,
        algorithmName: _labSettings.primaryAlgorithm.displayName,
        isRunning: isRunning,
        soundPackTitle: _audioEngine.activePack.title,
      ),
    );
  }

  void _handleNotificationAction(String actionId) {
    if (!mounted) return;
    if (actionId == 'pause_resume') {
      unawaited(_togglePauseResume());
    } else if (actionId == 'finish') {
      unawaited(_finishRun());
    }
  }

  void _onHoldTick() {
    if (!mounted) return;
    final bucket = (_holdController.value * 5).floor();
    if (bucket > _lastHapticBucket && _holdController.isAnimating) {
      _lastHapticBucket = bucket;
      HapticFeedback.lightImpact();
    }
    if (_holdController.isCompleted && !_isFinishing) {
      HapticFeedback.heavyImpact();
      unawaited(_finishRun());
    }
  }

  void _onHoldStart() {
    if (_isFinishing) return;
    _lastHapticBucket = -1;
    _holdController.forward(from: 0.0);
  }

  void _onHoldCancelOrShortTap() {
    if (_isFinishing) return;
    final wasShort = _holdController.value < 0.95;
    _holdController.reverse();
    if (wasShort) {
      final s = StradioStrings.of(widget.language);
      setState(() => _holdHintText = s.holdToEndHint);
      _holdHintTimer?.cancel();
      _holdHintTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _holdHintText = null);
      });
    }
  }

  Future<void> _finishRun() async {
    if (_isFinishing) return;
    _isFinishing = true;
    _elapsedTimer?.cancel();
    _ribbonController.stop();
    _continuousWaveController.stop();
    unawaited(_recordingService.stop());
    unawaited(_audioEngine.stopSession());
    unawaited(_foregroundService.stopWorkoutService());

    final hasRaw = _isDeveloperMode && _activeSamples.isNotEmpty;
    final samplesCopy = hasRaw
        ? List<SensorSample>.of(_activeSamples)
        : const <SensorSample>[];
    final healthSamples = hasRaw
        ? samplesCopy
        : List<SensorSample>.of(_recentHealthSamples);
    final replay = hasRaw
        ? (samplesCopy.length > 500
              ? await compute(_replayAllFourIsolate, {
                  'samples': samplesCopy,
                  'params': _detectorParams,
                })
              : StepDetector.replayAllFour(samplesCopy, _detectorParams))
        : const <AlgorithmVariant, List<DetectionEvent>>{};
    final recording = SavedRecording(
      recordingId: _recordingId,
      createdAt: DateTime.now(),
      config: _labSettings.toExperimentConfig().copyWithParameters(
        _detectorParams,
      ),
      samples: samplesCopy,
      liveStepCount: _primaryDetections.length,
      replayDetections: hasRaw
          ? {
              ThresholdAlgorithm.adaptiveMidpoint:
                  replay[AlgorithmVariant.a1MidpointRaw] ?? const [],
              ThresholdAlgorithm.meanStd:
                  replay[AlgorithmVariant.b1MeanSdRaw] ?? const [],
            }
          : const {},
      replayVariantDetections: replay,
      summaryDurationSeconds: _activeDurationSeconds,
      targetBpm: _labSettings.targetBpm,
      includeRawSamples: hasRaw,
    );
    final metrics = RunMetricsCalculator.computeSummary(
      detections: _primaryDetections,
      samples: samplesCopy,
      activity: _labSettings.activity,
      activeDurationSeconds: _activeDurationSeconds,
      targetBpm: _labSettings.targetBpm,
      heightCm: widget.userHeightCm,
      overrideStepCount: _primaryDetections.length,
    );
    final health = RunMetricsCalculator.analyzeSensorHealth(
      samples: healthSamples,
    );

    // Persist locally and emit run_completed immediately on finish (FR-6.1) so
    // exporting a story and closing the app never loses the run or telemetry.
    var savedOk = false;
    try {
      await _store.save(recording.toSummaryOnly());
      await _store.clearActiveSessionCache();
      savedOk = true;
    } on Object catch (error) {
      debugPrint('Auto-save on finish failed (will allow retry on summary): $error');
    }
    unawaited(
      _postHogService.captureWorkoutAndBenchmarks(
        recording: recording,
        metrics: metrics,
        health: health,
        soundPackCode: _audioEngine.activePack.code,
      ),
    );

    if (!mounted) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PostRunSummaryScreen(
          recording: recording,
          metrics: metrics,
          sensorHealth: health,
          store: _store,
          postHogService: _postHogService,
          soundPackId: _audioEngine.activePackId,
          language: widget.language,
          alreadySaved: savedOk,
        ),
      ),
    );

    if (!mounted) return;
    if ((savedOk || completed == true) && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    // If save failed and user backed out without retrying, return ready to resume.
    _isFinishing = false;
    _holdController.reset();
    await _startSensorStream();
  }

  Future<void> _showSoundPackPickerSheet() async {
    final s = StradioStrings.of(widget.language);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.paddingOf(sheetContext).bottom;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              key: const Key('sound_pack_picker_sheet'),
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomPadding),
              decoration: BoxDecoration(
                color: StradioColors.surfaceCard.withValues(alpha: 0.86),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
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
                    Text(
                      s.soundPackSheetTitle,
                      style: StradioTypography.headingSmall(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.soundPackSheetSubtitle,
                      style: StradioTypography.body(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    for (final pack in StradioSoundPack.catalog) ...[
                      Material(
                        color: _audioEngine.activePackId == pack.id
                            ? StradioColors.glowCoralSoft.withValues(
                                alpha: 0.85,
                              )
                            : StradioColors.warmIvory.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(StradioRadii.lg),
                        child: InkWell(
                          key: Key('sound_pack_option_${pack.code}'),
                          borderRadius: BorderRadius.circular(StradioRadii.lg),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            unawaited(_audioEngine.switchPack(pack.id));
                            unawaited(
                              StradioPreferencesService.saveActiveSoundPackId(
                                pack.id,
                              ),
                            );
                            setState(() {});
                            _syncForegroundNotification(
                              isRunning:
                                  _streamState == _RunStreamState.running,
                            );
                            Navigator.of(sheetContext).pop();
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                StradioRadii.lg,
                              ),
                              border: Border.all(
                                color: _audioEngine.activePackId == pack.id
                                    ? StradioColors.midnight
                                    : Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.headphones_rounded,
                                  size: 18,
                                  color: _audioEngine.activePackId == pack.id
                                      ? StradioColors.textAccentDeep
                                      : StradioColors.twilightPlum,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${pack.title} · ${pack.categoryLabel}',
                                        style: StradioTypography.pillBadge(),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        pack.tagline,
                                        style: StradioTypography.metricLabel(),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_audioEngine.activePackId == pack.id)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: StradioColors.midnight,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSensorCalibrationSheet() async {
    final pipelineState = switch (_streamState) {
      _RunStreamState.running => SensorPipelineState.active,
      _RunStreamState.paused => SensorPipelineState.ready,
      _RunStreamState.connecting => SensorPipelineState.calibrating,
      _RunStreamState.sensorError => SensorPipelineState.unavailable,
    };
    final health = RunMetricsCalculator.analyzeSensorHealth(
      samples: _isDeveloperMode ? _activeSamples : _recentHealthSamples.toList(),
      requestedRateHz: 100.0,
    );
    await SensorCalibrationSheet.show(
      context,
      state: pipelineState,
      healthReport: health,
      errorMessage: _sensorErrorText,
      initialSensitivity: _strideSensitivity,
      onApplyCalibration: _applyCalibrationSensitivity,
      language: widget.language,
      onRetrySensor: _startSensorStream,
      onSimulateStride: _simulateSingleStride,
    );
  }

  String _formatDuration(double seconds) {
    final s = seconds.round();
    final mins = (s ~/ 60).toString().padLeft(2, '0');
    final rem = (s % 60).toString().padLeft(2, '0');
    return '$mins:$rem';
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

  String _formatPaceFromSpeedKmh(double kmh) {
    final secPerKm = (3600.0 / kmh).round().clamp(150, 1800);
    final mins = secPerKm ~/ 60;
    final rem = (secPerKm % 60).toString().padLeft(2, '0');
    return '$mins:$rem';
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _stepPulseTimer?.cancel();
    _holdHintTimer?.cancel();
    _ribbonController.dispose();
    _continuousWaveController.dispose();
    _holdController.dispose();
    _foregroundService.removeActionListener(_handleNotificationAction);
    unawaited(_foregroundService.stopWorkoutService());
    if (_ownsAudioEngine) {
      unawaited(_audioEngine.dispose());
    } else {
      unawaited(_audioEngine.stopSession());
    }
    unawaited(_recordingService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(widget.language);
    final isId = widget.language == AppLanguage.id;
    final steps = _primaryDetections.length;
    final liveSpm = _currentLiveCadenceSpm();
    final hasCadence = liveSpm > 0;
    final isRunning = _streamState == _RunStreamState.running;
    final isPaused = _streamState == _RunStreamState.paused;
    final isSensorError = _streamState == _RunStreamState.sensorError;
    final allowDialSimulate = isSensorError || _isDeveloperMode;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    final currentDistanceKm = RunMetricsCalculator.estimateDistanceKm(
      steps: steps,
      activity: _labSettings.activity,
      heightCm: widget.userHeightCm,
    );
    final speedKmh = RunMetricsCalculator.estimateSpeedKmh(
      distanceKm: currentDistanceKm,
      activeDurationSeconds: _activeDurationSeconds,
    );
    final liveSpeedKmh = RunMetricsCalculator.estimateLiveSpeedKmh(
      liveCadenceSpm: liveSpm,
      activity: _labSettings.activity,
      heightCm: widget.userHeightCm,
      fallbackSpeedKmh: speedKmh,
    );
    final paceText = (steps > 0 && liveSpeedKmh >= 0.5)
        ? _formatPaceFromSpeedKmh(liveSpeedKmh)
        : '--:--';

    final (statusText, statusDotColor) = switch (_streamState) {
      _RunStreamState.running => (
        hasCadence
            ? 'ACTIVE • ${_audioEngine.activePack.title.toUpperCase()}'
            : (isId ? 'IDLE • MULAI MELANGKAH' : 'IDLE • TAKE A STEP'),
        hasCadence ? StradioColors.sonicCoral : StradioColors.textSecondary,
      ),
      _RunStreamState.paused => (
        s.pausedLabel.toUpperCase(),
        StradioColors.statusPaused,
      ),
      _RunStreamState.connecting => (
        s.calibratingLabel.toUpperCase(),
        StradioColors.twilightPlum,
      ),
      _RunStreamState.sensorError => (
        isId
            ? 'STANDBY • KETUK DIAL UNTUK SIMULASI'
            : 'IDLE • TAP DIAL TO SIMULATE STEP',
        StradioColors.textAccentDeep,
      ),
    };

    final liveBadgeLabel = switch (_streamState) {
      _RunStreamState.running => 'LIVE • ${_formatDuration(_activeDurationSeconds)}',
      _RunStreamState.paused => '${s.pausedLabel} • ${_formatDuration(_activeDurationSeconds)}',
      _RunStreamState.connecting => s.calibratingLabel,
      _RunStreamState.sensorError => s.standbyLabel,
    };

    return Scaffold(
      backgroundColor: StradioColors.warmIvory,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Minimal Active Header (Foto 4): Stradio left | LIVE pill + compact Sound Pack & Pause right
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/stradio-logo.png',
                        height: 20,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Stradio',
                        style: StradioTypography.headingSmall(fontSize: 16),
                      ),
                      const SizedBox(width: 8),

                      // Live Duration Pill (tappable -> Sensor Calibration)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Material(
                            color: StradioColors.surfaceRecessed.withValues(
                              alpha: 0.85,
                            ),
                            borderRadius: BorderRadius.circular(
                              StradioRadii.full,
                            ),
                            child: InkWell(
                              key: const Key('active_run_sensor_button'),
                              borderRadius: BorderRadius.circular(
                                StradioRadii.full,
                              ),
                              onTap: _openSensorCalibrationSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    StradioRadii.full,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      key: const Key('status_indicator_dot'),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isRunning
                                            ? StradioColors.sonicCoral
                                            : isPaused
                                            ? StradioColors.statusPaused
                                            : StradioColors.textAccentDeep,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        liveBadgeLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: StradioTypography.microCap(
                                          color: StradioColors.textPrimary,
                                        ).copyWith(fontSize: 9.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Compact Sound Pack Switcher (FR-4.2)
                      _HeaderCompactIcon(
                        buttonKey: const Key('sound_pack_selector_button'),
                        icon: Icons.headphones_rounded,
                        tooltip: 'Switch sound pack',
                        onTap: _showSoundPackPickerSheet,
                      ),
                      const SizedBox(width: 6),

                      // Compact Pause / Resume Button
                      _HeaderCompactIcon(
                        buttonKey: const Key('pause_resume_run_button'),
                        icon: isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        tooltip: isRunning ? 'Pause run' : 'Resume run',
                        onTap: _togglePauseResume,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Cadence Monolith Hero Focus (72px Sora tabular)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          hasCadence ? '${liveSpm.round()}' : '--',
                          key: const Key('active_run_cadence_monolith'),
                          style: StradioTypography.metricHero(fontSize: 68),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SPM',
                          style: StradioTypography.pillBadge(
                            color: StradioColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'CADENCE MONOLITH',
                      style: StradioTypography.microCap(
                        color: StradioColors.textSecondary,
                      ).copyWith(letterSpacing: 1.4),
                    ),
                  ],
                ),

                // 3. Concentric Acoustic Compass Dial + Step-Triggered Horizontal Wave
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final dialSize = math
                          .min(
                            constraints.maxWidth - 32,
                            constraints.maxHeight - 12,
                          )
                          .clamp(150.0, 256.0);

                      return Center(
                        child: GestureDetector(
                          key: const Key('active_run_glass_lens'),
                          behavior: HitTestBehavior.opaque,
                          onTap: allowDialSimulate
                              ? _simulateSingleStride
                              : null,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: dialSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Step-Triggered Acoustic Wave (idle flat ~1.5px -> surges on footstep)
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: AnimatedBuilder(
                                      animation: Listenable.merge([
                                        _ribbonController,
                                        _continuousWaveController,
                                      ]),
                                      builder: (_, _) {
                                        final energy =
                                            (_stepPulseActive && !reducedMotion)
                                            ? Curves.easeOut.transform(
                                                (1.0 - _ribbonController.value)
                                                    .clamp(0.0, 1.0),
                                              )
                                            : 0.0;
                                        return CustomPaint(
                                          painter: SonicRibbonPainter(
                                            phase: reducedMotion
                                                ? 0.0
                                                : _continuousWaveController
                                                          .value *
                                                      math.pi *
                                                      2,
                                            amplitude: 0.03 + energy * 0.85,
                                            pulseBoost: energy,
                                            strokeWidth: 1.6 + energy * 1.4,
                                            opacity: 0.35 + energy * 0.65,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // Concentric Compass Dial Rings + Cardinal Labels + Center Strike Node
                                SizedBox(
                                  width: dialSize,
                                  height: dialSize,
                                  child: RepaintBoundary(
                                    child: AnimatedBuilder(
                                      animation: Listenable.merge([
                                        _continuousWaveController,
                                        _ribbonController,
                                      ]),
                                      builder: (_, _) {
                                        final energy =
                                            (_stepPulseActive && !reducedMotion)
                                            ? (1.0 - _ribbonController.value)
                                                  .clamp(0.0, 1.0)
                                            : 0.0;
                                        return CustomPaint(
                                          painter: _CompassMonolithDialPainter(
                                            orbitAngle: reducedMotion
                                                ? 0.0
                                                : _continuousWaveController
                                                          .value *
                                                      math.pi *
                                                      2,
                                            energy: energy,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // Cardinal Degree Labels (0° / N, 90°, 180° / S, 270°)
                                SizedBox(
                                  width: dialSize,
                                  height: dialSize,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned(
                                        top: 0,
                                        child: Text(
                                          '0° / N',
                                          style: StradioTypography.metricLabel()
                                              .copyWith(fontSize: 9.5),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        child: Text(
                                          '180° / S',
                                          style: StradioTypography.metricLabel()
                                              .copyWith(fontSize: 9.5),
                                        ),
                                      ),
                                      Positioned(
                                        left: 2,
                                        child: Text(
                                          '270°',
                                          style: StradioTypography.metricLabel()
                                              .copyWith(fontSize: 9.5),
                                        ),
                                      ),
                                      Positioned(
                                        right: 2,
                                        child: Text(
                                          '90°',
                                          style: StradioTypography.metricLabel()
                                              .copyWith(fontSize: 9.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 4. Center Status Pill (tappable to simulate ONLY when sensor unavailable / Dev Mode)
                Center(
                  child: Material(
                    color: StradioColors.surfaceCard.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(StradioRadii.full),
                    child: InkWell(
                      key: isSensorError
                          ? const Key('simulate_stride_banner_button')
                          : const Key('active_run_status_pill'),
                      borderRadius: BorderRadius.circular(StradioRadii.full),
                      onTap: allowDialSimulate ? _simulateSingleStride : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            StradioRadii.full,
                          ),
                          border: Border.all(
                            color: StradioColors.borderSubtle,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusDotColor,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              statusText,
                              style: StradioTypography.microCap(
                                color: StradioColors.textSecondary,
                              ).copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Frosted 3-Metric Running Bar (Distance · Pace · Steps)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: StradioColors.surfaceCard.withValues(
                            alpha: 0.82,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _MonolithMetricItem(
                                label: s.distanceLabel.toUpperCase(),
                                value: currentDistanceKm.toStringAsFixed(2),
                                unit: 'km',
                              ),
                            ),
                            _MetricDotDivider(),
                            Expanded(
                              child: _MonolithMetricItem(
                                valueKey: const Key('active_run_pace_value'),
                                label: s.paceLabel.toUpperCase(),
                                value: paceText,
                                unit: '/km',
                              ),
                            ),
                            _MetricDotDivider(),
                            Expanded(
                              child: _MonolithMetricItem(
                                valueKey: const Key('active_run_step_count'),
                                label: s.stepsLabel.toUpperCase(),
                                value: _formatSteps(steps),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 6. Single 56dp Deep Midnight Obsidian "Hold to finish (1.5s)" Pill
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Semantics(
                    button: true,
                    label: 'Hold 1.5 seconds to finish run',
                    child: Listener(
                      key: const Key('hold_to_end_run_button'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => _onHoldStart(),
                      onPointerUp: (_) => _onHoldCancelOrShortTap(),
                      onPointerCancel: (_) => _onHoldCancelOrShortTap(),
                      child: AnimatedBuilder(
                        animation: _holdController,
                        builder: (_, _) {
                          final progress = _holdController.value;
                          final label = _isFinishing
                              ? (isId ? 'Menyimpan...' : 'Finishing...')
                              : (progress > 0.05
                                    ? (isId ? 'Tahan...' : 'Finishing...')
                                    : (_holdHintText ??
                                          (isId
                                              ? 'Tahan untuk selesai'
                                              : 'Hold to finish')));
                          return Container(
                            key: const Key('active_run_bottom_dock'),
                            height: 56,
                            decoration: BoxDecoration(
                              color: StradioColors.midnight,
                              borderRadius: BorderRadius.circular(
                                StradioRadii.full,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: StradioColors.midnight.withValues(
                                    alpha: 0.22,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                StradioRadii.full,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Horizontal Sonic Coral Progress Sweep (0% -> 100%)
                                  Positioned.fill(
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress.clamp(0.0, 1.0),
                                      child: const DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: StradioColors.sonicCoral,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: StradioColors.surfaceCard,
                                          ),
                                          child: const Icon(
                                            Icons.stop_rounded,
                                            size: 20,
                                            color: StradioColors.textAccentDeep,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            label,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                StradioTypography.buttonLabel(
                                                  color:
                                                      StradioColors.textOnDark,
                                                ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 44,
                                          child: Text(
                                            '1.5s',
                                            textAlign: TextAlign.center,
                                            style: StradioTypography.metricLabel(
                                              color: StradioColors.textOnDark
                                                  .withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

class _HeaderCompactIcon extends StatelessWidget {
  const _HeaderCompactIcon({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: StradioColors.surfaceCard.withValues(alpha: 0.88),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.90)),
        ),
        child: InkWell(
          key: buttonKey,
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 18, color: StradioColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _MonolithMetricItem extends StatelessWidget {
  const _MonolithMetricItem({
    this.valueKey,
    required this.label,
    required this.value,
    this.unit,
  });

  final Key? valueKey;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: StradioTypography.microCap(
            color: StradioColors.textSecondary,
          ).copyWith(fontSize: 9.5),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                key: valueKey,
                style: StradioTypography.headingSmall(fontSize: 19),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(
                  unit!,
                  style: StradioTypography.metricLabel().copyWith(
                    fontSize: 10.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricDotDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: StradioColors.borderSubtle.withValues(alpha: 0.95),
      ),
    );
  }
}

/// Concentric 3-ring compass dial + center Sonic Coral strike node & shockwave (Foto 4).
class _CompassMonolithDialPainter extends CustomPainter {
  const _CompassMonolithDialPainter({
    required this.orbitAngle,
    required this.energy,
  });

  final double orbitAngle;
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide * 0.44;
    final midR = outerR * 0.80;
    final innerR = outerR * 0.54;

    // Fine crosshairs
    final crossPaint = Paint()
      ..color = StradioColors.midnight.withValues(alpha: 0.06)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(center.dx, center.dy - outerR),
      Offset(center.dx, center.dy + outerR),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx - outerR, center.dy),
      Offset(center.dx + outerR, center.dy),
      crossPaint,
    );

    // Outer solid ring
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..color = StradioColors.midnight.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Middle dashed ring rotating slowly
    const dashCount = 48;
    final dashPaint = Paint()
      ..color = StradioColors.midnight.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final midRect = Rect.fromCircle(center: center, radius: midR);
    final sweep = (math.pi * 2) / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        midRect,
        orbitAngle + i * sweep,
        sweep * 0.45,
        false,
        dashPaint,
      );
    }

    // Inner frosted white rim
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Subtle coral core halo ring (expands on step shockwave)
    final shockR = innerR * 0.56 + (1.0 - energy) * (energy > 0 ? 22.0 : 0.0);
    canvas.drawCircle(
      center,
      shockR,
      Paint()
        ..color = StradioColors.sonicCoral.withValues(
          alpha: energy > 0 ? (0.45 * energy) : 0.24,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Central Sonic Coral strike node (scales 1.0 -> 1.55 on confirmed step)
    final dotR = 5.0 * (1.0 + energy * 0.55);
    canvas.drawCircle(
      center,
      dotR + 5.0,
      Paint()
        ..color = StradioColors.sonicCoral.withValues(
          alpha: 0.22 + energy * 0.28,
        ),
    );
    canvas.drawCircle(
      center,
      dotR,
      Paint()..color = StradioColors.sonicCoral,
    );
  }

  @override
  bool shouldRepaint(covariant _CompassMonolithDialPainter oldDelegate) =>
      oldDelegate.orbitAngle != orbitAngle || oldDelegate.energy != energy;
}
