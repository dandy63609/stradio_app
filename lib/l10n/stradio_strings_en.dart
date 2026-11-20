import 'stradio_strings.dart';

/// English (`en`) string bundle for STRADIO Daylight 3-Surface MVP.
class StradioStringsEn extends StradioStrings {
  const StradioStringsEn();

  @override
  String get closeLabel => 'Close';

  @override
  String get backLabel => 'Back';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get saveLabel => 'Save';

  @override
  String get clearAction => 'Clear';

  @override
  String get earphonesBadge => 'Recommended';

  @override
  String get earphonesTitle => 'Use Earphones for Full Immersion';

  @override
  String get earphonesBody =>
      'For a better experience, please use your earphones or headphones so you can clearly hear adaptive tempo soundscapes and stride feedback.';

  @override
  String get earphonesPrimaryAction => "I'm Wearing Earphones";

  @override
  String get earphonesLaterAction => 'Maybe later';

  @override
  String get soundPacksHeading => 'SOUND PACKS';

  @override
  String get swipeToStart => 'Swipe to start';

  @override
  String get previewAudioAction => 'Preview';

  @override
  String get stopPreviewAction => 'Stop';

  @override
  String motionSensorReadyWithPack(String packTitle) =>
      'Motion sensor ready · $packTitle';

  @override
  String get modeKickJogLoop => 'Kick + jog loop';

  @override
  String get modeDualStem => 'Dual-stem 140 BPM';

  @override
  String get modeTempoScaled => 'Tempo-scaled loop';

  @override
  String get modeStepSfxOnly => 'Step SFX only';

  @override
  String get strideTitle => 'Stride';

  @override
  String get rhythmTitle => 'Rhythm';

  @override
  String get stepsLabel => 'Steps';

  @override
  String get cadenceLabel => 'Cadence';

  @override
  String get takeStepHint => 'Take a step to trigger audio';

  @override
  String get holdToEndHint => 'Hold 1.5s to end';

  @override
  String get activeStrideLabel => 'Active Stride';

  @override
  String get walkingGrooveLabel => 'Walking groove';

  @override
  String get pausedLabel => 'Paused';

  @override
  String get calibratingLabel => 'Calibrating';

  @override
  String get standbyLabel => 'Standby';

  @override
  String get calibratingSensorMessage => 'Calibrating motion sensor...';

  @override
  String get sensorUnavailableShort => 'Motion sensor unavailable.';

  @override
  String get simulateStrideAction => 'Simulate stride (+1)';

  @override
  String get soundPackSheetTitle => 'Sound Pack';

  @override
  String get soundPackSheetSubtitle =>
      'Switch live without interrupting your run';

  @override
  String get recoverRunTitle => 'Recover unfinished run?';

  @override
  String recoverRunBody(int sampleCount, int durationSeconds) =>
      'Found an unsaved session with $sampleCount sensor samples (${durationSeconds}s).';

  @override
  String get discardAction => 'Discard';

  @override
  String get reviewAndSaveAction => 'Review & Save';

  @override
  String get cadenceTitle => 'Cadence';

  @override
  String get flowTitle => 'Flow';

  @override
  String avgSpmLabel(String value) => 'Avg. $value spm';

  @override
  String get distanceLabel => 'Distance';

  @override
  String get durationLabel => 'Duration';

  @override
  String get paceLabel => 'Pace';

  @override
  String get activeFilterLabel => 'Active';

  @override
  String get walkingFilterLabel => 'Walking';

  @override
  String stepsCountLabel(String formattedSteps) => '$formattedSteps steps';

  @override
  String get noStepsRecorded => 'No steps recorded';

  @override
  String get strideResonanceLock => 'Stride Resonance Lock';

  @override
  String get steadyWalkingFlow => 'Steady Walking Flow';

  @override
  String get readyToStride => 'Ready to stride';

  @override
  String get emptyCadenceChartHint =>
      'Complete a few steps to chart cadence rhythm.';

  @override
  String minSpmLabel(String value) => 'min. $value spm';

  @override
  String maxSpmLabel(String value) => 'max. $value spm';

  @override
  String syncPercentLabel(int percent) => '$percent% sync';

  @override
  String get exportIgStoryAction => 'Export Story';

  @override
  String get startNewRunAction => 'Start new run';

  @override
  String get savingRunAction => 'Saving run...';

  @override
  String get transparentStickerTab => 'Transparent Sticker';

  @override
  String get photoGlassTab => 'Photo Glass';

  @override
  String get addRunPhotoTitle => 'Add Run Photo';

