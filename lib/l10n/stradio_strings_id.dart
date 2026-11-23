import 'stradio_strings.dart';

/// Bahasa Indonesia (`id`) string bundle for STRADIO Daylight 3-Surface MVP.
class StradioStringsId extends StradioStrings {
  const StradioStringsId();

  @override
  String get closeLabel => 'Tutup';

  @override
  String get backLabel => 'Kembali';

  @override
  String get cancelAction => 'Batal';

  @override
  String get saveLabel => 'Simpan';

  @override
  String get clearAction => 'Hapus';

  @override
  String get earphonesBadge => 'Disarankan';

  @override
  String get earphonesTitle => 'Gunakan Earphone untuk Pengalaman Penuh';

  @override
  String get earphonesBody =>
      'Agar pengalaman lari lebih maksimal, gunakan earphone atau headphone supaya soundscape adaptif dan umpan balik langkah terdengar jelas.';

  @override
  String get earphonesPrimaryAction => 'Saya Pakai Earphone';

  @override
  String get earphonesLaterAction => 'Nanti saja';

  @override
  String get soundPacksHeading => 'PAKET SUARA';

  @override
  String get swipeToStart => 'Geser untuk mulai';

  @override
  String get previewAudioAction => 'Pratinjau';

  @override
  String get stopPreviewAction => 'Berhenti';

  @override
  String motionSensorReadyWithPack(String packTitle) =>
      'Sensor gerak siap · $packTitle';

  @override
  String get modeKickJogLoop => 'Kick + loop lari';

  @override
  String get modeDualStem => 'Dual-stem 140 BPM';

  @override
  String get modeTempoScaled => 'Loop ikut tempo';

  @override
  String get modeStepSfxOnly => 'Hanya SFX langkah';

  @override
  String get strideTitle => 'Langkah';

  @override
  String get rhythmTitle => 'Ritme';

  @override
  String get stepsLabel => 'Langkah';

  @override
  String get cadenceLabel => 'Kadensi';

  @override
  String get takeStepHint => 'Mulai melangkah untuk memicu audio';

  @override
  String get holdToEndHint => 'Tahan 1,5 dtk untuk selesai';

  @override
  String get activeStrideLabel => 'Lari Aktif';

  @override
  String get walkingGrooveLabel => 'Ritme Jalan';

  @override
  String get pausedLabel => 'Dijeda';

  @override
  String get calibratingLabel => 'Kalibrasi';

  @override
  String get standbyLabel => 'Siaga';

  @override
  String get calibratingSensorMessage => 'Mengkalibrasi sensor gerak...';

  @override
  String get sensorUnavailableShort => 'Sensor gerak tidak tersedia.';

  @override
  String get simulateStrideAction => 'Simulasi langkah (+1)';

  @override
  String get soundPackSheetTitle => 'Paket Suara';

  @override
  String get soundPackSheetSubtitle =>
      'Ganti langsung tanpa memutus sesi lari';

  @override
  String get recoverRunTitle => 'Pulihkan sesi belum selesai?';

  @override
  String recoverRunBody(int sampleCount, int durationSeconds, {int stepCount = 0}) =>
      sampleCount > 0
          ? 'Ditemukan sesi belum tersimpan dengan $sampleCount sampel sensor ($durationSeconds dtk).'
          : 'Ditemukan sesi belum tersimpan dengan $stepCount langkah ($durationSeconds dtk).';

  @override
  String get discardAction => 'Buang';

  @override
  String get reviewAndSaveAction => 'Tinjau & Simpan';

  @override
  String get cadenceTitle => 'Kadensi';

  @override
  String get flowTitle => 'Aliran';

  @override
  String avgSpmLabel(String value) => 'Rata-rata $value spm';

  @override
  String get distanceLabel => 'Jarak';

  @override
  String get durationLabel => 'Durasi';

  @override
  String get paceLabel => 'Pace';

  @override
  String get activeFilterLabel => 'Lari';

  @override
  String get walkingFilterLabel => 'Jalan';

  @override
  String stepsCountLabel(String formattedSteps) => '$formattedSteps langkah';

