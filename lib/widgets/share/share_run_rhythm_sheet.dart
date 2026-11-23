import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../evaluation/run_metrics_calculator.dart';
import '../../l10n/stradio_strings.dart';
import '../../models/sound_pack.dart';
import '../../screens/stradio/share_studio_screen.dart';
import '../../theme/stradio_theme.dart';
import 'share_template_models.dart';
import 'transparent_sticker_cards.dart';

/// Mockup 12 Quick Share Bottom Sheet (`Share Run Rhythm`).
///
/// Bridges [PostRunSummaryScreen] (Mockup 11) and [ShareStudioScreen] (9:16 Photo Glass):
/// - Horizontal carousel of the 3 revamped `TransparentStickerCard` templates (`Aura Wave`, `Sonic Dial`, `Minimal Stride`)
/// - 3 Quick Share pods (`Save` PNG, `Copy Text` caption, `Messages` text-only share; no IG direct intent / web link)
/// - `Share Rhythm Card` (Midnight capsule: direct PNG + caption share)
/// - `Story export 9:16` (Alabaster capsule: opens [ShareStudioScreen] directly in Photo Glass 9:16 mode)
class ShareRunRhythmSheet extends StatefulWidget {
  const ShareRunRhythmSheet({
    super.key,
    required this.metrics,
    required this.soundPack,
    this.language = AppLanguage.en,
    this.onSaveToGallery,
    this.onShareFile,
    this.onShareText,
  });

  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;
  final AppLanguage language;
  final Future<void> Function(String filePath)? onSaveToGallery;
  final Future<void> Function(String filePath, String caption)? onShareFile;
  final Future<void> Function(String caption)? onShareText;

  static Future<void> show(
    BuildContext context, {
    required RunSummaryMetrics metrics,
    required StradioSoundPack soundPack,
    AppLanguage language = AppLanguage.en,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareRunRhythmSheet(
        metrics: metrics,
        soundPack: soundPack,
        language: language,
      ),
    );
  }

  @override
  State<ShareRunRhythmSheet> createState() => _ShareRunRhythmSheetState();
}

class _ShareRunRhythmSheetState extends State<ShareRunRhythmSheet> {
  static const _templates = StickerTemplateId.values;

  final PageController _pageController = PageController(
    viewportFraction: 0.86,
  );
  final Map<StickerTemplateId, GlobalKey> _cardKeys = {
    for (final t in StickerTemplateId.values) t: GlobalKey(),
  };

  int _activeIndex = 0;
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;

  StickerTemplateId get _activeTemplate => _templates[_activeIndex];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTemplate(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeIndex = index;
      _statusMessage = null;
      _statusIsError = false;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _buildCaption() {
    final s = StradioStrings.of(widget.language);
    return s.buildShareCaption(
      steps: widget.metrics.totalSteps,
      distanceKm: ShareMetricFormat.distanceKm(widget.metrics),
      duration: widget.metrics.formattedDuration,
      avgSpm: ShareMetricFormat.avgSpm(widget.metrics),
      soundPackTitle: widget.soundPack.title,
    );
  }

  Future<File> _renderActiveStickerPng() async {
    final key = _cardKeys[_activeTemplate];
    final boundary =
        key?.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Sticker preview is not ready yet.');
    }
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Could not encode PNG image.');
    }
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/stradio_card_$ts.png');
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
      final file = await _renderActiveStickerPng();
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

  void _handleCopyText() {
    HapticFeedback.selectionClick();
    final caption = _buildCaption();
    unawaited(
      Clipboard.setData(ClipboardData(text: caption)).catchError((_) {}),
    );
    if (!mounted) return;
    final isId = widget.language == AppLanguage.id;
    setState(() {
      _statusMessage = isId ? 'Caption disalin ke clipboard' : 'Caption copied';
      _statusIsError = false;
    });
  }

