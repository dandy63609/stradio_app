import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../evaluation/run_metrics_calculator.dart';
import '../../l10n/stradio_strings.dart';
import '../../models/sound_pack.dart';
import '../../screens/stradio/share_studio_screen.dart';
import '../../theme/stradio_theme.dart';
import 'share_template_models.dart';
import 'transparent_sticker_cards.dart';

/// Streamlined Share Run Rhythm Bottom Sheet (`Card 12` / `UX-REVISION-HANDOFF.md`).
///
/// Renders:
/// - Header (`Share Run Rhythm` + `CARD` badge + Close button)
/// - 3 template chips (`Aura Wave`, `Sonic Dial`, `Minimal Stride`)
/// - Centered horizontal carousel with dot indicators
/// - 2 full-width action pills: `Share Rhythm Card` (PNG + caption) & `Instagram story export 9:16`
class ShareRunRhythmSheet extends StatefulWidget {
  const ShareRunRhythmSheet({
    super.key,
    required this.metrics,
    required this.soundPack,
    this.language = AppLanguage.en,
    this.onShareFile,
  });

  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;
  final AppLanguage language;
  final Future<void> Function(String filePath, String caption)? onShareFile;

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
      constraints: const BoxConstraints(maxWidth: double.infinity),
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
    viewportFraction: 0.78,
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
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => ShareStudioScreen(
          metrics: widget.metrics,
          soundPack: widget.soundPack,
          initialMode: ShareExportMode.photoGlass,
          language: widget.language,
        ),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(widget.language);
    final screenH = MediaQuery.sizeOf(context).height;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final carouselHeight = (screenH * 0.42).clamp(240.0, 350.0);

    return Container(
      key: const Key('share_run_rhythm_sheet'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            StradioColors.surfaceCard.withValues(alpha: 0.98),
            StradioColors.warmIvory.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: StradioColors.midnight.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomPadding),
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
                  const SizedBox(height: 12),

                  // Header: "Share Run Rhythm" + "CARD" pill + Close button
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              s.shareRunRhythmTitle,
                              style: StradioTypography.headingSmall(
                                fontSize: 19,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: StradioColors.surfaceRecessed.withValues(
                                  alpha: 0.85,
                                ),
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
                          backgroundColor: StradioColors.surfaceRecessed
                              .withValues(alpha: 0.85),
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
                  const SizedBox(height: 10),

                  // Centered Horizontal Carousel (scales cleanly on 360px-390px)
                  SizedBox(
                    height: carouselHeight,
                    child: PageView.builder(
                      controller: _pageController,
                      padEnds: true,
                      itemCount: _templates.length,
                      onPageChanged: (index) =>
                          setState(() => _activeIndex = index),
                      itemBuilder: (_, index) {
                        final template = _templates[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
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
                  const SizedBox(height: 8),

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
                  const SizedBox(height: 16),

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
                      label: Text(s.shareRhythmCardAction),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary Alabaster Capsule Button ("Instagram story export 9:16")
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      key: const Key('share_rhythm_open_studio_button'),
                      onPressed: _openStoryStudio916,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: StradioColors.surfaceCard.withValues(
                          alpha: 0.82,
                        ),
                        foregroundColor: StradioColors.textPrimary,
                        side: const BorderSide(
                          color: StradioColors.borderSubtle,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            StradioRadii.full,
                          ),
                        ),
                      ),
                      icon: const Icon(
                        Icons.grid_view_rounded,
                        size: 18,
                        color: StradioColors.textSecondary,
                      ),
                      label: Text(
                        widget.language == AppLanguage.id
                            ? 'Ekspor story 9:16'
                            : 'Story export 9:16',
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
          child: Text(
            label,
            style: StradioTypography.metricLabel(
              color: selected
                  ? StradioColors.textOnDark
                  : StradioColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
