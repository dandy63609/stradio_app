import 'package:flutter_test/flutter_test.dart';
import 'package:stradio_app/models/sound_pack.dart';
import 'package:stradio_app/services/audio_engine_service.dart';

class _FakeLoopBackend implements AudioLoopBackend {
  final List<String> startedAssets = [];
  final List<double> volumes = [];
  final List<double> rates = [];
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  bool disposed = false;

  @override
  Future<void> startLoop(
    String assetPath, {
    double volume = 1.0,
    double playbackRate = 1.0,
  }) async {
    startedAssets.add(assetPath);
    volumes.add(volume);
    rates.add(playbackRate);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    rates.add(rate);
  }

  @override
  Future<void> pause() async => pauseCount++;

  @override
  Future<void> resume() async => resumeCount++;

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> dispose() async => disposed = true;
}

class _FakeSfxPlay {
  const _FakeSfxPlay(this.assetPath, this.rate);
  final String assetPath;
  final double rate;
}

class _FakeSfxBackend implements StepSfxBackend {
  final List<String> preloaded = [];
  final List<_FakeSfxPlay> plays = [];
  bool disposed = false;

  @override
  Future<void> preload(List<String> assetPaths) async {
    preloaded.addAll(assetPaths);
  }

  @override
  Future<void> play(
    String assetPath, {
    double rate = 1.0,
    double volume = 1.0,
  }) async {
    plays.add(_FakeSfxPlay(assetPath, rate));
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  group('StradioSoundPack catalog', () {
    test('ships all 6 curated PRD-MVP sound packs with valid asset paths', () {
      expect(StradioSoundPack.catalog.length, 6);
      expect(
        StradioSoundPack.catalog.map((p) => p.code),
        equals([
          'BREAKBEAT_FVNKY',
          'LARI_NGACIR',
          'GBA_SAND_HOP',
          'SQUID',
          'SPONGE',
          'RUBBER_BOUNCY',
        ]),
      );
    });

    test('GBA_SAND_HOP clamps playback rate to [0.90, 1.18] around 132.5 BPM', () {
      final pack = StradioSoundPack.byId(SoundPackId.gbaSandHop);
      expect(pack.computePlaybackRate(90.0), closeTo(0.90, 1e-6));
      expect(pack.computePlaybackRate(132.5), closeTo(1.00, 1e-6));
      expect(pack.computePlaybackRate(150.0), closeTo(150.0 / 132.5, 1e-6));
      expect(pack.computePlaybackRate(190.0), closeTo(1.18, 1e-6));
    });

    test('assigns unified categoryLabel and producerCredit across all 6 packs', () {
      expect(
        StradioSoundPack.catalog.map((p) => p.categoryLabel),
        equals([
          'Runner Groove',
          'Runner Groove',
          '16-Bit Nostalgia',
          'Meme Pack',
          'Meme Pack',
          'Meme Pack',
        ]),
      );
      expect(
        StradioSoundPack.byId(SoundPackId.breakbeatFvnky).producerCredit,
        'by DDHANNi',
      );
      expect(
        StradioSoundPack.byId(SoundPackId.lariNgacir).producerCredit,
        'by DDHANNi',
      );
    });
  });

  group('StradioAudioEngine Preview', () {
    test('startPreview plays loop + simulated step SFX and updates previewProgressNotifier', () async {
      final primary = _FakeLoopBackend();
      final sfx = _FakeSfxBackend();
      final engine = StradioAudioEngine(
        primaryLoopBackend: primary,
        secondaryLoopBackend: _FakeLoopBackend(),
        sfxBackend: sfx,
        initialPack: SoundPackId.breakbeatFvnky,
      );

      await engine.startPreview(duration: const Duration(milliseconds: 600));
      expect(engine.isPreviewing, isTrue);
      expect(engine.isPreviewingNotifier.value, isTrue);
      expect(
        primary.startedAssets,
        equals(['assets/audio/breakbeat_fvnky/Full_Fade_NoKick_BG.mp3']),
      );
      expect(sfx.plays, isNotEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(engine.previewProgress, greaterThan(0.0));

      await engine.stopPreview();
      expect(engine.isPreviewing, isFalse);
      expect(engine.previewProgress, 0.0);
      await engine.dispose();
    });
  });

  group('StradioAudioEngine', () {
    test(
      'BREAKBEAT_FVNKY: silent BG in walking zone, fades in >= 130 SPM, hysteresis exit after < 120 SPM for 3s',
      () async {
        var nowMs = 10000;
        final primary = _FakeLoopBackend();
        final secondary = _FakeLoopBackend();
        final sfx = _FakeSfxBackend();

        final engine = StradioAudioEngine(
          primaryLoopBackend: primary,
          secondaryLoopBackend: secondary,
          sfxBackend: sfx,
          initialPack: SoundPackId.breakbeatFvnky,
          clockMs: () => nowMs,
          fadeDuration: Duration.zero,
        );

        await engine.startSession();
        expect(
          primary.startedAssets,
          equals(['assets/audio/breakbeat_fvnky/Full_Fade_NoKick_BG.mp3']),
        );
        expect(engine.primaryVolume, 0.0);
        expect(engine.inJoggingZone, isFalse);

        // Walking step (< 130 SPM): triggers kick drum, BG stays silent
        await engine.onStepDetected(cadenceSpm: 110.0);
        expect(sfx.plays.length, 1);
        expect(
          sfx.plays.first.assetPath,
          'assets/audio/breakbeat_fvnky/drums_1_step.mp3',
        );
        expect(engine.inJoggingZone, isFalse);
        expect(engine.primaryVolume, 0.0);

        // Enter Jogging Zone (>= 130 SPM)
        nowMs += 500;
        await engine.onStepDetected(cadenceSpm: 134.0);
        expect(engine.inJoggingZone, isTrue);
        expect(engine.primaryVolume, 1.0);

        // Hysteresis band (125 SPM): must NOT exit jogging zone
        nowMs += 4000;
        engine.updateCadence(125.0);
        expect(engine.inJoggingZone, isTrue);
        expect(engine.primaryVolume, 1.0);

        // Below 120 SPM for 2.5s: still in jogging zone
        engine.updateCadence(115.0);
        nowMs += 2500;
        engine.updateCadence(115.0);
        expect(engine.inJoggingZone, isTrue);

        // Below 120 SPM for >= 3.0s: exits jogging zone and fades out BG
        nowMs += 500;
        engine.updateCadence(115.0);
        expect(engine.inJoggingZone, isFalse);
        expect(engine.primaryVolume, 0.0);

        await engine.dispose();
      },
    );

    test(
      'LARI_NGACIR: starts dual stems in sync, bar-aligned jog stem fade-in, Step SFX off',
      () async {
        var nowMs = 0;
        final primary = _FakeLoopBackend();
        final secondary = _FakeLoopBackend();
        final sfx = _FakeSfxBackend();

        final engine = StradioAudioEngine(
          primaryLoopBackend: primary,
          secondaryLoopBackend: secondary,
          sfxBackend: sfx,
          initialPack: SoundPackId.lariNgacir,
          clockMs: () => nowMs,
          fadeDuration: Duration.zero,
        );

        await engine.startSession();
        expect(
          primary.startedAssets,
          equals(['assets/audio/lari_ngacir/lari_ngacir_layer1_walk.mp3']),
        );
        expect(
          secondary.startedAssets,
          equals(['assets/audio/lari_ngacir/lari_ngacir_layer2_jog.mp3']),
        );
        expect(engine.primaryVolume, 1.0);
        expect(engine.secondaryVolume, 0.0);

        // Trigger at exact bar boundary (1714 ms at 140 BPM) -> immediate fade-in
        nowMs = StradioSoundPack.byId(SoundPackId.lariNgacir).barDurationMs!;
        await engine.onStepDetected(cadenceSpm: 140.0);
        expect(sfx.plays, isEmpty); // Step SFX strictly off
        expect(engine.inJoggingZone, isTrue);
        expect(engine.secondaryVolume, 1.0);

        await engine.dispose();
      },
    );

    test(
      'GBA_SAND_HOP: dynamic playback rate + round-robin sand footsteps (01 -> 02 -> 03 -> 01)',
      () async {
        final primary = _FakeLoopBackend();
        final sfx = _FakeSfxBackend();

        final engine = StradioAudioEngine(
          primaryLoopBackend: primary,
          secondaryLoopBackend: _FakeLoopBackend(),
          sfxBackend: sfx,
          initialPack: SoundPackId.gbaSandHop,
          fadeDuration: Duration.zero,
        );

        await engine.startSession();
        expect(
          primary.startedAssets,
          equals(['assets/audio/gba_sand_hop/hoenn_island_loop.mp4']),
        );

        await engine.onStepDetected(cadenceSpm: 145.75); // 1.10x
        await engine.onStepDetected(cadenceSpm: 145.75);
        await engine.onStepDetected(cadenceSpm: 180.0); // clamped 1.18x
        await engine.onStepDetected(cadenceSpm: 100.0); // clamped 0.90x

        expect(
          sfx.plays.map((p) => p.assetPath),
          equals([
            'assets/audio/gba_sand_hop/gba_sand_01.mp3',
            'assets/audio/gba_sand_hop/gba_sand_02.mp3',
            'assets/audio/gba_sand_hop/gba_sand_03.mp3',
            'assets/audio/gba_sand_hop/gba_sand_01.mp3',
          ]),
        );
        expect(engine.currentPlaybackRate, closeTo(0.90, 1e-6));

        await engine.dispose();
      },
    );

    test(
      'SQUID, SPONGE, and RUBBER_BOUNCY: silent Layer 1 + alternating L/R & 1.00/1.03 micro-pitch',
      () async {
        final primary = _FakeLoopBackend();
        final sfx = _FakeSfxBackend();

        final engine = StradioAudioEngine(
          primaryLoopBackend: primary,
          secondaryLoopBackend: _FakeLoopBackend(),
          sfxBackend: sfx,
          initialPack: SoundPackId.squid,
          fadeDuration: Duration.zero,
        );

        await engine.startSession();
        expect(primary.startedAssets, isEmpty);

        await engine.onStepDetected(cadenceSpm: 140.0); // odd -> squid_1
        await engine.onStepDetected(cadenceSpm: 140.0); // even -> squid_2
        expect(
          sfx.plays.map((p) => p.assetPath),
          equals([
            'assets/audio/squid/squid_1.MP3',
            'assets/audio/squid/squid_2.MP3',
          ]),
        );

        // Zero-interruption switch to SPONGE mid-run
        sfx.plays.clear();
        await engine.switchPack(SoundPackId.sponge);
        expect(engine.isSessionActive, isTrue);
        await engine.onStepDetected(cadenceSpm: 140.0); // step 3 (odd) -> sponge_1
        await engine.onStepDetected(cadenceSpm: 140.0); // step 4 (even) -> sponge_2
        expect(
          sfx.plays.map((p) => p.assetPath),
          equals([
            'assets/audio/sponge/sponge_1.mp3',
            'assets/audio/sponge/sponge_2.mp3',
          ]),
        );

        // Zero-interruption switch to RUBBER_BOUNCY mid-run
        sfx.plays.clear();
        await engine.switchPack(SoundPackId.rubberBouncy);
        await engine.onStepDetected(cadenceSpm: 140.0); // step 5 (odd) -> 1.00
        await engine.onStepDetected(cadenceSpm: 140.0); // step 6 (even) -> 1.03
        expect(sfx.plays[0].assetPath, 'assets/audio/rubber_bouncy/rubber_01.mp3');
        expect(sfx.plays[0].rate, closeTo(1.00, 1e-6));
        expect(sfx.plays[1].rate, closeTo(1.03, 1e-6));

        // Pause suppresses step SFX and pauses loops; Stop ends session cleanly
        sfx.plays.clear();
        await engine.pauseSession();
        await engine.onStepDetected(cadenceSpm: 150.0);
        expect(sfx.plays, isEmpty);
        expect(primary.pauseCount, 1);

        await engine.resumeSession();
        expect(primary.resumeCount, 1);

        await engine.stopSession();
        expect(engine.isSessionActive, isFalse);

        await engine.dispose();
      },
    );
  });
}
