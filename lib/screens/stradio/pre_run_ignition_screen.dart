import 'dart:async';

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
import '../../widgets/liquid_glass_lens.dart';
import '../../widgets/sensor_calibration_sheet.dart';
import '../../widgets/sonic_ribbon_painter.dart';
import 'active_run_screen.dart';

/// Surface 1: Pre-Run Ignition (`docs/EXPERIENCE.md` & `docs/DESIGN.md`).
///
/// Zero-friction daylight launch on Warm Ivory (`#F5F0E8`) with:
/// - First-launch Audio Device Recommendation modal (`has_seen_audio_recommendation`).
/// - Central 100 Hz sonic ribbon visual overlapped by 1 [LiquidGlassLens] tray (`R-10`)
///   housing all 6 curated Sound Packs (`PRD-MVP.md` FR-4.1).
/// - Solid Midnight `56dp` bottom ignition pill (`Swipe to start`, also tappable).
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
    with SingleTickerProviderStateMixin {
  late final RecordingStore _store;
  late final PostHogTelemetryService _postHogService;
  late StradioUserProfile _profile;
  late SoundPackId _selectedPackId;
  late final AnimationController _ribbonController;
  SensorPipelineState _sensorState = SensorPipelineState.ready;
  double _swipeProgress = 0.0;
  bool _launching = false;

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

    _ribbonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowEarphonesModal();
    });
  }

  @override
  void dispose() {
    _ribbonController.dispose();
    super.dispose();
  }

  Future<void> _maybeShowEarphonesModal() async {
    final shouldShow =
        widget.showFirstLaunchModal ??
        !StradioPreferencesService.hasSeenAudioRecommendation();
    if (!shouldShow || !mounted) return;

    await EarphonesRecommendationModal.show(
      context,
      language: _profile.language,
      onDismissed: () {
        unawaited(StradioPreferencesService.setHasSeenAudioRecommendation(true));
      },
    );
  }

  void _selectPack(SoundPackId id) {
    if (_selectedPackId == id) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedPackId = id);
    if (!MediaQuery.disableAnimationsOf(context)) {
      _ribbonController.forward(from: 0.0);
    }
    unawaited(StradioPreferencesService.saveActiveSoundPackId(id));
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

  Future<void> _openSensorCalibration() async {
    await SensorCalibrationSheet.show(
      context,
      state: _sensorState,
      language: _profile.language,
      onRetrySensor: () {
        setState(() => _sensorState = SensorPipelineState.ready);
      },
    );
  }

  Future<void> _startRun() async {
    if (_launching) return;
    _launching = true;
    HapticFeedback.mediumImpact();

    final pack = StradioSoundPack.byId(_selectedPackId);
    final labSettings = StradioPreferencesService.loadLabSettings().copyWith(
      participantId: _profile.effectiveNickname,
      primaryAlgorithm: ThresholdAlgorithm.adaptiveMidpoint,
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

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(_profile.language);
    final activePack = StradioSoundPack.byId(_selectedPackId);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: StradioColors.warmIvory,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Bar: Sensor calibration | Brand Mark | Settings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Semantics(
                        button: true,
                        label: 'Motion sensor calibration',
                        child: IconButton(
                          key: const Key('pre_run_sensor_button'),
                          onPressed: _openSensorCalibration,
                          tooltip: 'Motion sensor',
                          style: IconButton.styleFrom(
                            backgroundColor: StradioColors.surfaceCard,
                            minimumSize: const Size(48, 48),
                            side: const BorderSide(
                              color: StradioColors.borderSubtle,
                            ),
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(
                            Icons.sensors_rounded,
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
                            height: 22,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Stradio',
                            style: StradioTypography.headingSmall(fontSize: 17),
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
                  const SizedBox(height: 16),

                  // Central Instrument Zone: Sonic Hero + 1 LiquidGlassLens Sound-Pack Tray (R-10)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxHeight < 460;
                        final heroHeight = isCompact ? 120.0 : 156.0;

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Sonic Waveform Well
                              SizedBox(
                                height: heroHeight,
                                child: Center(
                                  child: Container(
                                    width: heroHeight,
                                    height: heroHeight,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: StradioColors.surfaceRecessed,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Positioned.fill(
                                          child: AnimatedBuilder(
                                            animation: _ribbonController,
                                            builder: (_, _) {
                                              final packIndex = StradioSoundPack
                                                  .catalog
                                                  .indexWhere(
                                                    (p) =>
                                                        p.id == _selectedPackId,
                                                  );
                                              final phase = reducedMotion
                                                  ? 0.6
                                                  : 0.6 +
                                                        packIndex * 0.55 +
                                                        _ribbonController.value *
                                                            1.2 +
                                                        _swipeProgress * 1.8;
                                              return CustomPaint(
                                                painter: SonicRibbonPainter(
                                                  phase: phase,
                                                  amplitude: 0.68,
                                                  strokeWidth: 2.5,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        Positioned(
                                          top: isCompact ? 16 : 22,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: StradioColors.surfaceCard,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    StradioRadii.full,
                                                  ),
                                              border: Border.all(
                                                color:
                                                    StradioColors.borderSubtle,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 5,
                                                  height: 5,
                                                  decoration:
                                                      const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: StradioColors
                                                            .sonicCoral,
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '100 Hz IMU',
                                                  style:
                                                      StradioTypography.microCap(
                                                        color: StradioColors
                                                            .textPrimary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Sole LiquidGlassLens on Surface 1: 6 Sound Pack Selector Tray
                              LiquidGlassLens(
                                key: const Key('pre_run_sound_pack_tray'),
                                shape: LiquidGlassShape.rounded,
                                borderRadius: StradioRadii.tray,
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          s.soundPacksHeading,
                                          style: StradioTypography.microCap(),
                                        ),
                                        Text(
                                          activePack.artist,
                                          style:
                                              StradioTypography.metricLabel(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    LayoutBuilder(
                                      builder: (context, trayConstraints) {
                                        final twoCols =
                                            trayConstraints.maxWidth >= 260;
                                        final tileWidth = twoCols
                                            ? (trayConstraints.maxWidth - 10) /
                                                  2
                                            : trayConstraints.maxWidth;

                                        return Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            for (final pack
                                                in StradioSoundPack.catalog)
                                              SizedBox(
                                                width: tileWidth,
                                                child: _SoundPackTile(
                                                  pack: pack,
                                                  strings: s,
                                                  selected:
                                                      pack.id ==
                                                      _selectedPackId,
                                                  onTap: () =>
                                                      _selectPack(pack.id),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Honest 1-line sensor status above bottom thumb dock
                  Text(
                    s.motionSensorReadyWithPack(activePack.title),
                    textAlign: TextAlign.center,
                    style: StradioTypography.body(fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  // Primary Ignition Pill (56dp Midnight pill: swipe OR tap to start)
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
          ),
        ),
      ),
    );
  }
}

class _SoundPackTile extends StatelessWidget {
  const _SoundPackTile({
    required this.pack,
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final StradioSoundPack pack;
  final StradioStrings strings;
  final bool selected;
  final VoidCallback onTap;

  String _modeSummary() => switch (pack.backgroundMode) {
    BackgroundLayerMode.joggingZoneOnly => strings.modeKickJogLoop,
    BackgroundLayerMode.dualStemBarAligned => strings.modeDualStem,
    BackgroundLayerMode.continuousTempoScaled => strings.modeTempoScaled,
    BackgroundLayerMode.silent => strings.modeStepSfxOnly,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? StradioColors.surfaceCard : StradioColors.warmIvory,
      borderRadius: BorderRadius.circular(StradioRadii.lg),
      child: InkWell(
        key: Key('pre_run_pack_${pack.code}'),
        borderRadius: BorderRadius.circular(StradioRadii.lg),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StradioRadii.lg),
            border: Border.all(
              color: selected
                  ? StradioColors.midnight
                  : StradioColors.borderSubtle,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pack.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.pillBadge(
                        color: StradioColors.textPrimary,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: StradioColors.sonicCoral,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _modeSummary(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StradioTypography.metricLabel(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeToStartPill extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Swipe or tap to start run',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          final maxDrag = (trackWidth - 56).clamp(40.0, 420.0);

          return GestureDetector(
            key: const Key('swipe_to_start_pill'),
            onTap: onTriggerStart,
            onHorizontalDragUpdate: (details) {
              final next = (progress + details.delta.dx / maxDrag).clamp(
                0.0,
                1.0,
              );
              onProgressChanged(next);
            },
            onHorizontalDragEnd: (_) {
              if (progress >= 0.55) {
                onTriggerStart();
              } else {
                onProgressChanged(0.0);
              }
            },
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: StradioColors.midnight,
                borderRadius: BorderRadius.circular(StradioRadii.full),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    label,
                    style: StradioTypography.buttonLabel(
                      color: StradioColors.textOnDark,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: StradioColors.textOnDark.withValues(
                            alpha: 0.45,
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: progress * (maxDrag - 18),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: StradioColors.textOnDark.withValues(alpha: 0.14),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: StradioColors.textOnDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
