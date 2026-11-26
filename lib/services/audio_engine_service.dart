import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../models/sound_pack.dart';

/// Clock function returning monotonic-ish epoch milliseconds (injectable for tests).
typedef AudioClock = int Function();

/// Layer 1 contract: continuous looping background track playback.
abstract class AudioLoopBackend {
  Future<void> startLoop(
    String assetPath, {
    double volume = 1.0,
    double playbackRate = 1.0,
  });

  Future<void> setVolume(double volume);

  Future<void> fadeVolume(double volume, Duration duration);

  Future<void> setPlaybackRate(double rate);

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<void> dispose();
}

/// Layer 2 contract: ultra-low-latency one-shot step SFX playback.
abstract class StepSfxBackend {
  Future<void> preload(List<String> assetPaths);

  Future<void> play(String assetPath, {double rate = 1.0, double volume = 1.0});

  Future<void> dispose();
}

/// Shared single-flight initializer for the global native SoLoud C++ mixer.
class _SoLoudRuntime {
  static Future<void>? _initFuture;

  static Future<SoLoud> ensureInitialized() async {
    final soloud = SoLoud.instance;
    if (soloud.isInitialized) return soloud;
    _initFuture ??= soloud.init().catchError((Object error) {
      _initFuture = null;
      throw error;
    });
    await _initFuture;
    return soloud;
  }
}

/// Production Layer 1 backend powered by `flutter_soloud` (single C++ audio mixer,
/// gapless `.ogg`/`.mp3` looping, native audio-thread `fadeVolume`, and Voice Group sync).
class SoLoudLoopBackend implements AudioLoopBackend {
  SoLoudLoopBackend();

  AudioSource? _source;
  String? _loadedAssetPath;
  SoundHandle? _handle;
  bool _isStarted = false;

  Future<AudioSource> _ensureLoaded(SoLoud soloud, String assetPath) async {
    if (_source != null && _loadedAssetPath == assetPath) {
      return _source!;
    }
    await _releaseSource(soloud);
    final loaded = await soloud.loadAsset(assetPath, mode: LoadMode.memory);
    _source = loaded;
    _loadedAssetPath = assetPath;
    return loaded;
  }

  Future<void> _releaseSource(SoLoud soloud) async {
    final handle = _handle;
    _handle = null;
    _isStarted = false;
    if (handle != null && soloud.isInitialized) {
      try {
        await soloud.stop(handle);
      } on Object catch (error) {
        debugPrint('SoLoudLoopBackend.stop error: $error');
      }
    }
    final source = _source;
    _source = null;
    _loadedAssetPath = null;
    if (source != null && soloud.isInitialized) {
      try {
        await soloud.disposeSource(source);
      } on Object catch (error) {
        debugPrint('SoLoudLoopBackend.disposeSource error: $error');
      }
    }
  }

  /// Starts two [SoLoudLoopBackend] stems on the exact same sample clock using a
  /// native SoLoud Voice Group (`FR-3.4` LARI_NGACIR dual-stem synchronization).
  static Future<void> startSyncedPair({
    required SoLoudLoopBackend primary,
    required SoLoudLoopBackend secondary,
    required String primaryAsset,
    required String secondaryAsset,
    required double primaryVolume,
    required double secondaryVolume,
  }) async {
    try {
      final soloud = await _SoLoudRuntime.ensureInitialized();
      await Future.wait([primary.stop(), secondary.stop()]);
      final sources = await Future.wait([
        primary._ensureLoaded(soloud, primaryAsset),
        secondary._ensureLoaded(soloud, secondaryAsset),
      ]);

      final h1 = soloud.play(
        sources[0],
        volume: primaryVolume.clamp(0.0, 1.0),
        paused: true,
        looping: true,
      );
      final h2 = soloud.play(
        sources[1],
        volume: secondaryVolume.clamp(0.0, 1.0),
        paused: true,
        looping: true,
      );

      final group = soloud.createVoiceGroup();
      try {
        soloud.addVoicesToGroup(group, [h1, h2]);
        soloud.setPause(group, false);
      } finally {
        soloud.destroyVoiceGroup(group);
      }

      primary._handle = h1;
      primary._isStarted = true;
      secondary._handle = h2;
      secondary._isStarted = true;
    } on Object catch (error) {
      debugPrint('SoLoudLoopBackend.startSyncedPair error: $error');
    }
  }

