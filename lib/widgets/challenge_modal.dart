import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/challenge_utils.dart';
import '../main.dart' show isFirebaseAvailable;
import '../services/online_challenge_service.dart';
import '../services/share_service.dart';
import '../services/analytics_service.dart';
import '../models/online_room.dart';

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
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚔️', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 8),
            Text(
              'Play with a Friend',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.text),
            ),
            const SizedBox(height: 16),
            // Online toggle (only show if Firebase is available)
            if (isFirebaseAvailable) ...[
              _buildOnlineToggle(),
              const SizedBox(height: 12),
            ],
            // Tabs
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [_tab('Host Game', _isCreateTab), _tab('Enter Code', !_isCreateTab)]),
            ),
            const SizedBox(height: 18),
            if (_isCreateTab) _buildCreate() else _buildJoin(),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineToggle() {
    return GestureDetector(
      onTap: () {
        if (_generated || _isWaitingForOpponent) return;
        setState(() => _isOnlineMode = !_isOnlineMode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isOnlineMode ? c.primary.withValues(alpha: 0.1) : c.surface2,
          border: Border.all(
            color: _isOnlineMode ? c.primary : c.border,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _isOnlineMode ? c.primary : c.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                _isOnlineMode ? '🌐' : '📱',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOnlineMode ? 'Online Mode' : 'Offline Mode',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isOnlineMode ? c.primary : c.text,
                    ),
                  ),
                  Text(
                    _isOnlineMode
                        ? 'Real-time multiplayer with live progress'
                        : 'Share PIN to compare scores later',
                    style: TextStyle(fontSize: 10, color: c.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: _isOnlineMode ? c.primary : c.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(2),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _isOnlineMode ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isWaitingForOpponent) return;
          setState(() => _isCreateTab = label == 'Host Game');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? c.primary : c.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildCreate() {
    if (!_generated) {
      return Column(
        children: [
          Text(
            'Pick a difficulty level, then share the code with your friend',
            style: TextStyle(fontSize: 13, color: c.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _diffBar(),
          const SizedBox(height: 16),
          _gradBtn('Create Game Code →', _generate),
        ],
      );
    }

    // Online mode - waiting for opponent
    if (_isOnlineMode && _isWaitingForOpponent) {
      return _buildOnlineWaiting();
    }

    // Offline mode or online game started
    return Column(
      children: [
        Text(
          _isOnlineMode
              ? 'Share this code with your friend to play together!'
              : 'Your friend can scan the QR code or type the code below',
          style: TextStyle(fontSize: 13, color: c.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (!_isOnlineMode) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: QrImageView(data: 'sudoku://challenge?pin=$_pin', version: QrVersions.auto, size: 160),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Divider(color: c.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('or enter code', style: TextStyle(fontSize: 11, color: c.textMuted)),
              ),
              Expanded(child: Divider(color: c.border)),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Text(
          ChallengeUtils.formatPin(_pin),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.primary, letterSpacing: 8),
        ),
        const SizedBox(height: 4),
        Text(
          'Difficulty: ${_cDiff[0].toUpperCase()}${_cDiff.substring(1)}',
          style: TextStyle(fontSize: 11, color: c.textMuted),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            // Share button
            Expanded(
              child: GestureDetector(
                onTap: () {
                  ShareService().shareChallenge(pin: _pin, difficulty: _cDiff);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '📤 Share',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _gradBtn('Play Now →', () {
                Navigator.pop(context);
                widget.onStartChallenge(_cDiff, _seed, _pin);
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOnlineWaiting() {
    final playerCount = _currentRoom?.players.length ?? 1;

    return Column(
      children: [
        // Animated waiting indicator
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(c.primary),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Waiting for opponent...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text),
        ),
        const SizedBox(height: 6),
        Text(
          '$playerCount/2 players in room',
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
        const SizedBox(height: 20),
        // PIN display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                'GAME CODE',
                style: TextStyle(fontSize: 10, color: c.textMuted, letterSpacing: 1),
              ),
              const SizedBox(height: 6),
              Text(
                ChallengeUtils.formatPin(_pin),
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c.primary, letterSpacing: 8),
              ),
              const SizedBox(height: 6),
              Text(
                'Difficulty: ${_cDiff[0].toUpperCase()}${_cDiff.substring(1)}',
                style: TextStyle(fontSize: 11, color: c.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Share and Cancel buttons
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  ShareService().shareChallenge(pin: _pin, difficulty: _cDiff);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4F6EF7), Color(0xFFA855F7)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '📤 Share',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: _cancelOnlineRoom,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.errColor, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.errColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJoin() {
    // Online mode - waiting after joining
    if (_isOnlineMode && _isWaitingForOpponent) {
      return _buildOnlineJoinWaiting();
    }

    return Column(
      children: [
        Text(
          _isOnlineMode
              ? 'Enter the 6-digit code to join the live game'
              : 'Enter the 6-digit code your friend shared with you',
          style: TextStyle(fontSize: 13, color: c.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          enabled: !_isJoining,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c.text, letterSpacing: 8),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: c.surface2,
            hintText: '123456',
            hintStyle: TextStyle(fontSize: 18, color: c.textMuted, letterSpacing: 3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
          onSubmitted: (_) => _join(),
        ),
        if (_joinError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_joinError, style: TextStyle(fontSize: 12, color: c.errColor), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 10),
        _isJoining
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c.primary.withValues(alpha: 0.5), const Color(0xFFA855F7).withValues(alpha: 0.5)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                ),
              )
            : _gradBtn('Start Playing →', _join),
      ],
    );
  }

  Widget _buildOnlineJoinWaiting() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Text('✓', style: TextStyle(fontSize: 40, color: Color(0xFF10B981))),
        ),
        const SizedBox(height: 16),
        Text(
          'Joined! Starting soon...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text),
        ),
        const SizedBox(height: 6),
        Text(
          'Waiting for host to start the game',
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _joinStat(ChallengeUtils.formatPin(_pin), 'Code'),
              _joinStat(_cDiff[0].toUpperCase() + _cDiff.substring(1), 'Difficulty'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _cancelOnlineRoom,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              'Leave Room',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.text),
            ),
          ),
        ),
      ],
    );
  }

  Widget _joinStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.primary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: c.textMuted)),
      ],
    );
  }

  Widget _diffBar() {
    const diffs = ['easy', 'medium', 'hard', 'expert'];
    return Row(
      children: diffs.map((d) {
        final active = d == _cDiff;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() => _cDiff = d),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? c.primary : c.surface,
                  border: Border.all(color: active ? c.primary : c.border, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  d[0].toUpperCase() + d.substring(1),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : c.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _gradBtn(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4F6EF7), Color(0xFFA855F7)]),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
    );
  }
}
