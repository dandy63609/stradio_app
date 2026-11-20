import 'stradio_strings_en.dart';
import 'stradio_strings_id.dart';

/// Supported application languages for STRADIO (`en` default, `id` Bahasa Indonesia).
enum AppLanguage { en, id }

extension AppLanguageCode on AppLanguage {
  /// Two-letter ISO code (`en` or `id`).
  String get code => name;

  /// Native display label shown in language selectors.
  String get nativeLabel => switch (this) {
    AppLanguage.en => 'English',
    AppLanguage.id => 'Bahasa Indonesia',
  };

  static AppLanguage parse(String? raw) => switch (raw?.trim().toLowerCase()) {
    'id' || 'indonesia' || 'bahasa indonesia' => AppLanguage.id,
    _ => AppLanguage.en,
  };
}

/// Compile-time complete localization contract for STRADIO's Daylight 3-Surface MVP.
///
/// Adding a getter here forces the Dart analyzer to verify both `en` and `id`
/// implementations define it.
abstract class StradioStrings {
  const StradioStrings();

  static const StradioStrings _en = StradioStringsEn();
  static const StradioStrings _id = StradioStringsId();

  factory StradioStrings.of(AppLanguage language) => switch (language) {
    AppLanguage.en => _en,
    AppLanguage.id => _id,
  };

  // --- Common ---
  String get closeLabel;
  String get backLabel;
  String get cancelAction;
  String get saveLabel;
  String get clearAction;

  // --- First-Launch Earphones Modal ---
  String get earphonesBadge;
  String get earphonesTitle;
  String get earphonesBody;
  String get earphonesPrimaryAction;
  String get earphonesLaterAction;

  // --- Surface 1: Pre-Run Ignition ---
  String get soundPacksHeading;
  String get swipeToStart;
  String get previewAudioAction;
  String get stopPreviewAction;
  String motionSensorReadyWithPack(String packTitle);
  String get modeKickJogLoop;
  String get modeDualStem;
  String get modeTempoScaled;
  String get modeStepSfxOnly;

  // --- Surface 2: Active Run Instrument ---
  String get strideTitle;
  String get rhythmTitle;
  String get stepsLabel;
  String get cadenceLabel;
  String get takeStepHint;
  String get holdToEndHint;
  String get activeStrideLabel;
  String get walkingGrooveLabel;
  String get pausedLabel;
  String get calibratingLabel;
  String get standbyLabel;
  String get calibratingSensorMessage;
  String get sensorUnavailableShort;
  String get simulateStrideAction;
  String get soundPackSheetTitle;
  String get soundPackSheetSubtitle;
  String get recoverRunTitle;
  String recoverRunBody(int sampleCount, int durationSeconds);
  String get discardAction;
  String get reviewAndSaveAction;

  // --- Surface 3: Cadence Summary ---
  String get cadenceTitle;
  String get flowTitle;
  String avgSpmLabel(String value);
  String get distanceLabel;
  String get durationLabel;
  String get paceLabel;
  String get activeFilterLabel;
  String get walkingFilterLabel;
  String stepsCountLabel(String formattedSteps);
  String get noStepsRecorded;
  String get strideResonanceLock;
  String get steadyWalkingFlow;
  String get readyToStride;
  String get emptyCadenceChartHint;
  String minSpmLabel(String value);
  String maxSpmLabel(String value);
  String syncPercentLabel(int percent);
  String get exportIgStoryAction;
  String get startNewRunAction;
  String get savingRunAction;

  // --- Share Studio (Phase 3B) ---
  String get transparentStickerTab;
  String get photoGlassTab;
  String get addRunPhotoTitle;
  String get addRunPhotoSubtitle;
  String get chooseFromGallery;
  String get takePhotoWithCamera;
  String get dragCardHint;
  String get doubleTapResetHint;
  String get samplingPaletteHint;
  String get renderingPng;
  String get shareStoryAction;
  String get shareStickerAction;
  String get savedToGalleryMessage;
  String get storyReadyMessage;
  String get stickerReadyMessage;
  String get noCadenceSamplesYet;
  String get cadenceLockTitle;
  String get noLockZoneYet;
  String lockZoneRange(int minSpm, int maxSpm);
  String get backdropNone;
  String get backdropAdd;
  String buildShareCaption({
    required int steps,
    required String distanceKm,
    required String duration,
    required String avgSpm,
    required String soundPackTitle,
  });

  // --- Sensor Calibration Sheet (Mockup 09) ---
  String get sensorCalibrationTitle;
  String get sensorCalibrationSubtitle;
  String get sensorSyncedBadge;
  String get strideSensitivityLabel;
  String get audioSyncLatencyLabel;
  String get cadenceLockWindowLabel;
  String get adaptiveSpatialEqTitle;
  String get adaptiveSpatialEqSubtitle;
  String get applyAndCalibrateAction;
  String get resetAction;
  String get sensorActiveTitle;
  String get sensorActiveBody;
  String get sensorReadyTitle;
  String get sensorReadyBody;
  String get sensorCalibratingTitle;
  String get sensorCalibratingBody;
  String get sensorUnavailableTitle;
  String get sensorUnavailableBody;
  String get samplingRateLabel;
  String get samplesLabel;
  String get droppedLabel;
  String get pocketModeTip;
  String get reconnectSensorAction;

  // --- Daylight Settings Sheet ---
  String get settingsTitle;
  String get analyticsOptInTitle;
  String get analyticsOptInSubtitle;
  String get languageLabel;
  String get heightFieldLabel;
  String get heightErrorRange;
  String get earphoneGuideAction;
  String get clearHistoryAction;
  String get clearHistoryDialogTitle;
  String get clearHistoryDialogBody;
  String get historyClearedMessage;
}