  @override
  Future<void> startLoop(
    String assetPath, {
    double volume = 1.0,
    double playbackRate = 1.0,
  }) async {
    try {
      final soloud = await _SoLoudRuntime.ensureInitialized();
      await stop();
      final source = await _ensureLoaded(soloud, assetPath);
      _handle = soloud.play(
        source,
        volume: volume.clamp(0.0, 1.0),
        looping: true,
        scale: playbackRate,
      );
      _isStarted = true;
    } on Object catch (error) {
      debugPrint('SoLoudLoopBackend.startLoop error ($assetPath): $error');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    final handle = _handle;
    if (handle == null || !_isStarted || !SoLoud.instance.isInitialized) return;
    try {
      SoLoud.instance.setVolume(handle, volume.clamp(0.0, 1.0));
    } on Object catch (error) {
      debugPrint('SoLoudLoopBackend.setVolume error: $error');
    }
  }

  @override
  Future<void> fadeVolume(double volume, Duration duration) async {
    final handle = _handle;
    if (handle == null || !_isStarted || !SoLoud.instance.isInitialized) return;
    try {
      final clamped = volume.clamp(0.0, 1.0);
      if (duration <= Duration.zero) {
        SoLoud.instance.setVolume(handle, clamped);
      } else {
        SoLoud.instance.fadeVolume(handle, clamped, duration);
      }
    } on Object catch (error) {
      debugPrint('SoLoudLoopBackend.fadeVolume error: $error');
    }
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    final handle = _handle;
    if (handle == null || !_isStarted || !SoLoud.instance.isInitialized) return;
    try {
      SoLoud.instance.setRelativePlaySpeed(handle, rate);
    } on Object catch (error) {
      debugPrint('SoLoudLoopBackend.setPlaybackRate error: $error');
    }
  }

  @override
  Future<void> pause() async {
    final handle = _handle;
    if (handle == null || !_isStarted || !SoLoud.instance.isInitialized) return;
    try {
      SoLoud.instance.setPause(handle, true);
    } on Object catch (error) {
      debugPrint('SoLoudLoopBackend.pause error: $error');
    }
  }

  @override
  Future<void> resume() async {
    final handle = _handle;
    if (handle == null || !_isStarted || !SoLoud.instance.isInitialized) return;
    try {
      SoLoud.instance.setPause(handle, false);
    } on Object catch (error) {
      debugPrint('SoLoudLoopBackend.resume error: $error');
    }
  }

  @override
  Future<void> stop() async {
    final handle = _handle;
    _handle = null;
    _isStarted = false;
    if (handle == null || !SoLoud.instance.isInitialized) return;
    try {
      await SoLoud.instance.stop(handle);
    } on Object catch (error) {
      debugPrint('SoLoudLoopBackend.stop error: $error');
    }
  }

  @override
  Future<void> dispose() async {
    if (!SoLoud.instance.isInitialized) {
      _handle = null;
      _source = null;
      _loadedAssetPath = null;
      _isStarted = false;
      return;
    }
    await _releaseSource(SoLoud.instance);
  }
}

/// Production Layer 2 backend powered by `flutter_soloud` (preloaded in-memory PCM
/// triggered via synchronous Dart FFI with native polyphony and pitch scaling).
class SoLoudSfxBackend implements StepSfxBackend {
  SoLoudSfxBackend();

  final Map<String, AudioSource> _sources = {};

  Future<AudioSource> _ensureLoaded(SoLoud soloud, String assetPath) async {
    final existing = _sources[assetPath];
    if (existing != null) return existing;
    final loaded = await soloud.loadAsset(assetPath, mode: LoadMode.memory);
    _sources[assetPath] = loaded;
    return loaded;
  }

