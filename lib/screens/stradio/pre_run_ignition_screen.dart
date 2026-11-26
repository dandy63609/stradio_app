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
import '../../widgets/target_calibration_sheet.dart';
import 'active_run_screen.dart';

/// Surface 1: Pre-Run Ignition (`Card 07` / `UX-REVISION-HANDOFF.md` / Foto 2).
///
/// - Top-bleed runner legs hero (~52-55% height, `SafeArea(top: false)`) composited
///   with `BlendMode.multiply` over Warm Ivory + Ambient Orbital Cadence Dial.
/// - Floating frosted header (`Stradio` halo pill + Settings & Target Calibration icons).
/// - Suspended Curved Liquid Glass Deck (`Audition` EQ + upward 6-pack popover,
///   `SPM TARGET` & `PACE SYNC`, micro telemetry strip) anchored cleanly above
///   the `56dp` Deep Midnight Obsidian `Swipe to start` pill (swipe-only lock).
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
  static const String _runnerHeroAsset =
      'assets/design/Generate_cinematic_storyboard_grid_fbd8354d_2K.jpg_322851f9.jpg';

  late final RecordingStore _store;
  late final PostHogTelemetryService _postHogService;
  late final StradioAudioEngine _audioEngine;
  late final bool _ownsAudioEngine;
  late StradioUserProfile _profile;
  late SoundPackId _selectedPackId;
  late final AnimationController _orbitController;
  late int _targetPaceSec;
  late double _targetDistanceKm;
  late bool _adaptiveTempoScaling;
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
    _adaptiveTempoScaling =
        StradioPreferencesService.loadAdaptiveTempoScaling();

    _ownsAudioEngine = widget.audioEngine == null;
    _audioEngine =
        widget.audioEngine ??
        StradioAudioEngine(initialPack: _selectedPackId);
    _audioEngine.setAdaptiveTempoScaling(_adaptiveTempoScaling);

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (!_isTestBinding) {
      _orbitController.repeat();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowEarphonesModal();
    });
  }

  @override
  void dispose() {
    _orbitController.dispose();
    if (_ownsAudioEngine) {
      unawaited(_audioEngine.dispose());
    } else {
      unawaited(_audioEngine.stopPreview());
    }
    super.dispose();
  }

  Future<void> _maybeShowEarphonesModal() async {
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
      initialAdaptiveTempoScaling: _adaptiveTempoScaling,
      activePack: activePack,
      language: _profile.language,
      onAdaptiveTempoScalingChanged: (enabled) {
        _adaptiveTempoScaling = enabled;
        _audioEngine.setAdaptiveTempoScaling(enabled);
      },
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
          audioEngine: _audioEngine,
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

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(_profile.language);
    final isId = _profile.language == AppLanguage.id;
    final activePack = StradioSoundPack.byId(_selectedPackId);
    final targetSpm = StradioSoundPack.estimateCadenceFromPace(
      _targetPaceSec,
    ).round();
    final syncIntegrity = activePack.computeSyncIntegrity(
      targetPaceSecondsPerKm: _targetPaceSec,
    );
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final topInset = media.padding.top;
    final bottomInset = media.padding.bottom;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    // ~52-54% hero height on standard phones; scales down cleanly on compact 640px screens.
    final heroHeight = (screenH * (screenH < 700 ? 0.44 : 0.53)).clamp(
      240.0,
      480.0,
    );

    return Scaffold(
      backgroundColor: StradioColors.warmIvory,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              // 1. Top-bleed Runner Hero Zone (flush to top: 0 behind status bar)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: heroHeight,
                child: RepaintBoundary(
                  key: const Key('pre_run_open_waveform_hero'),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Ambient Orbital Cadence Dial behind runner legs
                      Center(
                        child: AnimatedBuilder(
                          animation: _orbitController,
                          builder: (_, _) => CustomPaint(
                            size: Size(heroHeight * 0.78, heroHeight * 0.78),
                            painter: _PreRunOrbitalDialPainter(
                              angle: reducedMotion
                                  ? 0.0
                                  : _orbitController.value * math.pi * 2,
                            ),
                          ),
                        ),
                      ),

                      // Runner's legs cutout composited seamlessly into Warm Ivory
                      Positioned.fill(
                        child: Image.asset(
                          _runnerHeroAsset,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          color: StradioColors.warmIvory,
                          colorBlendMode: BlendMode.multiply,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),

                      // Soft bottom vignette fading runner legs into Warm Ivory canvas
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 88,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  StradioColors.warmIvory.withValues(
                                    alpha: 0.0,
                                  ),
                                  StradioColors.warmIvory.withValues(
                                    alpha: 0.78,
                                  ),
                                  StradioColors.warmIvory,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Floating bottom-right Live Phase Coordinate Pill
                      Positioned(
                        right: 20,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: StradioColors.surfaceCard.withValues(
                              alpha: 0.88,
                            ),
                            borderRadius: BorderRadius.circular(
                              StradioRadii.full,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.92),
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
                              Text(
                                '100 HZ IMU • $targetSpm STRIDE',
                                style: StradioTypography.microCap(
                                  color: StradioColors.textSecondary,
                                ).copyWith(fontSize: 9.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Floating Overlay Header (within top SafeArea)
              Positioned(
                top: topInset + 10,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Frosted Warm Ivory Stradio Brand Halo Pill
                    ClipRRect(
                      borderRadius: BorderRadius.circular(StradioRadii.full),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
                          decoration: BoxDecoration(
                            color: StradioColors.surfaceCard.withValues(
                              alpha: 0.82,
                            ),
                            borderRadius: BorderRadius.circular(
                              StradioRadii.full,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.90),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/stradio-logo.png',
                                width: 20,
                                height: 20,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 18,
                                  color: StradioColors.sonicCoral,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Stradio',
                                style: StradioTypography.headingSmall(
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Right 2 Frosted Circular Action Buttons (Settings & Target Calibration)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FrostedCircleIconButton(
                          buttonKey: const Key('pre_run_settings_button'),
                          icon: Icons.graphic_eq_rounded,
                          tooltip: s.settingsTitle,
                          onTap: _openSettings,
                        ),
                        const SizedBox(width: 8),
                        _FrostedCircleIconButton(
                          buttonKey: const Key('pre_run_sensor_button'),
                          icon: Icons.tune_rounded,
                          tooltip: s.targetCalibrationTitle,
                          onTap: _openTargetCalibration,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Lower Anchored Column: Suspended Curved Liquid Glass Deck + Swipe to start
              // Anchored at bottom with ~18px gap so there is zero awkward empty void on tall phones.
              Positioned(
                left: 16,
                right: 16,
                bottom: 16 + bottomInset,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Suspended Curved Liquid Glass Deck (grows upward when pack list expands)
                    _buildSuspendedGlassDeck(
                      activePack: activePack,
                      targetSpm: targetSpm,
                      syncIntegrity: syncIntegrity,
                      isId: isId,
                    ),
                    const SizedBox(height: 18),

                    // Bottom 56dp Deep Midnight Obsidian "Swipe to start" Pill (swipe-only lock)
                    _SwipeToStartPill(
                      progress: _swipeProgress,
                      label: isId ? 'Geser untuk mulai' : 'Swipe to start',
                      onDragDelta: (deltaFraction) {
                        setState(() {
                          _swipeProgress = (_swipeProgress + deltaFraction)
                              .clamp(0.0, 1.0);
                        });
                      },
                      onDragEnd: () {
                        if (_swipeProgress >= 0.58) {
                          setState(() => _swipeProgress = 1.0);
                          unawaited(_startRun());
                        } else {
                          setState(() => _swipeProgress = 0.0);
                        }
                      },
                      onDragCancel: () => setState(() => _swipeProgress = 0.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuspendedGlassDeck({
    required StradioSoundPack activePack,
    required int targetSpm,
    required double syncIntegrity,
    required bool isId,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: StradioColors.surfaceCard.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.92),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: StradioColors.midnight.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Upward-expanding 6 Sound Pack Popover List
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: _isPackDeckExpanded
                    ? Container(
                        key: const Key('pre_run_expanded_pack_list'),
                        margin: const EdgeInsets.only(bottom: 10),
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: StradioColors.warmIvory.withValues(
                            alpha: 0.85,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: StradioColors.borderSubtle),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(6),
                          itemCount: StradioSoundPack.catalog.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (_, index) {
                            final pack = StradioSoundPack.catalog[index];
                            final selected = pack.id == _selectedPackId;
                            return Material(
                              color: selected
                                  ? StradioColors.glowCoralSoft
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                key: Key('pre_run_pack_${pack.code}'),
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _selectPack(pack.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pack.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  StradioTypography.pillBadge(),
                                            ),
                                            Text(
                                              pack.producerCredit != null
                                                  ? '${pack.categoryLabel} · ${pack.producerCredit}'
                                                  : pack.categoryLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  StradioTypography.metricLabel(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (selected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 18,
                                          color: StradioColors.textAccentDeep,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Sound Engine Selection Capsule
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: StradioColors.glowCoralSoft,
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            size: 17,
                            color: StradioColors.textAccentDeep,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activePack.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StradioTypography.pillBadge(),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: StradioColors.glowCoralSoft,
                                        borderRadius: BorderRadius.circular(
                                          StradioRadii.full,
                                        ),
                                      ),
                                      child: Text(
                                        '${syncIntegrity.round()}% Match',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: StradioTypography.microCap(
                                          color: StradioColors.textAccentDeep,
                                        ).copyWith(fontSize: 8.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      activePack.categoryLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: StradioTypography.metricLabel(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Interactive Audition Pill Button (10s preview)
                        ValueListenableBuilder<bool>(
                          valueListenable: _audioEngine.isPreviewingNotifier,
                          builder: (_, previewing, _) => Material(
                            color: previewing
                                ? StradioColors.sonicCoral
                                : StradioColors.midnight,
                            borderRadius: BorderRadius.circular(
                              StradioRadii.full,
                            ),
                            child: InkWell(
                              key: const Key('pre_run_preview_audio_button'),
                              borderRadius: BorderRadius.circular(
                                StradioRadii.full,
                              ),
                              onTap: _togglePreview,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 7,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      previewing
                                          ? Icons.stop_rounded
                                          : Icons.equalizer_rounded,
                                      size: 13,
                                      color: StradioColors.textOnDark,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      previewing
                                          ? (isId ? 'Stop' : 'Stop')
                                          : (isId ? 'Dengar' : 'Audition'),
                                      style: StradioTypography.microCap(
                                        color: StradioColors.textOnDark,
                                      ).copyWith(fontSize: 9.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),

                        // Expand Chevron for 6-pack selector
                        InkWell(
                          key: const Key('pre_run_timbre_dropdown_button'),
                          borderRadius: BorderRadius.circular(
                            StradioRadii.full,
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(
                              () => _isPackDeckExpanded = !_isPackDeckExpanded,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              _isPackDeckExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: StradioColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 10s Audio Preview Progress Line Bar
                    ValueListenableBuilder<bool>(
                      valueListenable: _audioEngine.isPreviewingNotifier,
                      builder: (_, previewing, _) {
                        if (!previewing) return const SizedBox.shrink();
                        return ValueListenableBuilder<double>(
                          valueListenable: _audioEngine.previewProgressNotifier,
                          builder: (_, progress, _) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ClipRRect(
                              key: const Key('pre_run_preview_progress_bar'),
                              borderRadius: BorderRadius.circular(
                                StradioRadii.full,
                              ),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 3,
                                backgroundColor: StradioColors.borderSubtle,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  StradioColors.sonicCoral,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Split Hero Metric Row: SPM TARGET | PACE SYNC (tappable to calibrate)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openTargetCalibration,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SPM TARGET',
                                style: StradioTypography.microCap(
                                  color: StradioColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$targetSpm',
                                      style: StradioTypography.metricHero(
                                        fontSize: 38,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'spm',
                                      style: StradioTypography.metricLabel(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          color: StradioColors.borderSubtle,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PACE SYNC',
                                style: StradioTypography.microCap(
                                  color: StradioColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      StradioSoundPack.formatPace(
                                        _targetPaceSec,
                                      ),
                                      style: StradioTypography.metricHero(
                                        fontSize: 38,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '/km',
                                      style: StradioTypography.metricLabel(),
                                    ),
                                  ],
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
              const SizedBox(height: 10),
              const Divider(height: 1, color: StradioColors.borderSubtle),
              const SizedBox(height: 9),

              // Micro Telemetry Strip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: StradioColors.twilightPlum,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${_targetDistanceKm.toStringAsFixed(1)} km Target',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StradioTypography.metricLabel(
                              color: StradioColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
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
                            '${syncIntegrity.toStringAsFixed(1)}% Harmonic Lock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StradioTypography.metricLabel(
                              color: StradioColors.textPrimary,
                            ),
                          ),
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
    );
  }
}

class _FrostedCircleIconButton extends StatelessWidget {
  const _FrostedCircleIconButton({
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
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: StradioColors.surfaceCard.withValues(alpha: 0.84),
            shape: CircleBorder(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.92)),
            ),
            child: InkWell(
              key: buttonKey,
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(icon, size: 19, color: StradioColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 56dp Deep Midnight Obsidian swipe-only ignition capsule (Foto 2).
class _SwipeToStartPill extends StatelessWidget {
  const _SwipeToStartPill({
    required this.progress,
    required this.label,
    required this.onDragDelta,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  final double progress;
  final String label;
  final ValueChanged<double> onDragDelta;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const height = 56.0;
        const knobSize = 44.0;
        const inset = 6.0;
        final travel = math.max(1.0, constraints.maxWidth - knobSize - inset * 2);

        return GestureDetector(
          key: const Key('swipe_to_start_pill'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) =>
              onDragDelta(details.delta.dx / travel),
          onHorizontalDragEnd: (_) => onDragEnd(),
          onHorizontalDragCancel: onDragCancel,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: StradioColors.midnight,
              borderRadius: BorderRadius.circular(StradioRadii.full),
              boxShadow: [
                BoxShadow(
                  color: StradioColors.midnight.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle coral sweep as runner drags slider
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(StradioRadii.full),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: StradioColors.sonicCoral.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Centered Label
                Text(
                  label,
                  style: StradioTypography.buttonLabel(
                    color: StradioColors.textOnDark.withValues(
                      alpha: (1.0 - progress * 0.5).clamp(0.4, 1.0),
                    ),
                  ),
                ),

                // Right Pulsing Sonic Coral Live Sensor Ring
                Positioned(
                  right: 12,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: StradioColors.sonicCoral.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: StradioColors.sonicCoral,
                      ),
                    ),
                  ),
                ),

                // Left Draggable Alabaster Slider Knob
                Positioned(
                  left: inset + travel * progress,
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: StradioColors.surfaceCard,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: StradioColors.midnight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ambient concentric orbital cadence dial painted behind the runner legs cutout.
class _PreRunOrbitalDialPainter extends CustomPainter {
  const _PreRunOrbitalDialPainter({required this.angle});

  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide * 0.46;
    final innerR = size.shortestSide * 0.35;

    final outerPaint = Paint()
      ..color = StradioColors.midnight.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, outerR, outerPaint);

    // Slowly rotating dashed inner ring
    final dashPaint = Paint()
      ..color = StradioColors.midnight.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const dashCount = 48;
    const sweep = (math.pi * 2) / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerR),
        angle + i * sweep,
        sweep * 0.45,
        false,
        dashPaint,
      );
    }

    // Central soft coral resonance dot
    canvas.drawCircle(
      center,
      8,
      Paint()..color = StradioColors.sonicCoral.withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      center,
      3.5,
      Paint()..color = StradioColors.sonicCoral.withValues(alpha: 0.78),
    );
  }

  @override
  bool shouldRepaint(covariant _PreRunOrbitalDialPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
