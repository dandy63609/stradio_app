import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/stradio_strings.dart';
import '../models/experiment_models.dart';
import '../theme/stradio_theme.dart';

/// Compact Daylight Settings Sheet reachable from Surface 1 top-right icon.
///
/// Includes anonymous PostHog telemetry toggle (default true), earphone guide re-access,
/// height stride calibration, language toggle, and workout history clearing
/// with tactile animated press feedback on action buttons.
class DaylightSettingsSheet extends StatefulWidget {
  const DaylightSettingsSheet({
    super.key,
    required this.profile,
    required this.onUpdateProfile,
    required this.onShowEarphoneGuide,
    required this.onClearHistory,
  });

  final StradioUserProfile profile;
  final ValueChanged<StradioUserProfile> onUpdateProfile;
  final VoidCallback onShowEarphoneGuide;
  final Future<void> Function() onClearHistory;

  static Future<void> show(
    BuildContext context, {
    required StradioUserProfile profile,
    required ValueChanged<StradioUserProfile> onUpdateProfile,
    required VoidCallback onShowEarphoneGuide,
    required Future<void> Function() onClearHistory,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (_) => DaylightSettingsSheet(
        profile: profile,
        onUpdateProfile: onUpdateProfile,
        onShowEarphoneGuide: onShowEarphoneGuide,
        onClearHistory: onClearHistory,
      ),
    );
  }

  @override
  State<DaylightSettingsSheet> createState() => _DaylightSettingsSheetState();
}

class _DaylightSettingsSheetState extends State<DaylightSettingsSheet> {
  late StradioUserProfile _profile;
  late TextEditingController _heightController;
  String? _heightError;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _heightController = TextEditingController(
      text: _profile.validHeightCm?.round().toString() ?? '',
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  void _commitProfile(StradioUserProfile next) {
    setState(() => _profile = next);
    widget.onUpdateProfile(next);
  }

  void _saveHeight() {
    final s = StradioStrings.of(_profile.language);
    final raw = _heightController.text.trim();
    if (raw.isEmpty) {
      setState(() => _heightError = null);
      _commitProfile(_profile.copyWith(clearHeight: true));
      return;
    }
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed < 100 || parsed > 240) {
      setState(() => _heightError = s.heightErrorRange);
      return;
    }
    setState(() => _heightError = null);
    _commitProfile(_profile.copyWith(heightCm: parsed));
  }

  Future<void> _confirmAndClearHistory() async {
    final s = StradioStrings.of(_profile.language);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: StradioColors.surfaceCard,
        title: Text(
          s.clearHistoryDialogTitle,
          style: StradioTypography.headingSmall(),
        ),
        content: Text(
          s.clearHistoryDialogBody,
          style: StradioTypography.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.cancelAction),
          ),
          FilledButton(
            key: const Key('confirm_clear_history_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: StradioColors.textAccentDeep,
            ),
            child: Text(s.clearAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      await widget.onClearHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.historyClearedMessage)),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StradioStrings.of(_profile.language);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          key: const Key('daylight_settings_sheet'),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + bottomPadding + bottomInset,
          ),
          decoration: BoxDecoration(
            color: StradioColors.surfaceCard.withValues(alpha: 0.86),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.90),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: StradioColors.midnight.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.settingsTitle,
                        style: StradioTypography.headingSmall(fontSize: 20),
                      ),
                    ),
                    IconButton(
                      key: const Key('settings_sheet_close_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: s.closeLabel,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 1. Anonymous Telemetry Toggle (Default ON)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: StradioColors.warmIvory.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(StradioRadii.lg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.analyticsOptInTitle,
                              style: StradioTypography.pillBadge(),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.analyticsOptInSubtitle,
                              style: StradioTypography.metricLabel(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        key: const Key('settings_analytics_optin_switch'),
                        value: _profile.analyticsEnabled,
                        onChanged: (enabled) => _commitProfile(
                          _profile.copyWith(analyticsEnabled: enabled),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Language Switcher (EN / ID)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.languageLabel,
                        style: StradioTypography.pillBadge(),
                      ),
                    ),
                    SegmentedButton<AppLanguage>(
                      key: const Key('settings_language_segmented'),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: AppLanguage.en, label: Text('EN')),
                        ButtonSegment(value: AppLanguage.id, label: Text('ID')),
                      ],
                      selected: {_profile.language},
                      onSelectionChanged: (selection) {
                        _commitProfile(
                          _profile.copyWith(language: selection.first),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Optional Height Calibration (cm)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('settings_height_field'),
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: InputDecoration(
                          labelText: s.heightFieldLabel,
                          hintText: '170',
                          errorText: _heightError,
                          filled: true,
                          fillColor: StradioColors.warmIvory.withValues(
                            alpha: 0.72,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(StradioRadii.md),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        key: const Key('settings_save_height_button'),
                        onPressed: _saveHeight,
                        child: Text(s.saveLabel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Re-open First-Launch Earphone Recommendation (with tactile color transition)
                _AnimatedActionButton(
                  buttonKey: const Key('settings_earphone_guide_button'),
                  icon: Icons.headphones_rounded,
                  label: s.earphoneGuideAction,
                  baseColor: StradioColors.warmIvory.withValues(alpha: 0.68),
                  pressedColor: StradioColors.glowVioletSoft,
                  foregroundColor: StradioColors.textPrimary,
                  pressedForegroundColor: StradioColors.twilightPlum,
                  pressedBorderColor: StradioColors.twilightPlum,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onShowEarphoneGuide();
                  },
                ),
                const SizedBox(height: 10),

                // 5. Clear Local Workout History (with tactile coral color transition)
                _AnimatedActionButton(
                  buttonKey: const Key('settings_clear_history_button'),
                  icon: Icons.delete_outline_rounded,
                  label: s.clearHistoryAction,
                  baseColor: StradioColors.warmIvory.withValues(alpha: 0.68),
                  pressedColor: StradioColors.glowCoralSoft,
                  foregroundColor: StradioColors.textAccentDeep,
                  pressedForegroundColor: StradioColors.textAccentDeep,
                  pressedBorderColor: StradioColors.sonicCoral,
                  onTap: _clearing ? null : _confirmAndClearHistory,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  const _AnimatedActionButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.baseColor,
    required this.pressedColor,
    required this.foregroundColor,
    required this.pressedForegroundColor,
    required this.pressedBorderColor,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final Color baseColor;
  final Color pressedColor;
  final Color foregroundColor;
  final Color pressedForegroundColor;
  final Color pressedBorderColor;
  final VoidCallback? onTap;

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final activeFg = _isPressed
        ? widget.pressedForegroundColor
        : widget.foregroundColor;

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        key: widget.buttonKey,
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                HapticFeedback.selectionClick();
                _setPressed(false);
                widget.onTap?.call();
              },
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _isPressed ? widget.pressedColor : widget.baseColor,
              borderRadius: BorderRadius.circular(StradioRadii.full),
              border: Border.all(
                color: _isPressed
                    ? widget.pressedBorderColor
                    : StradioColors.borderSubtle,
                width: _isPressed ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 18, color: activeFg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StradioTypography.buttonLabel(color: activeFg),
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
