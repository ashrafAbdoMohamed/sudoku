import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../game/cartoon_dialog.dart';
import '../game/free_coins.dart';
import '../game/fx.dart';
import '../game/game_backdrop.dart';
import '../game/rank_up.dart';
import '../game/ui_kit.dart';
import '../game/win_overlay.dart';
import '../models/progression.dart';
import '../state/game_store.dart';
import '../state/game_state.dart';
import '../widgets/opponent_progress.dart';
import '../widgets/achievements_modal.dart';
import '../widgets/coach_marks_overlay.dart';
import '../services/online_challenge_service.dart';
import '../services/analytics_service.dart';
import '../services/share_service.dart';
import '../services/leaderboard_service.dart';
import '../services/sound_service.dart';
import '../services/rate_app_service.dart';
import '../services/ad_service.dart';
import '../widgets/rate_app_dialog.dart';
import '../models/online_room.dart';
import '../models/achievement.dart';
import '../utils/daily_challenge.dart';
import '../widgets/board_scanner_loader.dart';
import '../widgets/banner_ad_widget.dart';

class GameScreen extends StatefulWidget {
  final GameStore store;
  final GameState? gameState;
  final GameState? game; // Alternative parameter name
  final VoidCallback? onToggleTheme;
  final bool isOnlineChallenge;
  final bool isDailyChallenge;
  final String? tournamentId;