  @override
  Future<void> preload(List<String> assetPaths) async {
    if (assetPaths.isEmpty) return;
    try {
      final soloud = await _SoLoudRuntime.ensureInitialized();
      for (final path in assetPaths) {
        try {
          await _ensureLoaded(soloud, path);
        } on Object catch (error) {
          debugPrint('SoLoudSfxBackend.preload error ($path): $error');
        }
      }
    } on Object catch (error) {
      debugPrint('SoLoudSfxBackend.preload init error: $error');
    }
  }

  @override
  Future<void> play(
    String assetPath, {
    double rate = 1.0,
    double volume = 1.0,
  }) async {
    try {
      final soloud = await _SoLoudRuntime.ensureInitialized();
      final source = await _ensureLoaded(soloud, assetPath);
      soloud.play(source, volume: volume.clamp(0.0, 1.0), scale: rate);
    } on Object catch (error) {
      debugPrint('SoLoudSfxBackend.play error ($assetPath): $error');
    }
  }

  @override
  Future<void> dispose() async {
    final allSources = _sources.values.toList();
    _sources.clear();
    if (!SoLoud.instance.isInitialized) return;
    for (final source in allSources) {
      try {
        await SoLoud.instance.disposeSource(source);
      } on Object catch (error) {
        debugPrint('SoLoudSfxBackend.dispose error: $error');
      }
    }
  }
}

/// No-op Layer 1 backend for tests or environments without audio plugins.
class NoopAudioLoopBackend implements AudioLoopBackend {
  @override
  Future<void> startLoop(
    String assetPath, {
    double volume = 1.0,
    double playbackRate = 1.0,
  }) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> fadeVolume(double volume, Duration duration) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// No-op Layer 2 backend for tests or environments without audio plugins.
class NoopStepSfxBackend implements StepSfxBackend {
  @override
  Future<void> preload(List<String> assetPaths) async {}

  @override
  Future<void> play(
    String assetPath, {
    double rate = 1.0,
    double volume = 1.0,
  }) async {}

  @override
  Future<void> dispose() async {}
}

/// Orchestrates STRADIO's decoupled 2-layer audio experience across all 6 Sound Packs
/// (`docs/PRD-MVP.md` FR-3 & FR-4).
class StradioAudioEngine {
  StradioAudioEngine({
    AudioLoopBackend? primaryLoopBackend,
    AudioLoopBackend? secondaryLoopBackend,
    StepSfxBackend? sfxBackend,
    SoundPackId initialPack = SoundPackId.breakbeatFvnky,
    AudioClock? clockMs,
    this.fadeDuration = const Duration(milliseconds: 800),
    this.fadeStepInterval = const Duration(milliseconds: 40),
  }) : _primaryLoop = primaryLoopBackend ?? SoLoudLoopBackend(),
       _secondaryLoop = secondaryLoopBackend ?? SoLoudLoopBackend(),
       _sfx = sfxBackend ?? SoLoudSfxBackend(),
       _activePack = StradioSoundPack.byId(initialPack),
       _clockMs = clockMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Safe test/headless constructor that performs no platform-channel/FFI calls.
  factory StradioAudioEngine.noop({
    SoundPackId initialPack = SoundPackId.breakbeatFvnky,
    AudioClock? clockMs,
  }) => StradioAudioEngine(
    primaryLoopBackend: NoopAudioLoopBackend(),
    secondaryLoopBackend: NoopAudioLoopBackend(),
    sfxBackend: NoopStepSfxBackend(),
    initialPack: initialPack,
    clockMs: clockMs,
  );

  /// PRD-MVP FR-3.2 cadence thresholds & hysteresis lockout.
  static const double joggingEntrySpm = 130.0;
  static const double joggingExitSpm = 120.0;
  static const int joggingExitHoldMs = 3000;

  final AudioLoopBackend _primaryLoop;
  final AudioLoopBackend _secondaryLoop;
  final StepSfxBackend _sfx;
  final AudioClock _clockMs;
  final Duration fadeDuration;
  final Duration fadeStepInterval;

  StradioSoundPack _activePack;
  bool _isSessionActive = false;
  bool _isPaused = false;
  bool _inJoggingZone = false;
  int? _belowExitSinceMs;
  int _stepCounter = 0;
  double _latestCadenceSpm = 0.0;
  double _currentPlaybackRate = 1.0;
  bool _adaptiveTempoScalingEnabled = true;
  double _primaryVolume = 0.0;
  double _secondaryVolume = 0.0;
  int? _dualStemStartedAtMs;
  int _lifecycleToken = 0;

