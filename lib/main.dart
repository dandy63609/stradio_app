import 'package:flutter/material.dart';

import 'models/experiment_models.dart';
import 'models/sound_pack.dart';
import 'screens/stradio/pre_run_ignition_screen.dart';
import 'services/audio_engine_service.dart';
import 'services/foreground_notification_service.dart';
import 'services/posthog_service.dart';
import 'services/preferences_service.dart';
import 'services/recording_repository.dart';
import 'services/recording_service.dart';
import 'theme/stradio_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StradioPreferencesService.init();

  final cachedApiKey = StradioPreferencesService.getPostHogApiKey();
  final initialProfile = StradioPreferencesService.loadUserProfile();
  final postHogService = PostHogTelemetryService(
    apiKey: cachedApiKey ?? '',
    enabled: initialProfile.analyticsEnabled,
  );
  final initialPackId = StradioPreferencesService.loadActiveSoundPackId();

  runApp(
    StradioApp(
      postHogService: postHogService,
      initialUserProfile: initialProfile,
      initialSoundPackId: initialPackId,
    ),
  );
}

/// Primary STRADIO application shell ("Stride + Audio: Movement becomes music").
///
/// Launches directly into Surface 1 ([PreRunIgnitionScreen]) with zero onboarding
/// or login friction (`docs/EXPERIENCE.md` & `docs/PRD-MVP.md` FR-5.1), using the
/// fixed Daylight Instrument Minimalism theme (`docs/DESIGN.md`).
class StradioApp extends StatelessWidget {
  const StradioApp({
    super.key,
    this.store,
    this.recordingService,
    this.postHogService,
    this.foregroundNotificationService,
    this.audioEngine,
    this.initialUserProfile,
    this.initialSoundPackId,
    this.showFirstLaunchModal,
  });

  final RecordingStore? store;
  final RecordingService? recordingService;
  final PostHogTelemetryService? postHogService;
  final ForegroundNotificationService? foregroundNotificationService;
  final StradioAudioEngine? audioEngine;
  final StradioUserProfile? initialUserProfile;
  final SoundPackId? initialSoundPackId;
  final bool? showFirstLaunchModal;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stradio',
      debugShowCheckedModeBanner: false,
      theme: StradioTheme.daylightTheme,
      home: PreRunIgnitionScreen(
        store: store,
        recordingService: recordingService,
        postHogService: postHogService,
        foregroundService: foregroundNotificationService,
        audioEngine: audioEngine,
        initialProfile: initialUserProfile,
        initialSoundPackId: initialSoundPackId,
        showFirstLaunchModal: showFirstLaunchModal,
      ),
    );
  }
}
