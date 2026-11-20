import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stradio_app/evaluation/run_metrics_calculator.dart';
import 'package:stradio_app/models/sound_pack.dart';
import 'package:stradio_app/screens/stradio/share_studio_screen.dart';
import 'package:stradio_app/theme/stradio_theme.dart';
import 'package:stradio_app/widgets/share/share_template_models.dart';

// Minimal valid 1x1 coral PNG for photo upload & dominant tint sampling tests.
final Uint8List _sample1x1Png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _sampleMetrics = RunSummaryMetrics(
  totalSteps: 3620,
  activeDurationSeconds: 1458,
  liveCadenceSpm: 156,
  averageCadenceSpm: 156,
  distanceKm: 3.44,
  speedKmh: 8.5,
  targetBpm: 156,
  rhythmScorePercent: 94,
  cadenceBucketsSpm: [118, 124, 148, 154, 156, 160, 158, 155, 162, 156],
);

const _emptyMetrics = RunSummaryMetrics(
  totalSteps: 0,
  activeDurationSeconds: 0,
  liveCadenceSpm: 0,
  averageCadenceSpm: 0,
  distanceKm: 0,
  speedKmh: 0,
  targetBpm: 140,
  rhythmScorePercent: 0,
  cadenceBucketsSpm: [],
);

void main() {
  group('Phase 3B: ShareStudioScreen (6 P2 Templates + Photo Glass)', () {
    testWidgets(
      'Switches across both modes and renders all 6 P2 templates cleanly',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: StradioTheme.daylightTheme,
            home: ShareStudioScreen(
              metrics: _sampleMetrics,
              soundPack: StradioSoundPack.byId(SoundPackId.breakbeatFvnky),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Mode 1: Transparent Sticker (3 templates with promotional STRADIO watermark)
        expect(find.byKey(const Key('sticker_card_aura_wave')), findsOneWidget);
        expect(find.text('STRADIO'), findsOneWidget);
        expect(PhotoBackdropPreset.presets.length, 8);

        await tester.tap(find.byKey(const Key('share_template_sonicDial')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('sticker_card_sonic_dial')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('share_template_minimalStride')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('sticker_card_minimal_stride')),
          findsOneWidget,
        );
        expect(find.text('118-162 spm Lock Zone'), findsOneWidget);

        // Switch to Mode 2: Photo Glass (3 templates)
        await tester.tap(find.byKey(const Key('share_mode_photo_glass_tab')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('photo_glass_orbital_nexus')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('share_template_classicWave')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('photo_glass_classic_wave')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('share_template_topoShard')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('photo_glass_topo_shard')),
          findsOneWidget,
        );
        expect(find.text('TOPO SHARD'), findsOneWidget);
      },
    );

    testWidgets(
      'Displays honest empty metrics (-- and 0.00 km) when session has 0 steps',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: StradioTheme.daylightTheme,
            home: ShareStudioScreen(
              metrics: _emptyMetrics,
              soundPack: StradioSoundPack.byId(SoundPackId.squid),
              initialMode: ShareExportMode.photoGlass,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('--'), findsWidgets);
        expect(find.text('0.00 km'), findsOneWidget);
        expect(find.text('Ready to stride'), findsOneWidget);
      },
    );

    testWidgets(
      'Photo Glass supports Gallery/Camera chooser, custom photo upload, preset switch, and drag-to-reposition + double-tap reset',
      (tester) async {
        ImageSource? requestedSource;

        await tester.pumpWidget(
          MaterialApp(
            theme: StradioTheme.daylightTheme,
            home: ShareStudioScreen(
              metrics: _sampleMetrics,
              soundPack: StradioSoundPack.byId(SoundPackId.lariNgacir),
              initialMode: ShareExportMode.photoGlass,
              onPickPhoto: (source) async {
                requestedSource = source;
                return _sample1x1Png;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap + Add -> verify both Gallery and Camera options appear
        await tester.tap(find.byKey(const Key('backdrop_add_photo_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('photo_source_chooser_sheet')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('photo_source_gallery_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('photo_source_camera_button')),
          findsOneWidget,
        );

        // Pick from Camera
        await tester.tap(find.byKey(const Key('photo_source_camera_button')));
        await tester.pumpAndSettle();
        expect(requestedSource, ImageSource.camera);
        expect(
          find.byKey(const Key('photo_glass_custom_image')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('backdrop_active_photo_thumb')),
          findsOneWidget,
        );

        // Drag card vertically and confirm offset changes & hint updates
        expect(
          find.text('Drag card to reposition over photo'),
          findsOneWidget,
        );
        await tester.drag(
          find.byKey(const Key('photo_glass_drag_handle')),
          const Offset(0, 40),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Double-tap card to reset center'),
          findsOneWidget,
        );

        // Double-tap resets offset back to Offset.zero
        final handleCenter = tester.getCenter(
          find.byKey(const Key('photo_glass_drag_handle')),
        );
        await tester.tapAt(handleCenter);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(handleCenter);
        await tester.pumpAndSettle();
        expect(
          find.text('Drag card to reposition over photo'),
          findsOneWidget,
        );

        // Switching to a preset clears custom photo cleanly
        await tester.tap(find.byKey(const Key('backdrop_option_forest_mist')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('photo_glass_custom_image')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Responsive ShareStudioScreen reflows cleanly at 360x640 and 768x1024 without overflow',
      (tester) async {
        for (final size in const [Size(360, 640), Size(768, 1024)]) {
          await tester.binding.setSurfaceSize(size);
          for (final mode in ShareExportMode.values) {
            await tester.pumpWidget(
              MaterialApp(
                theme: StradioTheme.daylightTheme,
                home: ShareStudioScreen(
                  metrics: _sampleMetrics,
                  soundPack: StradioSoundPack.byId(SoundPackId.gbaSandHop),
                  initialMode: mode,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const Key('share_save_gallery_button')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('share_export_png_button')),
              findsOneWidget,
            );
          }
        }
        addTearDown(() => tester.binding.setSurfaceSize(null));
      },
    );
  });
}
