import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../../widgets/daylight_settings_sheet.dart';
import '../../widgets/earphones_recommendation_modal.dart';
import '../../widgets/sonic_ribbon_painter.dart';
import '../../widgets/target_calibration_sheet.dart';
import 'active_run_screen.dart';

/// Surface 1: Pre-Run Ignition (`docs/EXPERIENCE.md`, `docs/DESIGN.md`, Mockup #07).
///
/// Zero-friction daylight launch on Warm Ivory (`#F5F0E8`) with:
/// - First-launch Audio Device Recommendation modal (`has_seen_audio_recommendation`).
/// - Open full-width multi-layered Sonic Ribbons over delicate concentric telemetry radar rings.
/// - Unified Glass Timbre Capsule with 10-second Audio Preview + live Progress Line Bar
///   and expandable 6-pack selector deck.
/// - Smoked Obsidian Glassmorphism `56dp` bottom ignition pill (`Swipe to start`, swipe-only lock).
class PreRunIgnitionScreen extends StatefulWidget {
  const PreRunIgnitionScreen({
    super.key,
    this.store,
    this.recordingService,
    this.postHogService,
    this.foregroundService,
    this.audioEngine,
    this.initialProfile,
    this.initialSoundPackId,
    this.showFirstLaunchModal,
  });

  final RecordingStore? store;
  final RecordingService? recordingService;
  final PostHogTelemetryService? postHogService;
  final ForegroundNotificationService? foregroundService;
  final StradioAudioEngine? audioEngine;
  final StradioUserProfile? initialProfile;
  final SoundPackId? initialSoundPackId;

  /// Overrides persisted `has_seen_audio_recommendation` when provided (useful for tests).
  final bool? showFirstLaunchModal;

  @override
  State<PreRunIgnitionScreen> createState() => _PreRunIgnitionScreenState();
}

