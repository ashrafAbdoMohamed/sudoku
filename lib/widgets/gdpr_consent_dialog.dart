import 'package:flutter/material.dart';
import '../game/cartoon_dialog.dart';
import '../game/ui_kit.dart';
import '../theme/app_theme.dart';

class GdprConsentDialog extends StatefulWidget {
  final AppColorScheme colors;
  final void Function(bool analytics, bool ads) onAccept;
  final VoidCallback onAcceptEssential;
  final VoidCallback onShowPrivacyPolicy;

  const GdprConsentDialog({
    super.key,
    required this.colors,
    required this.onAccept,
    required this.onAcceptEssential,
    required this.onShowPrivacyPolicy,
  });

  @override
  State<GdprConsentDialog> createState() => _GdprConsentDialogState();
}

class _GdprConsentDialogState extends State<GdprConsentDialog> {
  bool _analyticsConsent = true;
  bool _adsConsent = true;

  AppColorScheme get c => widget.colors;

  @override
  Widget build(BuildContext context) {
    Widget toggle(bool value, ValueChanged<bool>? onChanged) => Switch(value: value, onChanged: onChanged);
    return CartoonPanel(
      title: 'YOUR PRIVACY',
      color: const Color(0xFF4D7CFE),
      icon: const Text('🔒', style: TextStyle(fontSize: 24)),
      scrollable: true,
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelText(
            'We use a little data to keep the game running, see what to improve, and show ads. You choose what is OK.',
            size: 15,
          ),
          const SizedBox(height: 12),
          PanelRow.emoji(
            '⚙️',
            iconColor: const Color(0xFF7C8DB5),
            title: 'Essential',
            subtitle: 'Needed for the game to work',
            trailing: toggle(true, null),
          ),
          PanelRow.emoji(
            '📊',
            iconColor: const Color(0xFF4D7CFE),
            title: 'Analytics',
            subtitle: 'Anonymous usage data to improve the game',
            trailing: toggle(_analyticsConsent, (v) => setState(() => _analyticsConsent = v)),
          ),
          PanelRow.emoji(
            '🎯',
            iconColor: const Color(0xFFFF9F43),
            title: 'Personalised ads',
            subtitle: 'Ads that match your interests',
            trailing: toggle(_adsConsent, (v) => setState(() => _adsConsent = v)),
          ),
          Center(
            child: TextButton.icon(
              onPressed: widget.onShowPrivacyPolicy,
              icon: const Icon(Icons.description_rounded, size: 18, color: Color(0xFF4D7CFE)),
              label: const Text(
                'Read our privacy policy',
                style: TextStyle(
                  fontFamily: kBodyFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF4D7CFE),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          CartoonButton(
            label: _analyticsConsent && _adsConsent ? 'ACCEPT ALL' : 'SAVE CHOICES',
            onTap: () => widget.onAccept(_analyticsConsent, _adsConsent),
          ),
          const SizedBox(height: 4),
          CartoonButton.secondary(label: 'ESSENTIAL ONLY', onTap: widget.onAcceptEssential),
        ],
      ),
    );
  }
}
