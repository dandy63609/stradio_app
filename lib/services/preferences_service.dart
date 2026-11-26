import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/experiment_models.dart';
import '../models/sound_pack.dart';

/// Centralized local persistence service using [SharedPreferences] for user preferences,
/// telemetry credentials, target steps, and activity configs.
class StradioPreferencesService {
  StradioPreferencesService._();

  static const _keyPostHogApiKey = 'stradio_posthog_api_key';
  static const _keyTargetBpm = 'stradio_target_bpm';
  static const _keyTargetSteps = 'stradio_target_steps';
  static const _keyDeveloperOverlay = 'stradio_developer_overlay';
  static const _keyParticipantId = 'stradio_participant_id';
  static const _keyActivity = 'stradio_activity';
  static const _keyPhonePlacement = 'stradio_phone_placement';
  static const _keyPrimaryAlgorithm = 'stradio_primary_algorithm';
  static const _keyDarkMode = 'stradio_dark_mode';
  static const _keyUserProfileJson = 'stradio_user_profile_v1';
  static const _keyHasSeenAudioRecommendation = 'has_seen_audio_recommendation';
  static const _keyActiveSoundPack = 'stradio_active_sound_pack';
  static const _keyStrideSensitivity = 'stradio_stride_sensitivity';
  static const _keyTargetPaceSecondsPerKm = 'stradio_target_pace_sec_per_km';
  static const _keyTargetDistanceKm = 'stradio_target_distance_km';
  static const _keyAdaptiveTempoScaling = 'stradio_adaptive_tempo_scaling';
  static const double defaultStrideSensitivity = 1.68;
  static const int defaultTargetPaceSecondsPerKm = 360; // 6:00 /km
  static const double defaultTargetDistanceKm = 5.0;
  static const bool defaultAdaptiveTempoScaling = true;

  static SharedPreferences? _prefs;

  /// Initializes the underlying shared preferences instance.
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Loads saved settings into a [StradioLabSettings] instance.
  static StradioLabSettings loadLabSettings() {
    final p = _prefs;
    if (p == null) return const StradioLabSettings();

    final activityStr = p.getString(_keyActivity);
    final placementStr = p.getString(_keyPhonePlacement);
    final algorithmStr = p.getString(_keyPrimaryAlgorithm);

    final activity = Activity.values.firstWhere(
      (a) => a.value == activityStr,
      orElse: () => Activity.walking,
    );

    final phonePlacement = PhonePlacement.values.firstWhere(
      (pos) => pos.value == placementStr,
      orElse: () => PhonePlacement.hand,
    );

    final primaryAlgorithm = ThresholdAlgorithm.values.firstWhere(
      (algo) => algo.name == algorithmStr,
      orElse: () => ThresholdAlgorithm.adaptiveMidpoint,
    );

    return StradioLabSettings(
      developerOverlayEnabled: p.getBool(_keyDeveloperOverlay) ?? false,
      participantId: p.getString(_keyParticipantId) ?? 'P01',
      activity: activity,
      phonePlacement: phonePlacement,
      placementDetail: phonePlacement == PhonePlacement.hand ? 'Right hand' : 'Front right pocket',
      primaryAlgorithm: primaryAlgorithm,
      targetSteps: p.getInt(_keyTargetSteps) ?? ExperimentConfig.defaultTargetSteps,
      targetBpm: p.getInt(_keyTargetBpm) ?? 165,
    );
  }

  /// Saves updated [StradioLabSettings] to local storage.
  static Future<void> saveLabSettings(StradioLabSettings settings) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;

