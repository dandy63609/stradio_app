import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

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
import '../../widgets/liquid_glass_lens.dart';
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
      duration: const Duration(milliseconds: 360),
    );
    _continuousWaveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
      final snapshot = ActiveSessionSnapshot(
        recordingId: _recordingId,
        createdAt: DateTime.now(),
        config: _labSettings.toExperimentConfig(),
        samples: _isDeveloperMode ? List.of(_activeSamples) : const [],
        liveStepCount: _primaryDetections.length,
        detections: List.of(_primaryDetections),
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
    _stepPulseTimer = Timer(const Duration(milliseconds: 180), () {
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
        ),
      ),
    );

    if (!mounted) return;
    if (completed == true && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    // If user backed out of Summary without finishing, return ready to resume.
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
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              key: const Key('sound_pack_picker_sheet'),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                            ? StradioColors.glowCoralSoft
                            : StradioColors.warmIvory,
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
                                    : StradioColors.borderSubtle,
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
    final steps = _primaryDetections.length;
    final liveSpm = _currentLiveCadenceSpm();
    final hasCadence = liveSpm > 0;
    final isRunning = _streamState == _RunStreamState.running;
    final isJogZone = liveSpm >= StradioAudioEngine.joggingEntrySpm;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    final (pillLabel, dotColor) = switch (_streamState) {
      _RunStreamState.running => (
        isJogZone ? s.activeStrideLabel : s.walkingGrooveLabel,
        isJogZone ? StradioColors.sonicCoral : StradioColors.rhythmViolet,
      ),
      _RunStreamState.paused => (s.pausedLabel, StradioColors.statusPaused),
      _RunStreamState.connecting => (
        s.calibratingLabel,
        StradioColors.twilightPlum,
      ),
      _RunStreamState.sensorError => (
        s.standbyLabel,
        StradioColors.textAccentDeep,
      ),
    };

    return Scaffold(
      backgroundColor: StradioColors.warmIvory,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Brand Bar (Logo + Stradio) + Dual-Tone Stacked Sub-Header (Stride / Rhythm) + 100 Hz Sensor Pill (Mockup #10)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/stradio-logo.png',
                        height: 22,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Stradio',
                        style: StradioTypography.headingSmall(fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.strideTitle,
                              style: StradioTypography.titlePrimary(),
                            ),
                            Text(
                              s.rhythmTitle,
                              style: StradioTypography.titleMuted(),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Motion sensor status and calibration',
                        child: IconButton(
                          key: const Key('active_run_sensor_button'),
                          onPressed: _openSensorCalibrationSheet,
                          tooltip: 'Sensor status',
                          style: IconButton.styleFrom(
                            backgroundColor: StradioColors.surfaceCard,
                            minimumSize: const Size(48, 48),
                            side: const BorderSide(
                              color: StradioColors.borderSubtle,
                            ),
                            shape: const CircleBorder(),
                          ),
                          icon: Icon(
                            Icons.sensors_rounded,
                            size: 20,
                            color: _streamState == _RunStreamState.sensorError
                                ? StradioColors.textAccentDeep
                                : StradioColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Honest Loading / Error Inline Banner (R-27)
                  if (_streamState == _RunStreamState.connecting) ...[
                    const SizedBox(height: 10),
                    _InlineStatusStrip(
                      dotColor: StradioColors.twilightPlum,
                      message: s.calibratingSensorMessage,
                    ),
                  ] else if (_streamState == _RunStreamState.sensorError) ...[
                    const SizedBox(height: 10),
                    _InlineStatusStrip(
                      dotColor: StradioColors.textAccentDeep,
                      message: _sensorErrorText ?? s.sensorUnavailableShort,
                      actionLabel: s.simulateStrideAction,
                      actionKey: const Key('simulate_stride_banner_button'),
                      onAction: _simulateSingleStride,
                    ),
                  ],

                  // Central 256px Circular Acoustic Dial + 136px LiquidGlassLens (Glass 1 of 2)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final dialSize = math
                            .min(constraints.maxWidth, constraints.maxHeight)
                            .clamp(196.0, 264.0);
                        final lensSize = dialSize * 0.53;

                        return Center(
                          child: SizedBox(
                            width: dialSize,
                            height: dialSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: dialSize,
                                  height: dialSize,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: StradioColors.surfaceRecessed,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: RepaintBoundary(
                                    child: AnimatedBuilder(
                                      animation: Listenable.merge([
                                        _ribbonController,
                                        _continuousWaveController,
                                      ]),
                                      builder: (_, _) {
                                        final curvedImpulse = Curves.easeOutCubic
                                            .transform(_ribbonController.value);
                                        final continuousFlow =
                                            _continuousWaveController.value *
                                            math.pi *
                                            2 *
                                            (hasCadence
                                                ? (liveSpm / 140.0).clamp(
                                                    0.8,
                                                    1.6,
                                                  )
                                                : 0.65);
                                        final phase = reducedMotion
                                            ? 0.4
                                            : 0.4 +
                                                  steps * 0.52 +
                                                  continuousFlow +
                                                  curvedImpulse * 0.85;
                                        final smoothBoost = _stepPulseActive
                                            ? (1.0 - curvedImpulse * 0.55).clamp(
                                                0.25,
                                                1.0,
                                              )
                                            : 0.0;
                                        return CustomPaint(
                                          painter: SonicRibbonPainter(
                                            phase: phase,
                                            amplitude: isRunning ? 0.82 : 0.44,
                                            pulseBoost: smoothBoost,
                                            strokeWidth: 2.6,
                                            fillGradientArea: true,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // 4 Cardinal Acoustic Markers
                                Positioned(
                                  top: 14,
                                  child: _CardinalMarker(
                                    label: 'kick',
                                    dotColor: StradioColors.sonicCoral,
                                  ),
                                ),
                                Positioned(
                                  bottom: 14,
                                  child: _CardinalMarker(
                                    label: 'bass',
                                    dotColor: StradioColors.twilightPlum,
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  child: _CardinalMarker(
                                    label: 'sync',
                                    dotColor: StradioColors.midnight,
                                    dotFirst: true,
                                  ),
                                ),
                                Positioned(
                                  right: 14,
                                  child: _CardinalMarker(
                                    label: 'stem',
                                    dotColor: StradioColors.rhythmViolet,
                                    dotFirst: true,
                                  ),
                                ),

                                // Central 136px LiquidGlassLens reacting <30ms on footstrike
                                AnimatedScale(
                                  scale: (_stepPulseActive && !reducedMotion)
                                      ? 1.05
                                      : 1.0,
                                  duration: const Duration(milliseconds: 140),
                                  curve: Curves.easeOutCubic,
                                  child: LiquidGlassLens(
                                    key: const Key('active_run_glass_lens'),
                                    shape: LiquidGlassShape.circle,
                                    width: lensSize,
                                    height: lensSize,
                                    edgeIntensity: _stepPulseActive
                                        ? 0.065
                                        : 0.032,
                                    rippleEffect: _stepPulseActive
                                        ? 0.24
                                        : 0.08,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          hasCadence
                                              ? '${liveSpm.round()}'
                                              : '--',
                                          style: StradioTypography.metricValue(
                                            fontSize: 28,
                                          ),
                                        ),
                                        Text(
                                          'spm',
                                          style:
                                              StradioTypography.metricLabel(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 2 Borderless Metrics directly on Warm Ivory (Steps & Cadence)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.stepsLabel,
                            style: StradioTypography.metricLabel(),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatSteps(steps),
                            key: const Key('active_run_step_count'),
                            style: StradioTypography.metricValue(),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            s.cadenceLabel,
                            style: StradioTypography.metricLabel(),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasCadence ? '${liveSpm.round()} spm' : '-- spm',
                            key: const Key('active_run_cadence_value'),
                            style: StradioTypography.metricValue(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Calm 1-line helper for empty/0-step state or Hold-to-End hint
                  SizedBox(
                    height: 20,
                    child: Center(
                      child: Text(
                        _holdHintText ??
                            (steps == 0
                                ? s.takeStepHint
                                : '${_formatDuration(_activeDurationSeconds)} · ${_audioEngine.activePack.title}'),
                        key: const Key('active_run_helper_text'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StradioTypography.body(
                          fontSize: 13,
                          color: _holdHintText != null
                              ? StradioColors.textAccentDeep
                              : StradioColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bottom LiquidGlassLens Dock Cradle (Glass 2 of 2)
                  LiquidGlassLens(
                    key: const Key('active_run_bottom_dock'),
                    shape: LiquidGlassShape.pill,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        // Left 48dp Circle: Zero-Interruption 6-Sound-Pack Swap
                        Semantics(
                          button: true,
                          label: 'Switch sound pack',
                          child: IconButton(
                            key: const Key('sound_pack_selector_button'),
                            onPressed: _showSoundPackPickerSheet,
                            tooltip: 'Switch sound pack',
                            style: IconButton.styleFrom(
                              backgroundColor: StradioColors.surfaceCard,
                              minimumSize: const Size(48, 48),
                              side: const BorderSide(
                                color: StradioColors.borderSubtle,
                              ),
                              shape: const CircleBorder(),
                            ),
                            icon: const Icon(
                              Icons.headphones_rounded,
                              size: 20,
                              color: StradioColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Center Solid Midnight Pill: Active Status + Pause/Resume
                        Expanded(
                          child: Material(
                            color: StradioColors.midnight,
                            borderRadius: BorderRadius.circular(
                              StradioRadii.full,
                            ),
                            child: InkWell(
                              key: const Key('pause_resume_run_button'),
                              borderRadius: BorderRadius.circular(
                                StradioRadii.full,
                              ),
                              onTap: _togglePauseResume,
                              child: SizedBox(
                                height: 48,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      key: const Key('status_indicator_dot'),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: dotColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        pillLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: StradioTypography.pillBadge(
                                          color: StradioColors.textOnDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Right 48dp Circle: Hold 1.5s to End Session (Anti-Accidental Trigger)
                        Semantics(
                          button: true,
                          label: 'Hold 1.5 seconds to end run',
                          child: Listener(
                            key: const Key('hold_to_end_run_button'),
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (_) => _onHoldStart(),
                            onPointerUp: (_) => _onHoldCancelOrShortTap(),
                            onPointerCancel: (_) => _onHoldCancelOrShortTap(),
                            child: AnimatedBuilder(
                              animation: _holdController,
                              builder: (_, _) {
                                return SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: StradioColors.surfaceCard,
                                          border: Border.all(
                                            color: StradioColors.borderSubtle,
                                          ),
                                        ),
                                      ),
                                      if (_holdController.value > 0)
                                        SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: CircularProgressIndicator(
                                            value: _holdController.value,
                                            strokeWidth: 3.0,
                                            color: StradioColors.sonicCoral,
                                            backgroundColor: Colors.transparent,
                                          ),
                                        ),
                                      const Icon(
                                        Icons.stop_rounded,
                                        size: 20,
                                        color: StradioColors.textPrimary,
                                      ),
                                    ],
                                  ),
                                );
                              },
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
      ),
    );
  }
}

class _CardinalMarker extends StatelessWidget {
  const _CardinalMarker({
    required this.label,
    required this.dotColor,
    this.dotFirst = false,
  });

  final String label;
  final Color dotColor;
  final bool dotFirst;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
    );
    final text = Text(label, style: StradioTypography.metricLabel());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: dotFirst
          ? [dot, const SizedBox(width: 4), text]
          : [text, const SizedBox(width: 4), dot],
    );
  }
}

class _InlineStatusStrip extends StatelessWidget {
  const _InlineStatusStrip({
    required this.dotColor,
    required this.message,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final Color dotColor;
  final String message;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: StradioColors.surfaceCard,
        borderRadius: BorderRadius.circular(StradioRadii.lg),
        border: Border.all(color: StradioColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: StradioTypography.body(
                fontSize: 12,
                color: StradioColors.textPrimary,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              key: actionKey,
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: StradioColors.textAccentDeep,
                minimumSize: const Size(44, 44),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
