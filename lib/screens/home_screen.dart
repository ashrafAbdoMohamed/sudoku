import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/board_themes.dart';
import '../state/game_store.dart';
import '../state/game_state.dart';
import '../screens/game_screen.dart';
import '../widgets/challenge_modal.dart';
import '../widgets/achievements_modal.dart';
import '../widgets/statistics_modal.dart';
import '../widgets/settings_modal.dart';
import '../widgets/learning_modal.dart';
import '../widgets/banner_ad_widget.dart';
import '../utils/daily_challenge.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/ad_service.dart';

class HomeScreen extends StatefulWidget {
  final GameStore store;
  final GameState gameState;
  final VoidCallback onToggleTheme;
  final String? initialChallengePin; // Deep link challenge PIN

  const HomeScreen({
    super.key,
    required this.store,
    required this.gameState,
    required this.onToggleTheme,
    this.initialChallengePin,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _difficulty = 'easy';
  Timer? _countdownTimer;
  Duration _timeUntilNextDaily = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    // Update countdown every second if daily is completed
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (store.hasCompletedDailyToday) {
        _updateCountdown();
      }
    });

    // Auto-show challenge modal if opened via deep link
    if (widget.initialChallengePin != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showChallengeModal(initialPin: widget.initialChallengePin);
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    setState(() {
      _timeUntilNextDaily = DailyChallenge.timeUntilNextDaily();
    });
  }

  GameStore get store => widget.store;
  AppColorScheme get colors {
    final theme = ColorThemes.fromId(store.colorThemeId);
    return AppColors.fromColorTheme(theme, isDark: store.isDark);
  }

  // Difficulty icons
  static const _diffIcons = {
    'easy': '🌱',
    'medium': '🔥',
    'hard': '💪',
    'expert': '🏆',
  };

