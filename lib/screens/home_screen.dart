import 'dart:async';

import 'package:flutter/material.dart';

import '../game/cartoon_dialog.dart';
import '../game/free_coins.dart';
import '../game/fx.dart';
import '../game/home_backdrop.dart';
import '../game/rank_badge.dart';
import '../game/ui_kit.dart';
import '../models/progression.dart';
import '../screens/game_screen.dart';
import '../screens/journey_screen.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';
import '../state/game_state.dart';
import '../state/game_store.dart';
import '../theme/app_theme.dart';
import '../utils/daily_challenge.dart';
import '../widgets/achievements_modal.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/challenge_modal.dart';
import '../widgets/settings_modal.dart';
import '../widgets/statistics_modal.dart';

/// The cartoon Home: rank badge, PLAY (the next Journey level, or the saved
/// game), Challenge a Friend, and the Journey and Daily tiles.
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
  GameStore get store => widget.store;

  /// The old look's colours, still used by the modals (settings, stats...).
  AppColorScheme get colors {
    return AppColors.cartoon;
  }

  @override
  void initState() {
    super.initState();
    // Auto-show challenge modal if opened via deep link
    if (widget.initialChallengePin != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showChallengeModal(initialPin: widget.initialChallengePin);
      });
    }
  }

  // ─── Starting games ───

  Future<void> _navigateToGame({
    required String diff,
    int? seed,
    String? pin,
    bool isOnline = false,
    bool isDaily = false,
    int? journeyLevel,
  }) {
    widget.gameState.newGame(diff, seed: seed, pin: pin, online: isOnline, isDaily: isDaily, journeyLevel: journeyLevel);
    AnalyticsService().logGameStart(difficulty: diff, mode: widget.gameState.mode);
    return Navigator.of(context).push(
      FadeScaleRoute(
        builder: (_) => GameScreen(
          store: store,
          gameState: widget.gameState,
          onToggleTheme: widget.onToggleTheme,
          isOnlineChallenge: isOnline,
          isDailyChallenge: isDaily,
        ),
      ),
    );
  }

  void _playJourneyLevel(int level) {
    SoundService().playTap();
    store.clearSavedGame();
    _navigateToGame(diff: difficultyForLevel(level), seed: seedForLevel(level), journeyLevel: level);
  }

  void _playFreePlay(String diff) {
    store.clearSavedGame();
    _navigateToGame(diff: diff);
  }

  /// PLAY: the saved game if there is one, else the next Journey level.
  void _play() {
    if (store.savedGame != null) {
      _continueGame();
    } else {
      _playJourneyLevel(store.journeyNext);
    }
  }

  void _continueGame() {
    if (store.savedGame == null) return;
    SoundService().playTap();
    widget.gameState.loadFromSaved(store.savedGame!);
    AnalyticsService().logGameResume(difficulty: widget.gameState.difficulty);
    Navigator.of(context).push(
      FadeScaleRoute(
        builder: (_) => GameScreen(store: store, gameState: widget.gameState, onToggleTheme: widget.onToggleTheme),
      ),
    );
  }

  void _startDailyChallenge() {
    if (store.hasCompletedDailyToday) return;
    SoundService().playTap();
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

  void _openJourney() {
    SoundService().playTap();
    Navigator.of(context).push(
      FadeScaleRoute(
        builder: (_) => JourneyScreen(store: store, onPlayLevel: _playJourneyLevel, onFreePlay: _playFreePlay),
      ),
    );
  }

  // ─── Popups ───

  void _showReminderPrompt() {
    showCartoonDialog<void>(
      context,
      builder: (dialogContext) => CartoonPanel(
        title: 'DAILY REMINDER',
        color: const Color(0xFFFF9F43),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 6),
            PanelText(
              "Get one reminder at ${NotificationService.reminderHour - 12}:00 PM on days you haven't played yet, so your streak stays alive.",
            ),
            const SizedBox(height: 18),
            CartoonButton(
              label: 'REMIND ME',
              onTap: () async {
                Navigator.pop(dialogContext);
                await NotificationService().enableReminders(store, source: 'prompt');
              },
            ),
            const SizedBox(height: 4),
            CartoonButton.secondary(label: 'NOT NOW', onTap: () => Navigator.pop(dialogContext)),
          ],
        ),
      ),
    );
  }

  void _showAchievements() {
    showCartoonDialog<void>(context, builder: (_) => AchievementsModal(store: store, colors: colors));
  }

  void _showStatistics() {
    showCartoonDialog<void>(context, builder: (_) => StatisticsModal(store: store, colors: colors));
  }

  void _showSettings() {
    SoundService().playTap();
    showCartoonDialog<void>(
      context,
      builder: (_) => SettingsModal(
        store: store,
        colors: colors,
        onToggleTheme: widget.onToggleTheme,
        onProfileUpdate: () => setState(() {}),
      ),
    );
  }

  void _showChallengeModal({String? initialPin}) {
    showCartoonDialog<void>(
      context,
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

  // ─── Layout ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: HomeBackdrop()),
          SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) => Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      // Scrolls only on screens too short to fit everything.
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                              child: Column(
                                children: [
                                  Entrance(from: const Offset(0.6, 0), child: _topBar()),
                                  const SizedBox(height: 18),
                                  Entrance(
                                    delay: const Duration(milliseconds: 300),
                                    from: Offset.zero,
                                    curve: Curves.elasticOut,
                                    duration: const Duration(milliseconds: 900),
                                    child: RankBadge(store: store, onStats: _showStatistics, onAwards: _showAchievements),
                                  ),
                                  const Spacer(),
                                  const SizedBox(height: 16),
                                  Entrance(
                                    delay: const Duration(milliseconds: 450),
                                    from: const Offset(0, 0.6),
                                    child: _playButton(),
                                  ),
                                  const SizedBox(height: 14),
                                  Entrance(
                                    delay: const Duration(milliseconds: 520),
                                    from: const Offset(0, 0.6),
                                    child: _challengeButton(),
                                  ),
                                  const SizedBox(height: 30),
                                  Entrance(
                                    delay: const Duration(milliseconds: 600),
                                    from: const Offset(0, 0.6),
                                    child: Row(
                                      children: [
                                        Expanded(child: _journeyTile()),
                                        const SizedBox(width: 14),
                                        Expanded(child: _dailyTile()),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Banner ad (keyed so it reloads once the ads SDK has started)
                  SafeArea(top: false, child: BannerAdWidget(key: ValueKey(AdService().isInitialized))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        PressScale(
          child: GestureDetector(
            onTap: _showSettings,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFF3E6FA8),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0xFF2B4E7A), offset: Offset(0, 4))],
              ),
              child: const Icon(Icons.settings_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
        const SizedBox(width: 10),
        StreakPill(days: store.currentStreak, onTap: _startDailyChallenge),
        const Spacer(),
        CoinPill(coins: store.coins, onAdd: () => showFreeCoins(context, store)),
      ],
    );
  }

  Widget _playButton() {
    final saved = store.savedGame;
    final label = saved != null ? 'CONTINUE' : 'PLAY';
    final detail = saved != null ? _capitalized(saved.difficulty) : 'Level ${store.journeyNext}';
    return ChunkyButton(
      color: const Color(0xFFFF8A3D),
      height: 74,
      onTap: _play,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
          const SizedBox(width: 8),
          OutlinedText(label, size: 36, stroke: const Color(0xFFB04C12)),
          const SizedBox(width: 14),
          Text(
            detail,
            style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 22, color: Color(0xFF7A2E00)),
          ),
        ],
      ),
    );
  }

  Widget _challengeButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ChunkyButton(
          color: const Color(0xFF17B3C4),
          height: 66,
          onTap: () {
            SoundService().playTap();
            _showChallengeModal();
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VersusIcon(),
              SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: OutlinedText('CHALLENGE A FRIEND', size: 24, stroke: Color(0xFF08606C)),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -10,
          right: 18,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Text('LIVE RACE', style: TextStyle(fontFamily: kTitleFont, fontSize: 13, color: Color(0xFF7A4A00))),
          ),
        ),
      ],
    );
  }

  Widget _journeyTile() {
    final stage = store.journeyStage;
    final done = List.generate(levelsPerStage, (i) => stage * levelsPerStage + i + 1).where(store.isJourneyCleared).length;
    return _Tile(
      color: const Color(0xFF8E5BEA),
      ink: const Color(0xFF4A2896),
      art: const GameIcon(GameIcons.chestClosed, size: 78),
      title: 'JOURNEY',
      subtitle: 'Stage ${stage + 1} · $done/$levelsPerStage',
      onTap: _openJourney,
    );
  }

  Widget _dailyTile() {
    final done = store.hasCompletedDailyToday;
    return _Tile(
      color: done ? const Color(0xFF9AA3B5) : const Color(0xFFFF8A4C),
      ink: done ? const Color(0xFF5B6478) : const Color(0xFFA8400D),
      art: GameIcon(GameIcons.trophy, size: 74, greyed: done),
      title: done ? 'DONE!' : 'DAILY',
      subtitle: done ? null : _capitalized(DailyChallenge.todayDifficulty),
      footer: done ? const _DailyCountdown() : null,
      badge: !done,
      onTap: done ? null : _startDailyChallenge,
    );
  }

  static String _capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// A big tile with art popping out of its top: Journey, Daily.
