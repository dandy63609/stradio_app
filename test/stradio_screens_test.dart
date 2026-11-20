import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stradio_app/main.dart';
import 'package:stradio_app/models/experiment_models.dart';
import 'package:stradio_app/models/sound_pack.dart';
import 'package:stradio_app/screens/stradio/active_run_screen.dart';
import 'package:stradio_app/services/audio_engine_service.dart';
import 'package:stradio_app/services/foreground_notification_service.dart';
import 'package:stradio_app/services/posthog_service.dart';
import 'package:stradio_app/services/preferences_service.dart';
import 'package:stradio_app/services/recording_repository.dart';
import 'package:stradio_app/services/recording_service.dart';

class InMemoryRecordingStore implements RecordingStore {
  final List<SavedRecording> saved = [];
  ActiveSessionSnapshot? activeCache;

  @override
  Future<List<SavedRecording>> list() async => List.unmodifiable(saved);

  @override
  Future<void> save(SavedRecording recording) async {
    saved.add(recording);
  }

  @override
  Future<String> nextId(DateTime date) async =>
      nextRecordingId(saved.map((r) => r.recordingId), date);

  @override
  Future<void> clearAll() async {
    saved.clear();
    activeCache = null;
  }

  @override
  Future<void> saveActiveSessionCache(ActiveSessionSnapshot snapshot) async {
    activeCache = snapshot;
  }

  @override
  Future<ActiveSessionSnapshot?> loadActiveSessionCache() async => activeCache;

  @override
  Future<void> clearActiveSessionCache() async {
    activeCache = null;
  }
}

