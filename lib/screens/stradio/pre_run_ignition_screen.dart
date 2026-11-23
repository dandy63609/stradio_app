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
import '../../widgets/liquid_glass_lens.dart';
import '../../widgets/sensor_calibration_sheet.dart';
import '../../widgets/sonic_ribbon_painter.dart';
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
  SensorPipelineState _sensorState = SensorPipelineState.ready;
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
      duration: const Duration(seconds: 6),
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

  Future<void> _openSensorCalibration() async {
    await SensorCalibrationSheet.show(
      context,
      state: _sensorState,
      language: _profile.language,
      initialSensitivity: StradioPreferencesService.loadStrideSensitivity(),
      onApplyCalibration: (sensitivity) {
        unawaited(StradioPreferencesService.saveStrideSensitivity(sensitivity));
      },
      onRetrySensor: () {
        setState(() => _sensorState = SensorPipelineState.ready);
      },
    );
  }

  Future<void> _startRun() async {
    if (_launching) return;
    _launching = true;
    HapticFeedback.mediumImpact();
    await _audioEngine.stopPreview();

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
                            height: 24,
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
                  const SizedBox(height: 12),

                  // Central Instrument Zone: Open Radar Full-Width Sonic Ribbons + Unified Timbre Glass Capsule (Mockup #07)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxHeight < 430;
                        final heroHeight = isCompact ? 148.0 : 210.0;

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Mockup #07 Open Full-Width Waveform & Concentric Telemetry Radar
                              SizedBox(
                                key: const Key('pre_run_open_waveform_hero'),
                                height: heroHeight,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Concentric Telemetry Hairline Rings & Cardinal Degree Marks
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _OpenTelemetryRadarPainter(
                                          compact: isCompact,
                                        ),
                                      ),
                                    ),

                                    // Unclipped Full-Width Multi-Layered Sonic Ribbons
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: Listenable.merge([
                                          _ribbonController,
                                          _continuousWaveController,
                                          _audioEngine.previewProgressNotifier,
                                          _audioEngine.isPreviewingNotifier,
                                        ]),
                                        builder: (_, _) {
                                          final packIndex = StradioSoundPack
                                              .catalog
                                              .indexWhere(
                                                (p) => p.id == _selectedPackId,
                                              );
                                          final previewing = _audioEngine
                                              .isPreviewingNotifier
                                              .value;
                                          final previewProg = _audioEngine
                                              .previewProgressNotifier
                                              .value;
                                          final phase = reducedMotion
                                              ? 0.6
                                              : 0.6 +
                                                    packIndex * 0.55 +
                                                    _continuousWaveController
                                                            .value *
                                                        math.pi *
                                                        2 +
                                                    _ribbonController.value *
                                                        1.4 +
                                                    previewProg * 14.0 +
                                                    _swipeProgress * 2.0;
                                          return CustomPaint(
                                            painter: SonicRibbonPainter(
                                              phase: phase,
                                              amplitude: previewing
                                                  ? 0.86
                                                  : 0.68,
                                              pulseBoost: previewing
                                                  ? 0.35
                                                  : 0.0,
                                              strokeWidth: 2.6,
                                              fillGradientArea: true,
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    // Top Telemetry Pill ("100 Hz IMU")
                                    Positioned(
                                      top: isCompact ? 6 : 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: StradioColors.surfaceCard
                                              .withValues(alpha: 0.92),
                                          borderRadius: BorderRadius.circular(
                                            StradioRadii.full,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.85,
                                            ),
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
                                              '100 Hz IMU',
                                              style: StradioTypography.microCap(
                                                color:
                                                    StradioColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Sole LiquidGlassLens on Surface 1: Unified Timbre Glass Capsule + Preview Bar + Expandable 6-Pack Deck
                              LiquidGlassLens(
                                key: const Key('pre_run_sound_pack_tray'),
                                shape: LiquidGlassShape.rounded,
                                borderRadius: 28,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
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
                                            // Left: Tap to expand/collapse 6 sound pack list
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
                                                        width: 36,
                                                        height: 36,
                                                        decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: StradioColors
                                                              .glowCoralSoft,
                                                        ),
                                                        child: const Icon(
                                                          Icons
                                                              .graphic_eq_rounded,
                                                          size: 18,
                                                          color: StradioColors
                                                              .textAccentDeep,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
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
                                                            Text(
                                                              '${activePack.categoryLabel} · ${_modeSummary(activePack, s)}',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  StradioTypography.metricLabel(),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),

                                            // Right: Audition / Preview Pill Button + Disclosure Chevron
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
                                                          minHeight: 38,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 7,
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
                                                          size: 16,
                                                          color: StradioColors
                                                              .textOnDark,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          isPreviewing
                                                              ? s.stopPreviewAction
                                                              : s.previewAudioAction,
                                                          style:
                                                              StradioTypography.microCap(
                                                                color: StradioColors
                                                                    .textOnDark,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              key: const Key(
                                                'pre_run_expand_packs_chevron',
                                              ),
                                              onPressed: () {
                                                HapticFeedback.selectionClick();
                                                setState(
                                                  () => _isPackDeckExpanded =
                                                      !_isPackDeckExpanded,
                                                );
                                              },
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: Icon(
                                                _isPackDeckExpanded
                                                    ? Icons.expand_less_rounded
                                                    : Icons.expand_more_rounded,
                                                size: 20,
                                                color:
                                                    StradioColors.textSecondary,
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
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                s.soundPacksHeading,
                                                style:
                                                    StradioTypography.microCap(),
                                              ),
                                              Text(
                                                activePack.categoryLabel,
                                                style:
                                                    StradioTypography.metricLabel(),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          for (final pack
                                              in StradioSoundPack.catalog) ...[
                                            _MinimalSoundPackRow(
                                              pack: pack,
                                              subtitle: _modeSummary(pack, s),
                                              selected:
                                                  pack.id == _selectedPackId,
                                              onTap: () => _selectPack(pack.id),
                                            ),
                                            const SizedBox(height: 6),
                                          ],
                                        ],
                                      ],
                                    );
                                  },
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
          ),
        ),
      ),
    );
  }
}

