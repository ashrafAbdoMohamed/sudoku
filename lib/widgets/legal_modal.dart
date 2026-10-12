import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

enum LegalDocumentType { privacyPolicy, termsOfService }

class LegalModal extends StatelessWidget {
  final AppColorScheme colors;
  final LegalDocumentType documentType;

  const LegalModal({
    super.key,
    required this.colors,
    required this.documentType,
  });

  AppColorScheme get c => colors;

  String get _title => documentType == LegalDocumentType.privacyPolicy
      ? 'Privacy Policy'
      : 'Terms of Service';

  String get _icon => documentType == LegalDocumentType.privacyPolicy
      ? '🔒'
      : '📜';

  String get _content => documentType == LegalDocumentType.privacyPolicy
      ? _privacyPolicyContent
      : _termsOfServiceContent;

  // Hosted from legal/ via Firebase Hosting
  String get _webUrl => documentType == LegalDocumentType.privacyPolicy
      ? 'https://sudoku-96650.web.app/privacy-policy'
      : 'https://sudoku-96650.web.app/terms-of-service';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _buildContent(),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(_icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Text(
                _title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: c.text,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 20, color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final sections = _content.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        if (section.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              section.substring(2),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
          );
        } else if (section.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              section.substring(3),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              section,
              style: TextStyle(
                fontSize: 13,
                color: c.text,
                height: 1.6,
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                final uri = Uri.parse(_webUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_new, size: 16, color: c.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'View Online',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F6EF7), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Got It',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Privacy Policy Content
  // ─────────────────────────────────────────────────────────────────────────────

  static const String _privacyPolicyContent = '''
# Privacy Policy

Last updated: January 2025

## Introduction

Welcome to Sudoku ("we," "our," or "us"). We respect your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and safeguard your information when you use our mobile application.

## Information We Collect

**Device Information**
We collect a unique device identifier to enable features like leaderboards and game progress syncing. This identifier is randomly generated and cannot be used to personally identify you.

**Gameplay Data**
We collect anonymous gameplay statistics including:
• Games played and completed
• Completion times and scores
• Achievement progress
• Daily challenge streaks

**Analytics Data (with consent)**
If you consent, we collect anonymous usage analytics to improve the app experience, including:
• App usage patterns
• Feature engagement
• Crash reports

## How We Use Your Information

We use the collected information to:
• Provide and maintain our services
• Enable leaderboard and tournament features
• Track your achievements and progress
• Improve our app and user experience
• Send push notifications (with your permission)

## Data Storage and Security

Your gameplay data is stored locally on your device and synced to our secure servers (Firebase) for leaderboard features. We implement appropriate security measures to protect your data.

## Third-Party Services

Our app may use third-party services that collect information:
• Firebase (Google) - for data storage and analytics
• Ad networks - for displaying advertisements (with consent)

## Children's Privacy

Our app is suitable for all ages. We do not knowingly collect personal information from children under 13 without parental consent.

## Your Rights

You have the right to:
• Access your data
• Delete your data
• Opt-out of analytics and personalized ads
• Withdraw consent at any time

## Changes to This Policy

We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy in the app.

## Contact Us

If you have questions about this privacy policy, please contact us at:
rocketgamestation.dev@gmail.com
''';

  // ─────────────────────────────────────────────────────────────────────────────
  // Terms of Service Content
  // ─────────────────────────────────────────────────────────────────────────────

  static const String _termsOfServiceContent = '''
# Terms of Service

Last updated: January 2025

## Agreement to Terms

By downloading, installing, or using the Sudoku app ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use the App.

## Description of Service

Sudoku is a puzzle game application that provides:
• Classic Sudoku puzzles at various difficulty levels
• Daily challenges and tournaments
• Leaderboards and achievements
• Multiplayer challenge features

## User Conduct

You agree not to:
• Use the App for any unlawful purpose
• Attempt to gain unauthorized access to our systems
• Interfere with other users' enjoyment of the App
• Submit false information to leaderboards
• Reverse engineer or attempt to extract the source code

## Intellectual Property

All content in the App, including but not limited to graphics, logos, and software, is owned by us and protected by intellectual property laws. You may not copy, modify, or distribute any content without our permission.

## In-App Purchases

Some features may require in-app purchases. All purchases are final and non-refundable, except as required by applicable law. Prices are subject to change.

## Advertisements

The App may display advertisements. By using the App, you agree to receive such advertisements. You can opt out of personalized ads through the App settings.

## Disclaimer of Warranties

The App is provided "as is" without warranties of any kind. We do not guarantee that the App will be error-free, secure, or continuously available.

## Limitation of Liability

To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the App.

## Termination

We reserve the right to terminate or suspend your access to the App at any time, without notice, for any reason.

## Changes to Terms

We may modify these Terms at any time. Continued use of the App after changes constitutes acceptance of the new Terms.

## Governing Law

These Terms shall be governed by and construed in accordance with the laws of your jurisdiction.

## Contact Us

For questions about these Terms, please contact us at:
rocketgamestation.dev@gmail.com
''';
}
