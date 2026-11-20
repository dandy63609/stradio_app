import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../evaluation/run_metrics_calculator.dart';
import '../models/sound_pack.dart';
import '../theme/stradio_theme.dart';
import 'sonic_ribbon_painter.dart';

/// P1 Share Rhythm Modal (`docs/PRD-MVP.md` FR-5.5 Format A: Transparent Sticker PNG).
///
/// Captures the Daylight Liquid Glass cadence sticker via [RepaintBoundary] at 3x DPR
/// and shares the transparent PNG via `share_plus` (Instagram Stories / Reels / OS share).
class ShareRhythmModal extends StatefulWidget {
  const ShareRhythmModal({
    super.key,
    required this.metrics,
    required this.soundPack,
    this.onShareFile,
  });

  final RunSummaryMetrics metrics;
  final StradioSoundPack soundPack;

  /// Optional test hook overriding OS share sheet invocation.
  final Future<void> Function(String filePath)? onShareFile;

  static Future<void> show(
    BuildContext context, {
    required RunSummaryMetrics metrics,
    required StradioSoundPack soundPack,
    Future<void> Function(String filePath)? onShareFile,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareRhythmModal(
        metrics: metrics,
        soundPack: soundPack,
        onShareFile: onShareFile,
      ),
    );
  }

  @override
  State<ShareRhythmModal> createState() => _ShareRhythmModalState();
}

class _ShareRhythmModalState extends State<ShareRhythmModal> {
  final GlobalKey _stickerKey = GlobalKey();
  bool _exporting = false;
  String? _statusMessage;

  String _formatPace(RunSummaryMetrics m) {
    if (m.distanceKm <= 0.01 || m.activeDurationSeconds <= 0) return '--';
    final secPerKm = (m.activeDurationSeconds / m.distanceKm).round();
    final mins = secPerKm ~/ 60;
    final secs = (secPerKm % 60).toString().padLeft(2, '0');
    return '$mins:$secs /km';
  }

  Future<void> _exportTransparentPng() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _statusMessage = null;
    });

    try {
      final boundary =
          _stickerKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Sticker preview is not ready yet.');
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('Could not encode sticker PNG.');
      }

      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outFile = File('${tempDir.path}/stradio_rhythm_$ts.png');
      await outFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      if (widget.onShareFile != null) {
        await widget.onShareFile!(outFile.path);
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(outFile.path, mimeType: 'image/png')],
            text: 'Stradio (${widget.soundPack.title})',
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Transparent PNG ready for Instagram Stories.';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Export failed: $error';
      });
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final hasCadence = m.averageCadenceSpm > 0;
    final avgSpmText = hasCadence ? '${m.averageCadenceSpm.round()}' : '--';
    final distanceText = m.distanceKm > 0
        ? '${m.distanceKm.toStringAsFixed(2)} km'
        : '0.00 km';
    final paceText = _formatPace(m);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Container(
          key: const Key('share_rhythm_modal'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: StradioColors.surfaceCard,
            borderRadius: BorderRadius.circular(StradioRadii.tray),
            border: Border.all(color: StradioColors.borderSubtle),
          ),
          child: SingleChildScrollView(
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Share Rhythm',
                        style: StradioTypography.headingSmall(fontSize: 20),
                      ),
                    ),
                    IconButton(
                      key: const Key('share_rhythm_close_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                Text(
                  'Transparent liquid glass sticker for Instagram Stories',
                  style: StradioTypography.body(fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Preview well (checkerboard-tinted recessed backdrop; only RepaintBoundary is exported transparent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: StradioColors.surfaceRecessed,
                    borderRadius: BorderRadius.circular(StradioRadii.lg),
                  ),
                  child: Center(
                    child: RepaintBoundary(
                      key: _stickerKey,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Hero Frosted Circle (strictly no extraneous timestamps/logos inside per PRD FR-5.4)
                            Container(
                              width: 196,
                              height: 196,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: StradioColors.surfaceCard.withValues(
                                  alpha: 0.84,
                                ),
                                border: Border.all(
                                  color: StradioColors.surfaceGlassRim,
                                  width: 1.5,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Positioned.fill(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: CustomPaint(
                                        painter: SonicRibbonPainter(
                                          phase: 1.1,
                                          amplitude: 0.65,
                                          strokeWidth: 2.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        avgSpmText,
                                        style: StradioTypography.metricHero(
                                          fontSize: 42,
                                        ),
                                      ),
                                      Text(
                                        'spm',
                                        style: StradioTypography.metricLabel(
                                          color: StradioColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: StradioColors.midnight
                                              .withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                            StradioRadii.full,
                                          ),
                                        ),
                                        child: Text(
                                          hasCadence
                                              ? 'Stride Resonance Lock'
                                              : 'Ready to stride',
                                          style: StradioTypography.microCap(
                                            color: StradioColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Triple Frosted Metric Pills
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _StickerMetricPill(
                                  label: 'Distance',
                                  value: distanceText,
                                ),
                                _StickerMetricPill(
                                  label: 'Duration',
                                  value: m.formattedDuration,
                                ),
                                _StickerMetricPill(
                                  label: 'Pace',
                                  value: paceText,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Audio Footer Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: StradioColors.surfaceCard.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(
                                  StradioRadii.full,
                                ),
                                border: Border.all(
                                  color: StradioColors.surfaceGlassRim,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.headphones_rounded,
                                    size: 14,
                                    color: StradioColors.twilightPlum,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.soundPack.title,
                                    style: StradioTypography.pillBadge(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (_statusMessage != null) ...[
                  Text(
                    _statusMessage!,
                    key: const Key('share_rhythm_status_text'),
                    style: StradioTypography.body(
                      fontSize: 12,
                      color: StradioColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    key: const Key('share_export_png_button'),
                    onPressed: _exporting ? null : _exportTransparentPng,
                    icon: _exporting
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
                      _exporting
                          ? 'Rendering PNG...'
                          : 'Export Transparent Sticker',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Photo Glass & 9:16 Story templates coming in Phase 3B.',
                  textAlign: TextAlign.center,
                  style: StradioTypography.metricLabel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickerMetricPill extends StatelessWidget {
  const _StickerMetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: StradioColors.surfaceCard.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(StradioRadii.lg),
        border: Border.all(color: StradioColors.surfaceGlassRim),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: StradioTypography.metricLabel()),
          const SizedBox(height: 2),
          Text(value, style: StradioTypography.pillBadge()),
        ],
      ),
    );
  }
}
