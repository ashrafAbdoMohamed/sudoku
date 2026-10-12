import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/board_themes.dart';
import '../state/game_store.dart';
import '../services/rate_app_service.dart';
import '../services/share_service.dart';
import '../services/notification_service.dart';
import 'learning_modal.dart';
import 'achievements_modal.dart';
import 'legal_modal.dart';
import 'theme_picker.dart';

class SettingsModal extends StatefulWidget {
  final GameStore store;
  final AppColorScheme colors;
  final VoidCallback onToggleTheme;
  final VoidCallback? onProfileUpdate;

  const SettingsModal({
    super.key,
    required this.store,
    required this.colors,
    required this.onToggleTheme,
    this.onProfileUpdate,
  });

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  bool _remindersBlocked = false;
  late TextEditingController _nameCtrl;
  late String _selectedColor;
  bool _profileChanged = false;

  AppColorScheme get c => widget.colors;
  GameStore get store => widget.store;

  AppColorScheme _getCurrentColors() {
    final theme = ColorThemes.fromId(store.colorThemeId);
    return AppColors.fromColorTheme(theme, isDark: store.isDark);
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: store.name);
    _selectedColor = store.avatarColor;
    _nameCtrl.addListener(_onProfileChange);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onProfileChange);
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onProfileChange() {
    final nameChanged = _nameCtrl.text.trim() != store.name;
    final colorChanged = _selectedColor != store.avatarColor;
    setState(() => _profileChanged = nameChanged || colorChanged);
  }

  void _saveProfile() {
    if (!_profileChanged) return;
    HapticFeedback.mediumImpact();
    store.updateProfile(_nameCtrl.text.trim(), _selectedColor);
    widget.onProfileUpdate?.call();
    setState(() => _profileChanged = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile updated!'),
        backgroundColor: c.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('⚙️', style: TextStyle(fontSize: 26)),
                      const SizedBox(width: 12),
                      Text(
                        'Settings',
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
            ),
            const SizedBox(height: 20),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    _sectionTitle('Profile'),
                    const SizedBox(height: 12),
                    _buildProfileSection(),
                    const SizedBox(height: 20),

                    // Appearance Section
                    _sectionTitle('Appearance'),
                    const SizedBox(height: 12),
                    _settingRow(
                      icon: store.isDark ? '🌙' : '☀️',
                      title: 'Dark Mode',
                      subtitle: store.isDark ? 'Currently dark' : 'Currently light',
                      trailing: Switch(
                        value: store.isDark,
                        onChanged: (_) {
                          HapticFeedback.selectionClick();
                          widget.onToggleTheme();
                          setState(() {});
                        },
                        activeTrackColor: c.primary.withValues(alpha: 0.5),
                        activeThumbColor: c.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _actionRow(
                      icon: '🎨',
                      title: 'Themes',
                      subtitle: '${ColorThemes.fromId(store.colorThemeId).name} · ${BoardStyles.fromId(store.boardStyleId).name}',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showDialog(
                          context: context,
                          builder: (_) => ThemePickerModal(
                            store: store,
                            colors: _getCurrentColors(),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                    const SizedBox(height: 20),

                    // Sound & Haptics Section
                    _sectionTitle('Sound & Haptics'),
                    const SizedBox(height: 12),
                    _settingRow(
                      icon: '🔊',
                      title: 'Sound Effects',
                      subtitle: store.soundEnabled ? 'Enabled' : 'Disabled',
                      trailing: Switch(
                        value: store.soundEnabled,
                        onChanged: (_) {
                          HapticFeedback.selectionClick();
                          store.toggleSound();
                          setState(() {});
                        },
                        activeTrackColor: c.primary.withValues(alpha: 0.5),
                        activeThumbColor: c.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _settingRow(
                      icon: '📳',
                      title: 'Haptic Feedback',
                      subtitle: store.hapticEnabled ? 'Enabled' : 'Disabled',
                      trailing: Switch(
                        value: store.hapticEnabled,
                        onChanged: (_) {
                          if (store.hapticEnabled) {
                            HapticFeedback.selectionClick();
                          }
                          store.toggleHaptic();
                          setState(() {});
                        },
                        activeTrackColor: c.primary.withValues(alpha: 0.5),
                        activeThumbColor: c.primary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Reminders Section
                    _sectionTitle('Reminders'),
                    const SizedBox(height: 12),
                    _settingRow(
                      icon: '🔔',
                      title: 'Daily Challenge Reminder',
                      subtitle: store.dailyRemindersEnabled
                          ? 'Every day at ${NotificationService.reminderHour - 12}:00 PM'
                          : _remindersBlocked
                              ? 'Allow notifications in system settings'
                              : 'Off',
                      trailing: Switch(
                        value: store.dailyRemindersEnabled,
                        onChanged: (v) async {
                          HapticFeedback.selectionClick();
                          if (v) {
                            final granted = await NotificationService().enableReminders(store, source: 'settings');
                            _remindersBlocked = !granted;
                          } else {
                            await NotificationService().disableReminders(store);
                          }
                          if (mounted) setState(() {});
                        },
                        activeTrackColor: c.primary.withValues(alpha: 0.5),
                        activeThumbColor: c.primary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Help Section
                    _sectionTitle('Help'),
                    const SizedBox(height: 12),
                    _actionRow(
                      icon: '📚',
                      title: 'How to Play',
                      subtitle: 'Learn Sudoku techniques',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (_) => LearningModal(colors: c),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _actionRow(
                      icon: '🏆',
                      title: 'Achievements',
                      subtitle: '${store.unlockedCount}/${store.totalAchievements} unlocked',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (_) => AchievementsModal(
                            store: store,
                            colors: c,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _actionRow(
                      icon: '⭐',
                      title: 'Rate App',
                      subtitle: 'Love the app? Leave a review!',
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final service = RateAppService();
                        await service.openStoreListing();
                      },
                    ),
                    const SizedBox(height: 8),
                    _actionRow(
                      icon: '📤',
                      title: 'Share App',
                      subtitle: 'Invite friends to play Sudoku',
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await ShareService().shareApp();
                      },
                    ),
                    const SizedBox(height: 20),

                    // Legal Section
                    _sectionTitle('Legal'),
                    const SizedBox(height: 12),
                    _actionRow(
                      icon: '🔒',
                      title: 'Privacy Policy',
                      subtitle: 'How we handle your data',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showDialog(
                          context: context,
                          builder: (_) => LegalModal(
                            colors: c,
                            documentType: LegalDocumentType.privacyPolicy,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _actionRow(
                      icon: '📜',
                      title: 'Terms of Service',
                      subtitle: 'Terms and conditions',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showDialog(
                          context: context,
                          builder: (_) => LegalModal(
                            colors: c,
                            documentType: LegalDocumentType.termsOfService,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _actionRow(
                      icon: '🍪',
                      title: 'Privacy Settings',
                      subtitle: 'Manage consent preferences',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showPrivacySettings();
                      },
                    ),
                    const SizedBox(height: 20),

                    // App Info
                    Center(
                      child: Text(
                        'Sudoku v1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar preview and name
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _parseColor(_selectedColor),
                  border: Border.all(
                    color: c.border,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _nameCtrl.text.isNotEmpty
                      ? _nameCtrl.text[0].toUpperCase()
                      : 'P',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR NAME',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      maxLength: 20,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: c.surface,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: c.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Avatar color selection
          Text(
            'AVATAR COLOR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: c.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: avatarColors.map((color) {
              final argb = color.toARGB32();
              final hex = '#${argb.toRadixString(16).substring(2).toUpperCase()}';
              final active = hex == _selectedColor.toUpperCase();
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedColor = hex;
                    _profileChanged = true;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: active ? c.text : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: active
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          // Save button (only shows when changes are made)
          if (_profileChanged) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _saveProfile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F6EF7), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Save Profile',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: c.textMuted,
        letterSpacing: 1,
      ),
    );
  }

  Widget _settingRow({
    required String icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _actionRow({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🍪', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(
                    'Privacy Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildPrivacyToggle(
                title: 'Analytics',
                description: 'Help us improve with anonymous usage data',
                value: store.analyticsConsent,
                onChanged: (v) {
                  store.updateConsent(analytics: v);
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              _buildPrivacyToggle(
                title: 'Personalized Ads',
                description: 'Show ads relevant to your interests',
                value: store.adsConsent,
                onChanged: (v) {
                  store.updateConsent(ads: v);
                  setState(() {});
                },
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F6EF7), Color(0xFFA855F7)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  Widget _buildPrivacyToggle({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: c.primary.withValues(alpha: 0.5),
            activeThumbColor: c.primary,
          ),
        ],
      ),
    );
  }
}