  @override
  String get addRunPhotoSubtitle =>
      'Glass tint adapts automatically to your photo palette.';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get takePhotoWithCamera => 'Take Photo with Camera';

  @override
  String get dragCardHint => 'Drag card to reposition over photo';

  @override
  String get doubleTapResetHint => 'Double-tap card to reset center';

  @override
  String get samplingPaletteHint => 'Sampling photo palette...';

  @override
  String get renderingPng => 'Rendering PNG...';

  @override
  String get shareStoryAction => 'Share 9:16 Story';

  @override
  String get shareStickerAction => 'Share Sticker';

  @override
  String get savedToGalleryMessage => 'Saved to Stradio album in Gallery.';

  @override
  String get storyReadyMessage => '9:16 Story PNG ready to share.';

  @override
  String get stickerReadyMessage => 'Transparent sticker PNG ready to share.';

  @override
  String get noCadenceSamplesYet => 'No cadence samples yet';

  @override
  String get cadenceLockTitle => 'Cadence Lock';

  @override
  String get noLockZoneYet => 'No lock zone yet';

  @override
  String lockZoneRange(int minSpm, int maxSpm) =>
      '$minSpm-$maxSpm spm Lock Zone';

  @override
  String get backdropNone => 'None';

  @override
  String get backdropAdd => '+ Add';

  @override
  String buildShareCaption({
    required int steps,
    required String distanceKm,
    required String duration,
    required String avgSpm,
    required String soundPackTitle,
  }) =>
      'Stradio Run: $steps steps ($distanceKm) in $duration · Avg $avgSpm SPM · Vibe: $soundPackTitle #Stradio #RunTheVibe';

  @override
  String get sensorCalibrationTitle => 'Sensor Calibration';

  @override
  String get sensorCalibrationSubtitle => 'Stride & Audio Engine Parameters';

  @override
  String get sensorSyncedBadge => '100 HZ SYNCED';

  @override
  String get strideSensitivityLabel => 'Stride Sensitivity (IMU)';

  @override
  String get audioSyncLatencyLabel => 'Audio Sync Latency';

  @override
  String get cadenceLockWindowLabel => 'Cadence Lock Window';

  @override
  String get adaptiveSpatialEqTitle => 'Adaptive Spatial EQ';

  @override
  String get adaptiveSpatialEqSubtitle => 'Dynamic binaural pulse depth';

  @override
  String get applyAndCalibrateAction => 'Apply & Calibrate';

  @override
  String get resetAction => 'Reset';

  @override
  String get sensorActiveTitle => 'Motion sensor active';

  @override
  String get sensorActiveBody =>
      'Streaming raw 3-axis acceleration (A1 Adaptive Midpoint + Gravity).';

  @override
  String get sensorReadyTitle => 'Motion sensor ready';

  @override
  String get sensorReadyBody =>
      '100 Hz accelerometer ready. Stationary noise gate keeps idle steps at zero.';

  @override
  String get sensorCalibratingTitle => 'Calibrating motion sensor...';

  @override
  String get sensorCalibratingBody =>
      'Waiting for initial accelerometer samples to establish dynamic midpoint.';

  @override
  String get sensorUnavailableTitle => 'Motion sensor unavailable';

  @override
  String get sensorUnavailableBody =>
      'Accelerometer stream could not start. Check motion permissions or test with simulated steps.';

  @override
  String get samplingRateLabel => 'Sampling rate';

  @override
  String get samplesLabel => 'Samples';

  @override
  String get droppedLabel => 'Dropped';

  @override
  String get pocketModeTip =>
      'Pocket mode tip: keep Stradio battery optimization set to Unrestricted in Android settings so step audio continues with the screen locked.';

  @override
  String get reconnectSensorAction => 'Reconnect motion sensor';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get analyticsOptInTitle => 'Anonymous Telemetry';

  @override
  String get analyticsOptInSubtitle =>
      'Enabled by default to improve step detection. Client IP is never stored.';

  @override
  String get languageLabel => 'Language';

  @override
  String get heightFieldLabel => 'Height (cm, optional)';

  @override
  String get heightErrorRange => 'Enter height between 100 and 240 cm';

  @override
  String get earphoneGuideAction => 'Audio Device Recommendation';

  @override
  String get clearHistoryAction => 'Clear Workout History';

  @override
  String get clearHistoryDialogTitle => 'Clear workout history?';

  @override
  String get clearHistoryDialogBody =>
      'All locally saved run sessions on this device will be permanently removed.';

  @override
  String get historyClearedMessage => 'Workout history cleared.';
}
