import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../evaluation/run_metrics_calculator.dart';
import '../../l10n/stradio_strings.dart';
import '../../models/sound_pack.dart';
import '../../theme/stradio_theme.dart';
import '../../widgets/share/photo_glass_cards.dart';
import '../../widgets/share/share_template_models.dart';
import '../../widgets/share/transparent_sticker_cards.dart';

/// Injectable photo picker signature for testability (returns raw image bytes or null on cancel).
typedef PhotoBytesPicker = Future<Uint8List?> Function(ImageSource source);

/// Full-Screen Share Studio (`docs/DESIGN.md` §8 & `docs/PRD-MVP.md` FR-5.5).
///
/// Hosts both export modes across all 6 P2 templates:
/// - **Transparent Sticker (3x):** Aura Wave, Sonic Dial, Minimal Stride (transparent PNG cutout).
/// - **Photo Glass (3x):** Classic Wave, Orbital Nexus, Topo Shard (9:16 canvas with
///   Gallery/Camera photo upload, 3 ambient presets, auto-RGB glass tint, and drag-to-reposition).
/// Supports 1-tap `Save to Gallery` (`gal`) and OS share sheet (`share_plus`).
class ShareStudioScreen extends StatefulWidget {
  const ShareStudioScreen({
    super.key,
    required this.metrics,
    required this.soundPack,
    this.initialMode = ShareExportMode.transparentSticker,
    this.language = AppLanguage.en,
    this.onPickPhoto,
    this.onSaveToGallery,
    this.onShareFile,
  });

  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;
  final ShareExportMode initialMode;
  final AppLanguage language;
  final PhotoBytesPicker? onPickPhoto;
  final Future<void> Function(String filePath)? onSaveToGallery;
  final Future<void> Function(String filePath)? onShareFile;

  @override
  State<ShareStudioScreen> createState() => _ShareStudioScreenState();
}

