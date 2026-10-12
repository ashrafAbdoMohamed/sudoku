import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/challenge_utils.dart';
import '../main.dart' show isFirebaseAvailable;
import '../services/online_challenge_service.dart';
import '../services/share_service.dart';
import '../services/analytics_service.dart';
import '../models/online_room.dart';
import '../game/cartoon_dialog.dart';
import '../game/ui_kit.dart';
import '../services/sound_service.dart';

class ChallengeModal extends StatefulWidget {
  final AppColorScheme colors;
  final bool isDark;
  final void Function(String difficulty, int seed, String pin) onStartChallenge;
  final void Function(String difficulty, int seed, String pin, bool isOnline)? onStartOnlineChallenge;
  final String playerName;
  final String? initialPin; // Pre-fill PIN from deep link

  const ChallengeModal({
    super.key,
    required this.colors,
    required this.isDark,
    required this.onStartChallenge,
    this.onStartOnlineChallenge,
    this.playerName = 'Player',
    this.initialPin,
  });

  @override
  State<ChallengeModal> createState() => _ChallengeModalState();
}

class _ChallengeModalState extends State<ChallengeModal> {
  bool _isCreateTab = true;
  String _cDiff = 'easy';
  bool _generated = false;
  String _pin = '';
  int _seed = 0;
  final _pinController = TextEditingController();
  String _joinError = '';

  // Online mode
  bool _isOnlineMode = false;
  bool _isWaitingForOpponent = false;
  bool _isJoining = false;
  final OnlineChallengeService _onlineService = OnlineChallengeService();
  StreamSubscription<OnlineRoom?>? _roomSubscription;
  OnlineRoom? _currentRoom;

  AppColorScheme get c => widget.colors;

  @override
  void initState() {
    super.initState();
    // Pre-fill PIN from deep link and switch to Join tab
    if (widget.initialPin != null && widget.initialPin!.isNotEmpty) {
      _isCreateTab = false;
      _pinController.text = widget.initialPin!;
    } else {
      // The home button promises a live race, so start there.
      _isOnlineMode = isFirebaseAvailable;
    }
  }

  void _generate() async {
    _seed = Random().nextInt(99999) + 1;

    if (_isOnlineMode && isFirebaseAvailable) {
      // Create online room
      setState(() => _isWaitingForOpponent = true);

      final pin = await _onlineService.createRoom(_cDiff, _seed, widget.playerName);
      if (pin == null) {
        setState(() {
          _isWaitingForOpponent = false;
          _joinError = 'Failed to create online room. Please try again.';
        });
        return;
      }

      _pin = pin;
      _startListeningToRoom();
      setState(() => _generated = true);
      AnalyticsService().logChallengeCreated(difficulty: _cDiff, type: 'online');
    } else {
      // Offline mode - use existing PIN encoding
      _pin = ChallengeUtils.encodePin(_cDiff, _seed);
      setState(() => _generated = true);
      AnalyticsService().logChallengeCreated(difficulty: _cDiff, type: 'offline');
    }
  }

  void _startListeningToRoom() {
    _roomSubscription?.cancel();
    _roomSubscription = _onlineService.roomStateStream.listen((room) {
      if (!mounted) return;

      setState(() => _currentRoom = room);

      if (room != null && room.isFull && room.isWaiting) {
        // Both players joined - start the game
        _onlineService.startGame();
      }

      if (room != null && room.isPlaying) {
        // Game started - close modal and start
        Navigator.pop(context);
        if (widget.onStartOnlineChallenge != null) {
          widget.onStartOnlineChallenge!(_cDiff, _seed, _pin, true);
        } else {
          widget.onStartChallenge(_cDiff, _seed, _pin);
        }
      }
    });
  }

  void _cancelOnlineRoom() async {
    _roomSubscription?.cancel();
    await _onlineService.leaveRoom();
    setState(() {
      _isWaitingForOpponent = false;
      _generated = false;
      _currentRoom = null;
    });
  }

