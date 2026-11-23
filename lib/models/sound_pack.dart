/// Identifiers for the 6 curated STRADIO MVP Sound Packs (`docs/PRD-MVP.md` FR-4.1).
enum SoundPackId {
  breakbeatFvnky,
  lariNgacir,
  gbaSandHop,
  squid,
  sponge,
  rubberBouncy,
}

/// How Layer 1 (background loop) behaves for a given [StradioSoundPack].
enum BackgroundLayerMode {
  /// No background loop plays; pure step SFX only.
  silent,

  /// Background loop fades in at >= 130 SPM and fades out after < 120 SPM for 3s.
  joggingZoneOnly,

  /// Two synchronized loops: primary walk stem always audible, secondary jog stem
  /// fades in bar-aligned at >= 130 SPM and fades out after < 120 SPM for 3s.
  dualStemBarAligned,

  /// Single continuous loop from session start with dynamic playback rate scaling.
  continuousTempoScaled,
}

/// How Layer 2 (step SFX) selects samples and pitch per footstrike.
enum StepSfxMode {
  /// No step SFX triggered (music-only arrangement, e.g. `LARI_NGACIR`).
  off,

  /// Same single sample on every confirmed step.
  single,

  /// Deterministic odd/even alternation (left/right foot).
  alternating,

  /// Round-robin cycle through all step samples.
  roundRobin,

  /// Single sample with bipedal micro-pitch alternation (1.00 left / 1.03 right).
  microPitchAlternating,
}

/// Immutable specification of one STRADIO Sound Pack.
class StradioSoundPack {
  const StradioSoundPack({
    required this.id,
    required this.code,
    required this.title,
    required this.artist,
    required this.categoryLabel,
    required this.tagline,
    required this.backgroundMode,
    required this.stepSfxMode,
    this.producerCredit,
    this.primaryLoopAsset,
    this.secondaryLoopAsset,
    this.stepSfxAssets = const [],
    this.baseBpm,
    this.minPlaybackRate = 1.0,
    this.maxPlaybackRate = 1.0,
    this.rightStepPitchRate = 1.0,
  });

  final SoundPackId id;
  final String code;
  final String title;
  final String artist;

  /// Unified functional category badge shown across the UI (`Runner Groove`, `16-Bit Nostalgia`, `Meme Pack`).
  final String categoryLabel;

  /// Optional producer attribution shown as a subtitle credit (`by DDHANNi`).
  final String? producerCredit;

  final String tagline;
  final BackgroundLayerMode backgroundMode;
  final StepSfxMode stepSfxMode;

  /// Full Flutter asset path (`assets/audio/...`) for primary Layer 1 loop.
  final String? primaryLoopAsset;

  /// Full Flutter asset path (`assets/audio/...`) for synchronized jog stem (`LARI_NGACIR`).
  final String? secondaryLoopAsset;

  /// Full Flutter asset paths (`assets/audio/...`) preloaded into `Soundpool`.
  final List<String> stepSfxAssets;

  /// Reference BPM for bar-alignment (`LARI_NGACIR`: 140) or rate scaling (`GBA_SAND_HOP`: 132.5).
  final double? baseBpm;
  final double minPlaybackRate;
  final double maxPlaybackRate;

  /// Playback rate used on even (right-foot) steps when [stepSfxMode] is
  /// [StepSfxMode.microPitchAlternating].
  final double rightStepPitchRate;

  /// Duration of one 4/4 musical bar in milliseconds when [baseBpm] is set.
  int? get barDurationMs {
    final bpm = baseBpm;
    if (bpm == null || bpm <= 0) return null;
    return ((4.0 * 60000.0) / bpm).round();
  }