  const GameScreen({
    super.key,
    required this.store,
    this.gameState,
    this.game,
    this.onToggleTheme,
    this.isOnlineChallenge = false,
    this.isDailyChallenge = false,
    this.tournamentId,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  Timer? _timer;
  bool _showConfetti = false;
  final FocusNode _focusNode = FocusNode();
  final SoundService _sound = SoundService();

  // Coach marks state
  bool _showCoachMarks = false;
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _numpadKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _undoKey = GlobalKey();
  final GlobalKey _eraseKey = GlobalKey();
  final GlobalKey _notesKey = GlobalKey();
  final GlobalKey _hintKey = GlobalKey();

  // Animation for selected cell
  late AnimationController _selectionController;
  late Animation<double> _selectionAnimation;

  // Pulse on the cell a Hint points at
  late final AnimationController _glowController = AnimationController(
    duration: const Duration(milliseconds: 700),
    vsync: this,
  )..repeat(reverse: true);

  // What this game's result paid (set once when the game ends)
  bool _endHandled = false;
  int _earnedStars = 0;
  int _earnedCoins = 0;
  bool _chestReady = false;

  // Set by the debug-only shortcut: such a game never reaches leaderboards.
  bool _debugAssisted = false;

  // Online challenge state
  final OnlineChallengeService _onlineService = OnlineChallengeService();
  StreamSubscription<OnlineRoom?>? _roomSubscription;
  OnlineRoom? _currentRoom;
  PlayerState? _opponent;
  bool _opponentFinishedNotified = false;
  bool _opponentDisconnectedNotified = false;
  String? _lastOpponentStatus;

  // Achievement notification state
  final List<Achievement> _pendingAchievements = [];
  final List<Achievement> _endAchievements = [];
  Achievement? _showingAchievement;
  Timer? _achievementDismissTimer;

  GameState get game => widget.gameState ?? widget.game!;
  GameStore get store => widget.store;
  AppColorScheme get colors {
    return AppColors.cartoon;
  }

  bool get isOnline => widget.isOnlineChallenge;
  bool get isDaily => widget.isDailyChallenge;
  bool get isTournament => widget.tournamentId != null;
  final LeaderboardService _leaderboardService = LeaderboardService();
  final RateAppService _rateAppService = RateAppService();
  final AdService _adService = AdService();

  // Track games completed for interstitial ad frequency

  // Calculate progress percentage
  int get _filledCells {
    if (game.board.isEmpty) return 0;
    int count = 0;
    for (var row in game.board) {
      for (var cell in row) {
        if (cell != 0) count++;
      }
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    game.addListener(_onGameChange);
    _focusNode.requestFocus();

    // Setup selection animation
    _selectionController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _selectionAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _selectionController, curve: Curves.easeOut),
    );

    // Setup online challenge if enabled
    if (isOnline) {
      _setupOnlineChallenge();
    }

    // Setup daily challenge callbacks
    if (isDaily) {
      _setupDailyChallenge();
    }

    // Setup achievement callback
    store.onAchievementUnlocked = _onAchievementUnlocked;

    // Check if we should show coach marks (first game)
    if (store.shouldShowCoachMarks && !isOnline && !isDaily) {
      // Delay to allow UI to build and get positions
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowCoachMarks();
      });
    }
  }

  void _checkAndShowCoachMarks() {
    // Wait for puzzle to be generated
    if (game.isGenerating || game.puzzle.isEmpty) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _checkAndShowCoachMarks();
      });
      return;
    }

    // Show coach marks after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_showCoachMarks) {
        setState(() => _showCoachMarks = true);
      }
    });
  }

  void _onCoachMarksComplete() {
    setState(() => _showCoachMarks = false);
    store.markCoachMarksSeen();
  }

  List<CoachMark> _buildCoachMarks() {
    final marks = <CoachMark>[];

    Rect? getRect(GlobalKey key) {
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return null;
      final position = renderBox.localToGlobal(Offset.zero);
      return Rect.fromLTWH(
        position.dx,
        position.dy,
        renderBox.size.width,
        renderBox.size.height,
      );
    }

    final boardRect = getRect(_boardKey);
    final numpadRect = getRect(_numpadKey);
    final statsRect = getRect(_statsKey);
    final notesRect = getRect(_notesKey);
    final hintRect = getRect(_hintKey);
    final undoRect = getRect(_undoKey);

    if (boardRect != null) {
      marks.add(CoachMark(
        icon: '🎯',
        title: 'The Sudoku Board',
        description: 'Tap any empty cell to select it. Fill in numbers 1-9 so each row, column, and 3x3 box contains all digits.',
        targetRect: boardRect,
        position: TooltipPosition.below,
        spotlightPadding: 4,
      ));
    }

    if (numpadRect != null) {
      marks.add(CoachMark(
        icon: '🔢',
        title: 'Number Pad',
        description: 'After selecting a cell, tap a number to fill it in. Each key shows how many of that number are left to place.',
        targetRect: numpadRect,
        position: TooltipPosition.above,
        spotlightPadding: 4,
      ));
    }

    if (statsRect != null) {
      marks.add(CoachMark(
        icon: '⏱️',
        title: 'Game Stats',
        description: 'Your timer and hearts. Each mistake costs a heart; lose all five and the game is over. Tap pause for a break.',
        targetRect: statsRect,
        position: TooltipPosition.below,
      ));
    }

    if (notesRect != null) {
      marks.add(CoachMark(
        icon: '✏️',
        title: 'Notes Mode',
        description: 'Toggle notes to mark possible numbers in cells. Great for keeping track of your deductions!',
        targetRect: notesRect,
        position: TooltipPosition.above,
      ));
    }

    if (hintRect != null) {
      marks.add(CoachMark(
        icon: '💡',
        title: 'Need Help?',
        description: 'Hint (25 coins) lights up the easiest cell to solve next. Magic (60 coins) fills in the selected cell for you.',
        targetRect: hintRect,
        position: TooltipPosition.above,
      ));
    }

    if (undoRect != null) {
      marks.add(CoachMark(
        icon: '↩️',
        title: 'Made a Mistake?',
        description: 'Use Undo to go back, or Erase to clear a cell. Don\'t worry, everyone makes mistakes!',
        targetRect: undoRect,
        position: TooltipPosition.above,
        spotlightPadding: 12,
      ));
    }

    return marks;
  }

  void _onAchievementUnlocked(Achievement achievement) {
    AnalyticsService().logAchievementUnlocked(achievement.id);
    // Awards earned by finishing the puzzle are shown in the result popup.
    if (game.gameOver) {
      _endAchievements.add(achievement);
      return;
    }
    _pendingAchievements.add(achievement);
    _showNextAchievement();
  }

  void _showNextAchievement() {
    if (_showingAchievement != null || _pendingAchievements.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _showingAchievement = _pendingAchievements.removeAt(0);
    });

    _sound.playAchievement();

    // Auto-dismiss after 4 seconds
    _achievementDismissTimer?.cancel();
    _achievementDismissTimer = Timer(const Duration(seconds: 4), () {
      _dismissAchievement();
    });
  }

  void _dismissAchievement() {
    if (!mounted) return;
    _achievementDismissTimer?.cancel();
    setState(() {
      _showingAchievement = null;
    });
    // Show next achievement if any
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _showNextAchievement();
    });
  }

  void _setupDailyChallenge() {
    game.onDailyWon = (totalSeconds, mistakes) {
      store.recordDailyWin(totalSeconds, mistakes);
    };
    game.onDailyLost = (totalSeconds, mistakes) {
      store.recordDailyLoss(totalSeconds, mistakes);
    };
  }

  void _setupOnlineChallenge() async {
    // Setup callbacks for game state sync
    game.onProgressChange = (filledCells, mistakes) {
      _onlineService.updateProgress(filledCells, mistakes);
    };
    game.onGameWon = (totalSeconds) {
      _onlineService.markFinished(totalSeconds);
    };
    game.onGameLost = () {
      _onlineService.markLost();
    };

    // Wait for puzzle to be generated before sending initial progress
    while (game.isGenerating || game.board.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    // Send initial progress (cells that are pre-filled by the puzzle)
    _onlineService.updateProgress(_filledCells, game.mistakes);

    // Fetch initial room state immediately
    final initialRoom = await _onlineService.getCurrentRoom();
    if (mounted && initialRoom != null) {
      setState(() {
        _currentRoom = initialRoom;
        if (_onlineService.currentUid != null) {
          _opponent = initialRoom.getOpponent(_onlineService.currentUid!);
          _lastOpponentStatus = _opponent?.status;
        }
      });
    }

    // Small delay to ensure initial state is set before listening
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // Listen to room state changes
    _roomSubscription = _onlineService.roomStateStream.listen((room) {
      if (!mounted) return;

      final previousStatus = _lastOpponentStatus;

      setState(() {
        _currentRoom = room;
        if (room != null && _onlineService.currentUid != null) {
          _opponent = room.getOpponent(_onlineService.currentUid!);

          // Only update lastOpponentStatus if we have a valid opponent
          if (_opponent != null) {
            _lastOpponentStatus = _opponent!.status;
          }
        }
      });

      // Handle opponent status changes - only if opponent exists and status actually changed
      if (_opponent != null &&
          previousStatus != null &&
          previousStatus != _opponent!.status) {
        _handleOpponentStatusChange(previousStatus, _opponent!.status);
      }
    });
  }

  void _handleOpponentStatusChange(String? previousStatus, String newStatus) {
    if (previousStatus == newStatus) return;

    // Ignore transitions from null/waiting - these are initial states
    if (previousStatus == null || previousStatus == 'waiting') {
      // Only notify if opponent goes directly to disconnected/finished from waiting
      // (which would mean they left before game started)
      if (newStatus == 'disconnected' && previousStatus == 'waiting') {
        if (!_opponentDisconnectedNotified) {
          _opponentDisconnectedNotified = true;
          _showOpponentDisconnectedDialog();
        }
      }
      return;
    }

    // Opponent finished (won or lost) - only if they were previously playing
    if (newStatus == 'finished' && previousStatus == 'playing' && !_opponentFinishedNotified) {
      _opponentFinishedNotified = true;
      _showOpponentFinishedSnackbar();
    }

    // Opponent disconnected - only if they were previously playing
    if (newStatus == 'disconnected' && previousStatus == 'playing' && !_opponentDisconnectedNotified) {
      _opponentDisconnectedNotified = true;
      _showOpponentDisconnectedDialog();
    }
  }

  void _showOpponentFinishedSnackbar() {
    if (!mounted) return;
    final time = _opponent?.finishTime;
    final name = _opponent?.name ?? 'Opponent';

    if (time != null) {
      showCartoonDialog<void>(
        context,
        dismissible: false,
        builder: (context) => CartoonPanel(
          title: 'FINISHED FIRST',
          color: const Color(0xFFFF9F43),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GameIcon(GameIcons.trophy, size: 64),
              const SizedBox(height: 8),
              PanelText('$name solved it in ${_formatTime(time)}.\nKeep going and finish as runner-up!'),
              const SizedBox(height: 18),
              CartoonButton(label: 'KEEP GOING', onTap: () => Navigator.pop(context)),
            ],
          ),
        ),
      );
    } else {
      // Opponent lost due to mistakes - show encouraging snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name made too many mistakes! You can win this!'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showOpponentDisconnectedDialog() {
    if (!mounted) return;
    final name = _opponent?.name ?? 'Opponent';

    showCartoonDialog<void>(
      context,
      builder: (context) => CartoonPanel(
        title: 'OPPONENT LEFT',
        color: const Color(0xFF7C8DB5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 60, color: Color(0xFF7C8DB5)),
            const SizedBox(height: 8),
            PanelText('$name left the game or lost connection.\nYou can finish the puzzle or go home.'),
            const SizedBox(height: 18),
            CartoonButton(label: 'KEEP PLAYING', onTap: () => Navigator.pop(context)),
            const SizedBox(height: 4),
            CartoonButton.secondary(
              label: 'HOME',
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(this.context);
                _onlineService.leaveRoom();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        game.tick();
      }
    });
  }

  void _onGameChange() {
    if (!mounted) return;
    if (game.isGenerating) {
      setState(() {});
      return;
    }
    if (game.gameOver && _endHandled) {
      setState(() {});
      return;
    }
    if (game.status == GameStatus.won) {
      _endHandled = true;
      _endAchievements.clear();
      _timer?.cancel();
      _logGameEnd(won: true);
      // Daily challenges record their own stats via callbacks
      if (!isDaily) {
        store.recordWin(game.difficulty, game.seconds, game.mistakes);
      }

      // Check achievements
      // Determine if this is an online win (I won, not runner-up)
      bool isOnlineWinner = false;
      if (isOnline) {
        final opponentFinishTime = _opponent?.finishTime;
        if (_opponent == null || _opponent!.status == 'playing' || _opponent!.status == 'disconnected') {
          isOnlineWinner = true;
        } else if (opponentFinishTime == null) {
          isOnlineWinner = true;
        } else if (game.seconds <= opponentFinishTime) {
          isOnlineWinner = true;
        }
      }

      store.checkAchievements(
        difficulty: game.difficulty,
        time: game.seconds,
        mistakes: game.mistakes,
        hintsUsed: game.hintCells.length + game.hintsUsed,
        isChallenge: game.challengeMode,
        isOnline: isOnline,
        isDaily: isDaily,
        isOnlineWinner: isOnlineWinner,
      );

      // Submit to global leaderboard (not for online challenges)
      if (!isOnline && !_debugAssisted && store.deviceId != null) {
        _leaderboardService.submitScore(
          difficulty: game.difficulty,
          name: store.name,
          deviceId: store.deviceId!,
          time: game.seconds,
          mistakes: game.mistakes,
        );

        // Submit to tournament if playing a tournament
        if (isTournament && widget.tournamentId != null) {
          _leaderboardService.submitTournamentEntry(
            tournamentId: widget.tournamentId!,
            deviceId: store.deviceId!,
            name: store.name,
            time: game.seconds,
            mistakes: game.mistakes,
          );
        }
      }

      // Stars and coins: the Journey pays per level, everything else per win.
      _earnedStars = starsFor(mistakes: game.mistakes, usedHelp: game.usedHelp);
      final level = game.journeyLevel;
      if (level != null) {
        final result = store.completeJourneyLevel(level, _earnedStars);
        _earnedCoins = result.coins;
        _chestReady = result.chestReady;
      } else {
        _earnedCoins = store.rewardWin(game.difficulty, _earnedStars);
        _chestReady = false;
      }

      _sound.playWin();
      setState(() => _showConfetti = true);

      // Track games for interstitial ad (online duels never show one)
      if (!isOnline) _adService.recordGameCompleted();

      // Check for rate prompt after perfect win (0 mistakes)
      if (game.mistakes == 0) {
        _checkRatePrompt();
      }

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _showWinDialog();
      });
    } else if (game.status == GameStatus.lost) {
      _endHandled = true;
      _timer?.cancel();
      _logGameEnd(won: false);
      // Daily challenges record their own stats via callbacks
      if (!isDaily) {
        store.recordLoss(game.difficulty, game.seconds, game.mistakes);
      }

      // Track games for interstitial ad (online duels never show one)
      if (!isOnline) _adService.recordGameCompleted();

      _sound.playLose();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showLoseDialog();
      });
    }
    setState(() {});
  }

  /// Opens the system share sheet with this game's result
  void _shareResult({bool wonDuel = false}) {
    ShareService().shareResult(
      difficulty: game.difficulty,
      time: game.seconds,
      mistakes: game.mistakes,
      streak: store.currentStreak,
      isDaily: isDaily,
      dayNumber: isDaily ? DailyChallenge.todayNumber : null,
      challengePin: !isOnline && game.challengeMode ? game.challengePin : null,
      opponentName: isOnline ? (_opponent?.name ?? 'a friend') : null,
      wonDuel: wonDuel,
    );
  }

  void _logGameEnd({required bool won}) {
    AnalyticsService().logGameEnd(
      won: won,
      difficulty: game.difficulty,
      mode: game.mode,
      seconds: game.seconds,
      mistakes: game.mistakes,
      hints: game.hintCells.length + game.hintsUsed,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    _selectionController.dispose();
    _glowController.dispose();
    game.removeListener(_onGameChange);
    _roomSubscription?.cancel();

    // Clean up online callbacks and leave room
    if (isOnline) {
      game.onProgressChange = null;
      game.onGameWon = null;
      game.onGameLost = null;
      // Leave room when disposing (marks as disconnected)
      _onlineService.leaveRoom();
    }

    // Clean up daily callbacks
    if (isDaily) {
      game.onDailyWon = null;
      game.onDailyLost = null;
    }

    // Clean up achievement callback
    store.onAchievementUnlocked = null;
    _achievementDismissTimer?.cancel();

    if (!game.gameOver && game.puzzle.isNotEmpty && !game.isGenerating && !isOnline && !isDaily) {
      // Don't save online or daily games
      store.saveGame(game.toSavedGame());
    }
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // If online and game not over, confirm before leaving
    if (isOnline && !game.gameOver) {
      final shouldLeave = await showConfirm(
        context,
        title: 'LEAVE RACE?',
        message: 'You are in a live race. If you leave, your opponent wins.',
        cancel: 'STAY',
        confirm: 'LEAVE',
      );
      return shouldLeave;
    }
    return true;
  }

  void _newGame() async {
    final seed = game.challengeMode ? game.challengeSeed : null;
    final pin = game.challengeMode ? game.challengePin : null;
    setState(() {
      _showConfetti = false;
      _endHandled = false;
      _debugAssisted = false;
    });
    _timer?.cancel();
    final started = game.newGame(game.difficulty, seed: seed, pin: pin);
    AnalyticsService().logGameStart(difficulty: game.difficulty, mode: game.mode);
    await started;
    if (mounted) _startTimer();
  }

  // Handle keyboard input
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (game.paused && key == LogicalKeyboardKey.space) {
      _togglePause();
      return;
    }
    if (game.paused || game.gameOver || game.isGenerating) return;

    // Number keys 1-9
    if (key.keyId >= LogicalKeyboardKey.digit1.keyId &&
        key.keyId <= LogicalKeyboardKey.digit9.keyId) {
      final num = key.keyId - LogicalKeyboardKey.digit0.keyId;
      if (game.countForNumber(num) < 9) {
        _sound.playInput();
        game.inputNumber(num);
      }
      return;
    }

    // Numpad 1-9
    if (key.keyId >= LogicalKeyboardKey.numpad1.keyId &&
        key.keyId <= LogicalKeyboardKey.numpad9.keyId) {
      final num = key.keyId - LogicalKeyboardKey.numpad0.keyId;
      if (game.countForNumber(num) < 9) {
        _sound.playInput();
        game.inputNumber(num);
      }
      return;
    }

    // Arrow keys for navigation
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1, 0);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1, 0);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _moveSelection(0, -1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _moveSelection(0, 1);
    }

    // Backspace/Delete to erase
    if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
      _sound.playErase();
      game.eraseCell();
    }

    // N for notes toggle
    if (key == LogicalKeyboardKey.keyN) {
      _sound.playClick();
      game.toggleNotes();
    }

    // Z for undo
    if (key == LogicalKeyboardKey.keyZ) {
      _sound.playUndo();
      game.undo();
    }

    // H for hint
    if (key == LogicalKeyboardKey.keyH) {
      _useHint();
    }

    // Space to pause
    if (key == LogicalKeyboardKey.space) {
      _togglePause();
    }
  }

  void _moveSelection(int dr, int dc) {
    int r = game.selectedRow ?? 4;
    int c = game.selectedCol ?? 4;
    r = (r + dr).clamp(0, 8);
    c = (c + dc).clamp(0, 8);
    _sound.playTap();
    game.selectCell(r, c);
    _selectionController.forward(from: 0);
  }

  void _onCellTap(int r, int c) {
    _sound.playTap();
    game.selectCell(r, c);
    _selectionController.forward(from: 0);
  }


  // ───────────────────────────────────────────────────────────── tools

  /// Hint (paid): points at the easiest cell to solve now. Pressing it again
  /// while that cell is still open just re-selects it for free.
  void _useHint() {
    if (game.gameOver || game.paused || game.isGenerating) return;
    final glow = game.hintGlow;
    if (glow != null) {
      final parts = glow.split(',');
      _onCellTap(int.parse(parts[0]), int.parse(parts[1]));
      return;
    }
    if (store.coins < hintCost) {
      _notEnoughCoins();
      return;
    }
    if (!game.pointHint()) return;
    store.spend(hintCost);
    _sound.playHint();
    _selectionController.forward(from: 0);
    AnalyticsService().logHintUsed(source: 'coins');
  }

  /// Magic (paid): fills the selected cell (or a random one) with its answer.
  void _useMagic() {
    if (game.gameOver || game.paused || game.isGenerating) return;
    if (!store.spend(magicCost)) {
      _notEnoughCoins();
      return;
    }
    _sound.playHint();
    game.magicFill();
    _selectionController.forward(from: 0);
    AnalyticsService().logHintUsed(source: 'magic');
  }

  /// Debug builds only: fills every open cell but one, to test the ending.
  void _debugAlmostSolve() {
    if (game.gameOver || game.isGenerating) return;
    _debugAssisted = true;
    (int, int)? last;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (game.board[r][c] == game.solution[r][c]) continue;
        if (last == null) {
          last = (r, c);
          continue;
        }
        game.board[r][c] = game.solution[r][c];
      }
    }
    if (last != null) game.selectCell(last.$1, last.$2);
  }

  void _notEnoughCoins() {
    _sound.playWrong();
    showFreeCoins(context, store, title: 'NOT ENOUGH COINS');
  }

  void _togglePause() {
    if (game.gameOver || game.isGenerating) return;
    _sound.playClick();
    game.togglePause();
  }

  Future<void> _leave() async {
    _sound.playTap();
    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) Navigator.of(context).pop();
  }

  // ───────────────────────────────────────────────────────────── layout

  static const _boxLine = Color(0xFFFF9F43);
  static const _cellLine = Color(0xFFF2DDB8);
  static const _cream = Color(0xFFFFFBF2);
  static const _givenInk = Color(0xFF2A3A6E);
  static const _userInk = Color(0xFF8E3FD6);
  static const _helpInk = Color(0xFF2E9E35);
  static const _wrongInk = Color(0xFFF25A6B);

  static const _keyColors = [
    Color(0xFFF25A6B),
    Color(0xFFFF9F43),
    Color(0xFFF5C02B),
    Color(0xFF3FB26B),
    Color(0xFF1FB5A8),
    Color(0xFF4D9BFE),
    Color(0xFF4D7CFE),
    Color(0xFF8E5BEA),
    Color(0xFFE05BC4),
  ];

  static (String, Color) _difficultyStyle(String diff) => switch (diff) {
        'easy' => ('EASY', const Color(0xFF3FB26B)),
        'medium' => ('MEDIUM', const Color(0xFFFF9F43)),
        'hard' => ('HARD', const Color(0xFFF25A6B)),
        'expert' => ('EXPERT', const Color(0xFF8E5BEA)),
        _ => (diff.toUpperCase(), const Color(0xFF7C8DB5)),
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isOnline || game.gameOver,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: GameBackdrop.bottom,
          body: Stack(
            children: [
              const Positioned.fill(child: GameBackdrop()),
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                            child: Column(
                              children: [
                                _buildTopBar(),
                                const SizedBox(height: 8),
                                if (isOnline && _opponent != null) ...[
                                  OpponentProgressBar(opponent: _opponent!, colors: colors),
                                  const SizedBox(height: 8),
                                ],
                                KeyedSubtree(key: _statsKey, child: _buildStatusStrip()),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      // Keys and tools keep their size; the board gets the rest.
                                      const controls = 166.0;
                                      final board = min(constraints.maxWidth, constraints.maxHeight - controls - 24);
                                      return Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox.square(dimension: board, child: KeyedSubtree(key: _boardKey, child: _buildBoard())),
                                            const SizedBox(height: 14),
                                            KeyedSubtree(key: _numpadKey, child: _buildNumpad()),
                                            const SizedBox(height: 10),
                                            _buildTools(),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    BannerAdWidget(key: ValueKey(_adService.isInitialized)),
                  ],
                ),
              ),
              if (_showConfetti) const Positioned.fill(child: IgnorePointer(child: ConfettiBurst())),
              if (_showingAchievement != null)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 10,
                  left: 0,
                  right: 0,
                  child: AchievementUnlockNotification(
                    achievement: _showingAchievement!,
                    onDismiss: _dismissAchievement,
                  ),
                ),
              if (_showCoachMarks)
                Positioned.fill(
                  child: CoachMarksOverlay(
                    colors: colors,
                    marks: _buildCoachMarks(),
                    onComplete: _onCoachMarksComplete,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Back button, the level / mode title, coins.
  Widget _buildTopBar() {
    final level = game.journeyLevel;
    final String title;
    if (level != null) {
      title = 'LEVEL $level';
    } else if (isDaily) {
      title = 'DAILY';
    } else if (isOnline) {
      title = 'LIVE RACE';
    } else if (game.challengeMode) {
      title = 'CHALLENGE';
    } else {
      title = 'FREE PLAY';
    }
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          PressScale(
            child: GestureDetector(
              onTap: _leave,
              child: const GameIcon(GameIcons.back, size: 50, flipForRtl: true),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onLongPress: kDebugMode ? _debugAlmostSolve : null,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: OutlinedText(title, size: 28, stroke: GameBackdrop.ink),
                  ),
                ),
                if (level != null) ...[const SizedBox(height: 3), _stageDots(level)],
              ],
            ),
          ),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => CoinPill(
              coins: store.coins,
              background: GameBackdrop.ink,
              onAdd: () => showFreeCoins(context, store),
            ),
          ),
        ],
      ),
    );
  }

  /// The current stage's ten levels as dots: done, this one, still to come.
  Widget _stageDots(int level) {
    final first = stageOf(level) * levelsPerStage + 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var l = first; l < first + levelsPerStage; l++)
          Container(
            width: l == level ? 12 : 8,
            height: l == level ? 12 : 8,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: l == level
                  ? Colors.white
                  : store.isJourneyCleared(l)
                      ? const Color(0xFFFFC23D)
                      : Colors.white.withValues(alpha: 0.35),
              border: l == level ? Border.all(color: const Color(0xFFFFC23D), width: 2) : null,
            ),
          ),
      ],
    );
  }

  /// Difficulty, hearts left and the timer with its pause button.
  Widget _buildStatusStrip() {
    final (label, color) = _difficultyStyle(game.difficulty);
    final left = GameState.maxMistakes - game.mistakes;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(23),
        boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
            child: OutlinedText(label, size: 15, stroke: Color.lerp(color, Colors.black, 0.45)!),
          ),
          Expanded(
            child: Shake(
              trigger: game.mistakes,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < GameState.maxMistakes; i++)
                    AnimatedScale(
                      scale: i < left ? 1 : 0.8,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 22,
                        color: i < left ? const Color(0xFFF25A6B) : const Color(0xFFD9D4E2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Text(
            _fmtTime(game.seconds),
            style: const TextStyle(
              fontFamily: kBodyFont,
              fontWeight: FontWeight.w700,
              fontSize: 19,
              color: CartoonPanel.ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          PressScale(
            child: GestureDetector(
              onTap: _togglePause,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: Color(0xFF4D7CFE), shape: BoxShape.circle),
                child: Icon(game.paused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        const frame = 5.0;
        final cell = (size - frame * 2) / 9;
        final ready = !(game.puzzle.isEmpty || game.isGenerating);
        return Center(
          child: Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(frame),
            decoration: BoxDecoration(
              color: _boxLine,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: GameBackdrop.ink, offset: Offset(0, 6)),
                BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                children: [
                  Positioned.fill(child: Container(color: _cream)),
                  if (!ready)
                    const Center(child: BoardScannerLoader(primaryColor: _boxLine, borderColor: _cellLine))
                  else
                    Column(
                      children: [
                        for (var r = 0; r < 9; r++)
                          Expanded(
                            child: Row(
                              children: [
                                for (var c = 0; c < 9; c++) Expanded(child: _buildCell(r, c, cell)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),
                  if (game.paused) Positioned.fill(child: _pauseCover()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pauseCover() {
    return Container(
      color: _cream,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OutlinedText('PAUSED', size: 40, color: Color(0xFFFFC23D), stroke: Color(0xFF9A4A00)),
          const SizedBox(height: 6),
          const PanelText('Take a breather. The clock is stopped.', size: 15),
          const SizedBox(height: 18),
          SizedBox(
            width: 200,
            child: CartoonButton(
              label: 'RESUME',
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              onTap: () => game.togglePause(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int r, int c, double size) {
    final val = game.board[r][c];
    final given = game.isGiven[r][c];
    final isSel = r == game.selectedRow && c == game.selectedCol;
    final inGroup = !isSel &&
        game.hasSelection &&
        (r == game.selectedRow || c == game.selectedCol || (r ~/ 3 == game.selectedRow! ~/ 3 && c ~/ 3 == game.selectedCol! ~/ 3));
    final sameNum = !isSel && game.selectedValue > 0 && val == game.selectedValue;
    final isErr = !given && val != 0 && val != game.solution[r][c];
    final isHelp = game.hintCells.contains('$r,$c');
    final glowing = game.hintGlow == '$r,$c';

    Color bg = Colors.transparent;
    if (isSel) {
      bg = const Color(0xFFFFC870);
    } else if (sameNum) {
      bg = const Color(0xFFFFDE9E);
    } else if (inGroup) {
      bg = const Color(0xFFFFF0CF);
    }
    if (isErr) bg = isSel ? const Color(0xFFFFA3AE) : const Color(0xFFFFD6DB);

    final ink = isErr
        ? _wrongInk
        : given
            ? _givenInk
            : isHelp
                ? _helpInk
                : _userInk;

    Widget cellBox(Color color, [BoxBorder? border]) => Container(
          decoration: BoxDecoration(color: color, border: border),
          alignment: Alignment.center,
          child: val != 0
              ? Text(
                  '$val',
                  style: TextStyle(
                    fontFamily: kBodyFont,
                    fontWeight: given ? FontWeight.w700 : FontWeight.w600,
                    fontSize: size * 0.6,
                    height: 1,
                    color: ink,
                  ),
                )
              : game.notes[r][c].isNotEmpty
                  ? _buildNotes(r, c, size)
                  : null,
        );

    // The cell a Hint points at pulses green until it is solved.
    final Widget content0 = glowing
        ? AnimatedBuilder(
            animation: _glowController,
            builder: (context, _) => cellBox(
              Color.lerp(const Color(0xFFB8F0C8), const Color(0xFF6FDC8C), _glowController.value)!,
              Border.all(color: _helpInk, width: 2.5),
            ),
          )
        : cellBox(bg);
    Widget content = content0;

    if (isSel) {
      content = AnimatedBuilder(
        animation: _selectionAnimation,
        builder: (context, child) => Transform.scale(scale: _selectionAnimation.value, child: child),
        child: content,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c),
      child: content,
    );
  }

  Widget _buildNotes(int r, int c, double size) {
    final style = TextStyle(
      fontFamily: kBodyFont,
      fontWeight: FontWeight.w600,
      fontSize: size * 0.24,
      height: 1,
      color: const Color(0xFF8A7A9E),
    );
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Row(
                children: [
                  for (var j = 0; j < 3; j++)
                    Expanded(
                      child: Center(
                        child: Text(game.notes[r][c].contains(i * 3 + j + 1) ? '${i * 3 + j + 1}' : '', style: style),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Nine rainbow keys; each shows how many of its number are still to place.
  Widget _buildNumpad() {
    return Row(
      children: [
        for (var n = 1; n <= 9; n++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _numberKey(n),
            ),
          ),
      ],
    );
  }

  Widget _numberKey(int n) {
    final left = 9 - game.countForNumber(n);
    final done = left <= 0;
    final base = _keyColors[n - 1];
    final color = done
        ? const Color(0xFFB9C3CF)
        : game.notesMode
            ? Color.lerp(base, Colors.white, 0.35)!
            : base;
    return ChunkyButton(
      color: color,
      height: 58,
      radius: 14,
      depth: 5,
      onTap: done
          ? null
          : () {
              _sound.playInput();
              game.inputNumber(n);
            },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 30)
              : OutlinedText('$n', size: game.notesMode ? 22 : 28, stroke: Color.lerp(base, Colors.black, 0.45)!),
          if (!done)
            Text(
              '$left left',
              style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 10, height: 1, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildTools() {
    return Row(
      children: [
        Expanded(
          child: KeyedSubtree(
            key: _undoKey,
            child: _tool(
              color: const Color(0xFF4D7CFE),
              icon: const Icon(Icons.undo_rounded, color: Colors.white, size: 30),
              label: 'UNDO',
              onTap: () {
                _sound.playUndo();
                game.undo();
              },
            ),
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: _eraseKey,
            child: _tool(
              color: const Color(0xFF1FB5A8),
              icon: const Icon(Icons.backspace_rounded, color: Colors.white, size: 26),
              label: 'ERASE',
              onTap: () {
                _sound.playErase();
                game.eraseCell();
              },
            ),
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: _notesKey,
            child: _tool(
              color: const Color(0xFF8E5BEA),
              icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 28),
              label: 'NOTES',
              badge: _badge(game.notesMode ? 'ON' : 'OFF', game.notesMode ? const Color(0xFF3FB26B) : const Color(0xFF7C8DB5)),
              onTap: () {
                _sound.playClick();
                game.toggleNotes();
              },
            ),
          ),
        ),
        Expanded(
          child: _tool(
            color: const Color(0xFFFF9F43),
            icon: const GameIcon(GameIcons.wand, size: 32),
            label: 'MAGIC',
            badge: _priceBadge(magicCost),
            onTap: _useMagic,
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: _hintKey,
            child: _tool(
              color: const Color(0xFF3FB26B),
              icon: const GameIcon(GameIcons.hint, size: 32),
              label: 'HINT',
              badge: game.hintGlow != null ? null : _priceBadge(hintCost),
              onTap: _useHint,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tool({required Color color, required Widget icon, required String label, required VoidCallback onTap, Widget? badge}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ChunkyButton(
            color: color,
            height: 62,
            radius: 16,
            depth: 5,
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: OutlinedText(label, size: 13, stroke: Color.lerp(color, Colors.black, 0.45)!, strokeWidth: 3),
                ),
              ],
            ),
          ),
          if (badge != null) Positioned(top: -8, right: -4, child: IgnorePointer(child: badge)),
        ],
      ),
    );
  }

  Widget _priceBadge(int price) {
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 6, 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2250),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameIcon(GameIcons.coin, size: 14),
          const SizedBox(width: 2),
          Text('$price', style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(text, style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 10, color: Colors.white)),
    );
  }

  // ───────────────────────────────────────────────────────────── results

  String get _difficultyName => _difficultyStyle(game.difficulty).$1;

  Future<void> _showWinDialog() async {
    if (isOnline) {
      _showOnlineWinDialog();
      return;
    }
    final level = game.journeyLevel;
    Widget? extra;
    String title, subtitle, action;
    String? secondary = 'HOME';
    VoidCallback? share = _shareResult;
    if (level != null) {
      title = 'LEVEL $level';
      subtitle = 'Stage ${stageOf(level) + 1} · $_difficultyName';
      action = 'NEXT LEVEL';
      if (_chestReady) extra = _chestNote();
    } else if (isDaily) {
      title = 'DAILY DONE';
      subtitle = 'See you tomorrow!';
      action = 'HOME';
      secondary = null;
      extra = _streakTiles();
    } else if (game.challengeMode) {
      title = 'CHALLENGE';
      subtitle = 'Show your friend how you did!';
      action = 'REPLAY';
      extra = _pinTile(game.challengePin ?? '');
    } else {
      title = 'SOLVED!';
      subtitle = '$_difficultyName puzzle';
      action = 'PLAY AGAIN';
    }
    if (_endAchievements.isNotEmpty) {
      extra = Column(
        children: [
          if (extra != null) ...[extra, const SizedBox(height: 8)],
          _awardsStrip(),
        ],
      );
    }
    final again = await showWinOverlay(
      context,
      store: store,
      title: title,
      subtitle: subtitle,
      stars: _earnedStars,
      reward: _earnedCoins,
      time: _fmtTime(game.seconds),
      mistakes: game.mistakes,
      actionLabel: action,
      secondaryLabel: secondary,
      extra: extra,
      onShare: share,
    );
    if (!mounted) return;
    await maybeShowRankUp(context, store);
    if (!mounted) return;
    await _maybeShowInterstitialAd();
    if (!mounted) return;
    if (again != true || isDaily) {
      Navigator.of(context).pop();
    } else if (level != null) {
      _playJourneyLevel(level + 1);
    } else {
      _newGame();
    }
  }

  Future<void> _showLoseDialog() async {
    if (isOnline) {
      _showOnlineLoseDialog();
      return;
    }
    final level = game.journeyLevel;
    final retry = await showCartoonDialog<bool>(
      context,
      dismissible: false,
      builder: (context) => CartoonPanel(
        title: 'OUT OF HEARTS',
        color: const Color(0xFFF25A6B),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.heart_broken_rounded, color: Color(0xFFF25A6B), size: 72),
            const SizedBox(height: 6),
            PanelText(
              isDaily
                  ? 'That was your ${GameState.maxMistakes}th mistake. The daily puzzle comes back tomorrow!'
                  : 'That was your ${GameState.maxMistakes}th mistake. The answers are on the board — have another go!',
            ),
            if (isDaily) ...[const SizedBox(height: 12), _streakTiles()],
            const SizedBox(height: 18),
            if (!isDaily) ...[
              CartoonButton(
                label: level != null ? 'TRY AGAIN' : 'NEW PUZZLE',
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 26),
                onTap: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 4),
            ],
            CartoonButton.secondary(label: 'HOME', onTap: () => Navigator.of(context).pop(false)),
          ],
        ),
      ),
    );
    if (!mounted) return;
    await _maybeShowInterstitialAd();
    if (!mounted) return;
    if (retry == true) {
      if (level != null) {
        _playJourneyLevel(level);
      } else {
        _newGame();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  void _playJourneyLevel(int level) async {
    setState(() {
      _showConfetti = false;
      _endHandled = false;
      _debugAssisted = false;
    });
    _timer?.cancel();
    final started = game.newGame(difficultyForLevel(level), seed: seedForLevel(level), journeyLevel: level);
    AnalyticsService().logGameStart(difficulty: game.difficulty, mode: 'journey');
    await started;
    if (mounted) _startTimer();
  }

  /// "New award" chips for achievements unlocked by this win.
  Widget _awardsStrip() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final a in _endAchievements)
          Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE3FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF8E5BEA), width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  a.name,
                  style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF5B2EA6)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _chestNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0CF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC23D), width: 2),
      ),
      child: Row(
        children: [
          const Breathing(amount: 0.1, child: GameIcon(GameIcons.chestClosed, size: 44)),
          const SizedBox(width: 8),
          const Expanded(
            child: PanelText('Stage complete! Open the chest on the Journey map.', size: 14, align: TextAlign.start),
          ),
        ],
      ),
    );
  }

  Widget _streakTiles() {
    return StatRow([
      StatTile(
        value: '${store.currentStreak}',
        label: 'Day streak',
        icon: const GameIcon(GameIcons.flame, size: 24),
        color: const Color(0xFFF25A6B),
      ),
      StatTile(
        value: '${store.longestStreak}',
        label: 'Best streak',
        icon: const GameIcon(GameIcons.trophy, size: 24),
      ),
    ]);
  }

  Widget _pinTile(String pin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0DFC0), width: 2),
      ),
      child: Column(
        children: [
          const Text(
            'CHALLENGE PIN',
            style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A7A9E), letterSpacing: 1),
          ),
          Text(pin, style: const TextStyle(fontFamily: kTitleFont, fontSize: 28, color: Color(0xFF8E5BEA), letterSpacing: 5)),
        ],
      ),
    );
  }

  /// Who finished first, if I just finished the race.
  OnlineResultType _onlineResult() {
    final opponentTime = _opponent?.finishTime;
    if (_opponent == null || _opponent!.status == 'playing' || _opponent!.status == 'disconnected') {
      return OnlineResultType.winner;
    }
    if (opponentTime == null || game.seconds <= opponentTime) return OnlineResultType.winner;
    return OnlineResultType.runnerUp;
  }

  void _showOnlineWinDialog() {
    final result = _onlineResult();
    _showOnlineResult(result, onShare: () => _shareResult(wonDuel: result == OnlineResultType.winner));
  }

  void _showOnlineLoseDialog() => _showOnlineResult(OnlineResultType.gameOver);

  void _showOnlineResult(OnlineResultType result, {VoidCallback? onShare}) {
    final (title, color, line) = switch (result) {
      OnlineResultType.winner => ('YOU WON!', const Color(0xFF3FB26B), 'You finished first!'),
      OnlineResultType.runnerUp => ('RUNNER-UP', const Color(0xFF4D7CFE), 'So close! You solved it too.'),
      OnlineResultType.gameOver => ('OUT OF HEARTS', const Color(0xFFF25A6B), 'Too many mistakes this time.'),
    };
    final name = _opponent?.name ?? 'Opponent';
    final oppTime = _opponent?.finishTime;
    showCartoonDialog<void>(
      context,
      dismissible: false,
      builder: (context) => CartoonPanel(
        title: title,
        color: color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (result == OnlineResultType.winner)
              const GameIcon(GameIcons.trophy, size: 72)
            else if (result == OnlineResultType.gameOver)
              const Icon(Icons.heart_broken_rounded, color: Color(0xFFF25A6B), size: 64),
            if (result != OnlineResultType.gameOver && _earnedCoins > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedText('+$_earnedCoins', size: 26, color: const Color(0xFF7CE08A), stroke: const Color(0xFF1F6E3F)),
                  const SizedBox(width: 6),
                  const GameIcon(GameIcons.coin, size: 28),
                ],
              ),
            ],
            const SizedBox(height: 6),
            PanelText(line),
            const SizedBox(height: 12),
            _raceRow('YOU', _fmtTime(game.seconds), game.mistakes, const Color(0xFF8E5BEA)),
            const SizedBox(height: 8),
            _raceRow(name.toUpperCase(), oppTime != null ? _fmtTime(oppTime) : _opponentStatusLabel(), _opponent?.mistakes ?? 0, const Color(0xFF7C8DB5)),
            const SizedBox(height: 18),
            if (onShare != null) ...[
              CartoonButton(
                label: 'SHARE',
                color: const Color(0xFF4D7CFE),
                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                onTap: onShare,
              ),
              const SizedBox(height: 4),
            ],
            CartoonButton.secondary(
              label: 'HOME',
              onTap: () {
                _onlineService.leaveRoom();
                Navigator.pop(context);
                Navigator.pop(this.context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _opponentStatusLabel() => switch (_opponent?.status) {
        'playing' => 'Still playing',
        'disconnected' => 'Left',
        'finished' => 'Out',
        _ => '--:--',
      };

  Widget _raceRow(String who, String time, int mistakes, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              who,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: kTitleFont, fontSize: 18, color: color),
            ),
          ),
          const Icon(Icons.timer_rounded, size: 18, color: Color(0xFF8A7A9E)),
          const SizedBox(width: 3),
          Text(time, style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 15, color: CartoonPanel.ink)),
          const SizedBox(width: 10),
          const Icon(Icons.close_rounded, size: 18, color: Color(0xFFF25A6B)),
          Text('$mistakes', style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 15, color: CartoonPanel.ink)),
        ],
      ),
    );
  }

  /// Show an interstitial every few finished games, at the break after a
  /// result dialog. Completes once the ad is closed.
  Future<void> _maybeShowInterstitialAd() async {
    // Don't show during online matches (disruptive)
    if (isOnline) return;
    await _adService.maybeShowInterstitial();
  }

  Future<void> _checkRatePrompt() async {
    final shouldPrompt = await _rateAppService.recordPerfectWin();
    if (shouldPrompt && mounted) {
      // Delay slightly to not interrupt win celebration
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => RateAppDialog(
              colors: colors,
              onRate: () async {
                Navigator.pop(context);
                await _rateAppService.requestReview();
              },
              onLater: () {
                Navigator.pop(context);
                _rateAppService.dismissPrompt();
              },
              onNever: () async {
                Navigator.pop(context);
                // Mark as "rated" so we never ask again
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_rated_app', true);
              },
            ),
          );
        }
      });
    }
  }

  String _fmtTime(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

enum OnlineResultType { winner, runnerUp, gameOver }

/// Thin lines between cells and thick orange lines around each 3×3 box.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final thin = Paint()
      ..color = _GameScreenState._cellLine
      ..strokeWidth = 1.2;
    final thick = Paint()
      ..color = _GameScreenState._boxLine
      ..strokeWidth = 3.5;
    final step = size.width / 9, stepY = size.height / 9;
    for (var i = 1; i < 9; i++) {
      final paint = i % 3 == 0 ? null : thin;
      if (paint == null) continue;
      canvas.drawLine(Offset(i * step, 0), Offset(i * step, size.height), paint);
      canvas.drawLine(Offset(0, i * stepY), Offset(size.width, i * stepY), paint);
    }
    for (final i in [3, 6]) {
      canvas.drawLine(Offset(i * step, 0), Offset(i * step, size.height), thick);
      canvas.drawLine(Offset(0, i * stepY), Offset(size.width, i * stepY), thick);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