  void _join() async {
    final pinText = _pinController.text.replaceAll(RegExp(r'\D'), '');

    if (_isOnlineMode && isFirebaseAvailable) {
      // Join online room
      if (pinText.length != 6) {
        setState(() => _joinError = 'Please enter a 6-digit code.');
        return;
      }

      setState(() {
        _isJoining = true;
        _joinError = '';
      });

      final result = await _onlineService.joinRoom(pinText, widget.playerName);

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _isJoining = false;
          _joinError = result.error ?? 'Failed to join room.';
        });
        return;
      }

      _pin = pinText;
      _seed = result.seed!;
      _cDiff = result.difficulty!;
      _startListeningToRoom();
      AnalyticsService().logChallengeJoined(
          difficulty: _cDiff, type: 'online', fromLink: widget.initialPin != null);

      setState(() {
        _isJoining = false;
        _isWaitingForOpponent = true;
      });
    } else {
      // Offline mode - decode PIN
      final data = ChallengeUtils.decodePin(pinText);
      if (data == null) {
        setState(() => _joinError = 'Invalid code. Please check and try again.');
        return;
      }
      setState(() => _joinError = '');
      AnalyticsService().logChallengeJoined(
          difficulty: data.difficulty, type: 'offline', fromLink: widget.initialPin != null);
      Navigator.pop(context);
      widget.onStartChallenge(data.difficulty, data.seed, pinText);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _roomSubscription?.cancel();
    // Note: Don't leave the room here - the game screen will handle it
    // Only leave if we were waiting but cancelled (handled by _cancelOnlineRoom)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CartoonPanel(
      title: 'PLAY A FRIEND',
      color: const Color(0xFF1FB5A8),
      onClose: () {
        if (_isWaitingForOpponent) _cancelOnlineRoom();
        Navigator.pop(context);
      },
      scrollable: true,
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isFirebaseAvailable) ...[
            _modeCards(),
            const SizedBox(height: 12),
          ],
          _tabs(),
          const SizedBox(height: 14),
          if (_isCreateTab) _buildCreate() else _buildJoin(),
        ],
      ),
    );
  }

  /// Live race vs. share-a-code: two big cards, the chosen one lit up.
  Widget _modeCards() {
    Widget card(bool online, String emoji, String title, String text, Color color) {
      final active = _isOnlineMode == online;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_generated || _isWaitingForOpponent || active) return;
            SoundService().playTap();
            setState(() => _isOnlineMode = online);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            decoration: BoxDecoration(
              color: active ? color : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: active ? Colors.white : const Color(0xFFF0DFC0), width: 3),
              boxShadow: [BoxShadow(color: active ? Color.lerp(color, Colors.black, 0.35)! : const Color(0xFFF0DFC0), offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 2),
                FittedBox(
                  child: active
                      ? OutlinedText(title, size: 17, stroke: Color.lerp(color, Colors.black, 0.45)!)
                      : Text(title, style: const TextStyle(fontFamily: kTitleFont, fontSize: 17, color: Color(0xFF8A7A9E))),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kBodyFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.15,
                    color: active ? Colors.white : const Color(0xFF8A7A9E),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card(true, '⚡', 'LIVE RACE', 'Play at the same time, see their progress', const Color(0xFFFF8A3D)),
        const SizedBox(width: 10),
        card(false, '🔢', 'SHARE A CODE', 'Same puzzle, compare times later', const Color(0xFF8E5BEA)),
      ],
    );
  }

  Widget _tabs() {
    Widget tab(String label, bool create) {
      final active = _isCreateTab == create;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_isWaitingForOpponent || active) return;
            SoundService().playTap();
            setState(() => _isCreateTab = create);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF1FB5A8) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: active ? const [BoxShadow(color: Color(0xFF0E7068), offset: Offset(0, 3))] : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(fontFamily: kTitleFont, fontSize: 15, color: active ? Colors.white : const Color(0xFF8A7A9E)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFF3E4C8), borderRadius: BorderRadius.circular(23)),
      child: Row(children: [tab('I HOST', true), tab('I HAVE A CODE', false)]),
    );
  }

  Widget _buildCreate() {
    if (!_generated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelText('Pick a difficulty, then send the code to your friend.', size: 15),
          const SizedBox(height: 12),
          _diffBar(),
          const SizedBox(height: 14),
          CartoonButton(label: 'GET A CODE', onTap: _generate),
        ],
      );
    }

    if (_isOnlineMode && _isWaitingForOpponent) {
      return _buildOnlineWaiting();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelText(
          _isOnlineMode ? 'Send this code to your friend to play together!' : 'Your friend can scan this or type the code',
          size: 15,
        ),
        const SizedBox(height: 10),
        if (!_isOnlineMode) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF0DFC0), width: 2),
              ),
              child: QrImageView(data: 'sudoku://challenge?pin=$_pin', version: QrVersions.auto, size: 150),
            ),
          ),
          const SizedBox(height: 10),
        ],
        _codeBox(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: CartoonButton(
                label: 'SHARE',
                color: const Color(0xFF4D7CFE),
                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                onTap: () => ShareService().shareChallenge(pin: _pin, difficulty: _cDiff),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CartoonButton(
                label: 'PLAY',
                onTap: () {
                  Navigator.pop(context);
                  widget.onStartChallenge(_cDiff, _seed, _pin);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The big game code with its difficulty.
  Widget _codeBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0DFC0), width: 2),
      ),
      child: Column(
        children: [
          const Text('GAME CODE', style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1, color: Color(0xFF8A7A9E))),
          FittedBox(
            child: Text(
              ChallengeUtils.formatPin(_pin),
              style: const TextStyle(fontFamily: kTitleFont, fontSize: 36, letterSpacing: 6, color: Color(0xFF8E5BEA)),
            ),
          ),
          Text(
            '${_cDiff[0].toUpperCase()}${_cDiff.substring(1)} puzzle',
            style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF8A7A9E)),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineWaiting() {
    final playerCount = _currentRoom?.players.length ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 6, color: Color(0xFFFF8A3D), backgroundColor: Color(0xFFFFE3CC)),
          ),
        ),
        const SizedBox(height: 12),
        const Center(child: OutlinedText('WAITING...', size: 24, color: Color(0xFFFFC23D), stroke: Color(0xFF9A4A00))),
        PanelText('$playerCount/2 players in the room', size: 14),
        const SizedBox(height: 12),
        _codeBox(),
        const SizedBox(height: 14),
        CartoonButton(
          label: 'SHARE CODE',
          color: const Color(0xFF4D7CFE),
          icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
          onTap: () => ShareService().shareChallenge(pin: _pin, difficulty: _cDiff),
        ),
        const SizedBox(height: 4),
        CartoonButton(label: 'CANCEL', color: const Color(0xFFF25A6B), height: 48, size: 18, onTap: _cancelOnlineRoom),
      ],
    );
  }

  Widget _buildJoin() {
    if (_isOnlineMode && _isWaitingForOpponent) {
      return _buildOnlineJoinWaiting();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelText(
          _isOnlineMode ? 'Type the 6-digit code to join the live race' : 'Type the 6-digit code your friend sent you',
          size: 15,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          enabled: !_isJoining,
          style: const TextStyle(fontFamily: kTitleFont, fontSize: 32, letterSpacing: 8, color: Color(0xFF8E5BEA)),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            hintText: '000000',
            hintStyle: const TextStyle(fontFamily: kTitleFont, fontSize: 32, letterSpacing: 8, color: Color(0xFFE6DCCB)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFF0DFC0), width: 2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFF0DFC0), width: 2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF8E5BEA), width: 3)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onSubmitted: (_) => _join(),
        ),
        if (_joinError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _joinError,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFF25A6B)),
          ),
        ],
        const SizedBox(height: 12),
        CartoonButton(label: _isJoining ? 'JOINING...' : 'START PLAYING', onTap: _isJoining ? null : _join),
      ],
    );
  }

  Widget _buildOnlineJoinWaiting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: Icon(Icons.check_circle_rounded, color: Color(0xFF3FB26B), size: 64)),
        const Center(child: OutlinedText('YOU\'RE IN!', size: 26, color: Color(0xFF7CE08A), stroke: Color(0xFF1F6E3F))),
        const PanelText('Waiting for your friend to start the race', size: 14),
        const SizedBox(height: 12),
        _codeBox(),
        const SizedBox(height: 14),
        CartoonButton.secondary(label: 'LEAVE ROOM', onTap: _cancelOnlineRoom),
      ],
    );
  }

  Widget _diffBar() {
    const diffs = [
      ('easy', 'EASY', Color(0xFF3FB26B)),
      ('medium', 'MEDIUM', Color(0xFFFF9F43)),
      ('hard', 'HARD', Color(0xFFF25A6B)),
      ('expert', 'EXPERT', Color(0xFF8E5BEA)),
    ];
    return Row(
      children: [
        for (final (id, label, color) in diffs)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () {
                  SoundService().playTap();
                  setState(() => _cDiff = id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 44,
                  decoration: BoxDecoration(
                    color: id == _cDiff ? color : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: id == _cDiff ? Colors.white : color, width: 2.5),
                    boxShadow: [BoxShadow(color: id == _cDiff ? Color.lerp(color, Colors.black, 0.35)! : color.withValues(alpha: 0.3), offset: const Offset(0, 3))],
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(label, style: TextStyle(fontFamily: kTitleFont, fontSize: 14, color: id == _cDiff ? Colors.white : color)),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