  /// Computes clamped dynamic playback rate for [BackgroundLayerMode.continuousTempoScaled].
  double computePlaybackRate(double cadenceSpm) {
    if (backgroundMode != BackgroundLayerMode.continuousTempoScaled) {
      return 1.0;
    }
    final bpm = baseBpm;
    if (bpm == null || bpm <= 0 || cadenceSpm <= 0) return 1.0;
    return (cadenceSpm / bpm).clamp(minPlaybackRate, maxPlaybackRate);
  }

  /// Estimates target step cadence (SPM) from a target running or walking pace
  /// (`210..900` sec/km, i.e. `3:30..15:00 /km`).
  static double estimateCadenceFromPace(int paceSecondsPerKm) {
    final clamped = paceSecondsPerKm.clamp(210, 900);
    if (clamped <= 600) {
      final t = (600 - clamped) / 390.0;
      return 132.0 + t * 54.0;
    }
    final walkT = (clamped - 600) / 300.0;
    return 132.0 - walkT * 28.0;
  }

  /// Formats pace seconds per kilometer as `m:ss`.
  static String formatPace(int secondsPerKm) {
    final clamped = secondsPerKm.clamp(180, 900);
    final mins = clamped ~/ 60;
    final secs = (clamped % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  /// Computes deterministic match percentage (`65.0..99.6`) between this pack's
  /// tempo/layering profile and the runner's calibrated [targetPaceSecondsPerKm].
  double computeSyncIntegrity({required int targetPaceSecondsPerKm}) {
    final cadence = estimateCadenceFromPace(targetPaceSecondsPerKm);
    final rawScore = switch (backgroundMode) {
      BackgroundLayerMode.continuousTempoScaled => () {
        final refBpm = baseBpm ?? 132.5;
        final minBand = refBpm * minPlaybackRate;
        final maxBand = refBpm * maxPlaybackRate;
        if (cadence >= minBand && cadence <= maxBand) {
          return 99.4 - (cadence - refBpm).abs() * 0.08;
        }
        final excess = cadence < minBand ? minBand - cadence : cadence - maxBand;
        return 97.0 - excess * 0.65;
      }(),
      BackgroundLayerMode.dualStemBarAligned => () {
        final sweetSpot = (baseBpm ?? 140.0) + 14.0;
        return 99.2 - (cadence - sweetSpot).abs() * 0.14;
      }(),
      BackgroundLayerMode.joggingZoneOnly =>
        cadence < 130.0
            ? 88.0 - (130.0 - cadence) * 0.60
            : 99.4 - (cadence - 158.0).abs() * 0.18,
      BackgroundLayerMode.silent => 98.6 - (cadence - 152.0).abs() * 0.06,
    };
    return rawScore.clamp(65.0, 99.6);
  }

  /// Finds the 5-second pace increment (`210..900` s/km) yielding highest sync integrity.
  int get optimalPaceSecondsPerKm {
    var bestPace = 360;
    var bestScore = -1.0;
    for (var pace = 210; pace <= 900; pace += 5) {
      final score = computeSyncIntegrity(targetPaceSecondsPerKm: pace);
      if (score > bestScore) {
        bestScore = score;
        bestPace = pace;
      }
    }
    return bestPace;
  }

  /// All 6 curated MVP sound packs defined in `docs/PRD-MVP.md` FR-4.1.
  static const List<StradioSoundPack> catalog = [
    StradioSoundPack(
      id: SoundPackId.breakbeatFvnky,
      code: 'BREAKBEAT_FVNKY',
      title: 'Breakbeat Fvnky',
      artist: 'DDHANNi',
      categoryLabel: 'Runner Groove',
      producerCredit: 'by DDHANNi',
      tagline: 'Step kick drum + jog-activated Indonesian breakbeat loop',
      backgroundMode: BackgroundLayerMode.joggingZoneOnly,
      stepSfxMode: StepSfxMode.single,
      primaryLoopAsset: 'assets/audio/breakbeat_fvnky/Full_Fade_NoKick_BG.mp3',
      stepSfxAssets: ['assets/audio/breakbeat_fvnky/drums_1_step.mp3'],
    ),
    StradioSoundPack(
      id: SoundPackId.lariNgacir,
      code: 'LARI_NGACIR',
      title: 'Lari Ngacir',
      artist: 'DDHANNi',
      categoryLabel: 'Runner Groove',
      producerCredit: 'by DDHANNi',
      tagline: 'Dual-stem 140 BPM progression, bar-aligned jog drums',
      backgroundMode: BackgroundLayerMode.dualStemBarAligned,
      stepSfxMode: StepSfxMode.off,
      primaryLoopAsset: 'assets/audio/lari_ngacir/lari_ngacir_layer1_walk.mp3',
      secondaryLoopAsset: 'assets/audio/lari_ngacir/lari_ngacir_layer2_jog.mp3',
      baseBpm: 140.0,
    ),
    StradioSoundPack(
      id: SoundPackId.gbaSandHop,
      code: 'GBA_SAND_HOP',
      title: 'GBA Sand Hop',
      artist: '16-Bit Nostalgia',
      categoryLabel: '16-Bit Nostalgia',
      tagline: 'Tempo-scaled coastal loop + crunchy sand footsteps',
      backgroundMode: BackgroundLayerMode.continuousTempoScaled,
      stepSfxMode: StepSfxMode.roundRobin,
      primaryLoopAsset: 'assets/audio/gba_sand_hop/hoenn_island_loop.mp4',
      stepSfxAssets: [
        'assets/audio/gba_sand_hop/gba_sand_01.mp3',
        'assets/audio/gba_sand_hop/gba_sand_02.mp3',
        'assets/audio/gba_sand_hop/gba_sand_03.mp3',
      ],
      baseBpm: 132.5,
      minPlaybackRate: 0.90,
      maxPlaybackRate: 1.18,
    ),
    StradioSoundPack(
      id: SoundPackId.squid,
      code: 'SQUID',
      title: 'Squid Stride',
      artist: 'Meme Pack',
      categoryLabel: 'Meme Pack',
      tagline: 'Alternating hollow suction clunks per footstep',
      backgroundMode: BackgroundLayerMode.silent,
      stepSfxMode: StepSfxMode.alternating,
      stepSfxAssets: [
        'assets/audio/squid/squid_1.MP3',
        'assets/audio/squid/squid_2.MP3',
      ],
    ),
    StradioSoundPack(
      id: SoundPackId.sponge,
      code: 'SPONGE',
      title: 'Sponge Stride',
      artist: 'Meme Pack',
      categoryLabel: 'Meme Pack',
      tagline: 'Alternating wet cartoon squelches per footstep',
      backgroundMode: BackgroundLayerMode.silent,
      stepSfxMode: StepSfxMode.alternating,
      stepSfxAssets: [
        'assets/audio/sponge/sponge_1.mp3',
        'assets/audio/sponge/sponge_2.mp3',
      ],
    ),
    StradioSoundPack(
      id: SoundPackId.rubberBouncy,
      code: 'RUBBER_BOUNCY',
      title: 'Rubber Bouncy',
      artist: 'Meme Pack',
      categoryLabel: 'Meme Pack',
      tagline: 'Elastic bounce with 1.00 / 1.03 bipedal micro-pitch',
      backgroundMode: BackgroundLayerMode.silent,
      stepSfxMode: StepSfxMode.microPitchAlternating,
      stepSfxAssets: ['assets/audio/rubber_bouncy/rubber_01.mp3'],
      rightStepPitchRate: 1.03,
    ),
  ];

  static StradioSoundPack byId(SoundPackId id) =>
      catalog.firstWhere((pack) => pack.id == id);

  static StradioSoundPack byCode(String? code) {
    if (code == null) return catalog.first;
    for (final pack in catalog) {
      if (pack.code == code || pack.id.name == code) return pack;
    }
    return catalog.first;
  }
}
