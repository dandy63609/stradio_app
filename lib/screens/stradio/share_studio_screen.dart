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
/// Renders an edge-to-edge full-screen stage behind floating dark smoked glassmorphism controls:
/// - **Transparent Sticker (3x):** Aura Wave, Sonic Dial, Minimal Stride over checkerboard preview
///   (checkerboard stays outside `RepaintBoundary` so saved/shared PNGs have true alpha transparency).
/// - **Photo Glass (3x):** Classic Wave, Orbital Nexus, Topo Shard over full-bleed photo, procedural
///   gradient, custom 2-color gradient, or true transparent (`None`) stage.
/// Supports both drag-to-reposition and pinch-to-resize on all templates.
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
  PhotoGlassTemplateId _photoTemplate = PhotoGlassTemplateId.classicWave;
  PhotoBackdropPreset _selectedPreset = PhotoBackdropPreset.presets.first;

  Uint8List? _customPhotoBytes;
  List<Color>? _customGradientColors;
  Color _activeTintSeed = PhotoBackdropPreset.presets.first.tintSeed;

  Offset _cardOffset = Offset.zero;
  double _cardScale = 1.0;
  double _scaleStartValue = 1.0;

  bool _busy = false;
  bool _samplingTint = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  bool get _isTransparentExport {
    if (_mode == ShareExportMode.transparentSticker) return true;
    return _customPhotoBytes == null &&
        _customGradientColors == null &&
        _selectedPreset.isNone;
  }

  bool get _hasTransform =>
      _cardOffset != Offset.zero || (_cardScale - 1.0).abs() > 0.01;

  void _resetTransform() {
    HapticFeedback.selectionClick();
    setState(() {
      _cardOffset = Offset.zero;
      _cardScale = 1.0;
    });
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
        _customGradientColors = null;
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
      _customGradientColors = null;
      _selectedPreset = preset;
      _activeTintSeed = preset.tintSeed;
      _statusMessage = null;
      _statusIsError = false;
    });
  }

  Future<void> _openCustomColorSheet() async {
    final s = StradioStrings.of(widget.language);
    var topColor =
        _customGradientColors?.first ?? PhotoBackdropPreset.customPaletteColors[4];
    var bottomColor =
        _customGradientColors?.last ?? PhotoBackdropPreset.customPaletteColors[2];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  key: const Key('custom_color_picker_sheet'),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181824).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
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
                            color: Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(StradioRadii.full),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        s.customGradientTitle,
                        style: StradioTypography.headingSmall(
                          fontSize: 18,
                          color: StradioColors.textOnDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Live Gradient Preview Bar
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [topColor, bottomColor],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        s.topColorLabel,
                        style: StradioTypography.microCap(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SwatchRow(
                        keyPrefix: 'custom_top_color',
                        selected: topColor,
                        ringColor: Colors.white,
                        onSelect: (c) => setSheetState(() => topColor = c),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        s.bottomColorLabel,
                        style: StradioTypography.microCap(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SwatchRow(
                        keyPrefix: 'custom_bottom_color',
                        selected: bottomColor,
                        ringColor: StradioColors.sonicCoral,
                        onSelect: (c) => setSheetState(() => bottomColor = c),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              StradioColors.sonicCoral,
                              StradioColors.rhythmViolet,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(StradioRadii.full),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('custom_color_apply_button'),
                            borderRadius: BorderRadius.circular(StradioRadii.full),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _customPhotoBytes = null;
                                _customGradientColors = [topColor, bottomColor];
                                _activeTintSeed = Color.lerp(
                                  topColor,
                                  bottomColor,
                                  0.5,
                                )!;
                                _statusMessage = null;
                                _statusIsError = false;
                              });
                              Navigator.of(sheetContext).pop();
                            },
                            child: Center(
                              child: Text(
                                s.applyGradientAction,
                                style: StradioTypography.pillBadge(
                                  color: StradioColors.textOnDark,
                                ).copyWith(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<File> _renderExportPng() async {
    final boundary =
        _captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Preview canvas is not ready yet.');
    }
    final targetRatio = _isTransparentExport
        ? 3.0
        : (1080.0 / boundary.size.width).clamp(2.5, 4.5);
    final image = await boundary.toImage(pixelRatio: targetRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Could not encode PNG image.');
    }
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final prefix = _isTransparentExport ? 'stradio_sticker' : 'stradio_story';
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
        _statusMessage = _isTransparentExport
            ? s.stickerReadyMessage
            : s.storyReadyMessage;
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
    final highContrast = MediaQuery.highContrastOf(context);

    return Scaffold(
      key: const Key('share_studio_screen'),
      backgroundColor: const Color(0xFF0E0E14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-Screen Edge-to-Edge Canvas + Capture Layer
          Positioned.fill(
            child: _buildFullScreenCanvas(
              isPhotoGlass: isPhotoGlass,
              highContrast: highContrast,
            ),
          ),

          // 2. Floating Top Glass Chrome (Close, Mode Switcher, Template Pills)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Back to summary',
                          child: _DarkGlassCircleButton(
                            key: const Key('share_studio_back_button'),
                            highContrast: highContrast,
                            icon: Icons.close_rounded,
                            tooltip: 'Close',
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DarkGlassContainer(
                            highContrast: highContrast,
                            borderRadius: BorderRadius.circular(StradioRadii.full),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _GlassModeTab(
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
                                  child: _GlassModeTab(
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
                        const SizedBox(width: 10),
                        _DarkGlassCircleButton(
                          key: const Key('share_studio_reset_transform_button'),
                          highContrast: highContrast,
                          icon: _hasTransform
                              ? Icons.center_focus_strong_rounded
                              : Icons.open_with_rounded,
                          iconColor: _hasTransform
                              ? StradioColors.sonicCoral
                              : Colors.white.withValues(alpha: 0.45),
                          tooltip: 'Reset card position & size',
                          onTap: _hasTransform ? _resetTransform : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Template Selector Glass Bar
                    Center(
                      child: _DarkGlassContainer(
                        highContrast: highContrast,
                        borderRadius: BorderRadius.circular(StradioRadii.full),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isPhotoGlass)
                              for (var i = 0; i < StickerTemplateId.values.length; i++)
                                Flexible(
                                  child: _GlassTemplatePill(
                                    key: Key(
                                      'share_template_${StickerTemplateId.values[i].name}',
                                    ),
                                    label: StickerTemplateId.values[i].label,
                                    selected:
                                        _stickerTemplate ==
                                        StickerTemplateId.values[i],
                                    onTap: () => setState(() {
                                      _stickerTemplate =
                                          StickerTemplateId.values[i];
                                      _statusMessage = null;
                                    }),
                                  ),
                                )
                            else
                              for (var i = 0; i < PhotoGlassTemplateId.values.length; i++)
                                Flexible(
                                  child: _GlassTemplatePill(
                                    key: Key(
                                      'share_template_${PhotoGlassTemplateId.values[i].name}',
                                    ),
                                    label: PhotoGlassTemplateId.values[i].label,
                                    selected:
                                        _photoTemplate ==
                                        PhotoGlassTemplateId.values[i],
                                    onTap: () => setState(() {
                                      _photoTemplate =
                                          PhotoGlassTemplateId.values[i];
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
              ),
            ),
          ),

          // 3. Floating Bottom Glass Dock (Hint, Status, Backdrop Strip, Save / Add to Story)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_statusMessage != null || _samplingTint) ...[
                      Center(
                        child: _DarkGlassContainer(
                          highContrast: highContrast,
                          borderRadius: BorderRadius.circular(StradioRadii.full),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: Text(
                            _samplingTint
                                ? s.samplingPaletteHint
                                : _statusMessage!,
                            key: const Key('share_studio_status_text'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: StradioTypography.body(
                              fontSize: 12,
                              color: _statusIsError
                                  ? StradioColors.sonicCoral
                                  : StradioColors.textOnDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.34),
                          borderRadius: BorderRadius.circular(StradioRadii.full),
                        ),
                        child: Text(
                          _hasTransform
                              ? s.doubleTapResetHint
                              : s.dragPinchHint,
                          key: const Key('photo_glass_drag_hint'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StradioTypography.metricLabel(
                            color: Colors.white.withValues(alpha: 0.85),
                          ).copyWith(fontSize: 11),
                        ),
                      ),
                    ),
                    if (isPhotoGlass) ...[
                      const SizedBox(height: 10),
                      _buildBackdropStrip(highContrast: highContrast),
                    ],
                    const SizedBox(height: 12),
                    _buildBottomActionRow(
                      s: s,
                      isPhotoGlass: isPhotoGlass,
                      highContrast: highContrast,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenCanvas({
    required bool isPhotoGlass,
    required bool highContrast,
  }) {
    final activeCard = FittedBox(
      fit: BoxFit.scaleDown,
      child: isPhotoGlass
          ? PhotoGlassOverlayCard(
              template: _photoTemplate,
              metrics: widget.metrics,
              soundPack: widget.soundPack,
              tintSeed: _activeTintSeed,
            )
          : TransparentStickerCard(
              template: _stickerTemplate,
              metrics: widget.metrics,
              soundPack: widget.soundPack,
            ),
    );

    final draggableScalableCard = GestureDetector(
      key: const Key('photo_glass_drag_handle'),
      behavior: HitTestBehavior.opaque,
      onScaleStart: (_) => _scaleStartValue = _cardScale,
      onScaleUpdate: (details) {
        setState(() {
          _cardOffset = Offset(
            (_cardOffset.dx + details.focalPointDelta.dx).clamp(-120.0, 120.0),
            (_cardOffset.dy + details.focalPointDelta.dy).clamp(-160.0, 160.0),
          );
          if (details.scale != 1.0) {
            _cardScale = (_scaleStartValue * details.scale).clamp(0.65, 1.45);
          }
        });
      },
      onDoubleTap: _resetTransform,
      child: Transform.translate(
        key: const Key('photo_glass_draggable_transform'),
        offset: _cardOffset,
        child: Transform.scale(
          scale: _cardScale,
          child: _isTransparentExport
              ? RepaintBoundary(
                  key: _captureKey,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: activeCard,
                  ),
                )
              : activeCard,
        ),
      ),
    );

    // Case A: Transparent PNG Export (Transparent Sticker mode OR Photo Glass "None")
    // Checkerboard stays strictly OUTSIDE RepaintBoundary so PNG export has true alpha!
    // Vertical padding matches Case B in Photo Glass mode so "None" never shifts downward.
    if (_isTransparentExport) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            key: const Key('share_transparent_checkerboard'),
            child: CustomPaint(painter: _CheckerboardPainter()),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                96,
                20,
                isPhotoGlass ? 152 : 112,
              ),
              child: draggableScalableCard,
            ),
          ),
        ],
      );
    }

    // Case B: Full-Bleed 9:16 Photo Glass Backdrop + Overlay Card inside RepaintBoundary
    return RepaintBoundary(
      key: _captureKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_customPhotoBytes != null)
            Image.memory(
              _customPhotoBytes!,
              key: const Key('photo_glass_custom_image'),
              fit: BoxFit.cover,
            )
          else
            DecoratedBox(
              key: const Key('photo_glass_gradient_backdrop'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      _customGradientColors ?? _selectedPreset.gradientColors,
                ),
              ),
            ),
          // Subtle legibility vignette behind top/bottom glass chrome
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.24),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.36),
                  ],
                  stops: const [0.0, 0.22, 0.72, 1.0],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 96, 20, 152),
              child: draggableScalableCard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdropStrip({required bool highContrast}) {
    final s = StradioStrings.of(widget.language);
    final isNoneSelected =
        _customPhotoBytes == null &&
        _customGradientColors == null &&
        _selectedPreset.isNone;
    final isCustomGradientSelected =
        _customPhotoBytes == null && _customGradientColors != null;

    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // 1. None (True Transparent Alpha)
          _CompactTextTile(
            key: const Key('backdrop_option_none'),
            icon: Icons.layers_clear_outlined,
            label: s.backdropNone,
            selected: isNoneSelected,
            highContrast: highContrast,
            onTap: () => _selectPreset(PhotoBackdropPreset.none),
          ),
          const SizedBox(width: 8),

          // 2. Add (Gallery / Camera)
          _CompactTextTile(
            key: const Key('backdrop_add_photo_button'),
            icon: Icons.add_photo_alternate_outlined,
            label: s.backdropAddShort,
            selected: false,
            highContrast: highContrast,
            onTap: _showPhotoSourceChooser,
          ),
          const SizedBox(width: 8),

          // 3. Active Custom Photo Thumbnail
          if (_customPhotoBytes != null) ...[
            GestureDetector(
              key: const Key('backdrop_active_photo_thumb'),
              onTap: _showPhotoSourceChooser,
              child: Container(
                width: 50,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: StradioColors.sonicCoral,
                    width: 2.0,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_customPhotoBytes!, fit: BoxFit.cover),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: StradioColors.sonicCoral,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // 4. 8 Ambient Gradient Presets (Icon + Gradient Only)
          for (final preset in PhotoBackdropPreset.presets) ...[
            _GradientIconTile(
              key: Key('backdrop_option_${preset.id}'),
              icon: preset.icon,
              colors: preset.gradientColors,
              selected:
                  _customPhotoBytes == null &&
                  _customGradientColors == null &&
                  _selectedPreset.id == preset.id,
              onTap: () => _selectPreset(preset),
            ),
            const SizedBox(width: 8),
          ],

          // 5. Custom 2-Color Gradient Combination Picker
          _GradientIconTile(
            key: const Key('backdrop_custom_color_button'),
            icon: Icons.palette_outlined,
            colors:
                _customGradientColors ??
                [
                  const Color(0xFF28283A).withValues(alpha: 0.88),
                  const Color(0xFF191923).withValues(alpha: 0.92),
                ],
            selected: isCustomGradientSelected,
            onTap: _openCustomColorSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionRow({
    required StradioStrings s,
    required bool isPhotoGlass,
    required bool highContrast,
  }) {
    final saveLabel = isPhotoGlass ? s.savePhotoLabel : s.saveLabel;

    return Row(
      children: [
        // Left: Dark Smoked Black Glass Save Button
        _DarkGlassContainer(
          highContrast: highContrast,
          fillColor: const Color(0xFF14141C).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(StradioRadii.full),
          padding: EdgeInsets.zero,
          child: InkWell(
            key: const Key('share_save_gallery_button'),
            borderRadius: BorderRadius.circular(StradioRadii.full),
            onTap: _busy ? null : _handleSaveToGallery,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.download_rounded,
                    size: 18,
                    color: StradioColors.textOnDark,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      saveLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StradioTypography.pillBadge(
                        color: StradioColors.textOnDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Right: Coral-to-Violet Gradient "Add to Story" Button
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  StradioColors.sonicCoral,
                  StradioColors.rhythmViolet,
                ],
              ),
              borderRadius: BorderRadius.circular(StradioRadii.full),
              boxShadow: [
                BoxShadow(
                  color: StradioColors.sonicCoral.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('share_export_png_button'),
                borderRadius: BorderRadius.circular(StradioRadii.full),
                onTap: _busy ? null : _handleShare,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_busy)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: StradioColors.textOnDark,
                          ),
                        )
                      else
                        const Icon(
                          Icons.send_rounded,
                          size: 17,
                          color: StradioColors.textOnDark,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _busy ? s.renderingPng : s.addToStoryAction,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StradioTypography.pillBadge(
                            color: StradioColors.textOnDark,
                          ).copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DarkGlassContainer extends StatelessWidget {
  const _DarkGlassContainer({
    required this.highContrast,
    required this.borderRadius,
    required this.padding,
    required this.child,
    this.fillColor,
  });

  final bool highContrast;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final bg = fillColor ?? const Color(0xFF14141E).withValues(alpha: 0.72);
    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: highContrast ? const Color(0xFF14141E) : bg,
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: child,
    );

    if (highContrast) return inner;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: inner,
      ),
    );
  }
}

class _DarkGlassCircleButton extends StatelessWidget {
  const _DarkGlassCircleButton({
    super.key,
    required this.highContrast,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor = StradioColors.textOnDark,
  });

  final bool highContrast;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _DarkGlassContainer(
        highContrast: highContrast,
        borderRadius: BorderRadius.circular(StradioRadii.full),
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(StradioRadii.full),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 19, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _GlassModeTab extends StatelessWidget {
  const _GlassModeTab({
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
      color: selected
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(StradioRadii.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(StradioRadii.full),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(StradioRadii.full),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: StradioColors.sonicCoral,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StradioTypography.pillBadge(
                      color: selected
                          ? StradioColors.textOnDark
                          : Colors.white.withValues(alpha: 0.68),
                    ).copyWith(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassTemplatePill extends StatelessWidget {
  const _GlassTemplatePill({
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
      color: selected
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(StradioRadii.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(StradioRadii.full),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(StradioRadii.full),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.26),
                  ),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: StradioColors.sonicCoral,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StradioTypography.pillBadge(
                      color: selected
                          ? StradioColors.textOnDark
                          : Colors.white.withValues(alpha: 0.68),
                    ).copyWith(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactTextTile extends StatelessWidget {
  const _CompactTextTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.highContrast,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool highContrast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    final tile = Container(
      width: 50,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF14141E).withValues(alpha: 0.72),
        borderRadius: radius,
        border: Border.all(
          color: selected
              ? StradioColors.sonicCoral
              : Colors.white.withValues(alpha: 0.22),
          width: selected ? 2.0 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: StradioColors.textOnDark),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StradioTypography.microCap(
                color: StradioColors.textOnDark,
              ).copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: highContrast
          ? tile
          : ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: tile,
              ),
            ),
    );
  }
}

class _GradientIconTile extends StatelessWidget {
  const _GradientIconTile({
    super.key,
    required this.icon,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avgLum =
        colors.fold<double>(0.0, (acc, c) => acc + c.computeLuminance()) /
        colors.length;
    final iconColor = avgLum > 0.56
        ? StradioColors.midnight
        : StradioColors.textOnDark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(
            color: selected
                ? StradioColors.sonicCoral
                : Colors.white.withValues(alpha: 0.24),
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Center(
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({
    required this.keyPrefix,
    required this.selected,
    required this.ringColor,
    required this.onSelect,
  });

  final String keyPrefix;
  final Color selected;
  final Color ringColor;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PhotoBackdropPreset.customPaletteColors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final color = PhotoBackdropPreset.customPaletteColors[index];
          final isSelected = color.toARGB32() == selected.toARGB32();
          return GestureDetector(
            key: Key('${keyPrefix}_$index'),
            onTap: () => onSelect(color),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: isSelected
                      ? ringColor
                      : Colors.white.withValues(alpha: 0.25),
                  width: isSelected ? 2.5 : 1.0,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: color.computeLuminance() > 0.5
                          ? StradioColors.midnight
                          : Colors.white,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

/// Subtle neutral dark checkerboard pattern rendered strictly OUTSIDE `RepaintBoundary`
/// to preview true PNG alpha transparency on Transparent Sticker & Photo Glass `None`.
class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 14.0;
    final lightPaint = Paint()..color = const Color(0xFF282834);
    final darkPaint = Paint()..color = const Color(0xFF1C1C26);

    canvas.drawRect(Offset.zero & size, darkPaint);
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if ((r + c).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell, r * cell, cell, cell),
            lightPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
