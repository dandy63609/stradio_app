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

const _shortRunMetrics = RunSummaryMetrics(
  totalSteps: 16,
  activeDurationSeconds: 6,
  liveCadenceSpm: 162,
  averageCadenceSpm: 162,
  distanceKm: 0.01,
  speedKmh: 6.0,
  targetBpm: 160,
  rhythmScorePercent: 91,
  cadenceBucketsSpm: [],
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
  group('Phase 3B: ShareStudioScreen (Full-Screen Glassmorphism + 6 P2 Templates)', () {
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

        // Mode 1: Transparent Sticker shows checkerboard outside capture + 3 sticker cards
        expect(
          find.byKey(const Key('share_transparent_checkerboard')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('sticker_card_aura_wave')), findsOneWidget);
        expect(
          find.byKey(const Key('aura_wave_corner_ribbon_image')),
          findsOneWidget,
        );
        expect(find.text('STRADIO'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Add to Story'), findsOneWidget);
        expect(PhotoBackdropPreset.presets.length, 8);

        await tester.tap(find.byKey(const Key('share_template_sonicDial')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('sticker_card_sonic_dial')),
          findsOneWidget,
        );
        expect(find.text('Cadence Resonance Dial'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('share_template_minimalStride')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('sticker_card_minimal_stride')),
          findsOneWidget,
        );
        expect(find.text('118-162 spm Lock Zone'), findsOneWidget);
        expect(find.text('CADENCE RANGE CONSISTENCY'), findsOneWidget);

        // Switch to Mode 2: Photo Glass (3 templates + Save Photo / Add to Story)
        await tester.tap(find.byKey(const Key('share_mode_photo_glass_tab')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('photo_glass_classic_wave')),
          findsOneWidget,
        );
        expect(find.text('Save Photo'), findsOneWidget);
        expect(find.text('Add to Story'), findsOneWidget);

        await tester.tap(find.byKey(const Key('share_template_orbitalNexus')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('photo_glass_orbital_nexus')),
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
      'Short runs without 10s buckets still render stem bars in Aura Wave & Sonic Dial while 0-step runs stay honest',
      (tester) async {
        // Short run with real steps -> bars render (no empty-state text)
        await tester.pumpWidget(
          MaterialApp(
            theme: StradioTheme.daylightTheme,
            home: ShareStudioScreen(
              metrics: _shortRunMetrics,
              soundPack: StradioSoundPack.byId(SoundPackId.breakbeatFvnky),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('No cadence samples yet'), findsNothing);

        // 0-step run -> honest placeholders
        await tester.pumpWidget(
          MaterialApp(
            theme: StradioTheme.daylightTheme,
            home: ShareStudioScreen(
              key: const Key('empty_photo_glass_studio'),
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
      'Photo Glass supports photo chooser, None transparent mode, custom 2-color picker, drag/pinch & double-tap reset',
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

        // Tap Add -> verify both Gallery and Camera options appear
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
        expect(find.text('Drag to move · Pinch to resize'), findsOneWidget);
        await tester.drag(
          find.byKey(const Key('photo_glass_drag_handle')),
          const Offset(0, 40),
        );
        await tester.pumpAndSettle();
        expect(find.text('Double-tap card to reset center'), findsOneWidget);

        // Two-finger pinch gesture scales cleanly without assertion errors
        final handleCenter = tester.getCenter(
          find.byKey(const Key('photo_glass_drag_handle')),
        );
        final g1 = await tester.startGesture(handleCenter - const Offset(30, 0));
        final g2 = await tester.startGesture(handleCenter + const Offset(30, 0));
        await tester.pump();
        await g1.moveBy(const Offset(-20, 0));
        await g2.moveBy(const Offset(20, 0));
        await tester.pump();
        await g1.up();
        await g2.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Double-tap resets offset & scale back to default
        await tester.tapAt(handleCenter);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(handleCenter);
        await tester.pumpAndSettle();
        expect(find.text('Drag to move · Pinch to resize'), findsOneWidget);

        // Selecting None displays true transparent checkerboard stage
        await tester.tap(find.byKey(const Key('backdrop_option_none')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('share_transparent_checkerboard')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('photo_glass_gradient_backdrop')),
          findsNothing,
        );

        // Custom 2-Color Gradient Picker Sheet
        final customBtn = find.byKey(const Key('backdrop_custom_color_button'));
        await tester.ensureVisible(customBtn);
        await tester.tap(customBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('custom_color_picker_sheet')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('custom_top_color_0')));
        await tester.tap(find.byKey(const Key('custom_bottom_color_4')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('custom_color_apply_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('photo_glass_gradient_backdrop')),
          findsOneWidget,
        );

        // Switching to a curated preset keeps the Photo Glass card vertically synchronized with None
        final noneCenter = tester.getCenter(
          find.byKey(const Key('photo_glass_drag_handle')),
        );
        final forestBtn = find.byKey(const Key('backdrop_option_forest_mist'));
        await tester.ensureVisible(forestBtn);
        await tester.tap(forestBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('photo_glass_custom_image')),
          findsNothing,
        );
        final forestCenter = tester.getCenter(
          find.byKey(const Key('photo_glass_drag_handle')),
        );
        expect((forestCenter.dy - noneCenter.dy).abs(), lessThan(2.0));
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
