import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/cartoon_dialog.dart';
import '../game/ui_kit.dart';
import '../services/notification_service.dart';
import '../services/rate_app_service.dart';
import '../services/share_service.dart';
import '../state/game_store.dart';
import '../theme/app_theme.dart';
import 'achievements_modal.dart';
import 'learning_modal.dart';
import 'legal_modal.dart';

class SettingsModal extends StatefulWidget {
  final GameStore store;
  final AppColorScheme colors;
  final VoidCallback onToggleTheme;
  final VoidCallback? onProfileUpdate;

  const SettingsModal({super.key, required this.store, required this.colors, required this.onToggleTheme, this.onProfileUpdate});

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  bool _remindersBlocked = false;
  late final TextEditingController _nameCtrl = TextEditingController(text: store.name);
  late String _selectedColor = store.avatarColor;
  bool _profileChanged = false;

  AppColorScheme get c => widget.colors;
  GameStore get store => widget.store;

  @override
  void initState() {
    super.initState();
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
    FocusScope.of(context).unfocus();
    setState(() => _profileChanged = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved!')));
  }

  Color _parseColor(String hex) => Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  Widget _switch(bool value, ValueChanged<bool> onChanged) => Switch(
    value: value,
    onChanged: (v) {
      HapticFeedback.selectionClick();
      onChanged(v);
    },
  );

  @override
  Widget build(BuildContext context) {
    return CartoonPanel(
      title: 'SETTINGS',
      color: const Color(0xFF4D7CFE),
      onClose: () => Navigator.pop(context),
      width: 400,
      scrollable: true,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelSection('Profile'),
          _profile(),
          const PanelSection('Sound & feel'),
          PanelRow(
            icon: GameIcon(store.soundEnabled ? GameIcons.soundOn : GameIcons.soundOff, size: 28),
            iconColor: const Color(0xFF4D7CFE),
            title: 'Sound effects',
            trailing: _switch(store.soundEnabled, (_) => setState(store.toggleSound)),
          ),
          PanelRow.emoji(
            '📳',
            iconColor: const Color(0xFF1FB5A8),
            title: 'Vibration',
            trailing: _switch(store.hapticEnabled, (_) => setState(store.toggleHaptic)),
          ),
          GestureDetector(
            // Debug builds: long-press sends every kind of reminder, 5s apart.
            onLongPress: kDebugMode ? NotificationService().debugPreview : null,
            child: PanelRow.emoji(
              '🔔',
              iconColor: const Color(0xFFFF9F43),
              title: 'Reminders',
              subtitle: store.dailyRemindersEnabled
                  ? 'Daily puzzle and streak, max one a day'
                  : _remindersBlocked
                  ? 'Allow notifications in system settings'
                  : 'Off',
              trailing: _switch(store.dailyRemindersEnabled, (v) async {
                if (v) {
                  final granted = await NotificationService().enableReminders(store, source: 'settings');
                  _remindersBlocked = !granted;
                } else {
                  await NotificationService().disableReminders(store);
                }
                if (mounted) setState(() {});
              }),
            ),
          ),
          const PanelSection('Help'),
          PanelRow.emoji(
            '📚',
            iconColor: const Color(0xFF3FB26B),
            title: 'How to play',
            subtitle: 'Rules and solving tricks',
            onTap: () {
              Navigator.pop(context);
              showCartoonDialog<void>(context, builder: (_) => LearningModal(colors: c));
            },
          ),
          PanelRow.emoji(
            '🏆',
            iconColor: const Color(0xFFFFC23D),
            title: 'Awards',
            subtitle: '${store.unlockedCount}/${store.totalAchievements} unlocked',
            onTap: () {
              Navigator.pop(context);
              showCartoonDialog<void>(
                context,
                builder: (_) => AchievementsModal(store: store, colors: c),
              );
            },
          ),
          PanelRow.emoji(
            '⭐',
            iconColor: const Color(0xFFFFC23D),
            title: 'Rate the game',
            subtitle: 'Enjoying it? A review helps a lot!',
            onTap: () => RateAppService().openStoreListing(),
          ),
          PanelRow.emoji('📤', iconColor: const Color(0xFF4D7CFE), title: 'Share with friends', onTap: () => ShareService().shareApp()),
          const PanelSection('Privacy'),
          PanelRow.emoji(
            '🔒',
            iconColor: const Color(0xFF7C8DB5),
            title: 'Privacy policy',
            onTap: () => showCartoonDialog<void>(
              context,
              builder: (_) => LegalModal(colors: c, documentType: LegalDocumentType.privacyPolicy),
            ),
          ),
          PanelRow.emoji(
            '📜',
            iconColor: const Color(0xFF7C8DB5),
            title: 'Terms of service',
            onTap: () => showCartoonDialog<void>(
              context,
              builder: (_) => LegalModal(colors: c, documentType: LegalDocumentType.termsOfService),
            ),
          ),
          PanelRow.emoji(
            '🍪',
            iconColor: const Color(0xFF7C8DB5),
            title: 'Privacy choices',
            subtitle: 'Analytics and ads',
            onTap: _showPrivacySettings,
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Sudoku v1.0.3',
              style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: Color(0xFF8A7A9E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profile() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0DFC0), width: 2),
        boxShadow: const [BoxShadow(color: Color(0xFFF0DFC0), offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _parseColor(_selectedColor),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Color.lerp(_parseColor(_selectedColor), Colors.black, 0.35)!, offset: const Offset(0, 3))],
                ),
                alignment: Alignment.center,
                child: OutlinedText(
                  _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'P',
                  size: 24,
                  stroke: Color.lerp(_parseColor(_selectedColor), Colors.black, 0.45)!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  maxLength: 20,
                  style: const TextStyle(fontFamily: kBodyFont, fontSize: 17, fontWeight: FontWeight.w700, color: CartoonPanel.ink),
                  decoration: InputDecoration(
                    labelText: 'Your name',
                    labelStyle: const TextStyle(fontFamily: kBodyFont, color: Color(0xFF8A7A9E)),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFFFF8EA),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFF0DFC0), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFF0DFC0), width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF8E5BEA), width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final color in avatarColors) _avatarDot(color)]),
          if (_profileChanged) ...[const SizedBox(height: 12), CartoonButton(label: 'SAVE', height: 48, size: 19, onTap: _saveProfile)],
        ],
      ),
    );
  }

  Widget _avatarDot(Color color) {
    final hex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    final active = hex == _selectedColor.toUpperCase();
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedColor = hex;
          _profileChanged = _nameCtrl.text.trim() != store.name || hex != store.avatarColor;
        });
      },
      child: AnimatedScale(
        scale: active ? 1.15 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: active ? CartoonPanel.ink : Colors.white, width: 3),
          ),
          child: active ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
        ),
      ),
    );
  }

  void _showPrivacySettings() {
    showCartoonDialog<void>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => CartoonPanel(
          title: 'PRIVACY',
          color: const Color(0xFF7C8DB5),
          onClose: () => Navigator.pop(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PanelRow.emoji(
                '📊',
                iconColor: const Color(0xFF4D7CFE),
                title: 'Analytics',
                subtitle: 'Anonymous usage data to improve the game',
                trailing: _switch(store.analyticsConsent, (v) {
                  store.updateConsent(analytics: v);
                  setLocal(() {});
                }),
              ),
              PanelRow.emoji(
                '🎯',
                iconColor: const Color(0xFFFF9F43),
                title: 'Personalised ads',
                subtitle: 'Ads that match your interests',
                trailing: _switch(store.adsConsent, (v) {
                  store.updateConsent(ads: v);
                  setLocal(() {});
                }),
              ),
              const SizedBox(height: 8),
              CartoonButton(label: 'DONE', onTap: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}