class _Tile extends StatelessWidget {
  final Color color;
  final Color ink;
  final Widget art;
  final String title;
  final String? subtitle;
  final Widget? footer;
  final bool badge;
  final VoidCallback? onTap;
  const _Tile({
    required this.color,
    required this.ink,
    required this.art,
    required this.title,
    this.subtitle,
    this.footer,
    this.badge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      pressed: 0.94,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 150,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned.fill(
                top: 26,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: Color.lerp(color, Colors.black, 0.35)!, offset: const Offset(0, 6))],
                  ),
                  padding: const EdgeInsets.only(bottom: 10),
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedText(title, size: 22, stroke: ink),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                        ),
                      ?footer,
                    ],
                  ),
                ),
              ),
              Positioned(top: 0, child: art),
              if (badge)
                Positioned(
                  top: 18,
                  right: -4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5484D),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: const Text('!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two player avatars facing off with a lightning bolt: "versus".
class _VersusIcon extends StatelessWidget {
  const _VersusIcon();

  @override
  Widget build(BuildContext context) {
    Widget avatar(Color color) => Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.antiAlias,
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
    );
    return SizedBox(
      width: 62,
      height: 42,
      child: Stack(
        children: [
          Positioned(left: 0, top: 2, child: avatar(const Color(0xFFFF9F43))),
          Positioned(right: 0, top: 2, child: avatar(const Color(0xFF8E5BEA))),
          Positioned(
            left: 20,
            top: 9,
            child: Container(
              width: 22,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFFB85C00), size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Next in 5h 12m" until tomorrow's daily. Its own timer, once a minute, so
/// the rest of Home isn't rebuilt every second.
class _DailyCountdown extends StatefulWidget {
  const _DailyCountdown();

  @override
  State<_DailyCountdown> createState() => _DailyCountdownState();
}

class _DailyCountdownState extends State<_DailyCountdown> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = DailyChallenge.timeUntilNextDaily();
    final h = left.inHours, m = left.inMinutes % 60;
    return Text(
      h > 0 ? 'Next in ${h}h ${m}m' : 'Next in ${m}m',
      style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
    );
  }
}