  Timer? _barAlignTimer;
  Timer? _lifecycleFadeTimer;
  Timer? _previewProgressTimer;
  Timer? _previewStepTimer;
  bool _isPreviewing = false;
  double _previewProgress = 0.0;
  int _previewStepCounter = 0;

  final ValueNotifier<bool> isPreviewingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> previewProgressNotifier = ValueNotifier<double>(
    0.0,
  );

  StradioSoundPack get activePack => _activePack;
  SoundPackId get activePackId => _activePack.id;
  bool get isSessionActive => _isSessionActive;
  bool get isPaused => _isPaused;
  bool get inJoggingZone => _inJoggingZone;
  bool get isPreviewing => _isPreviewing;
  double get previewProgress => _previewProgress;
  double get currentPlaybackRate => _currentPlaybackRate;
  bool get adaptiveTempoScalingEnabled => _adaptiveTempoScalingEnabled;
  double get primaryVolume => _primaryVolume;
  double get secondaryVolume => _secondaryVolume;

  /// Toggles dynamic BPM playback-rate scaling (`GBA_SAND_HOP`).
  void setAdaptiveTempoScaling(bool enabled) {
    if (_adaptiveTempoScalingEnabled == enabled) return;
    _adaptiveTempoScalingEnabled = enabled;
    if (_isSessionActive &&
        !_isPaused &&
        _activePack.backgroundMode ==
            BackgroundLayerMode.continuousTempoScaled) {
      final nextRate = enabled
          ? _activePack.computePlaybackRate(_latestCadenceSpm)
          : 1.0;
      if ((nextRate - _currentPlaybackRate).abs() >= 0.005) {
        _currentPlaybackRate = nextRate;
        unawaited(_primaryLoop.setPlaybackRate(nextRate));
      }
    }
  }

  /// Preloads step SFX for the active pack (non-blocking, failure-tolerant).
  Future<void> preloadActivePack() async {
    await _sfx.preload(_activePack.stepSfxAssets);
  }

  /// Starts a 10-second audition preview on the Pre-Run Ignition screen with
  /// live progress (`0.0..1.0`) and simulated ~160 SPM footsteps (`375ms`).
  Future<void> startPreview({
    SoundPackId? packId,
    Duration duration = const Duration(seconds: 10),
  }) async {
    if (_isSessionActive) return;
    await stopPreview();
    _lifecycleToken++;
    _cancelTimers();

    if (packId != null && _activePack.id != packId) {
      _activePack = StradioSoundPack.byId(packId);
    }

    _isPreviewing = true;
    _previewProgress = 0.0;
    _previewStepCounter = 0;
    isPreviewingNotifier.value = true;
    previewProgressNotifier.value = 0.0;

    await _sfx.preload(_activePack.stepSfxAssets);

    // Audition Layer 1 at active jogging intensity so user hears the pack's full vibe.
    switch (_activePack.backgroundMode) {
      case BackgroundLayerMode.silent:
        _primaryVolume = 0.0;
        _secondaryVolume = 0.0;
      case BackgroundLayerMode.joggingZoneOnly:
        final asset = _activePack.primaryLoopAsset;
        if (asset != null) {
          _primaryVolume = 0.90;
          await _primaryLoop.startLoop(asset, volume: _primaryVolume);
        }
      case BackgroundLayerMode.dualStemBarAligned:
        final walkAsset = _activePack.primaryLoopAsset;
        final jogAsset = _activePack.secondaryLoopAsset;
        if (walkAsset != null && jogAsset != null) {
          _primaryVolume = 0.95;
          _secondaryVolume = 0.85;
          await _startDualStems(
            walkAsset: walkAsset,
            jogAsset: jogAsset,
            primaryVolume: _primaryVolume,
            secondaryVolume: _secondaryVolume,
          );
        }
      case BackgroundLayerMode.continuousTempoScaled:
        final asset = _activePack.primaryLoopAsset;
        if (asset != null) {
          _primaryVolume = 0.95;
          final rate = _activePack.computePlaybackRate(156.0);
          await _primaryLoop.startLoop(
            asset,
            volume: _primaryVolume,
            playbackRate: rate,
          );
        }
    }

    // Trigger an immediate first footstrike SFX, then repeat every 375ms (~160 SPM).
    unawaited(_triggerPreviewStepSfx());
    _previewStepTimer = Timer.periodic(
      const Duration(milliseconds: 375),
      (_) {
        if (!_isPreviewing || _isSessionActive) return;
        unawaited(_triggerPreviewStepSfx());
      },
    );

    final totalMs = duration.inMilliseconds.clamp(500, 60000);
    const tickMs = 50;
    var elapsedMs = 0;
    _previewProgressTimer = Timer.periodic(
      const Duration(milliseconds: tickMs),
      (timer) {
        if (!_isPreviewing || _isSessionActive) {
          timer.cancel();
          return;
        }
        elapsedMs += tickMs;
        final next = (elapsedMs / totalMs).clamp(0.0, 1.0);
        _previewProgress = next;
        previewProgressNotifier.value = next;
        if (elapsedMs >= totalMs) {
          timer.cancel();
          unawaited(stopPreview());
        }
      },
    );
  }