/// Delicate concentric telemetry rings and cardinal ticks behind the open Pre-Run waveform (Mockup #07).
class _OpenTelemetryRadarPainter extends CustomPainter {
  const _OpenTelemetryRadarPainter({required this.compact});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    final outerR = (compact ? size.height * 0.44 : size.height * 0.45).clamp(
      52.0,
      98.0,
    );
    final midR = outerR * 0.72;
    final innerR = outerR * 0.42;

    // Soft ambient radial glow behind center
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          StradioColors.sonicCoral.withValues(alpha: 0.12),
          StradioColors.rhythmViolet.withValues(alpha: 0.08),
          StradioColors.warmIvory.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerR * 1.25));
    canvas.drawCircle(center, outerR * 1.25, glowPaint);

    // Outer hairline ring & crosshairs
    final ringPaint = Paint()
      ..color = StradioColors.borderSubtle.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    canvas.drawCircle(center, outerR, ringPaint);
    canvas.drawCircle(
      center,
      innerR,
      ringPaint..color = Colors.white.withValues(alpha: 0.85),
    );

    // Subtle horizontal & vertical crosshair hairlines
    final crossPaint = Paint()
      ..color = StradioColors.borderSubtle.withValues(alpha: 0.40)
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

    // Dashed middle calibration ring
    const dashCount = 36;
    final dashPaint = Paint()
      ..color = StradioColors.borderSubtle.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final rect = Rect.fromCircle(center: center, radius: midR);
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i * 2 * math.pi) / dashCount;
      canvas.drawArc(rect, startAngle, (math.pi / dashCount) * 0.9, false, dashPaint);
    }

    // Small coral & plum cardinal node dots on the middle ring
    canvas.drawCircle(
      Offset(center.dx, center.dy - midR),
      3.0,
      Paint()..color = StradioColors.sonicCoral,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + midR),
      2.2,
      Paint()..color = StradioColors.twilightPlum.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(covariant _OpenTelemetryRadarPainter oldDelegate) =>
      oldDelegate.compact != compact;
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