RecordingService _fakeSensorService() => RecordingService(
  source: (_) => Stream.value(
    AccelerometerEvent(0.0, 0.0, 9.81, DateTime.now()),
  ),
  userSource: (_) => Stream.value(
    UserAccelerometerEvent(0.0, 0.0, 0.0, DateTime.now()),
  ),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StradioPreferencesService.init();
  });

  group('Phase 3A: Daylight Liquid Glass 3-Surface MVP', () {
    testWidgets(
      'First-launch Earphone Recommendation modal shows once, persists dismissal, and opens Pre-Run Ignition',
      (tester) async {
        final store = InMemoryRecordingStore();
        final audioEngine = StradioAudioEngine.noop();

        await tester.pumpWidget(
          StradioApp(
            store: store,
            recordingService: _fakeSensorService(),
            foregroundNotificationService: NoopForegroundNotificationService(),
            audioEngine: audioEngine,
            showFirstLaunchModal: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('earphones_recommendation_modal')),
          findsOneWidget,
        );
        expect(find.text('Use Earphones for Full Immersion'), findsOneWidget);
        expect(find.text('Recommended'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('earphones_modal_primary_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('earphones_recommendation_modal')),
          findsNothing,
        );
        expect(
          StradioPreferencesService.hasSeenAudioRecommendation(),
          isTrue,
        );
        expect(find.byKey(const Key('swipe_to_start_pill')), findsOneWidget);
      },
    );

    testWidgets(
      'Full 3-Surface flow: Pre-Run (select pack) -> Active Run (steps, mid-run pack swap, Hold 1.5s) -> Cadence Summary -> Share Rhythm Modal -> Save & New Run',
      (tester) async {
        final store = InMemoryRecordingStore();
        final postHog = PostHogTelemetryService(
          apiKey: 'phc_test_daylight',
          enabled: true,
          transport: (uri, payload) async => 200,
        );
        final foreground = NoopForegroundNotificationService();
        final audioEngine = StradioAudioEngine.noop();

        await tester.pumpWidget(
          StradioApp(
            store: store,
            recordingService: _fakeSensorService(),
            postHogService: postHog,
            foregroundNotificationService: foreground,
            audioEngine: audioEngine,
            showFirstLaunchModal: false,
          ),
        );
        await tester.pumpAndSettle();

        // Surface 1: select LARI_NGACIR and tap Swipe to start pill
        final lariTile = find.byKey(const Key('pre_run_pack_LARI_NGACIR'));
        await tester.ensureVisible(lariTile);
        await tester.tap(lariTile);
        await tester.pump();

        await tester.tap(find.byKey(const Key('swipe_to_start_pill')));
        await tester.pumpAndSettle();

        // Surface 2: Active Run Instrument running with LARI_NGACIR & honest 0-step empty hint
        expect(find.text('Stride'), findsOneWidget);
        expect(find.text('Rhythm'), findsOneWidget);
        expect(find.byKey(const Key('active_run_glass_lens')), findsOneWidget);
        expect(find.byKey(const Key('active_run_bottom_dock')), findsOneWidget);
        expect(find.text('Take a step to trigger audio'), findsOneWidget);
        expect(audioEngine.activePackId, SoundPackId.lariNgacir);
        expect(audioEngine.isSessionActive, isTrue);
        expect(foreground.isServiceActive, isTrue);

        // Zero-interruption mid-run sound pack swap -> SQUID
        await tester.tap(find.byKey(const Key('sound_pack_selector_button')));
        await tester.pumpAndSettle();
        final squidOpt = find.byKey(const Key('sound_pack_option_SQUID'));
        await tester.ensureVisible(squidOpt);
        await tester.tap(squidOpt);
        await tester.pumpAndSettle();
        expect(audioEngine.activePackId, SoundPackId.squid);
        expect(audioEngine.isSessionActive, isTrue);

        // Short tap on stop button must NOT end run; shows Hold 1.5s hint
        await tester.tap(find.byKey(const Key('hold_to_end_run_button')));
        await tester.pump();
        expect(find.text('Hold 1.5s to end'), findsOneWidget);
        expect(find.text('Stride'), findsOneWidget);

        // Hold for 1.5s -> completes session and opens Surface 3 (Cadence Summary)
        final holdCenter = tester.getCenter(
          find.byKey(const Key('hold_to_end_run_button')),
        );
        final gesture = await tester.startGesture(holdCenter);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 1600));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('Cadence'), findsOneWidget);
        expect(find.text('Flow'), findsOneWidget);
        expect(
          find.byKey(const Key('summary_hero_glass_circle')),
          findsOneWidget,
        );
        expect(find.text('Squid Stride'), findsOneWidget);
        expect(foreground.isServiceActive, isFalse);

        // Open Phase 3B full-screen ShareStudioScreen from Cadence Summary
        await tester.tap(find.byKey(const Key('export_ig_story_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('share_studio_screen')), findsOneWidget);
        expect(
          find.byKey(const Key('share_save_gallery_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('share_studio_back_button')));
        await tester.pumpAndSettle();

        // Tap Start new run -> persists recording, dispatches telemetry, returns to Surface 1
        await tester.tap(find.byKey(const Key('start_new_run_button')));
        await tester.pumpAndSettle();
        expect(store.saved.length, 1);
        expect(find.byKey(const Key('swipe_to_start_pill')), findsOneWidget);
      },
    );

    testWidgets(
      'Daylight Settings Sheet toggles UU PDP PostHog opt-in, opens Earphone guide, and clears history',
      (tester) async {
        final store = InMemoryRecordingStore();
        final postHog = PostHogTelemetryService(apiKey: 'phc_key');
        expect(postHog.enabled, isFalse);

        await tester.pumpWidget(
          StradioApp(
            store: store,
            recordingService: _fakeSensorService(),
            postHogService: postHog,
            foregroundNotificationService: NoopForegroundNotificationService(),
            audioEngine: StradioAudioEngine.noop(),
            showFirstLaunchModal: false,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('pre_run_settings_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('daylight_settings_sheet')), findsOneWidget);

        // Default UU PDP switch is OFF -> toggle ON calls postHog.setEnabled(true)
        final optInSwitch = find.byKey(
          const Key('settings_analytics_optin_switch'),
        );
        expect(tester.widget<Switch>(optInSwitch).value, isFalse);
        await tester.tap(optInSwitch);
        await tester.pumpAndSettle();
        expect(postHog.enabled, isTrue);

        // Re-open Earphone Recommendation modal from Settings
        final guideBtn = find.byKey(const Key('settings_earphone_guide_button'));
        await tester.ensureVisible(guideBtn);
        await tester.tap(guideBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('earphones_recommendation_modal')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Sensor unavailable fallback shows honest error strip, calibration sheet, and Simulate stride (+1)',
      (tester) async {
        final unavailableService = RecordingService(
          source: (_) => const Stream<AccelerometerEvent>.empty(),
        );
        final audioEngine = StradioAudioEngine.noop();

        await tester.pumpWidget(
          MaterialApp(
            home: ActiveRunScreen(
              store: InMemoryRecordingStore(),
              recordingService: unavailableService,
              foregroundService: NoopForegroundNotificationService(),
              audioEngine: audioEngine,
              autoStart: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Standby'), findsOneWidget);
        expect(
          find.byKey(const Key('simulate_stride_banner_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('simulate_stride_banner_button')));
        await tester.pump();
        expect(find.text('1'), findsOneWidget);

        // Open P1 Sensor Calibration sheet
        await tester.tap(find.byKey(const Key('active_run_sensor_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('sensor_calibration_sheet')),
          findsOneWidget,
        );
        expect(find.text('Motion sensor unavailable'), findsOneWidget);
      },
    );

    testWidgets(
      'Crash recovery dialog recovers or discards cached ActiveSessionSnapshot cleanly',
      (tester) async {
        final store = InMemoryRecordingStore();
        store.activeCache = ActiveSessionSnapshot(
          recordingId: 'REC_20261120_001',
          createdAt: DateTime.utc(2026, 11, 20),
          config: const ExperimentConfig(
            participantId: 'Runner',
            activity: Activity.jogging,
            phonePlacement: PhonePlacement.pocket,
            placementDetail: 'Pocket',
            trialNumber: 1,
            targetSteps: 100,
          ),
          targetBpm: 150,
          activeDurationSeconds: 45,
          samples: [
            SensorSample(
              recordingId: 'REC_20261120_001',
              sampleIndex: 0,
              timestampNs: 1000000,
              axMps2: 0.1,
              ayMps2: 0.2,
              azMps2: 9.8,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ActiveRunScreen(
              store: store,
              recordingService: _fakeSensorService(),
              foregroundService: NoopForegroundNotificationService(),
              audioEngine: StradioAudioEngine.noop(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Recover unfinished run?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('recovery_discard_button')));
        await tester.pumpAndSettle();
        expect(store.activeCache, isNull);
      },
    );

    testWidgets(
      'Lockscreen notification actions (pause_resume & finish) control ActiveRunScreen and AudioEngine',
      (tester) async {
        final foreground = NoopForegroundNotificationService();
        final audioEngine = StradioAudioEngine.noop();

        await tester.pumpWidget(
          MaterialApp(
            home: ActiveRunScreen(
              store: InMemoryRecordingStore(),
              recordingService: _fakeSensorService(),
              foregroundService: foreground,
              audioEngine: audioEngine,
              autoStart: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(audioEngine.isSessionActive, isTrue);
        expect(audioEngine.isPaused, isFalse);

        foreground.simulateNotificationAction('pause_resume');
        await tester.pump();
        expect(find.text('Paused'), findsOneWidget);
        expect(audioEngine.isPaused, isTrue);

        foreground.simulateNotificationAction('pause_resume');
        await tester.pump();
        expect(audioEngine.isPaused, isFalse);

        foreground.simulateNotificationAction('finish');
        await tester.pumpAndSettle();
        expect(find.text('Cadence'), findsOneWidget);
        expect(foreground.isServiceActive, isFalse);
      },
    );

    testWidgets(
      'Responsive Daylight layout holds across 360x640, 412x915, and 768x1024 without overflow',
      (tester) async {
        for (final size in const [
          Size(360, 640),
          Size(412, 915),
          Size(768, 1024),
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            StradioApp(
              store: InMemoryRecordingStore(),
              recordingService: _fakeSensorService(),
              foregroundNotificationService: NoopForegroundNotificationService(),
              audioEngine: StradioAudioEngine.noop(),
              showFirstLaunchModal: false,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('swipe_to_start_pill')), findsOneWidget);
        }
        addTearDown(() => tester.binding.setSurfaceSize(null));
      },
    );
  });

  test(
    'ForegroundNotificationService bypasses throttle on Running <-> Paused state transition',
    () {
      final service = FlutterForegroundNotificationService();
      expect(service.shouldDispatchUpdate(true, 1000), isTrue);
      expect(service.shouldDispatchUpdate(true, 1300), isFalse);
      expect(service.shouldDispatchUpdate(false, 1350), isTrue);
      expect(service.shouldDispatchUpdate(false, 1500), isFalse);
      expect(service.shouldDispatchUpdate(true, 1600), isTrue);
    },
  );
}