  /// Stops any active audition preview and resets preview progress to `0.0`.
  Future<void> stopPreview() async {
    _previewProgressTimer?.cancel();
    _previewProgressTimer = null;
    _previewStepTimer?.cancel();
    _previewStepTimer = null;
    if (!_isPreviewing) return;

    _isPreviewing = false;
    _previewProgress = 0.0;
    isPreviewingNotifier.value = false;
    previewProgressNotifier.value = 0.0;

    if (!_isSessionActive) {
      _primaryVolume = 0.0;
      _secondaryVolume = 0.0;
      await _primaryLoop.stop();
      await _secondaryLoop.stop();
    }
  }

  Future<void> _triggerPreviewStepSfx() async {
    final assets = _activePack.stepSfxAssets;
    if (_activePack.stepSfxMode == StepSfxMode.off || assets.isEmpty) {
      return;
    }
    _previewStepCounter++;
    final (assetPath, rate) = switch (_activePack.stepSfxMode) {
      StepSfxMode.off => ('', 1.0),
      StepSfxMode.single => (assets.first, 1.0),
      StepSfxMode.alternating => (
        assets[(_previewStepCounter - 1) % assets.length],
        1.0,
      ),
      StepSfxMode.roundRobin => (
        assets[(_previewStepCounter - 1) % assets.length],
        1.0,
      ),
      StepSfxMode.microPitchAlternating => (
        assets.first,
        _previewStepCounter.isOdd ? 1.0 : _activePack.rightStepPitchRate,
      ),
    };
    if (assetPath.isNotEmpty) {
      await _sfx.play(assetPath, rate: rate, volume: 0.92);
    }
  }

  /// Starts audio layers for a new running session.
  Future<void> startSession({double initialCadenceSpm = 0.0}) async {
    await stopPreview();
    _lifecycleToken++;
    _cancelTimers();
    _isSessionActive = true;
    _isPaused = false;
    _belowExitSinceMs = null;
    _latestCadenceSpm = initialCadenceSpm;
    _inJoggingZone = initialCadenceSpm >= joggingEntrySpm;
    _stepCounter = 0;

    await _sfx.preload(_activePack.stepSfxAssets);
    await _startLayersForActivePack();
  }

  /// Pauses active Layer 1 loops with an 800 ms smooth fadeout (`OQ-3`) and
  /// suppresses step SFX until resumed.
  Future<void> pauseSession() async {
    if (!_isSessionActive || _isPaused) return;
    _isPaused = true;
    final token = ++_lifecycleToken;
    _cancelTimers();

    final hasAudibleLoop = _primaryVolume > 0.001 || _secondaryVolume > 0.001;
    if (fadeDuration > Duration.zero && hasAudibleLoop) {
      if (_primaryVolume > 0.001) {
        _fadePrimaryTo(0.0);
      }
      if (_secondaryVolume > 0.001) {
        _fadeSecondaryTo(0.0);
      }
      _lifecycleFadeTimer = Timer(fadeDuration, () {
        if (_lifecycleToken != token || !_isPaused) return;
        unawaited(_primaryLoop.pause());
        unawaited(_secondaryLoop.pause());
      });
    } else {
      await _primaryLoop.pause();
      await _secondaryLoop.pause();
    }
  }