    await Future.wait([
      p.setBool(_keyDeveloperOverlay, settings.developerOverlayEnabled),
      p.setString(_keyParticipantId, settings.participantId),
      p.setString(_keyActivity, settings.activity.value),
      p.setString(_keyPhonePlacement, settings.phonePlacement.value),
      p.setString(_keyPrimaryAlgorithm, settings.primaryAlgorithm.name),
      p.setInt(_keyTargetSteps, settings.targetSteps),
      p.setInt(_keyTargetBpm, settings.targetBpm),
    ]);
  }

  /// Retrieves the cached PostHog API Key if present.
  static String? getPostHogApiKey() {
    return _prefs?.getString(_keyPostHogApiKey);
  }

  /// Stores the PostHog API Key locally.
  static Future<void> setPostHogApiKey(String apiKey) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setString(_keyPostHogApiKey, apiKey);
  }

  /// Returns true if Dark Mode (Deep Obsidian) is enabled.
  static bool isDarkMode() {
    return _prefs?.getBool(_keyDarkMode) ?? false;
  }

  /// Persists the selected theme mode preference.
  static Future<void> setDarkMode(bool isDark) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setBool(_keyDarkMode, isDark);
  }

  /// Loads the saved [StradioUserProfile] or returns the default profile.
  static StradioUserProfile loadUserProfile() {
    final raw = _prefs?.getString(_keyUserProfileJson);
    if (raw == null || raw.trim().isEmpty) {
      return const StradioUserProfile();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return StradioUserProfile.fromMap(decoded);
      }
    } on Object {
      // Fallback to clean default if stored JSON is malformed.
    }
    return const StradioUserProfile();
  }

  /// Saves the [StradioUserProfile] to local storage.
  static Future<void> saveUserProfile(StradioUserProfile profile) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setString(_keyUserProfileJson, jsonEncode(profile.toMap()));
  }

  /// Whether the first-launch audio device recommendation modal was dismissed.
  static bool hasSeenAudioRecommendation() {
    return _prefs?.getBool(_keyHasSeenAudioRecommendation) ?? false;
  }

  /// Persists dismissal of the first-launch audio device recommendation modal.
  static Future<void> setHasSeenAudioRecommendation(bool value) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setBool(_keyHasSeenAudioRecommendation, value);
  }

  /// Loads the runner's last selected [SoundPackId], defaulting to `BREAKBEAT_FVNKY`.
  static SoundPackId loadActiveSoundPackId() {
    final code = _prefs?.getString(_keyActiveSoundPack);
    return StradioSoundPack.byCode(code).id;
  }

  /// Persists the active [SoundPackId].
  static Future<void> saveActiveSoundPackId(SoundPackId id) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setString(_keyActiveSoundPack, StradioSoundPack.byId(id).code);
  }

  /// Loads the calibrated IMU stride sensitivity (`0.8..2.4`, default `1.68`).
  static double loadStrideSensitivity() {
    final raw = _prefs?.getDouble(_keyStrideSensitivity);
    if (raw == null || raw.isNaN) return defaultStrideSensitivity;
    return raw.clamp(0.8, 2.4);
  }

  /// Persists the calibrated IMU stride sensitivity (`0.8..2.4`).
  static Future<void> saveStrideSensitivity(double sensitivity) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setDouble(_keyStrideSensitivity, sensitivity.clamp(0.8, 2.4));
  }

  /// Loads calibrated target pace in seconds/km (`210..900`, default `360` = `6:00 /km`).
  static int loadTargetPaceSecondsPerKm() {
    final raw = _prefs?.getInt(_keyTargetPaceSecondsPerKm);
    if (raw == null) return defaultTargetPaceSecondsPerKm;
    return raw.clamp(210, 900);
  }

  /// Persists calibrated target pace in seconds/km (`210..900`).
  static Future<void> saveTargetPaceSecondsPerKm(int secondsPerKm) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setInt(_keyTargetPaceSecondsPerKm, secondsPerKm.clamp(210, 900));
  }

  /// Loads calibrated target distance in km (`1.0..21.1`, default `5.0`).
  static double loadTargetDistanceKm() {
    final raw = _prefs?.getDouble(_keyTargetDistanceKm);
    if (raw == null || raw.isNaN) return defaultTargetDistanceKm;
    return raw.clamp(1.0, 21.1);
  }

  /// Persists calibrated target distance in km (`1.0..21.1`).
  static Future<void> saveTargetDistanceKm(double km) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setDouble(_keyTargetDistanceKm, km.clamp(1.0, 21.1));
  }

  /// Whether dynamic tempo/pitch scaling (`GBA_SAND_HOP`) follows live cadence.
  static bool loadAdaptiveTempoScaling() {
    return _prefs?.getBool(_keyAdaptiveTempoScaling) ??
        defaultAdaptiveTempoScaling;
  }

  /// Persists the `Adaptive Tempo Scaling` toggle from Run & Rhythm Target.
  static Future<void> saveAdaptiveTempoScaling(bool enabled) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setBool(_keyAdaptiveTempoScaling, enabled);
  }
}

