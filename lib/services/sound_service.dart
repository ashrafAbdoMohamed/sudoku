import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../state/game_store.dart';

/// Sound effects and haptics for the Sudoku app.
///
/// The sounds are synthesized by `tools/generate_sfx.py` into `assets/sfx/`
/// (the same "glass marimba" set as Word Search). Audio failures are
/// swallowed: a missing sound must never break the game.
///
/// How playback is set up matters (learned the hard way in Word Search):
/// - A few preloaded players per sound, reused in turn. audioplayers'
///   AudioPool can't be used in low-latency mode: it never gets a "finished"
///   event there, so it creates a new native player per play and never frees
///   it, which makes long sessions slow and glitchy.
/// - No position polling: by default every player that has played asks
///   Android for its position on every frame, forever.
/// - Copies of one sound load one after another: on Android a copy reuses
///   the first one's loaded sound, and if it asks before that load finished
///   it stays silent for good.
/// - No audio focus: game sounds mix with music and ads instead of pausing
///   them.
/// - When Android's main thread is backed up, sounds are dropped instead of
///   queued, so a slow phone never builds up lag.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static const _sounds = [
    'tap', 'found', 'miss', 'hint', 'reveal', 'coin', 'star_1', 'star_2', //
    'star_3', 'win', 'whoosh', 'no_coins', 'tick_4',
  ];

  final Map<String, List<AudioPlayer>> _players = {};
  final Map<String, int> _next = {};
  bool _initialized = false;
  bool _soundEnabled = true;
  bool _hapticEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get hapticEnabled => _hapticEnabled;

  Future<void> init(GameStore store) async {
    if (_initialized) return;
    _soundEnabled = store.soundEnabled;
    _hapticEnabled = store.hapticEnabled;
    _initialized = true;
    try {
      final context = AudioContextConfig(respectSilence: true).build();
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: context.iOS,
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      await Future.wait(
        _sounds.map((name) async {
          final players = <AudioPlayer>[];
          for (var i = 0; i < 2; i++) {
            final player = AudioPlayer()..positionUpdater = null;
            await player.setPlayerMode(PlayerMode.lowLatency);
            await player.setReleaseMode(ReleaseMode.stop);
            await player.setSource(AssetSource('sfx/$name.wav'));
            await player.setVolume(_volume(name));
            players.add(player);
          }
          _players[name] = players;
        }),
      );
    } catch (e) {
      debugPrint('SoundService init failed: $e');
    }
  }

  void updateSettings({bool? sound, bool? haptic}) {
    if (sound != null) _soundEnabled = sound;
    if (haptic != null) _hapticEnabled = haptic;
  }

  static double _volume(String name) => switch (name) {
    'tap' || 'tick_4' => 0.6,
    'miss' || 'whoosh' => 0.7,
    'coin' => 0.8,
    _ => 1,
  };

  // ─── Sound Effects ───

  /// Play when tapping a cell
  Future<void> playTap() async {
    _haptic(HapticFeedback.selectionClick);
    _play('tap');
  }

  /// Play when inputting a number
  Future<void> playInput() async {
    _haptic(HapticFeedback.lightImpact);
    _play('tick_4');
  }

  /// Play when number is correct
  Future<void> playCorrect() async {
    _haptic(HapticFeedback.lightImpact);
    _play('found');
  }

  /// Play when number is wrong
  Future<void> playWrong() async {
    _haptic(HapticFeedback.heavyImpact);
    _play('miss');
  }

  /// Play when completing a row/column/box
  Future<void> playComplete() async {
    _haptic(HapticFeedback.mediumImpact);
    _play('star_2');
  }

  /// Play when winning the game
  Future<void> playWin() async {
    _haptic(HapticFeedback.heavyImpact);
    _play('win');
  }

  /// Play when losing the game
  Future<void> playLose() async {
    _haptic(HapticFeedback.vibrate);
    _play('no_coins');
  }

  /// Play when unlocking an achievement
  Future<void> playAchievement() async {
    _haptic(HapticFeedback.mediumImpact);
    _play('star_3');
  }

  /// Play when using a hint
  Future<void> playHint() async {
    _haptic(HapticFeedback.mediumImpact);
    _play('hint');
  }

  /// Play when erasing
  Future<void> playErase() async {
    _haptic(HapticFeedback.lightImpact);
    _play('whoosh');
  }

  /// Play when undoing
  Future<void> playUndo() async {
    _haptic(HapticFeedback.lightImpact);
    _play('whoosh');
  }

  /// Play button click
  Future<void> playClick() async {
    _haptic(HapticFeedback.lightImpact);
    _play('tap');
  }

  /// Play when coins are earned
  Future<void> playCoin() async {
    _haptic(HapticFeedback.mediumImpact);
    _play('coin');
  }

  /// Play for 1-3 stars on the win screen
  Future<void> playStar(int n) async {
    _play('star_${n.clamp(1, 3)}');
  }

  // ─── Internal Methods ───

  /// Plays not finished yet. Each play is two calls into Android's main
  /// thread (stop, then play); when the phone can't keep up, new sounds are
  /// dropped instead of queued.
  int _pending = 0;
  static const _maxPending = 6;

  void _play(String name) {
    if (!_soundEnabled || _pending >= _maxPending) return;
    final players = _players[name];
    if (players == null || players.isEmpty) return;
    final i = _next[name] ?? 0;
    _next[name] = (i + 1) % players.length;
    final player = players[i];
    _pending++;
    () async {
      try {
        // A call that never returns must not hold its slot forever.
        await () async {
          await player.stop();
          await player.resume();
        }().timeout(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('Sound $name failed: $e');
      } finally {
        _pending--;
      }
    }();
  }

  void _haptic(Function hapticFunction) {
    if (_hapticEnabled) {
      hapticFunction();
    }
  }

  void dispose() {
    for (final players in _players.values) {
      for (final p in players) {
        p.dispose();
      }
    }
    _players.clear();
  }
}

/// Extension for easier haptic feedback
extension HapticHelper on SoundService {
  void selectionClick() => _haptic(HapticFeedback.selectionClick);
  void lightImpact() => _haptic(HapticFeedback.lightImpact);
  void mediumImpact() => _haptic(HapticFeedback.mediumImpact);
  void heavyImpact() => _haptic(HapticFeedback.heavyImpact);
  void vibrate() => _haptic(HapticFeedback.vibrate);
}