  /// Resumes a paused running session without resetting step parity or pack state.
  Future<void> resumeSession() async {
    if (!_isSessionActive || !_isPaused) return;
    _isPaused = false;
    _lifecycleToken++;
    _cancelTimers();
    await _primaryLoop.resume();
    await _secondaryLoop.resume();
    _applyCurrentZoneVolumes(immediate: false);
  }

  /// Stops all active loops and timers at session end with an 800 ms smooth fadeout (`OQ-3`).
  Future<void> stopSession() async {
    final hadAudibleLoop = _primaryVolume > 0.001 || _secondaryVolume > 0.001;
    final token = ++_lifecycleToken;
    _cancelTimers();
    _isSessionActive = false;
    _isPaused = false;
    _inJoggingZone = false;
    _belowExitSinceMs = null;
    _dualStemStartedAtMs = null;
    _currentPlaybackRate = 1.0;

    if (fadeDuration > Duration.zero && hadAudibleLoop) {
      if (_primaryVolume > 0.001) {
        _fadePrimaryTo(0.0);
      }
      if (_secondaryVolume > 0.001) {
        _fadeSecondaryTo(0.0);
      }
      _lifecycleFadeTimer = Timer(fadeDuration, () {
        if (_lifecycleToken != token || _isSessionActive || _isPreviewing) {
          return;
        }
        unawaited(_primaryLoop.stop());
        unawaited(_secondaryLoop.stop());
      });
    } else {
      _primaryVolume = 0.0;
      _secondaryVolume = 0.0;
      await _primaryLoop.stop();
      await _secondaryLoop.stop();
    }
  }

  /// Switches to another Sound Pack immediately with zero session interruption
  /// (`docs/PRD-MVP.md` FR-4.2: does not reset steps, timers, or foreground service).
  Future<void> switchPack(SoundPackId packId) async {
    if (_activePack.id == packId) return;
    final wasPreviewing = _isPreviewing;
    if (wasPreviewing) {
      await stopPreview();
    }
    _activePack = StradioSoundPack.byId(packId);
    await _sfx.preload(_activePack.stepSfxAssets);

    if (!_isSessionActive) return;

    _lifecycleToken++;
    _cancelTimers();
    await _primaryLoop.stop();
    await _secondaryLoop.stop();
    _dualStemStartedAtMs = null;
    _primaryVolume = 0.0;
    _secondaryVolume = 0.0;

    await _startLayersForActivePack();
    if (_isPaused) {
      await _primaryLoop.pause();
      await _secondaryLoop.pause();
    }
  }

  /// Called on every confirmed footstrike from `StepDetector` (A1).
  Future<void> onStepDetected({required double cadenceSpm}) async {
    if (!_isSessionActive || _isPaused) return;

    _stepCounter++;
    updateCadence(cadenceSpm);

    final assets = _activePack.stepSfxAssets;
    if (_activePack.stepSfxMode == StepSfxMode.off || assets.isEmpty) {
      return;
    }

    final (assetPath, rate) = switch (_activePack.stepSfxMode) {
      StepSfxMode.off => ('', 1.0),
      StepSfxMode.single => (assets.first, 1.0),
      StepSfxMode.alternating => (
        // Odd steps (1, 3, 5...) -> left (index 0); even steps (2, 4...) -> right (index 1)
        assets[(_stepCounter - 1) % assets.length],
        1.0,
      ),
      StepSfxMode.roundRobin => (
        assets[(_stepCounter - 1) % assets.length],
        1.0,
      ),
      StepSfxMode.microPitchAlternating => (
        assets.first,
        _stepCounter.isOdd ? 1.0 : _activePack.rightStepPitchRate,
      ),
    };

    if (assetPath.isNotEmpty) {
      await _sfx.play(assetPath, rate: rate);
    }
  }