class _PreRunIgnitionScreenState extends State<PreRunIgnitionScreen>
    with TickerProviderStateMixin {
  late final RecordingStore _store;
  late final PostHogTelemetryService _postHogService;
  late final StradioAudioEngine _audioEngine;
  late final bool _ownsAudioEngine;
  late StradioUserProfile _profile;
  late SoundPackId _selectedPackId;
  late final AnimationController _ribbonController;
  late final AnimationController _continuousWaveController;
  late int _targetPaceSec;
  late double _targetDistanceKm;
  double _swipeProgress = 0.0;
  bool _isPackDeckExpanded = false;
  bool _launching = false;

  bool get _isTestBinding =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? FileRecordingStore();
    _profile =
        widget.initialProfile ?? StradioPreferencesService.loadUserProfile();
    _postHogService =
        widget.postHogService ??
        PostHogTelemetryService(enabled: _profile.analyticsEnabled);
    _postHogService.setEnabled(_profile.analyticsEnabled);
    _selectedPackId =
        widget.initialSoundPackId ??
        StradioPreferencesService.loadActiveSoundPackId();
    _targetPaceSec = StradioPreferencesService.loadTargetPaceSecondsPerKm();
    _targetDistanceKm = StradioPreferencesService.loadTargetDistanceKm();

    _ownsAudioEngine = widget.audioEngine == null;
    _audioEngine =
        widget.audioEngine ??
        StradioAudioEngine(initialPack: _selectedPackId);

    _ribbonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _continuousWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );

    if (!_isTestBinding) {
      _continuousWaveController.repeat();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowEarphonesModal();
    });
  }

  @override
  void dispose() {
    _ribbonController.dispose();
    _continuousWaveController.dispose();
    if (_ownsAudioEngine) {
      unawaited(_audioEngine.dispose());
    } else {
      unawaited(_audioEngine.stopPreview());
    }
    super.dispose();
  }

  Future<void> _maybeShowEarphonesModal() async {
    // Shows on every app launch unless explicitly suppressed by widget tests.
    final shouldShow = widget.showFirstLaunchModal ?? true;
    if (!shouldShow || !mounted) return;

    await EarphonesRecommendationModal.show(
      context,
      language: _profile.language,
      onDismissed: () {
        unawaited(StradioPreferencesService.setHasSeenAudioRecommendation(true));
      },
    );
  }

  Future<void> _togglePreview() async {
    HapticFeedback.selectionClick();
    if (_audioEngine.isPreviewing) {
      await _audioEngine.stopPreview();
    } else {
      await _audioEngine.startPreview(packId: _selectedPackId);
    }
    if (mounted) setState(() {});
  }

  void _selectPack(SoundPackId id) {
    HapticFeedback.selectionClick();
    final wasPreviewing = _audioEngine.isPreviewing;
    setState(() {
      _selectedPackId = id;
      _isPackDeckExpanded = false;
    });
    if (!MediaQuery.disableAnimationsOf(context)) {
      _ribbonController.forward(from: 0.0);
    }
    unawaited(StradioPreferencesService.saveActiveSoundPackId(id));
    unawaited(_audioEngine.switchPack(id));
    if (wasPreviewing) {
      unawaited(_audioEngine.startPreview(packId: id));
    }
  }

  Future<void> _openSettings() async {
    await DaylightSettingsSheet.show(
      context,
      profile: _profile,
      onUpdateProfile: (updated) {
        setState(() => _profile = updated);
        _postHogService.setEnabled(updated.analyticsEnabled);
        unawaited(StradioPreferencesService.saveUserProfile(updated));
      },
      onShowEarphoneGuide: () {
        if (!mounted) return;
        unawaited(
          EarphonesRecommendationModal.show(
            context,
            language: _profile.language,
            onDismissed: () {
              unawaited(
                StradioPreferencesService.setHasSeenAudioRecommendation(true),
              );
            },
          ),
        );
      },
      onClearHistory: () async {
        await _store.clearAll();
      },
    );
  }

  Future<void> _openTargetCalibration() async {
    final activePack = StradioSoundPack.byId(_selectedPackId);
    await TargetCalibrationSheet.show(
      context,
      initialPaceSecondsPerKm: _targetPaceSec,
      initialDistanceKm: _targetDistanceKm,
      activePack: activePack,
      language: _profile.language,
      onApply: (paceSec, distanceKm) {
        if (!mounted) return;
        setState(() {
          _targetPaceSec = paceSec;
          _targetDistanceKm = distanceKm;
        });
      },
    );
  }

  Future<void> _startRun() async {
    if (_launching) return;
    _launching = true;
    HapticFeedback.mediumImpact();
    await _audioEngine.stopPreview();

    final pack = StradioSoundPack.byId(_selectedPackId);
    final derivedTargetBpm = StradioSoundPack.estimateCadenceFromPace(
      _targetPaceSec,
    ).round();
    final labSettings = StradioPreferencesService.loadLabSettings().copyWith(
      participantId: _profile.effectiveNickname,
      primaryAlgorithm: ThresholdAlgorithm.adaptiveMidpoint,
      targetBpm: derivedTargetBpm,
    );

    if (!mounted) {
      _launching = false;
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActiveRunScreen(
          store: _store,
          recordingService: widget.recordingService,
          postHogService: _postHogService,
          foregroundService: widget.foregroundService,
          audioEngine: widget.audioEngine,
          initialSoundPackId: pack.id,
          initialLabSettings: labSettings,
          userHeightCm: _profile.validHeightCm,
          language: _profile.language,
          autoStart: true,
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _swipeProgress = 0.0;
        _launching = false;
      });
    } else {
      _launching = false;
    }
  }

  String _modeSummary(StradioSoundPack pack, StradioStrings s) {
    final base = switch (pack.backgroundMode) {
      BackgroundLayerMode.joggingZoneOnly => s.modeKickJogLoop,
      BackgroundLayerMode.dualStemBarAligned => s.modeDualStem,
      BackgroundLayerMode.continuousTempoScaled => s.modeTempoScaled,
      BackgroundLayerMode.silent => s.modeStepSfxOnly,
    };
    if (pack.producerCredit != null) {
      return '$base · ${pack.producerCredit}';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(_profile.language);
    final isId = _profile.language == AppLanguage.id;
    final activePack = StradioSoundPack.byId(_selectedPackId);
    final syncIntegrity = activePack.computeSyncIntegrity(
      targetPaceSecondsPerKm: _targetPaceSec,
    );
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompactHeight = screenHeight < 700;

    return Scaffold(
      backgroundColor: StradioColors.warmIvory,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar + IMU Sensor Ready Pill (padded cleanly on Warm Ivory)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Semantics(
                            button: true,
                            label: 'Target pace and distance calibration',
                            child: IconButton(
                              key: const Key('pre_run_sensor_button'),
                              onPressed: _openTargetCalibration,
                              tooltip: isId
                                  ? 'Kalibrasi target'
                                  : 'Target calibration',
                              style: IconButton.styleFrom(
                                backgroundColor: StradioColors.surfaceCard,
                                minimumSize: const Size(48, 48),
                                side: const BorderSide(
                                  color: StradioColors.borderSubtle,
                                ),
                                shape: const CircleBorder(),
                              ),
                              icon: const Icon(
                                Icons.graphic_eq_rounded,
                                size: 20,
                                color: StradioColors.textPrimary,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/stradio-logo.png',
                                height: 24,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Stradio',
                                style: StradioTypography.headingSmall(
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          Semantics(
                            button: true,
                            label: 'Open settings',
                            child: IconButton(
                              key: const Key('pre_run_settings_button'),
                              onPressed: _openSettings,
                              tooltip: 'Settings',
                              style: IconButton.styleFrom(
                                backgroundColor: StradioColors.surfaceCard,
                                minimumSize: const Size(48, 48),
                                side: const BorderSide(
                                  color: StradioColors.borderSubtle,
                                ),
                                shape: const CircleBorder(),
                              ),
                              icon: const Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: StradioColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: StradioColors.surfaceRecessed.withValues(
                            alpha: 0.72,
                          ),
                          borderRadius: BorderRadius.circular(
                            StradioRadii.full,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: StradioColors.sonicCoral,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'IMU SENSOR READY · 100 HZ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StradioTypography.microCap(
                                  color: StradioColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Vertically Centered Full Edge-to-Edge Compass Radar & Sonic Wave (Mockup #07)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final h = constraints.maxHeight;
                      final w = constraints.maxWidth;
                      final compactRadar = h < 185;
                      final ovalH = (h * 0.44).clamp(64.0, 128.0);
                      final ovalW = ovalH * 0.74;

                      return SizedBox(
                        key: const Key('pre_run_open_waveform_hero'),
                        width: w,
                        height: h,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Centered Compass Hairline Rings & Cardinal Marks (0°/N, 90°, 180°/S, 270°)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _OpenTelemetryRadarPainter(
                                  compact: compactRadar,
                                ),
                              ),
                            ),

                            // Edge-to-Edge Flowing Multi-Harmonic Sonic Wave
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _ribbonController,
                                    _continuousWaveController,
                                    _audioEngine.previewProgressNotifier,
                                    _audioEngine.isPreviewingNotifier,
                                  ]),
                                  builder: (_, _) {
                                    final packIndex = StradioSoundPack.catalog
                                        .indexWhere(
                                          (p) => p.id == _selectedPackId,
                                        );
                                    final previewing =
                                        _audioEngine.isPreviewingNotifier.value;
                                    final previewProg = _audioEngine
                                        .previewProgressNotifier
                                        .value;
                                    final phase = reducedMotion
                                        ? 0.6
                                        : 0.6 +
                                              packIndex * 0.55 +
                                              _continuousWaveController.value *
                                                  math.pi *
                                                  2 +
                                              _ribbonController.value * 1.4 +
                                              previewProg * 16.0 +
                                              _swipeProgress * 2.0;
                                    return CustomPaint(
                                      painter: SonicRibbonPainter(
                                        phase: phase,
                                        amplitude: previewing ? 0.88 : 0.72,
                                        pulseBoost: previewing ? 0.40 : 0.0,
                                        strokeWidth: 2.5,
                                        fillGradientArea: true,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // Coral Resonance Node + Right-Center Frosted Glass Focal Lens (Mockup #07)
                            Transform.translate(
                              offset: Offset(-w * 0.13, 0),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: StradioColors.textAccentDeep,
                                  boxShadow: [
                                    BoxShadow(
                                      color: StradioColors.sonicCoral.withValues(
                                        alpha: 0.55,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(w * 0.21, 0),
                              child: IgnorePointer(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(ovalW),
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(
                                      sigmaX: 2.5,
                                      sigmaY: 2.5,
                                    ),
                                    child: Container(
                                      width: ovalW,
                                      height: ovalH,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          ovalW,
                                        ),
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.75,
                                          ),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: ovalW * 0.68,
                                          height: ovalW * 0.68,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: StradioColors.sonicCoral
                                                  .withValues(alpha: 0.34),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: StradioColors.sonicCoral
                                                    .withValues(alpha: 0.72),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Dock over 2 Edge-to-Edge Flowing Coral & Blue Ribbon Curves
                Stack(
                  children: [
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _BottomAmbientRibbonsPainter(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Glassmorphism Sound Pack Capsule directly above 3 Target Metrics
                          ClipRRect(
                            key: const Key('pre_run_sound_pack_tray'),
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: 14,
                                sigmaY: 14,
                              ),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  10,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      StradioColors.surfaceCard.withValues(
                                        alpha: 0.84,
                                      ),
                                      StradioColors.warmIvory.withValues(
                                        alpha: 0.72,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: StradioColors.midnight.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ValueListenableBuilder<bool>(
                                  valueListenable:
                                      _audioEngine.isPreviewingNotifier,
                                  builder: (context, isPreviewing, _) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                key: const Key(
                                                  'pre_run_timbre_dropdown_button',
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      StradioRadii.full,
                                                    ),
                                                onTap: () {
                                                  HapticFeedback.selectionClick();
                                                  setState(
                                                    () => _isPackDeckExpanded =
                                                        !_isPackDeckExpanded,
                                                  );
                                                },
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                        horizontal: 4,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration:
                                                            const BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: StradioColors
                                                                  .glowCoralSoft,
                                                            ),
                                                        child: const Icon(
                                                          Icons
                                                              .graphic_eq_rounded,
                                                          size: 16,
                                                          color: StradioColors
                                                              .textAccentDeep,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              activePack.title,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: StradioTypography.pillBadge(
                                                                color: StradioColors
                                                                    .textPrimary,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Flexible(
                                                                  child: Container(
                                                                    padding:
                                                                        const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              6,
                                                                          vertical:
                                                                              1.5,
                                                                        ),
                                                                    decoration: BoxDecoration(
                                                                      color: StradioColors
                                                                          .glowCoralSoft,
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            StradioRadii
                                                                                .full,
                                                                          ),
                                                                    ),
                                                                    child: Text(
                                                                      '${syncIntegrity.round()}% Match',
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      style: StradioTypography.microCap(
                                                                        color: StradioColors
                                                                            .textAccentDeep,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 6,
                                                                ),
                                                                Flexible(
                                                                  child: Text(
                                                                    activePack
                                                                        .categoryLabel,
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style:
                                                                        StradioTypography.metricLabel(),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Semantics(
                                              button: true,
                                              label: isPreviewing
                                                  ? s.stopPreviewAction
                                                  : s.previewAudioAction,
                                              child: Material(
                                                color: isPreviewing
                                                    ? StradioColors.sonicCoral
                                                    : StradioColors.midnight,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      StradioRadii.full,
                                                    ),
                                                child: InkWell(
                                                  key: const Key(
                                                    'pre_run_preview_audio_button',
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        StradioRadii.full,
                                                      ),
                                                  onTap: _togglePreview,
                                                  child: Container(
                                                    constraints:
                                                        const BoxConstraints(
                                                          minHeight: 36,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isPreviewing
                                                              ? Icons
                                                                    .stop_rounded
                                                              : Icons
                                                                    .play_arrow_rounded,
                                                          size: 15,
                                                          color: StradioColors
                                                              .textOnDark,
                                                        ),
                                                        const SizedBox(
                                                          width: 3,
                                                        ),
                                                        Text(
                                                          isPreviewing
                                                              ? s
                                                                    .stopPreviewAction
                                                              : s
                                                                    .previewAudioAction,
                                                          style:
                                                              StradioTypography.microCap(
                                                                color:
                                                                    StradioColors
                                                                        .textOnDark,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Semantics(
                                              button: true,
                                              label: 'Toggle sound pack list',
                                              child: InkWell(
                                                key: const Key(
                                                  'pre_run_expand_packs_chevron',
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      StradioRadii.full,
                                                    ),
                                                onTap: () {
                                                  HapticFeedback.selectionClick();
                                                  setState(
                                                    () => _isPackDeckExpanded =
                                                        !_isPackDeckExpanded,
                                                  );
                                                },
                                                child: SizedBox(
                                                  width: 28,
                                                  height: 36,
                                                  child: Icon(
                                                    _isPackDeckExpanded
                                                        ? Icons
                                                              .expand_less_rounded
                                                        : Icons
                                                              .expand_more_rounded,
                                                    size: 20,
                                                    color: StradioColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Animated Line Bar when Music Preview is Running
                                        ValueListenableBuilder<double>(
                                          valueListenable: _audioEngine
                                              .previewProgressNotifier,
                                          builder: (context, progress, _) {
                                            if (!isPreviewing &&
                                                progress <= 0.0) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                                left: 4,
                                                right: 4,
                                              ),
                                              child: ClipRRect(
                                                key: const Key(
                                                  'pre_run_preview_progress_bar',
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      StradioRadii.full,
                                                    ),
                                                child: SizedBox(
                                                  height: 4,
                                                  child: LinearProgressIndicator(
                                                    value: progress.clamp(
                                                      0.02,
                                                      1.0,
                                                    ),
                                                    backgroundColor:
                                                        StradioColors
                                                            .borderSubtle,
                                                    valueColor:
                                                        const AlwaysStoppedAnimation<
                                                          Color
                                                        >(
                                                          StradioColors
                                                              .sonicCoral,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),

                                        // Expandable Minimalist 6-Pack Selection Deck
                                        if (_isPackDeckExpanded) ...[
                                          const SizedBox(height: 10),
                                          const Divider(
                                            height: 1,
                                            color: StradioColors.borderSubtle,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  s.soundPacksHeading,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      StradioTypography.microCap(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  activePack.categoryLabel,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      StradioTypography.metricLabel(),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxHeight: isCompactHeight
                                                  ? 132
                                                  : 205,
                                            ),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  for (final pack
                                                      in StradioSoundPack
                                                          .catalog) ...[
                                                    _MinimalSoundPackRow(
                                                      pack: pack,
                                                      subtitle: _modeSummary(
                                                        pack,
                                                        s,
                                                      ),
                                                      selected:
                                                          pack.id ==
                                                          _selectedPackId,
                                                      onTap: () =>
                                                          _selectPack(pack.id),
                                                    ),
                                                    const SizedBox(height: 6),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 3 Target Metrics directly below Music Capsule & above Swipe to Start (Mockup #07)
                          InkWell(
                            key: const Key('pre_run_target_metrics_row'),
                            borderRadius: BorderRadius.circular(
                              StradioRadii.md,
                            ),
                            onTap: _openTargetCalibration,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _BottomTargetMetricColumn(
                                        label: isId
                                            ? 'Target Pace'
                                            : 'Pace Target',
                                        value: StradioSoundPack.formatPace(
                                          _targetPaceSec,
                                        ),
                                        unit: '/km',
                                        valueKey: const Key(
                                          'pre_run_pace_target_value',
                                        ),
                                      ),
                                    ),
                                    VerticalDivider(
                                      width: 14,
                                      thickness: 1,
                                      color: StradioColors.borderSubtle
                                          .withValues(alpha: 0.8),
                                    ),
                                    Expanded(
                                      child: _BottomTargetMetricColumn(
                                        label: isId
                                            ? 'Target Jarak'
                                            : 'Distance Target',
                                        value: _targetDistanceKm
                                            .toStringAsFixed(1),
                                        unit: 'km',
                                        valueKey: const Key(
                                          'pre_run_distance_target_value',
                                        ),
                                      ),
                                    ),
                                    VerticalDivider(
                                      width: 14,
                                      thickness: 1,
                                      color: StradioColors.borderSubtle
                                          .withValues(alpha: 0.8),
                                    ),
                                    Expanded(
                                      child: _BottomTargetMetricColumn(
                                        label: isId
                                            ? 'Sinkronisasi'
                                            : 'Sync Integrity',
                                        value: syncIntegrity.toStringAsFixed(1),
                                        unit: '%',
                                        valueKey: const Key(
                                          'pre_run_sync_integrity_value',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Primary Ignition Pill (56dp Smoked Obsidian Glassmorphism pill: Swipe-Only Lock)
                          _SwipeToStartPill(
                            label: s.swipeToStart,
                            progress: _swipeProgress,
                            onProgressChanged: (v) =>
                                setState(() => _swipeProgress = v),
                            onTriggerStart: _startRun,
                          ),
                        ],
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

class _BottomTargetMetricColumn extends StatelessWidget {
  const _BottomTargetMetricColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueKey,
  });

  final String label;
  final String value;
  final String unit;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: StradioTypography.metricLabel(
            color: StradioColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                key: valueKey,
                style: StradioTypography.metricValue(fontSize: 22),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: StradioTypography.metricLabel(
                  color: StradioColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Delicate concentric compass rings, tilted orbit ellipse & cardinal degrees (Mockup #07).
class _OpenTelemetryRadarPainter extends CustomPainter {
  const _OpenTelemetryRadarPainter({required this.compact});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.50);
    final outerR = (compact ? size.height * 0.39 : size.height * 0.38).clamp(
      52.0,
      118.0,
    );
    final innerR = outerR * 0.50;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          StradioColors.sonicCoral.withValues(alpha: 0.11),
          StradioColors.rhythmViolet.withValues(alpha: 0.08),
          StradioColors.warmIvory.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerR * 1.25));
    canvas.drawCircle(center, outerR * 1.25, glowPaint);

    // Outer hairline circle & inner ring
    final ringPaint = Paint()
      ..color = StradioColors.borderSubtle.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    canvas.drawCircle(center, outerR, ringPaint);
    canvas.drawCircle(
      center,
      innerR,
      ringPaint..color = StradioColors.borderSubtle.withValues(alpha: 0.36),
    );

    // Crosshairs
    final crossPaint = Paint()
      ..color = StradioColors.borderSubtle.withValues(alpha: 0.44)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(center.dx - outerR, center.dy),
      Offset(center.dx + outerR, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - outerR),
      Offset(center.dx, center.dy + outerR),
      crossPaint,
    );

    // Tilted dashed ellipse orbit matching Mockup #07
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.26);
    final ovalRect = Rect.fromCenter(
      center: Offset.zero,
      width: outerR * 1.92,
      height: outerR * 1.18,
    );
    final ovalPath = Path()..addOval(ovalRect);
    final dashedPaint = Paint()
      ..color = StradioColors.borderSubtle.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (final metric in ovalPath.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9.0) {
        final end = math.min(d + 4.5, metric.length);
        canvas.drawPath(metric.extractPath(d, end), dashedPaint);
      }
    }
    canvas.restore();

    // Cardinal degree labels: 0° / N, 90°, 180° / S, 270°
    _drawLabel(canvas, '0° / N', Offset(center.dx, center.dy - outerR - 10));
    _drawLabel(canvas, '180° / S', Offset(center.dx, center.dy + outerR + 10));
    _drawLabel(canvas, '270°', Offset(center.dx - outerR * 0.72, center.dy - 10));
    _drawLabel(canvas, '90°', Offset(center.dx + outerR * 0.72, center.dy + 10));
  }

  void _drawLabel(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: StradioColors.textSecondary.withValues(alpha: 0.65),
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _OpenTelemetryRadarPainter oldDelegate) =>
      oldDelegate.compact != compact;
}

/// Two subtle edge-to-edge flowing coral & twilight-blue curves behind the bottom dock (Mockup #07).
class _BottomAmbientRibbonsPainter extends CustomPainter {
  const _BottomAmbientRibbonsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final coralPaint = Paint()
      ..color = StradioColors.sonicCoral.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final coralPath = Path()
      ..moveTo(0, size.height * 0.58)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.44,
        size.width * 0.56,
        size.height * 0.88,
        size.width,
        size.height * 0.52,
      );
    canvas.drawPath(coralPath, coralPaint);

    final bluePaint = Paint()
      ..color = StradioColors.twilightPlum.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final bluePath = Path()
      ..moveTo(0, size.height * 0.74)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.86,
        size.width * 0.66,
        size.height * 0.48,
        size.width,
        size.height * 0.66,
      );
    canvas.drawPath(bluePath, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MinimalSoundPackRow extends StatelessWidget {
  const _MinimalSoundPackRow({
    required this.pack,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final StradioSoundPack pack;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? StradioColors.surfaceCard
          : StradioColors.warmIvory.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(StradioRadii.lg),
      child: InkWell(
        key: Key('pre_run_pack_${pack.code}'),
        borderRadius: BorderRadius.circular(StradioRadii.lg),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StradioRadii.lg),
            border: Border.all(
              color: selected
                  ? StradioColors.midnight
                  : StradioColors.borderSubtle,
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? StradioColors.sonicCoral
                      : StradioColors.borderSubtle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.pillBadge(
                        color: StradioColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.metricLabel(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? StradioColors.glowCoralSoft
                      : StradioColors.surfaceRecessed,
                  borderRadius: BorderRadius.circular(StradioRadii.full),
                ),
                child: Text(
                  pack.categoryLabel,
                  style: StradioTypography.microCap(
                    color: selected
                        ? StradioColors.textAccentDeep
                        : StradioColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Smoked Obsidian Frosted Glassmorphism Ignition Pill (`.lg-obsidian-surface` in Mockup #07).
/// Strictly locked to swipe gesture (`progress >= 0.65`) to prevent accidental pocket/thumb taps.
class _SwipeToStartPill extends StatefulWidget {
  const _SwipeToStartPill({
    required this.label,
    required this.progress,
    required this.onProgressChanged,
    required this.onTriggerStart,
  });

  final String label;
  final double progress;
  final ValueChanged<double> onProgressChanged;
  final VoidCallback onTriggerStart;

  @override
  State<_SwipeToStartPill> createState() => _SwipeToStartPillState();
}

class _SwipeToStartPillState extends State<_SwipeToStartPill> {
  double _localProgress = 0.0;

  @override
  void didUpdateWidget(covariant _SwipeToStartPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != oldWidget.progress) {
      _localProgress = widget.progress;
    }
  }

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final effectiveProgress = _localProgress;

    return Semantics(
      button: true,
      label: 'Swipe right to start run',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          final maxDrag = (trackWidth - 60).clamp(40.0, 420.0);

          final pillBody = Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              gradient: highContrast
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF242434).withValues(alpha: 0.80),
                        StradioColors.midnight.withValues(alpha: 0.86),
                      ],
                    ),
              color: highContrast ? StradioColors.midnight : null,
              borderRadius: BorderRadius.circular(StradioRadii.full),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.36),
                width: 1.25,
              ),
              boxShadow: [
                BoxShadow(
                  color: StradioColors.midnight.withValues(alpha: 0.26),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Top Specular Glass Rim Highlight
                Positioned(
                  top: 0,
                  left: 24,
                  right: 24,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.52),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Subtle internal coral-violet glass refraction sheen
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(StradioRadii.full),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            StradioColors.sonicCoral.withValues(
                              alpha: 0.10 + effectiveProgress * 0.16,
                            ),
                            Colors.transparent,
                            StradioColors.rhythmViolet.withValues(alpha: 0.12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Text(
                  widget.label,
                  style: StradioTypography.buttonLabel(
                    color: StradioColors.textOnDark.withValues(
                      alpha: (1.0 - effectiveProgress * 0.55).clamp(0.35, 0.96),
                    ),
                  ),
                ),

                // Right Target Halo Ring Indicator
                Positioned(
                  right: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: StradioColors.warmIvory.withValues(
                            alpha: 0.92,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Left Tactile Alabaster Frosted Glass Handle
                Positioned(
                  left: effectiveProgress * maxDrag,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: StradioColors.surfaceCard.withValues(alpha: 0.96),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: StradioColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );

          return GestureDetector(
            key: const Key('swipe_to_start_pill'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {
              _localProgress = widget.progress;
            },
            onHorizontalDragUpdate: (details) {
              final next = (_localProgress + details.delta.dx / maxDrag).clamp(
                0.0,
                1.0,
              );
              _localProgress = next;
              widget.onProgressChanged(next);
            },
            onHorizontalDragEnd: (_) {
              if (_localProgress >= 0.65) {
                _localProgress = 0.0;
                widget.onTriggerStart();
              } else {
                _localProgress = 0.0;
                widget.onProgressChanged(0.0);
              }
            },
            onHorizontalDragCancel: () {
              _localProgress = 0.0;
              widget.onProgressChanged(0.0);
            },
            child: highContrast
                ? pillBody
                : ClipRRect(
                    borderRadius: BorderRadius.circular(StradioRadii.full),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: pillBody,
                    ),
                  ),
          );
        },
      ),
    );
  }
}