  @override
  String get noStepsRecorded => 'Belum ada langkah';

  @override
  String get strideResonanceLock => 'Ritme Langkah Terkunci';

  @override
  String get steadyWalkingFlow => 'Aliran Jalan Stabil';

  @override
  String get readyToStride => 'Siap melangkah';

  @override
  String get emptyCadenceChartHint =>
      'Lakukan beberapa langkah untuk memetakan ritme kadensi.';

  @override
  String minSpmLabel(String value) => 'min. $value spm';

  @override
  String maxSpmLabel(String value) => 'maks. $value spm';

  @override
  String syncPercentLabel(int percent) => '$percent% sinkron';

  @override
  String get exportIgStoryAction => 'Ekspor Story';

  @override
  String get startNewRunAction => 'Mulai lari baru';

  @override
  String get savingRunAction => 'Menyimpan sesi...';

  @override
  String get transparentStickerTab => 'Stiker Transparan';

  @override
  String get photoGlassTab => 'Foto Kaca';

  @override
  String get addRunPhotoTitle => 'Tambah Foto Lari';

  @override
  String get addRunPhotoSubtitle =>
      'Warna kaca otomatis menyesuaikan palet fotomu.';

  @override
  String get chooseFromGallery => 'Pilih dari Galeri';

  @override
  String get takePhotoWithCamera => 'Ambil Foto dengan Kamera';

  @override
  String get dragCardHint => 'Geser kartu untuk mengatur posisi di atas foto';

  @override
  String get doubleTapResetHint => 'Ketuk dua kali kartu untuk reset ke tengah';

  @override
  String get samplingPaletteHint => 'Menyesuaikan palet warna foto...';

  @override
  String get renderingPng => 'Merender PNG...';

  @override
  String get shareStoryAction => 'Bagikan Story 9:16';

  @override
  String get shareStickerAction => 'Bagikan Stiker';

  @override
  String get savedToGalleryMessage => 'Tersimpan di album Stradio di Galeri.';

  @override
  String get storyReadyMessage => 'PNG Story 9:16 siap dibagikan.';

  @override
  String get stickerReadyMessage => 'Stiker PNG transparan siap dibagikan.';

  @override
  String get noCadenceSamplesYet => 'Belum ada sampel kadensi';

  @override
  String get cadenceLockTitle => 'Kunci Kadensi';

  @override
  String get noLockZoneYet => 'Belum ada zona kunci';

  @override
  String lockZoneRange(int minSpm, int maxSpm) =>
      'Zona Kunci $minSpm-$maxSpm spm';

  @override
  String get backdropNone => 'Polos';

  @override
  String get backdropAdd => '+ Tambah';

  @override
  String buildShareCaption({
    required int steps,
    required String distanceKm,
    required String duration,
    required String avgSpm,
    required String soundPackTitle,
  }) =>
      'Lari bareng Stradio: $steps langkah ($distanceKm) dalam $duration · Rata-rata $avgSpm SPM · Musik: $soundPackTitle #Stradio #RunTheVibe';

  @override
  String get sensorCalibrationTitle => 'Kalibrasi Sensor';

  @override
  String get sensorCalibrationSubtitle => 'Parameter Langkah & Mesin Audio';

  @override
  String get sensorSyncedBadge => '100 HZ SINKRON';

  @override
  String get strideSensitivityLabel => 'Sensitivitas Langkah (IMU)';

  @override
  String get audioSyncLatencyLabel => 'Latensi Sinkronisasi Audio';

  @override
  String get cadenceLockWindowLabel => 'Rentang Kunci Kadensi';

  @override
  String get adaptiveSpatialEqTitle => 'EQ Spasial Adaptif';

  @override
  String get adaptiveSpatialEqSubtitle => 'Kedalaman pulsa binaural dinamis';

  @override
  String get applyAndCalibrateAction => 'Terapkan & Kalibrasi';

  @override
  String get resetAction => 'Reset';

  @override
  String get sensorActiveTitle => 'Sensor gerak aktif';