  /// Evaluates live cadence (SPM) for jogging-zone hysteresis and dynamic tempo scaling.
  /// Call both on step events and periodically (e.g. every 1s) so hysteresis exits
  /// cleanly even if the runner slows to a complete stop.
  void updateCadence(double cadenceSpm) {
    _latestCadenceSpm = cadenceSpm;
    if (!_isSessionActive || _isPaused) return;

    if (_activePack.backgroundMode == BackgroundLayerMode.continuousTempoScaled) {
      final nextRate = _adaptiveTempoScalingEnabled
          ? _activePack.computePlaybackRate(cadenceSpm)
          : 1.0;
      if ((nextRate - _currentPlaybackRate).abs() >= 0.005) {
        _currentPlaybackRate = nextRate;
        unawaited(_primaryLoop.setPlaybackRate(nextRate));
      }
      return;
    }

    if (_activePack.backgroundMode != BackgroundLayerMode.joggingZoneOnly &&
        _activePack.backgroundMode != BackgroundLayerMode.dualStemBarAligned) {
      return;
    }

    final nowMs = _clockMs();
    if (!_inJoggingZone) {
      if (cadenceSpm >= joggingEntrySpm) {
        _inJoggingZone = true;
        _belowExitSinceMs = null;
        _onEnterJoggingZone(nowMs);
      }
    } else {
      if (cadenceSpm < joggingExitSpm) {
        _belowExitSinceMs ??= nowMs;
        if (nowMs - _belowExitSinceMs! >= joggingExitHoldMs) {
          _inJoggingZone = false;
          _belowExitSinceMs = null;
          _onExitJoggingZone();
        }
      } else {
        // Above 120 SPM cancels exit countdown (hysteresis band 120..130 SPM).
        _belowExitSinceMs = null;
      }
    }
  }

  Future<void> _startDualStems({
    required String walkAsset,
    required String jogAsset,
    required double primaryVolume,
    required double secondaryVolume,
  }) async {
    final p = _primaryLoop;
    final s = _secondaryLoop;
    if (p is SoLoudLoopBackend && s is SoLoudLoopBackend) {
      await SoLoudLoopBackend.startSyncedPair(
        primary: p,
        secondary: s,
        primaryAsset: walkAsset,
        secondaryAsset: jogAsset,
        primaryVolume: primaryVolume,
        secondaryVolume: secondaryVolume,
      );
      return;
    }
    await Future.wait([
      _primaryLoop.startLoop(walkAsset, volume: primaryVolume),
      _secondaryLoop.startLoop(jogAsset, volume: secondaryVolume),
    ]);
  }

  Future<void> _startLayersForActivePack() async {
    switch (_activePack.backgroundMode) {
      case BackgroundLayerMode.silent:
        _primaryVolume = 0.0;
        _secondaryVolume = 0.0;
        _currentPlaybackRate = 1.0;

      case BackgroundLayerMode.joggingZoneOnly:
        final asset = _activePack.primaryLoopAsset;
        if (asset == null) return;
        final target = _inJoggingZone ? 1.0 : 0.0;
        _primaryVolume = target;
        _currentPlaybackRate = 1.0;
        await _primaryLoop.startLoop(asset, volume: target);

      case BackgroundLayerMode.dualStemBarAligned:
        final walkAsset = _activePack.primaryLoopAsset;
        final jogAsset = _activePack.secondaryLoopAsset;
        if (walkAsset == null || jogAsset == null) return;
        _primaryVolume = 1.0;
        _secondaryVolume = _inJoggingZone ? 1.0 : 0.0;
        _currentPlaybackRate = 1.0;
        _dualStemStartedAtMs = _clockMs();
        await _startDualStems(
          walkAsset: walkAsset,
          jogAsset: jogAsset,
          primaryVolume: _primaryVolume,
          secondaryVolume: _secondaryVolume,
        );

      case BackgroundLayerMode.continuousTempoScaled:
        final asset = _activePack.primaryLoopAsset;
        if (asset == null) return;
        _primaryVolume = 1.0;
        _secondaryVolume = 0.0;
        _currentPlaybackRate = _adaptiveTempoScalingEnabled
            ? _activePack.computePlaybackRate(_latestCadenceSpm)
            : 1.0;
        await _primaryLoop.startLoop(
          asset,
          volume: 1.0,
          playbackRate: _currentPlaybackRate,
        );
    }
  }

