import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:soundpool/soundpool.dart';

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

/// Production Layer 1 backend powered by `audioplayers`.
class AudioplayersLoopBackend implements AudioLoopBackend {
  AudioplayersLoopBackend({this.requestAudioFocus = true});

  final bool requestAudioFocus;
  AudioPlayer? _player;
  bool _isStarted = false;

  Future<AudioPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;

    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: requestAudioFocus
              ? AndroidAudioFocus.gain
              : AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    _player = player;
    return player;
  }

  String _normalizeAssetPath(String assetPath) =>
      assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;

  @override
  Future<void> startLoop(
    String assetPath, {
    double volume = 1.0,
    double playbackRate = 1.0,
  }) async {
    try {
      final player = await _ensurePlayer();
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.play(AssetSource(_normalizeAssetPath(assetPath)));
      if ((playbackRate - 1.0).abs() > 0.001) {
        await player.setPlaybackRate(playbackRate);
      }
      _isStarted = true;
    } on Object catch (error) {
      debugPrint('AudioplayersLoopBackend.startLoop error ($assetPath): $error');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    final player = _player;
    if (player == null) return;
    try {
      await player.setVolume(volume.clamp(0.0, 1.0));
    } on Object catch (error) {
      debugPrint('AudioplayersLoopBackend.setVolume error: $error');
    }
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    final player = _player;
    if (player == null || !_isStarted) return;
    try {
      await player.setPlaybackRate(rate);
    } on Object catch (error) {
      debugPrint('AudioplayersLoopBackend.setPlaybackRate error: $error');
    }
  }

  @override
  Future<void> pause() async {
    final player = _player;
    if (player == null || !_isStarted) return;
    try {
      await player.pause();
    } on Object catch (error) {
      debugPrint('AudioplayersLoopBackend.pause error: $error');
    }
  }

  @override
  Future<void> resume() async {
    final player = _player;
    if (player == null || !_isStarted) return;
    try {
      await player.resume();
    } on Object catch (error) {
      debugPrint('AudioplayersLoopBackend.resume error: $error');
    }
  }

  @override
  Future<void> stop() async {
    final player = _player;
    _isStarted = false;
    if (player == null) return;
    try {
      await player.stop();
    } on Object catch (error) {
      debugPrint('AudioplayersLoopBackend.stop error: $error');
    }
  }

  @override
  Future<void> dispose() async {
    final player = _player;
    _player = null;
    _isStarted = false;
    if (player == null) return;
    try {
      await player.dispose();
    } on Object catch (error) {
      debugPrint('AudioplayersLoopBackend.dispose error: $error');
    }
  }
}

/// Production Layer 2 backend powered by native Android `Soundpool`.
class SoundpoolSfxBackend implements StepSfxBackend {
  SoundpoolSfxBackend({this.maxStreams = 4});

  final int maxStreams;
  Soundpool? _pool;
  final Map<String, int> _soundIds = {};

  Soundpool _ensurePool() {
    return _pool ??= Soundpool.fromOptions(
      options: SoundpoolOptions(
        streamType: StreamType.music,
        maxStreams: maxStreams,
      ),
    );
  }

  @override
  Future<void> preload(List<String> assetPaths) async {
    if (assetPaths.isEmpty) return;
    try {
      final pool = _ensurePool();
      for (final path in assetPaths) {
        if (_soundIds.containsKey(path)) continue;
        final data = await rootBundle.load(path);
        final id = await pool.load(data);
        if (id >= 0) {
          _soundIds[path] = id;
        }
      }
    } on Object catch (error) {
      debugPrint('SoundpoolSfxBackend.preload error: $error');
    }
  }

  @override
  Future<void> play(
    String assetPath, {
    double rate = 1.0,
    double volume = 1.0,
  }) async {
    try {
      final pool = _ensurePool();
      var soundId = _soundIds[assetPath];
      if (soundId == null) {
        final data = await rootBundle.load(assetPath);
        soundId = await pool.load(data);
        if (soundId >= 0) {
          _soundIds[assetPath] = soundId;
        } else {
          return;
        }
      }
      await pool.setVolume(soundId: soundId, volume: volume.clamp(0.0, 1.0));
      await pool.play(soundId, rate: rate);
    } on Object catch (error) {
      debugPrint('SoundpoolSfxBackend.play error ($assetPath): $error');
    }
  }

  @override
  Future<void> dispose() async {
    final pool = _pool;
    _pool = null;
    _soundIds.clear();
    if (pool == null) return;
    try {
      pool.dispose();
    } on Object catch (error) {
      debugPrint('SoundpoolSfxBackend.dispose error: $error');
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
  }) : _primaryLoop =
           primaryLoopBackend ??
           AudioplayersLoopBackend(requestAudioFocus: true),
       _secondaryLoop =
           secondaryLoopBackend ??
           AudioplayersLoopBackend(requestAudioFocus: false),
       _sfx = sfxBackend ?? SoundpoolSfxBackend(),
       _activePack = StradioSoundPack.byId(initialPack),
       _clockMs = clockMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Safe test/headless constructor that performs no platform-channel calls.
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
  double _primaryVolume = 0.0;
  double _secondaryVolume = 0.0;
  int? _dualStemStartedAtMs;

  Timer? _primaryFadeTimer;
  Timer? _secondaryFadeTimer;
  Timer? _barAlignTimer;