class _ShareStudioScreenState extends State<ShareStudioScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  late ShareExportMode _mode;
  StickerTemplateId _stickerTemplate = StickerTemplateId.auraWave;
  PhotoGlassTemplateId _photoTemplate = PhotoGlassTemplateId.orbitalNexus;
  PhotoBackdropPreset _selectedPreset = PhotoBackdropPreset.presets.first;

  Uint8List? _customPhotoBytes;
  Color _activeTintSeed = PhotoBackdropPreset.presets.first.tintSeed;
  Offset _overlayOffset = Offset.zero;

  bool _busy = false;
  bool _samplingTint = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  Future<void> _showPhotoSourceChooser() async {
    final s = StradioStrings.of(widget.language);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            key: const Key('photo_source_chooser_sheet'),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: StradioColors.surfaceCard,
              borderRadius: BorderRadius.circular(StradioRadii.tray),
              border: Border.all(color: StradioColors.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: StradioColors.borderSubtle,
                      borderRadius: BorderRadius.circular(StradioRadii.full),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  s.addRunPhotoTitle,
                  style: StradioTypography.headingSmall(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  s.addRunPhotoSubtitle,
                  style: StradioTypography.body(fontSize: 13),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    key: const Key('photo_source_gallery_button'),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _pickPhoto(ImageSource.gallery);
                    },
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(s.chooseFromGallery),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('photo_source_camera_button'),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _pickPhoto(ImageSource.camera);
                    },
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(s.takePhotoWithCamera),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      Uint8List? bytes;
      if (widget.onPickPhoto != null) {
        bytes = await widget.onPickPhoto!(source);
      } else {
        final picked = await _picker.pickImage(
          source: source,
          maxWidth: 1440,
          imageQuality: 90,
        );
        if (picked != null) {
          bytes = await picked.readAsBytes();
        }
      }
      if (bytes == null || !mounted) return;

      setState(() {
        _customPhotoBytes = bytes;
        _samplingTint = true;
        _statusMessage = null;
        _statusIsError = false;
      });
      final sampled = await sampleDominantTintColor(bytes);
      if (!mounted) return;
      setState(() {
        _activeTintSeed = sampled;
        _samplingTint = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _samplingTint = false;
        _statusIsError = true;
        _statusMessage =
            'Permission needed for ${source == ImageSource.camera ? "camera" : "gallery"}: ${error.message ?? error.code}';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _samplingTint = false;
        _statusIsError = true;
        _statusMessage = 'Could not load photo: $error';
      });
    }
  }

  void _selectPreset(PhotoBackdropPreset preset) {
    HapticFeedback.selectionClick();
    setState(() {
      _customPhotoBytes = null;
      _selectedPreset = preset;
      _activeTintSeed = preset.tintSeed;
      _statusMessage = null;
      _statusIsError = false;
    });
  }

  Future<File> _renderExportPng() async {
    final boundary =
        _captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Preview canvas is not ready yet.');
    }
    final targetRatio = _mode == ShareExportMode.photoGlass
        ? (1080.0 / boundary.size.width).clamp(2.5, 4.5)
        : 3.0;
    final image = await boundary.toImage(pixelRatio: targetRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Could not encode PNG image.');
    }
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final prefix = _mode == ShareExportMode.photoGlass
        ? 'stradio_story'
        : 'stradio_sticker';
    final file = File('${tempDir.path}/${prefix}_$ts.png');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _handleSaveToGallery() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
      _statusIsError = false;
    });
    try {
      final file = await _renderExportPng();
      if (widget.onSaveToGallery != null) {
        await widget.onSaveToGallery!(file.path);
      } else {
        final hasAccess = await Gal.hasPermission(toAlbum: true);
        if (!hasAccess) {
          final granted = await Gal.requestPermission(toAlbum: true);
          if (!granted) {
            throw StateError('Gallery permission was denied.');
          }
        }
        await Gal.putImage(file.path, album: 'Stradio');
      }
      if (!mounted) return;
      final s = StradioStrings.of(widget.language);
      setState(() {
        _statusMessage = s.savedToGalleryMessage;
        _statusIsError = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Save failed: $error';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _buildShareCaption() {
    final s = StradioStrings.of(widget.language);
    return s.buildShareCaption(
      steps: widget.metrics.totalSteps,
      distanceKm: ShareMetricFormat.distanceKm(widget.metrics),
      duration: widget.metrics.formattedDuration,
      avgSpm: ShareMetricFormat.avgSpm(widget.metrics),
      soundPackTitle: widget.soundPack.title,
    );
  }

  Future<void> _handleShare() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
      _statusIsError = false;
    });
    try {
      final file = await _renderExportPng();
      final caption = _buildShareCaption();
      if (widget.onShareFile != null) {
        await widget.onShareFile!(file.path);
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'image/png')],
            text: caption,
          ),
        );
      }
      if (!mounted) return;
      final s = StradioStrings.of(widget.language);
      setState(() {
        _statusMessage = _mode == ShareExportMode.photoGlass
            ? s.storyReadyMessage
            : s.stickerReadyMessage;
        _statusIsError = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Share failed: $error';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(widget.language);
    final isPhotoGlass = _mode == ShareExportMode.photoGlass;

    return Scaffold(
      key: const Key('share_studio_screen'),
      backgroundColor: StradioColors.warmIvory,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Bar: Back Button + 2-Option Mode Switcher Pill
                  Row(
                    children: [
                      Semantics(
                        button: true,
                        label: 'Back to summary',
                        child: IconButton(
                          key: const Key('share_studio_back_button'),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Back',
                          style: IconButton.styleFrom(
                            backgroundColor: StradioColors.surfaceCard,
                            minimumSize: const Size(48, 48),
                            side: const BorderSide(
                              color: StradioColors.borderSubtle,
                            ),
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: StradioColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: StradioColors.surfaceRecessed,
                            borderRadius: BorderRadius.circular(
                              StradioRadii.full,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ModeTabPill(
                                  key: const Key('share_mode_sticker_tab'),
                                  label: s.transparentStickerTab,
                                  selected: !isPhotoGlass,
                                  onTap: () => setState(() {
                                    _mode = ShareExportMode.transparentSticker;
                                    _statusMessage = null;
                                  }),
                                ),
                              ),
                              Expanded(
                                child: _ModeTabPill(
                                  key: const Key('share_mode_photo_glass_tab'),
                                  label: s.photoGlassTab,
                                  selected: isPhotoGlass,
                                  onTap: () => setState(() {
                                    _mode = ShareExportMode.photoGlass;
                                    _statusMessage = null;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Sub-Navbar: 3 Template Selector Pills for Active Mode (all visible at once)
                  Row(
                    children: [
                      if (!isPhotoGlass)
                        for (var i = 0; i < StickerTemplateId.values.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _TemplateChoicePill(
                              key: Key(
                                'share_template_${StickerTemplateId.values[i].name}',
                              ),
                              label: StickerTemplateId.values[i].label,
                              selected:
                                  _stickerTemplate ==
                                  StickerTemplateId.values[i],
                              onTap: () => setState(() {
                                _stickerTemplate = StickerTemplateId.values[i];
                                _statusMessage = null;
                              }),
                            ),
                          ),
                        ]
                      else
                        for (var i = 0; i < PhotoGlassTemplateId.values.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _TemplateChoicePill(
                              key: Key(
                                'share_template_${PhotoGlassTemplateId.values[i].name}',
                              ),
                              label: PhotoGlassTemplateId.values[i].label,
                              selected:
                                  _photoTemplate ==
                                  PhotoGlassTemplateId.values[i],
                              onTap: () => setState(() {
                                _photoTemplate = PhotoGlassTemplateId.values[i];
                                _statusMessage = null;
                              }),
                            ),
                          ),
                        ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Central Preview Stage
                  Expanded(
                    child: isPhotoGlass
                        ? _buildPhotoGlassStage()
                        : _buildTransparentStickerStage(),
                  ),

                  // Horizontal Photo Backdrop Carousel Strip (Photo Glass only)
                  if (isPhotoGlass) ...[
                    const SizedBox(height: 10),
                    _buildBackdropStrip(),
                  ],

                  // Honest Status / Feedback Strip
                  if (_statusMessage != null || _samplingTint) ...[
                    const SizedBox(height: 8),
                    Text(
                      _samplingTint
                          ? s.samplingPaletteHint
                          : _statusMessage!,
                      key: const Key('share_studio_status_text'),
                      textAlign: TextAlign.center,
                      style: StradioTypography.body(
                        fontSize: 12,
                        color: _statusIsError
                            ? StradioColors.textAccentDeep
                            : StradioColors.textPrimary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Bottom Actions: Save to Gallery + Primary Share CTA
                  Row(
                    children: [
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          key: const Key('share_save_gallery_button'),
                          onPressed: _busy ? null : _handleSaveToGallery,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text(s.saveLabel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            key: const Key('share_export_png_button'),
                            onPressed: _busy ? null : _handleShare,
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: StradioColors.textOnDark,
                                    ),
                                  )
                                : const Icon(Icons.ios_share_rounded, size: 18),
                            label: Text(
                              _busy
                                  ? s.renderingPng
                                  : (isPhotoGlass
                                        ? s.shareStoryAction
                                        : s.shareStickerAction),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransparentStickerStage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StradioColors.surfaceRecessed,
        borderRadius: BorderRadius.circular(StradioRadii.tray),
        border: Border.all(color: StradioColors.borderSubtle),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: RepaintBoundary(
            key: _captureKey,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TransparentStickerCard(
                template: _stickerTemplate,
                metrics: widget.metrics,
                soundPack: widget.soundPack,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGlassStage() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxDx = (constraints.maxWidth * 0.14).clamp(12.0, 48.0);
                  final maxDy = (constraints.maxHeight * 0.22).clamp(
                    24.0,
                    120.0,
                  );

                  return RepaintBoundary(
                    key: _captureKey,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Photo or Procedural Ambient Backdrop
                          if (_customPhotoBytes != null)
                            Image.memory(
                              _customPhotoBytes!,
                              key: const Key('photo_glass_custom_image'),
                              fit: BoxFit.cover,
                            )
                          else
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _selectedPreset.gradientColors,
                                ),
                              ),
                            ),

                          // 4 Corner Viewfinder Markers (`PRD-MVP.md` FR-5.5 Format B)
                          const _ViewfinderCorners(),

                          // Draggable Frosted Glass Overlay Card (double-tap to recenter)
                          Center(
                            child: Transform.translate(
                              key: const Key('photo_glass_draggable_transform'),
                              offset: _overlayOffset,
                              child: GestureDetector(
                                key: const Key('photo_glass_drag_handle'),
                                onPanUpdate: (details) {
                                  setState(() {
                                    _overlayOffset = Offset(
                                      (_overlayOffset.dx + details.delta.dx)
                                          .clamp(-maxDx, maxDx),
                                      (_overlayOffset.dy + details.delta.dy)
                                          .clamp(-maxDy, maxDy),
                                    );
                                  });
                                },
                                onDoubleTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _overlayOffset = Offset.zero);
                                },
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: PhotoGlassOverlayCard(
                                      template: _photoTemplate,
                                      metrics: widget.metrics,
                                      soundPack: widget.soundPack,
                                      tintSeed: _activeTintSeed,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _overlayOffset == Offset.zero
              ? StradioStrings.of(widget.language).dragCardHint
              : StradioStrings.of(widget.language).doubleTapResetHint,
          key: const Key('photo_glass_drag_hint'),
          style: StradioTypography.metricLabel(),
        ),
      ],
    );
  }

  Widget _buildBackdropStrip() {
    final s = StradioStrings.of(widget.language);
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // None (Warm Ivory Daylight)
          _BackdropChip(
            key: const Key('backdrop_option_none'),
            label: s.backdropNone,
            selected: _customPhotoBytes == null && _selectedPreset.isNone,
            colors: PhotoBackdropPreset.none.gradientColors,
            onTap: () => _selectPreset(PhotoBackdropPreset.none),
          ),
          const SizedBox(width: 8),

          // + Add (Gallery / Camera)
          Material(
            color: StradioColors.surfaceCard,
            borderRadius: BorderRadius.circular(StradioRadii.md),
            child: InkWell(
              key: const Key('backdrop_add_photo_button'),
              borderRadius: BorderRadius.circular(StradioRadii.md),
              onTap: _showPhotoSourceChooser,
              child: Container(
                width: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(StradioRadii.md),
                  border: Border.all(color: StradioColors.borderSubtle),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 18,
                      color: StradioColors.textPrimary,
                    ),
                    const SizedBox(height: 2),
                    Text(s.backdropAdd, style: StradioTypography.metricLabel()),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Active Custom Photo Thumbnail with Coral Ring
          if (_customPhotoBytes != null) ...[
            Container(
              key: const Key('backdrop_active_photo_thumb'),
              width: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(StradioRadii.md),
                border: Border.all(
                  color: StradioColors.sonicCoral,
                  width: 2.0,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(_customPhotoBytes!, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
          ],

          // 3 Curated Procedural Ambient Presets
          for (final preset in PhotoBackdropPreset.presets) ...[
            _BackdropChip(
              key: Key('backdrop_option_${preset.id}'),
              label: preset.label,
              selected:
                  _customPhotoBytes == null && _selectedPreset.id == preset.id,
              colors: preset.gradientColors,
              onTap: () => _selectPreset(preset),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ModeTabPill extends StatelessWidget {
  const _ModeTabPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? StradioColors.surfaceCard : Colors.transparent,
      borderRadius: BorderRadius.circular(StradioRadii.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(StradioRadii.full),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: StradioTypography.pillBadge(
                color: selected
                    ? StradioColors.textPrimary
                    : StradioColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateChoicePill extends StatelessWidget {
  const _TemplateChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? StradioColors.midnight : StradioColors.surfaceCard,
      borderRadius: BorderRadius.circular(StradioRadii.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(StradioRadii.full),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StradioRadii.full),
            border: Border.all(
              color: selected
                  ? StradioColors.midnight
                  : StradioColors.borderSubtle,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: StradioTypography.pillBadge(
                color: selected
                    ? StradioColors.textOnDark
                    : StradioColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackdropChip extends StatelessWidget {
  const _BackdropChip({
    super.key,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StradioRadii.md),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(
            color: selected
                ? StradioColors.sonicCoral
                : StradioColors.borderSubtle,
            width: selected ? 2.0 : 1.0,
          ),
        ),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: StradioColors.surfaceCard.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(StradioRadii.full),
          ),
          child: Text(
            label,
            style: StradioTypography.microCap(
              color: StradioColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewfinderCorners extends StatelessWidget {
  const _ViewfinderCorners();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: CustomPaint(painter: _ViewfinderPainter()),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StradioColors.surfaceCard.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const arm = 14.0;
    // Top-left
    canvas.drawLine(Offset.zero, const Offset(arm, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, arm), paint);
    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - arm, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, arm), paint);
    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(arm, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - arm),
      paint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - arm, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
