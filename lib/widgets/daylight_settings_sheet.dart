import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/stradio_strings.dart';
import '../models/experiment_models.dart';
import '../theme/stradio_theme.dart';

/// Compact Daylight Settings Sheet reachable from Surface 1 top-right icon.
///
/// Preserves UU PDP PostHog opt-in control, earphone guide re-access,
/// height stride calibration, language toggle, and workout history clearing
/// without reintroducing a multi-tab navigation shell.
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: Container(
          key: const Key('daylight_settings_sheet'),
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

                // 1. UU PDP Opt-in Analytics Toggle
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: StradioColors.warmIvory,
                    borderRadius: BorderRadius.circular(StradioRadii.lg),
                    border: Border.all(color: StradioColors.borderSubtle),
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
                          fillColor: StradioColors.warmIvory,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(StradioRadii.md),
                            borderSide: const BorderSide(
                              color: StradioColors.borderSubtle,
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

                // 4. Re-open First-Launch Earphone Recommendation
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('settings_earphone_guide_button'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onShowEarphoneGuide();
                    },
                    icon: const Icon(Icons.headphones_rounded, size: 18),
                    label: Text(s.earphoneGuideAction),
                  ),
                ),
                const SizedBox(height: 10),

                // 5. Clear Local Workout History
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('settings_clear_history_button'),
                    onPressed: _clearing ? null : _confirmAndClearHistory,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: StradioColors.textAccentDeep,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(s.clearHistoryAction),
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