  StradioSoundPack get activePack => _activePack;
  SoundPackId get activePackId => _activePack.id;
  bool get isSessionActive => _isSessionActive;
  bool get isPaused => _isPaused;
  bool get inJoggingZone => _inJoggingZone;
  double get currentPlaybackRate => _currentPlaybackRate;
  double get primaryVolume => _primaryVolume;
  double get secondaryVolume => _secondaryVolume;

  /// Preloads step SFX for the active pack (non-blocking, failure-tolerant).
  Future<void> preloadActivePack() async {
    await _sfx.preload(_activePack.stepSfxAssets);
  }

  /// Starts audio layers for a new running session.
  Future<void> startSession({double initialCadenceSpm = 0.0}) async {
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

  /// Pauses active Layer 1 loops cleanly and suppresses step SFX until resumed.
  Future<void> pauseSession() async {
    if (!_isSessionActive || _isPaused) return;
    _isPaused = true;
    _cancelTimers();
    await _primaryLoop.pause();
    await _secondaryLoop.pause();
  }

  /// Resumes a paused running session without resetting step parity or pack state.
  Future<void> resumeSession() async {
    if (!_isSessionActive || !_isPaused) return;
    _isPaused = false;
    await _primaryLoop.resume();
    await _secondaryLoop.resume();
    _applyCurrentZoneVolumes(immediate: false);
  }

  /// Stops all active loops and timers at session end.
  Future<void> stopSession() async {
    _cancelTimers();
    _isSessionActive = false;
    _isPaused = false;
    _inJoggingZone = false;
    _belowExitSinceMs = null;
    _dualStemStartedAtMs = null;
    _primaryVolume = 0.0;
    _secondaryVolume = 0.0;
    _currentPlaybackRate = 1.0;
    await _primaryLoop.stop();
    await _secondaryLoop.stop();
  }

  /// Switches to another Sound Pack immediately with zero session interruption
  /// (`docs/PRD-MVP.md` FR-4.2: does not reset steps, timers, or foreground service).
  Future<void> switchPack(SoundPackId packId) async {
    if (_activePack.id == packId) return;
    _activePack = StradioSoundPack.byId(packId);
    await _sfx.preload(_activePack.stepSfxAssets);

    if (!_isSessionActive) return;

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
      final nextRate = _activePack.computePlaybackRate(cadenceSpm);
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
        await Future.wait([
          _primaryLoop.startLoop(walkAsset, volume: _primaryVolume),
          _secondaryLoop.startLoop(jogAsset, volume: _secondaryVolume),
        ]);

      case BackgroundLayerMode.continuousTempoScaled:
        final asset = _activePack.primaryLoopAsset;
        if (asset == null) return;
        _primaryVolume = 1.0;
        _secondaryVolume = 0.0;
        _currentPlaybackRate = _activePack.computePlaybackRate(
          _latestCadenceSpm,
        );
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
    if (_activePack.backgroundMode == BackgroundLayerMode.joggingZoneOnly) {
      final target = _inJoggingZone ? 1.0 : 0.0;
      if (immediate) {
        _primaryVolume = target;
        unawaited(_primaryLoop.setVolume(target));
      } else {
        _fadePrimaryTo(target);
      }
    } else if (_activePack.backgroundMode ==
        BackgroundLayerMode.dualStemBarAligned) {
      final target = _inJoggingZone ? 1.0 : 0.0;
      if (immediate) {
        _secondaryVolume = target;
        unawaited(_secondaryLoop.setVolume(target));
      } else {
        _fadeSecondaryTo(target);
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
    _primaryFadeTimer?.cancel();
    _primaryFadeTimer = _runFade(
      from: _primaryVolume,
      to: target,
      onStep: (v) {
        _primaryVolume = v;
        unawaited(_primaryLoop.setVolume(v));
      },
    );
  }

  void _fadeSecondaryTo(double target) {
    _secondaryFadeTimer?.cancel();
    _secondaryFadeTimer = _runFade(
      from: _secondaryVolume,
      to: target,
      onStep: (v) {
        _secondaryVolume = v;
        unawaited(_secondaryLoop.setVolume(v));
      },
    );
  }

  Timer? _runFade({
    required double from,
    required double to,
    required void Function(double volume) onStep,
  }) {
    if ((from - to).abs() < 0.001 || fadeDuration <= Duration.zero) {
      onStep(to);
      return null;
    }

    final totalSteps = (fadeDuration.inMilliseconds /
            fadeStepInterval.inMilliseconds)
        .round()
        .clamp(1, 200);
    var currentStep = 0;

    return Timer.periodic(fadeStepInterval, (timer) {
      currentStep++;
      if (currentStep >= totalSteps) {
        timer.cancel();
        onStep(to);
        return;
      }
      final t = currentStep / totalSteps;
      onStep(from + (to - from) * t);
    });
  }

  void _cancelTimers() {
    _primaryFadeTimer?.cancel();
    _primaryFadeTimer = null;
    _secondaryFadeTimer?.cancel();
    _secondaryFadeTimer = null;
    _barAlignTimer?.cancel();
    _barAlignTimer = null;
  }

  Future<void> dispose() async {
    _cancelTimers();
    await _primaryLoop.dispose();
    await _secondaryLoop.dispose();
    await _sfx.dispose();
  }
}
