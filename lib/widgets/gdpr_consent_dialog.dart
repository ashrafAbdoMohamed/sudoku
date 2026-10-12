import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('🔒', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Privacy Matters',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: c.text,
                            ),
                          ),
                          Text(
                            'We respect your choices',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Description
                Text(
                  'We use cookies and similar technologies to improve your experience, analyze app usage, and show personalized ads.',
                  style: TextStyle(
                    fontSize: 14,
                    color: c.text,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Consent options
                _buildConsentOption(
                  title: 'Essential',
                  description: 'Required for the app to function properly',
                  icon: '⚙️',
                  value: true,
                  enabled: false,
                  onChanged: null,
                ),
                const SizedBox(height: 12),
                _buildConsentOption(
                  title: 'Analytics',
                  description: 'Help us improve by sharing anonymous usage data',
                  icon: '📊',
                  value: _analyticsConsent,
                  enabled: true,
                  onChanged: (v) => setState(() => _analyticsConsent = v ?? true),
                ),
                const SizedBox(height: 12),
                _buildConsentOption(
                  title: 'Personalized Ads',
                  description: 'Show ads relevant to your interests',
                  icon: '🎯',
                  value: _adsConsent,
                  enabled: true,
                  onChanged: (v) => setState(() => _adsConsent = v ?? true),
                ),
                const SizedBox(height: 24),

                // Privacy Policy link
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onShowPrivacyPolicy();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 16, color: c.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Read our Privacy Policy',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onAcceptEssential();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: c.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Essential Only',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onAccept(_analyticsConsent, _adsConsent);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F6EF7), Color(0xFFA855F7)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _analyticsConsent && _adsConsent ? 'Accept All' : 'Save Choices',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
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
    );
  }

  Widget _buildConsentOption({
    required String title,
    required String description,
    required String icon,
    required bool value,
    required bool enabled,
    required ValueChanged<bool?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeTrackColor: c.primary.withValues(alpha: 0.5),
              activeThumbColor: c.primary,
              inactiveThumbColor: enabled ? null : c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