  @override
  String get sensorActiveBody =>
      'Menerima akselerasi 3-sumbu mentah (A1 Adaptive Midpoint + Gravity).';

  @override
  String get sensorReadyTitle => 'Sensor gerak siap';

  @override
  String get sensorReadyBody =>
      'Akselerometer 100 Hz siap. Noise gate menjaga langkah tetap nol saat diam.';

  @override
  String get sensorCalibratingTitle => 'Mengkalibrasi sensor gerak...';

  @override
  String get sensorCalibratingBody =>
      'Menunggu sampel awal akselerometer untuk membentuk titik tengah dinamis.';

  @override
  String get sensorUnavailableTitle => 'Sensor gerak tidak tersedia';

  @override
  String get sensorUnavailableBody =>
      'Stream akselerometer gagal dimulai. Periksa izin gerak atau uji dengan simulasi langkah.';

  @override
  String get samplingRateLabel => 'Laju sampel';

  @override
  String get samplesLabel => 'Sampel';

  @override
  String get droppedLabel => 'Terlewat';

  @override
  String get pocketModeTip =>
      'Tips mode saku: atur optimasi baterai Stradio ke Tanpa Batas (Unrestricted) di pengaturan Android agar audio langkah tetap jalan saat layar terkunci.';

  @override
  String get reconnectSensorAction => 'Sambungkan ulang sensor';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get analyticsOptInTitle => 'Analitik Anonim';

  @override
  String get analyticsOptInSubtitle =>
      'Aktif secara default untuk meningkatkan deteksi langkah. IP klien tidak pernah disimpan.';

  @override
  String get languageLabel => 'Bahasa';

  @override
  String get heightFieldLabel => 'Tinggi badan (cm, opsional)';

  @override
  String get heightErrorRange => 'Masukkan tinggi antara 100 dan 240 cm';

  @override
  String get earphoneGuideAction => 'Panduan Perangkat Audio';

  @override
  String get clearHistoryAction => 'Hapus Riwayat Lari';

  @override
  String get clearHistoryDialogTitle => 'Hapus riwayat lari?';

  @override
  String get clearHistoryDialogBody =>
      'Semua sesi lari lokal yang tersimpan di perangkat ini akan dihapus permanen.';

  @override
  String get historyClearedMessage => 'Riwayat lari dihapus.';

  @override
  String get backdropAddShort => 'Tambah';

  @override
  String get customGradientTitle => 'Latar Gradien Kustom';

  @override
  String get topColorLabel => 'WARNA ATAS';

  @override
  String get bottomColorLabel => 'WARNA BAWAH';

  @override
  String get applyGradientAction => 'Terapkan Gradien';

  @override
  String get dragPinchHint => 'Geser posisi · Cubit ubah ukuran';

  @override
  String get savePhotoLabel => 'Simpan Foto';

  @override
  String get addToStoryAction => 'Tambah ke Story';

  @override
  String get shareRunRhythmTitle => 'Bagikan Ritme Lari';

  @override
  String get quickShareHeading => 'BAGIKAN CEPAT';

  @override
  String get copyTextAction => 'Salin Teks';

  @override
  String get messagesAction => 'Pesan';

  @override
  String get shareRhythmCardAction => 'Bagikan Kartu Ritme';

  @override
  String get storyExport916Action => 'Ekspor Story 9:16';

  @override
  String get captionCopiedMessage => 'Caption disalin ke clipboard';

  @override
  String get messageReadyMessage => 'Teks siap dibagikan';

  @override
  String get paceTargetLabel => 'Target Pace';

  @override
  String get distanceTargetLabel => 'Target Jarak';

  @override
  String get syncIntegrityLabel => 'Sinkronisasi';

  @override
  String get targetCalibrationTitle => 'Kalibrasi Target';

  @override
  String get applyTargetsAction => 'Terapkan Target';

  @override
  String get holdStopCaption => 'TAHAN TOMBOL STOP UNTUK MENGAKHIRI SESI';

  @override
  String lockOptimalPaceLabel(String pace, String syncPct) =>
      'Kunci Pace Optimal ($pace /km · $syncPct%)';
}