  void _onEnterJoggingZone(int nowMs) {
    if (_activePack.backgroundMode == BackgroundLayerMode.joggingZoneOnly) {
      _fadePrimaryTo(1.0);
    } else if (_activePack.backgroundMode ==
        BackgroundLayerMode.dualStemBarAligned) {
      _barAlignTimer?.cancel();
      final delayMs = _msUntilNextBar(nowMs);
      if (delayMs <= 0) {
        _fadeSecondaryTo(1.0);
      } else {
        _barAlignTimer = Timer(Duration(milliseconds: delayMs), () {
          if (_isSessionActive && !_isPaused && _inJoggingZone) {
            _fadeSecondaryTo(1.0);
          }
        });
      }
    }
  }

  void _onExitJoggingZone() {
    _barAlignTimer?.cancel();
    if (_activePack.backgroundMode == BackgroundLayerMode.joggingZoneOnly) {
      _fadePrimaryTo(0.0);
    } else if (_activePack.backgroundMode ==
        BackgroundLayerMode.dualStemBarAligned) {
      _fadeSecondaryTo(0.0);
    }
  }

  void _applyCurrentZoneVolumes({required bool immediate}) {
    switch (_activePack.backgroundMode) {
      case BackgroundLayerMode.silent:
        return;
      case BackgroundLayerMode.joggingZoneOnly:
        final target = _inJoggingZone ? 1.0 : 0.0;
        if (immediate) {
          _primaryVolume = target;
          unawaited(_primaryLoop.setVolume(target));
        } else {
          _fadePrimaryTo(target);
        }
      case BackgroundLayerMode.dualStemBarAligned:
        final secondaryTarget = _inJoggingZone ? 1.0 : 0.0;
        if (immediate) {
          _primaryVolume = 1.0;
          _secondaryVolume = secondaryTarget;
          unawaited(_primaryLoop.setVolume(1.0));
          unawaited(_secondaryLoop.setVolume(secondaryTarget));
        } else {
          _fadePrimaryTo(1.0);
          _fadeSecondaryTo(secondaryTarget);
        }
      case BackgroundLayerMode.continuousTempoScaled:
        if (immediate) {
          _primaryVolume = 1.0;
          unawaited(_primaryLoop.setVolume(1.0));
        } else {
          _fadePrimaryTo(1.0);
        }
    }
  }

  int _msUntilNextBar(int nowMs) {
    final barMs = _activePack.barDurationMs;
    final startedAt = _dualStemStartedAtMs;
    if (barMs == null || barMs <= 0 || startedAt == null) return 0;
    final elapsed = nowMs - startedAt;
    if (elapsed <= 0) return 0;
    final mod = elapsed % barMs;
    return mod == 0 ? 0 : barMs - mod;
  }

  void _fadePrimaryTo(double target) {
    _primaryVolume = target;
    if (fadeDuration <= Duration.zero) {
      unawaited(_primaryLoop.setVolume(target));
    } else {
      unawaited(_primaryLoop.fadeVolume(target, fadeDuration));
    }
  }

  void _fadeSecondaryTo(double target) {
    _secondaryVolume = target;
    if (fadeDuration <= Duration.zero) {
      unawaited(_secondaryLoop.setVolume(target));
    } else {
      unawaited(_secondaryLoop.fadeVolume(target, fadeDuration));
    }
  }

  void _cancelTimers() {
    _barAlignTimer?.cancel();
    _barAlignTimer = null;
    _lifecycleFadeTimer?.cancel();
    _lifecycleFadeTimer = null;
    _previewProgressTimer?.cancel();
    _previewProgressTimer = null;
    _previewStepTimer?.cancel();
    _previewStepTimer = null;
  }

  Future<void> dispose() async {
    _lifecycleToken++;
    await stopPreview();
    _cancelTimers();
    await _primaryLoop.dispose();
    await _secondaryLoop.dispose();
    await _sfx.dispose();
  }
}
