import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../evaluation/run_metrics_calculator.dart';
import '../../theme/stradio_theme.dart';

/// Top-level export modes in `ShareStudioScreen` (`docs/DESIGN.md` §8).
enum ShareExportMode { transparentSticker, photoGlass }

/// 3 Transparent Sticker templates (Format A: transparent PNG cutout).
enum StickerTemplateId { auraWave, sonicDial, minimalStride }

/// 3 Photo Glass 9:16 templates (Format B: 1080x1920 vertical canvas + auto-tint).
enum PhotoGlassTemplateId { classicWave, orbitalNexus, topoShard }

extension StickerTemplateLabel on StickerTemplateId {
  String get label => switch (this) {
    StickerTemplateId.auraWave => 'Aura Wave',
    StickerTemplateId.sonicDial => 'Sonic Dial',
    StickerTemplateId.minimalStride => 'Minimal Stride',
  };
}

extension PhotoGlassTemplateLabel on PhotoGlassTemplateId {
  String get label => switch (this) {
    PhotoGlassTemplateId.classicWave => 'Classic Wave',
    PhotoGlassTemplateId.orbitalNexus => 'Orbital Nexus',
    PhotoGlassTemplateId.topoShard => 'Topo Shard',
  };
}

/// Curated procedural ambient backdrops for `Photo Glass` (0 KB raster bloat).
class PhotoBackdropPreset {
  const PhotoBackdropPreset({
    required this.id,
    required this.label,
    required this.gradientColors,
    required this.tintSeed,
    this.isNone = false,
  });

  final String id;
  final String label;
  final List<Color> gradientColors;
  final Color tintSeed;
  final bool isNone;

  static const PhotoBackdropPreset none = PhotoBackdropPreset(
    id: 'none',
    label: 'None',
    gradientColors: [StradioColors.warmIvory, StradioColors.surfaceRecessed],
    tintSeed: StradioColors.surfaceCard,
    isNone: true,
  );

  static const List<PhotoBackdropPreset> presets = [
    PhotoBackdropPreset(
      id: 'morning_trail',
      label: 'Morning',
      gradientColors: [Color(0xFFDFD5C8), Color(0xFFC5B9D6), Color(0xFFE7B6A9)],
      tintSeed: Color(0xFFE7B6A9),
    ),
    PhotoBackdropPreset(
      id: 'forest_mist',
      label: 'Forest',
      gradientColors: [Color(0xFF283A33), Color(0xFF4F6F60), Color(0xFF9EB5A5)],
      tintSeed: Color(0xFF6B8F7C),
    ),
    PhotoBackdropPreset(
      id: 'golden_dusk',
      label: 'Dusk',
      gradientColors: [Color(0xFF2D2B4E), Color(0xFF5D538C), Color(0xFFD98773)],
      tintSeed: Color(0xFF9A7EC0),
    ),
  ];
}

/// Shared honest metric formatting helpers reused across all 6 share templates.
class ShareMetricFormat {
  const ShareMetricFormat._();

  static String avgSpm(RunSummaryMetrics m) =>
      m.averageCadenceSpm > 0 ? '${m.averageCadenceSpm.round()}' : '--';

  static String distanceKm(RunSummaryMetrics m) =>
      '${m.distanceKm.toStringAsFixed(2)} km';

  static String distanceShort(RunSummaryMetrics m) =>
      m.distanceKm.toStringAsFixed(2);

  static String pace(RunSummaryMetrics m) {
    if (m.distanceKm <= 0.01 || m.activeDurationSeconds <= 0) return '--';
    final secPerKm = (m.activeDurationSeconds / m.distanceKm).round();
    final mins = secPerKm ~/ 60;
    final secs = (secPerKm % 60).toString().padLeft(2, '0');
    return '$mins:$secs /km';
  }

  static String paceShort(RunSummaryMetrics m) {
    if (m.distanceKm <= 0.01 || m.activeDurationSeconds <= 0) return '--';
    final secPerKm = (m.activeDurationSeconds / m.distanceKm).round();
    final mins = secPerKm ~/ 60;
    final secs = (secPerKm % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  static (int? minSpm, int? maxSpm) cadenceRange(RunSummaryMetrics m) {
    final valid = m.cadenceBucketsSpm.where((v) => v > 0).toList();
    if (valid.isEmpty) return (null, null);
    return (valid.reduce(math.min).round(), valid.reduce(math.max).round());
  }

  static String resonanceLabel(RunSummaryMetrics m) {
    if (m.averageCadenceSpm <= 0) return 'Ready to stride';
    if (m.averageCadenceSpm >= 130) return 'Stride Resonance Lock';
    return 'Steady Walking Flow';
  }

  /// Normalizes cadence buckets into a fixed bar count (returns empty list when no real steps).
  static List<double> sampleStems(RunSummaryMetrics m, {int count = 20}) {
    final valid = m.cadenceBucketsSpm.where((v) => v > 0).toList();
    if (valid.isEmpty) return const [];
    if (valid.length == count) return valid;
    return [
      for (var i = 0; i < count; i++)
        valid[((i / math.max(1, count - 1)) * (valid.length - 1)).round()],
    ];
  }
}

/// Blends a sampled photo RGB color gently into Warm Ivory card base so `#191923`
/// Midnight and `#4A4658` Slate ink always retain >= 4.5:1 WCAG AA contrast.
Color buildPhotoGlassFill({
  required Color tintSeed,
  required bool highContrast,
  double opacity = 0.84,
}) {
  if (highContrast) return StradioColors.surfaceCard;
  final blended = Color.lerp(StradioColors.surfaceCard, tintSeed, 0.16)!;
  return blended.withValues(alpha: opacity);
}

/// Samples an average RGB color from user-selected photo bytes using Dart's built-in
/// image codec at 24px width (zero extra image decoding package required).
Future<Color> sampleDominantTintColor(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 24);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();
    if (byteData == null || byteData.lengthInBytes < 4) {
      return StradioColors.surfaceCard;
    }

    var rSum = 0;
    var gSum = 0;
    var bSum = 0;
    var pixels = 0;
    final data = byteData.buffer.asUint8List();
    for (var i = 0; i + 3 < data.length; i += 4) {
      if (data[i + 3] < 64) continue;
      rSum += data[i];
      gSum += data[i + 1];
      bSum += data[i + 2];
      pixels++;
    }
    if (pixels == 0) return StradioColors.surfaceCard;
    return Color.fromARGB(
      255,
      (rSum ~/ pixels).clamp(0, 255),
      (gSum ~/ pixels).clamp(0, 255),
      (bSum ~/ pixels).clamp(0, 255),
    );
  } on Object {
    return StradioColors.surfaceCard;
  }
}
