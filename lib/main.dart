import 'dart:async';

import 'package:flutter/material.dart';

import 'models/experiment_models.dart';
import 'screens/stradio/active_run_screen.dart';
import 'screens/stradio/onboarding_screen.dart';
import 'screens/stradio/root_navigation_shell.dart';
import 'services/export_service.dart';
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
  final savedLabSettings = StradioPreferencesService.loadLabSettings();
  final initialDark = StradioPreferencesService.isDarkMode();

  runApp(
    StradioApp(
      postHogService: postHogService,
      initialLabSettings: savedLabSettings,
      initialDarkMode: initialDark,
      enableConsumerShell: true,
      initialUserProfile: initialProfile,
    ),
  );
}

/// Primary STRADIO application shell ("Stride + Audio: Movement becomes music").
///
/// In `v0.2.0` consumer mode ([enableConsumerShell] = `true` or when
/// [initialUserProfile] is provided), launches into [OnboardingScreen] on first
/// run (`hasCompletedOnboarding == false`) and then into [RootNavigationShell]
/// with [HomeScreen]. Preserves direct [ActiveRunScreen] launch when
/// [enableConsumerShell] is `false` for backward-compatible widget test suites.
class StradioApp extends StatefulWidget {
  const StradioApp({
    super.key,
    this.store,
    this.recordingService,
    this.exportService,
    this.postHogService,
    this.foregroundNotificationService,
    this.initialLabSettings = const StradioLabSettings(),
    this.initialDarkMode = false,
    this.enableConsumerShell = false,
    this.initialUserProfile,
  });

  final RecordingStore? store;
  final RecordingService? recordingService;
  final ExportService? exportService;
  final PostHogTelemetryService? postHogService;
  final ForegroundNotificationService? foregroundNotificationService;
  final StradioLabSettings initialLabSettings;
  final bool initialDarkMode;
  final bool enableConsumerShell;
  final StradioUserProfile? initialUserProfile;

  @override
  State<StradioApp> createState() => _StradioAppState();
}

class _StradioAppState extends State<StradioApp> {
  late bool _isDarkMode;
  late StradioUserProfile _userProfile;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
    _userProfile =
        widget.initialUserProfile ??
        StradioPreferencesService.loadUserProfile();
  }

  void _toggleThemeMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    unawaited(StradioPreferencesService.setDarkMode(_isDarkMode));
  }

  @override
  Widget build(BuildContext context) {
    final useConsumerShell =
        widget.enableConsumerShell || widget.initialUserProfile != null;

    Widget homeWidget;
    if (useConsumerShell) {
      if (!_userProfile.hasCompletedOnboarding) {
        homeWidget = OnboardingScreen(
          initialProfile: _userProfile,
          onLanguageChanged: (lang) {
            setState(() {
              _userProfile = _userProfile.copyWith(language: lang);
            });
          },
          onComplete: (completedProfile) {
            widget.postHogService?.setEnabled(
              completedProfile.analyticsEnabled,
            );
            setState(() {
              _userProfile = completedProfile;
            });
          },
        );
      } else {
        homeWidget = RootNavigationShell(
          initialProfile: _userProfile,
          store: widget.store,
          recordingService: widget.recordingService,
          exportService: widget.exportService,
          postHogService: widget.postHogService,
          foregroundService: widget.foregroundNotificationService,
          onToggleThemeMode: _toggleThemeMode,
          onProfileChanged: (updated) {
            setState(() {
              _userProfile = updated;
            });
          },
        );
      }
    } else {
      homeWidget = ActiveRunScreen(
        store: widget.store,
        recordingService: widget.recordingService,
        exportService: widget.exportService,
        postHogService: widget.postHogService,
        foregroundService: widget.foregroundNotificationService,
        initialLabSettings: widget.initialLabSettings,
        onToggleThemeMode: _toggleThemeMode,
      );
    }

    return MaterialApp(
      title: 'Stradio',
      debugShowCheckedModeBanner: false,
      theme: StradioTheme.lightTheme,
      darkTheme: StradioTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: homeWidget,
    );
  }
}