  Future<void> _handleShareMessagesText() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _busy = true;
      _statusMessage = null;
      _statusIsError = false;
    });
    try {
      final caption = _buildCaption();
      if (widget.onShareText != null) {
        await widget.onShareText!(caption);
      } else {
        await SharePlus.instance.share(ShareParams(text: caption));
      }
      if (!mounted) return;
      final isId = widget.language == AppLanguage.id;
      setState(() {
        _statusMessage = isId ? 'Teks siap dibagikan' : 'Message ready to share';
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

  Future<void> _handleShareRhythmCard() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _statusMessage = null;
      _statusIsError = false;
    });
    try {
      final file = await _renderActiveStickerPng();
      final caption = _buildCaption();
      if (widget.onShareFile != null) {
        await widget.onShareFile!(file.path, caption);
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
        _statusMessage = s.stickerReadyMessage;
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

  void _openStoryStudio916() {
    HapticFeedback.selectionClick();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ShareStudioScreen(
          metrics: widget.metrics,
          soundPack: widget.soundPack,
          initialMode: ShareExportMode.photoGlass,
          language: widget.language,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(widget.language);
    final isId = widget.language == AppLanguage.id;
    final screenH = MediaQuery.sizeOf(context).height;
    final carouselHeight = (screenH * 0.34).clamp(190.0, 300.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Container(
          key: const Key('share_run_rhythm_sheet'),
          decoration: BoxDecoration(
            color: StradioColors.warmIvory,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: StradioColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: StradioColors.midnight.withValues(alpha: 0.16),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
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
                const SizedBox(height: 10),

                // Mockup 12 Header: "Share Run Rhythm" + "CARD" pill + Close button
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            isId ? 'Bagikan Ritme Lari' : 'Share Run Rhythm',
                            style: StradioTypography.headingSmall(fontSize: 19),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: StradioColors.surfaceRecessed,
                              borderRadius: BorderRadius.circular(
                                StradioRadii.full,
                              ),
                            ),
                            child: Text(
                              'CARD',
                              style: StradioTypography.microCap(
                                color: StradioColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('share_rhythm_close_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: s.closeLabel,
                      style: IconButton.styleFrom(
                        backgroundColor: StradioColors.surfaceRecessed,
                        minimumSize: const Size(38, 38),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: StradioColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3 Template Pills: Aura Wave · Sonic Dial · Minimal Stride
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _templates.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _TemplatePillChip(
                          label: _templates[i].label,
                          selected: i == _activeIndex,
                          onTap: () => _selectTemplate(i),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Horizontal Carousel of the 3 Revamped Transparent Sticker Cards
                SizedBox(
                  height: carouselHeight,
                  child: PageView.builder(
                    controller: _pageController,
                    padEnds: false,
                    itemCount: _templates.length,
                    onPageChanged: (index) => setState(() => _activeIndex = index),
                    itemBuilder: (_, index) {
                      final template = _templates[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: RepaintBoundary(
                              key: _cardKeys[template],
                              child: TransparentStickerCard(
                                template: template,
                                metrics: widget.metrics,
                                soundPack: widget.soundPack,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // 3 Carousel Indicator Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _templates.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: i == _activeIndex ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _activeIndex
                              ? StradioColors.midnight
                              : StradioColors.borderSubtle,
                          borderRadius: BorderRadius.circular(
                            StradioRadii.full,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                if (_statusMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _statusIsError
                          ? StradioColors.glowCoralSoft
                          : StradioColors.surfaceCard,
                      borderRadius: BorderRadius.circular(StradioRadii.lg),
                      border: Border.all(
                        color: _statusIsError
                            ? StradioColors.sonicCoral
                            : StradioColors.borderSubtle,
                      ),
                    ),
                    child: Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: StradioTypography.metricLabel(
                        color: _statusIsError
                            ? StradioColors.textAccentDeep
                            : StradioColors.textPrimary,
                      ),
                    ),
                  ),
                ],

                // QUICK SHARE Section (3 Rounded-Square Pods matching Mockup 12, without IG Stories)
                Text(
                  isId ? 'BAGIKAN CEPAT' : 'QUICK SHARE',
                  style: StradioTypography.microCap(
                    color: StradioColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _QuickSharePod(
                        podKey: const Key('share_rhythm_quick_save'),
                        icon: Icons.download_rounded,
                        label: isId ? 'Simpan' : 'Save',
                        onTap: _handleSaveToGallery,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickSharePod(
                        podKey: const Key('share_rhythm_quick_copy'),
                        icon: Icons.link_rounded,
                        label: isId ? 'Salin Teks' : 'Copy Text',
                        onTap: _handleCopyText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickSharePod(
                        podKey: const Key('share_rhythm_quick_messages'),
                        icon: Icons.chat_outlined,
                        label: isId ? 'Pesan' : 'Messages',
                        onTap: _handleShareMessagesText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Primary Midnight Capsule Button ("Share Rhythm Card")
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    key: const Key('share_rhythm_primary_button'),
                    onPressed: _busy ? null : _handleShareRhythmCard,
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
                      isId ? 'Bagikan Kartu Ritme' : 'Share Rhythm Card',
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary Alabaster Capsule Button ("Story export 9:16" -> opens ShareStudioScreen)
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('share_rhythm_open_studio_button'),
                    onPressed: _openStoryStudio916,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: StradioColors.surfaceCard,
                      foregroundColor: StradioColors.textPrimary,
                      side: const BorderSide(color: StradioColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(StradioRadii.full),
                      ),
                    ),
                    icon: const Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color: StradioColors.textSecondary,
                    ),
                    label: Text(
                      isId ? 'Ekspor Story 9:16' : 'Story export 9:16',
                      style: StradioTypography.pillBadge(
                        color: StradioColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplatePillChip extends StatelessWidget {
  const _TemplatePillChip({
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StradioRadii.full),
            border: Border.all(
              color: selected
                  ? StradioColors.midnight
                  : StradioColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: StradioColors.sonicCoral,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: StradioTypography.metricLabel(
                  color: selected
                      ? StradioColors.textOnDark
                      : StradioColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickSharePod extends StatelessWidget {
  const _QuickSharePod({
    required this.podKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key podKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StradioColors.surfaceCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: podKey,
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: StradioColors.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: StradioColors.surfaceRecessed,
                ),
                child: Icon(icon, size: 19, color: StradioColors.textPrimary),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: StradioTypography.metricLabel(
                    color: StradioColors.textSecondary,
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
