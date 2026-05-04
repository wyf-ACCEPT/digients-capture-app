import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/forms.dart';
import '../../widgets/nav.dart';
import '../../state/auth_controller.dart';
import '../../state/hand_presence_settings_controller.dart';
import '../../state/theme_controller.dart';
import '../../fixtures/data.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _wifiOnly = true;
  bool _autoUpload = true;
  bool _backgroundUpload = false;
  bool _notifyApproval = true;
  bool _notifyPoints = true;

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final p = fixtureProfile;
    final themeCtl = context.watch<ThemeController>();
    final auth = context.watch<AuthController>();
    final hpSettings = context.watch<HandPresenceSettingsController>();
    final profile = auth.session?.profile;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          DCNavBar(title: 'Settings', onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                _Section(title: 'ACCOUNT', children: [
                  _SettingsRow(label: 'Email', valueText: profile?.email ?? '—'),
                  _SettingsRow(label: 'Phone', valueText: profile?.phone ?? '—'),
                  _SettingsRow(label: 'UID', valueText: profile?.uid ?? p.uid, mono: true, isLast: true),
                ]),
                _Section(title: 'UPLOADS', children: [
                  _SettingsRow(
                    label: 'Wi-Fi only',
                    trailing: DCToggle(value: _wifiOnly, onChanged: (v) => setState(() => _wifiOnly = v)),
                  ),
                  _SettingsRow(
                    label: 'Auto-upload after capture',
                    trailing: DCToggle(value: _autoUpload, onChanged: (v) => setState(() => _autoUpload = v)),
                  ),
                  _SettingsRow(
                    label: 'Background uploads',
                    trailing: DCToggle(value: _backgroundUpload, onChanged: (v) => setState(() => _backgroundUpload = v)),
                    isLast: true,
                  ),
                ]),
                _Section(title: 'RECORDING FEEDBACK', children: [
                  _SettingsRow(
                    label: 'Hand-presence cues',
                    trailing: DCToggle(
                      value: hpSettings.masterEnabled,
                      onChanged: (v) => hpSettings.setMaster(v),
                    ),
                  ),
                  _SettingsRow(
                    label: 'Audio tones',
                    trailing: DCToggle(
                      value: hpSettings.rawTones,
                      onChanged: (v) => hpSettings.setTones(v),
                    ),
                  ),
                  _SettingsRow(
                    label: 'Voice cues',
                    trailing: DCToggle(
                      value: hpSettings.rawVoice,
                      onChanged: (v) => hpSettings.setVoice(v),
                    ),
                  ),
                  _SettingsRow(
                    label: 'Border indicator',
                    trailing: DCToggle(
                      value: hpSettings.rawBorder,
                      onChanged: (v) => hpSettings.setBorder(v),
                    ),
                  ),
                  _SettingsRow(
                    label: 'Vibrate on no hands',
                    trailing: DCToggle(
                      value: hpSettings.rawVibrateOnNone,
                      onChanged: (v) => hpSettings.setVibrateOnNone(v),
                    ),
                    isLast: true,
                  ),
                ]),
                _Section(title: 'NOTIFICATIONS', children: [
                  _SettingsRow(
                    label: 'Approval results',
                    trailing: DCToggle(value: _notifyApproval, onChanged: (v) => setState(() => _notifyApproval = v)),
                  ),
                  _SettingsRow(
                    label: 'Points credited',
                    trailing: DCToggle(value: _notifyPoints, onChanged: (v) => setState(() => _notifyPoints = v)),
                    isLast: true,
                  ),
                ]),
                _Section(title: 'APPEARANCE', children: [
                  _SettingsRow(
                    label: 'Theme',
                    trailing: DCSegmented<ThemeMode>(
                      values: const [ThemeMode.system, ThemeMode.dark, ThemeMode.light],
                      labels: const ['Auto', 'Dark', 'Light'],
                      selected: themeCtl.mode,
                      onChanged: (m) => themeCtl.setMode(m),
                    ),
                    isLast: true,
                  ),
                ]),
                _Section(title: 'ABOUT', children: [
                  _SettingsRow(label: 'Version', valueText: '2.0.0', mono: true),
                  _SettingsRow(label: 'Privacy Policy', trailing: Icon(Icons.chevron_right, color: c.textDim)),
                  _SettingsRow(label: 'Terms of Service', trailing: Icon(Icons.chevron_right, color: c.textDim)),
                  _SettingsRow(label: 'Open-source licenses', trailing: Icon(Icons.chevron_right, color: c.textDim), isLast: true),
                ]),
                _Section(title: '', children: [
                  _SettingsRow(
                    label: 'Sign Out',
                    danger: true,
                    onTap: () => context.read<AuthController>().logout(),
                  ),
                  _SettingsRow(label: 'Delete account', danger: true, isLast: true),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(title, style: DCText.eyebrow(color: c.textDim, size: 10)),
            ),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(
                top: BorderSide(color: c.border),
                bottom: BorderSide(color: c.border),
              ),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String? valueText;
  final Widget? trailing;
  final bool mono;
  final bool danger;
  final bool isLast;
  final VoidCallback? onTap;
  const _SettingsRow({
    required this.label,
    this.valueText,
    this.trailing,
    this.mono = false,
    this.danger = false,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: DCText.inter(size: 15, weight: FontWeight.w500, color: danger ? c.danger : c.text),
            ),
          ),
          if (valueText != null)
            Text(
              valueText!,
              style: mono
                  ? DCText.mono(size: 13, weight: FontWeight.w500, color: c.textDim)
                  : DCText.inter(size: 13, weight: FontWeight.w500, color: c.textDim),
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}