  Future<void> _navigateToGame({int? seed, String? pin, String? diff, bool isOnline = false, bool isDaily = false}) {
    final d = diff ?? _difficulty;
    widget.gameState.newGame(d, seed: seed, pin: pin, online: isOnline, isDaily: isDaily);
    AnalyticsService().logGameStart(difficulty: d, mode: widget.gameState.mode);
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          store: store,
          gameState: widget.gameState,
          onToggleTheme: widget.onToggleTheme,
          isOnlineChallenge: isOnline,
          isDailyChallenge: isDaily,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _startDailyChallenge() {
    if (store.hasCompletedDailyToday) return;
    store.clearSavedGame();
    _navigateToGame(
      diff: DailyChallenge.todayDifficulty,
      seed: DailyChallenge.todaySeed,
      isDaily: true,
    ).then((_) => _afterDailyChallenge());
  }

  void _afterDailyChallenge() {
    if (!mounted) return;
    NotificationService().reschedule(store);

    // Offer reminders once, right after the first solved daily - the moment
    // the player has a streak worth protecting
    if (store.hasCompletedDailyToday && !store.dailyRemindersEnabled && !store.reminderPromptShown) {
      store.markReminderPromptShown();
      _showReminderPrompt();
    }
  }

  void _showReminderPrompt() {
    final c = colors;
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔔', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text(
                'Never miss a daily puzzle',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.text),
              ),
              const SizedBox(height: 8),
              Text(
                "Get one reminder at ${NotificationService.reminderHour - 12}:00 PM when you haven't played yet, so your streak stays alive.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  Navigator.pop(dialogContext);
                  await NotificationService().enableReminders(store, source: 'prompt');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4F6EF7), Color(0xFFA855F7)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Remind Me',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Not now', style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _continueGame() {
    if (store.savedGame == null) return;
    widget.gameState.loadFromSaved(store.savedGame!);
    AnalyticsService().logGameResume(difficulty: widget.gameState.difficulty);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(store: store, gameState: widget.gameState, onToggleTheme: widget.onToggleTheme),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(c),
                  const SizedBox(height: 20),
                  // 1. Time-sensitive - Daily Challenge
                  _buildDailyChallengeCard(c),
                  const SizedBox(height: 16),
                  // 2. Challenge a Friend - Highlighted card
                  _buildChallengeFriendCard(c),
                  const SizedBox(height: 16),
                  // 3. New Puzzle
                  _buildPlaySection(c),
                  const SizedBox(height: 20),
                  // 4. Quick Stats Overview
                  _buildStats(c),
                  const SizedBox(height: 20),
                  // 5. Historical Data
                  _sectionLabel('Recent Scores', c),
                  const SizedBox(height: 9),
                  _buildScores(c),
                  const SizedBox(height: 20),
                  // Banner Ad (keyed so it reloads once the ads SDK finishes starting)
                  BannerAdWidget(key: ValueKey(AdService().isInitialized)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorScheme c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF4F6EF7), Color(0xFFA855F7)],
          ).createShader(bounds),
          child: const Text('Sudoku', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1.5, color: Colors.white)),
        ),
        Row(
          children: [
            // _iconButton('📚', _showLearning, c),
            // const SizedBox(width: 8),
            _achievementsButton(c),
            const SizedBox(width: 8),
            _iconButton('⚙️', _showSettings, c),
          ],
        ),
      ],
    );
  }

  Widget _iconButton(String icon, VoidCallback onTap, AppColorScheme c) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.surface,
          border: Border.all(color: c.border),
        ),
        alignment: Alignment.center,
        child: Text(icon, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _achievementsButton(AppColorScheme c) {
    final progress = store.achievementProgress;

    return GestureDetector(
      onTap: _showAchievements,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.surface,
          border: Border.all(color: c.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 16)),
            // Progress ring
            if (progress > 0 && progress < 1)
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(c.primary.withValues(alpha: 0.6)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAchievements() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (_) => AchievementsModal(
        store: store,
        colors: colors,
      ),
    );
  }

  void _showLearning() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (_) => LearningModal(colors: colors),
    );
  }

  void _showSettings() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (_) => SettingsModal(
        store: store,
        colors: colors,
        onToggleTheme: widget.onToggleTheme,
        onProfileUpdate: () => setState(() {}),
      ),
    );
  }

  Widget _buildProfileCard(AppColorScheme c) {
    final color = _parseColor(store.avatarColor);
    return GestureDetector(
      onTap: _showSettings,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4F6EF7), Color(0xFF7C3AED)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF4F6EF7).withValues(alpha:0.38), blurRadius: 32, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white.withValues(alpha:0.3), width: 3),
              ),
              alignment: Alignment.center,
              child: Text(
                store.name.isNotEmpty ? store.name[0].toUpperCase() : 'P',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 3),
                  Text('${store.rankIcon} ${store.rankName}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha:0.65))),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${store.won} win${store.won != 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha:0.9))),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.18),
                border: Border.all(color: Colors.white.withValues(alpha:0.28)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(AppColorScheme c) {
    return GestureDetector(
      onTap: _showStatistics,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: c.primary.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _statCard('${store.played}', 'Played', Icons.grid_3x3_rounded, c)),
                _verticalStatDivider(c),
                Expanded(child: _statCard('${store.won}', 'Won', Icons.emoji_events_outlined, c)),
                _verticalStatDivider(c),
                Expanded(child: _statCard(store.winRate, 'Win Rate', Icons.percent_rounded, c)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 16, color: c.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Tap for detailed statistics',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 12, color: c.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalStatDivider(AppColorScheme c) {
    return Container(
      width: 1,
      height: 40,
      color: c.border,
    );
  }

  Widget _statCard(String value, String label, IconData icon, AppColorScheme c) {
    return Column(
      children: [
        Icon(icon, size: 18, color: c.primary.withValues(alpha: 0.7)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.primary)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.textMuted)),
      ],
    );
  }

  void _showStatistics() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (_) => StatisticsModal(
        store: store,
        colors: colors,
      ),
    );
  }

  Widget _buildDailyChallengeCard(AppColorScheme c) {
    final completed = store.hasCompletedDailyToday;
    final todayTime = store.todayDailyTime;
    final difficulty = DailyChallenge.todayDifficulty;
    final streak = store.currentStreak;
    final longestStreak = store.longestStreak;

    return GestureDetector(
      onTap: completed ? null : _startDailyChallenge,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: completed
              ? LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade700])
              : const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (completed ? Colors.grey : const Color(0xFFFF6B6B)).withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('📅', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Challenge',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${DailyChallenge.difficultyDisplayName(difficulty)} difficulty',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (completed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _fmtTime(todayTime ?? 0),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Play',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        DailyChallenge.streakEmoji(streak),
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$streak day${streak != 1 ? 's' : ''} streak',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            DailyChallenge.streakMessage(streak),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Best: $longestStreak days',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      if (completed)
                        Text(
                          'Next in ${DailyChallenge.formatDuration(_timeUntilNextDaily)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!store.canMaintainStreak && !completed) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.yellow.shade200, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Play today to start a new streak!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.yellow.shade200,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaySection(AppColorScheme c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F6EF7), Color(0xFFA855F7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.grid_3x3_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Puzzle',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: c.text,
                        ),
                      ),
                      Text(
                        'Select difficulty and start playing',
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
          ),

          // Difficulty cards - 2x2 grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildDifficultyGrid(c),
          ),
          const SizedBox(height: 14),

          // Main play button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _buildMainPlayButton(c),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyGrid(AppColorScheme c) {
    final diffColors = {
      'easy': const Color(0xFF10B981),
      'medium': const Color(0xFF3B82F6),
      'hard': const Color(0xFFF59E0B),
      'expert': const Color(0xFFEF4444),
    };
    final diffClues = {
      'easy': '32-37 clues',
      'medium': '30-31 clues',
      'hard': '25-29 clues',
      'expert': '22-24 clues',
    };

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDifficultyCard('easy', diffColors, diffClues, c)),
            const SizedBox(width: 10),
            Expanded(child: _buildDifficultyCard('medium', diffColors, diffClues, c)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildDifficultyCard('hard', diffColors, diffClues, c)),
            const SizedBox(width: 10),
            Expanded(child: _buildDifficultyCard('expert', diffColors, diffClues, c)),
          ],
        ),
      ],
    );
  }

  Widget _buildDifficultyCard(
    String diff,
    Map<String, Color> diffColors,
    Map<String, String> diffClues,
    AppColorScheme c,
  ) {
    final isSelected = diff == _difficulty;
    final color = diffColors[diff]!;
    final icon = _diffIcons[diff] ?? '🎮';
    final clues = diffClues[diff] ?? '';
    final bestTime = store.bestTimes[diff];
    final stats = store.getStatsForDifficulty(diff);
    final winRate = stats.played > 0 ? (stats.winRate * 100).toInt() : null;

    // Check if there's a saved game for this difficulty
    final hasSavedGame = store.savedGame?.difficulty == diff;
    final savedTime = hasSavedGame ? store.savedGame!.seconds : 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _difficulty = diff);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (hasSavedGame ? c.primary : c.border),
            width: isSelected ? 2.5 : (hasSavedGame ? 2 : 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 20)),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  )
                else if (winRate != null)
                  Text(
                    '$winRate%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              diff[0].toUpperCase() + diff.substring(1),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              clues,
              style: TextStyle(
                fontSize: 10,
                color: c.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Best time or Continue indicator
                if (hasSavedGame) ...[
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _continueGame();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F6EF7), Color(0xFFA855F7)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            _fmtTime(savedTime),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 12,
                    color: bestTime != null ? c.primary : c.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    bestTime != null ? _fmtTime(bestTime) : 'No record',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: bestTime != null ? c.text : c.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPlayButton(AppColorScheme c) {
    final icon = _diffIcons[_difficulty] ?? '🎮';

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        store.clearSavedGame();
        _navigateToGame();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F6EF7), Color(0xFFA855F7)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F6EF7).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
            const SizedBox(width: 8),
            Text(
              'New Game',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '($icon ${_difficulty[0].toUpperCase()}${_difficulty.substring(1)})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeFriendCard(AppColorScheme c) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showChallengeModal();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF72585), Color(0xFF7209B7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF72585).withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('⚔️', style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Challenge a Friend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compete on the same puzzle!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Play',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF72585),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, AppColorScheme c) {
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.textMuted, letterSpacing: 1));
  }

  Widget _buildScores(AppColorScheme c) {
    if (store.scores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text('No games played yet.\nStart your first puzzle!', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.textMuted)),
      );
    }
    return Column(
      children: store.scores.take(10).map((s) {
        final badge = _diffBadge(s.diff, c);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: c.primary.withValues(alpha:0.1), blurRadius: 24, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badge.$1, borderRadius: BorderRadius.circular(6)),
                child: Text(s.diff.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: badge.$2, letterSpacing: 0.4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fmtTime(s.time), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                    Text('${s.mistakes} mistake${s.mistakes != 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: c.textMuted)),
                  ],
                ),
              ),
              Text(s.date, style: TextStyle(fontSize: 11, color: c.textMuted)),
            ],
          ),
        );
      }).toList(),
    );
  }

  (Color, Color) _diffBadge(String diff, AppColorScheme c) {
    final isDark = store.isDark;
    switch (diff) {
      case 'easy':
        return isDark ? (DiffBadgeColors.easyDark.bg, DiffBadgeColors.easyDark.text) : (DiffBadgeColors.easy.bg, DiffBadgeColors.easy.text);
      case 'medium':
        return isDark ? (DiffBadgeColors.mediumDark.bg, DiffBadgeColors.mediumDark.text) : (DiffBadgeColors.medium.bg, DiffBadgeColors.medium.text);
      case 'hard':
        return isDark ? (DiffBadgeColors.hardDark.bg, DiffBadgeColors.hardDark.text) : (DiffBadgeColors.hard.bg, DiffBadgeColors.hard.text);
      case 'expert':
        return isDark ? (DiffBadgeColors.expertDark.bg, DiffBadgeColors.expertDark.text) : (DiffBadgeColors.expert.bg, DiffBadgeColors.expert.text);
      default:
        return (c.surface2, c.textMuted);
    }
  }

  void _showChallengeModal({String? initialPin}) {
    showDialog(
      context: context,
      builder: (_) => ChallengeModal(
        colors: colors,
        isDark: store.isDark,
        playerName: store.name,
        initialPin: initialPin,
        onStartChallenge: (diff, seed, pin) {
          Navigator.of(context).pop();
          _navigateToGame(diff: diff, seed: seed, pin: pin);
        },
        onStartOnlineChallenge: (diff, seed, pin, isOnline) {
          _navigateToGame(diff: diff, seed: seed, pin: pin, isOnline: isOnline);
        },
      ),
    );
  }

  String _fmtTime(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

