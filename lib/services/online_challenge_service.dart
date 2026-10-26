import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../models/online_room.dart';

/// Service for managing online multiplayer challenge rooms via Firebase Realtime Database
class OnlineChallengeService {
  static final OnlineChallengeService _instance = OnlineChallengeService._internal();
  factory OnlineChallengeService() => _instance;
  OnlineChallengeService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String? _currentRoomPin;
  String? _currentUid;
  StreamSubscription<DatabaseEvent>? _roomSubscription;

  /// True while the host's "delete room if I drop" handler is armed (waiting phase only)
  bool _roomRemovalArmed = false;

  final _roomStateController = StreamController<OnlineRoom?>.broadcast();
  Stream<OnlineRoom?> get roomStateStream => _roomStateController.stream;

  String? get currentRoomPin => _currentRoomPin;
  String? get currentUid => _currentUid;
  bool get isInRoom => _currentRoomPin != null;

  /// Get current room state immediately (for initial load)
  Future<OnlineRoom?> getCurrentRoom() async {
    if (_currentRoomPin == null) return null;

    try {
      final snapshot = await _db.child('rooms/$_currentRoomPin').get();
      if (!snapshot.exists) return null;

      final data = snapshot.value as Map<dynamic, dynamic>;
      return OnlineRoom.fromMap(_currentRoomPin!, data);
    } catch (_) {
      return null;
    }
  }

  /// Generate a unique 6-digit PIN for the room
  String _generatePin() {
    final random = Random();
    // Generate PIN between 100000 and 999999
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Generate a unique user ID for this session
  String _generateUid() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a new online challenge room
  Future<String?> createRoom(String difficulty, int seed, String playerName) async {
    // Clean up any existing room first
    await leaveRoom();

    // Try up to 5 times to generate a unique PIN
    for (int attempt = 0; attempt < 5; attempt++) {
      final pin = _generatePin();
      final roomRef = _db.child('rooms/$pin');

      // Check if room already exists
      final snapshot = await roomRef.get();
      if (snapshot.exists) continue;

      _currentUid = _generateUid();
      _currentRoomPin = pin;

      final now = DateTime.now().millisecondsSinceEpoch;
      final roomData = {
        'difficulty': difficulty,
        'seed': seed,
        'status': 'waiting',
        'createdAt': now,
        'startedAt': null,
        'winner': null,
        'players': {
          _currentUid!: {
            'name': playerName,
            'progress': 0,
            'mistakes': 0,
            'status': 'waiting',
            'finishTime': null,
            'lastSeen': now,
          }
        }
      };

      try {
        await roomRef.set(roomData);
        // If the host drops before anyone joins, the server deletes the room
        await roomRef.onDisconnect().remove();
        _roomRemovalArmed = true;
        _startListening();
        return pin;
      } catch (e) {
        _currentRoomPin = null;
        _currentUid = null;
        continue;
      }
    }
    return null;
  }

  /// Join an existing room by PIN
  Future<({bool success, String? error, String? difficulty, int? seed})> joinRoom(String pin, String playerName) async {
    // Clean up any existing room first
    await leaveRoom();

    final roomRef = _db.child('rooms/$pin');
    final snapshot = await roomRef.get();

    if (!snapshot.exists) {
      return (success: false, error: 'Room not found. Check the PIN and try again.', difficulty: null, seed: null);
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    final room = OnlineRoom.fromMap(pin, data);

    if (room.isFull) {
      return (success: false, error: 'Room is full. Only 2 players allowed.', difficulty: null, seed: null);
    }

    if (!room.isWaiting) {
      return (success: false, error: 'Game already started in this room.', difficulty: null, seed: null);
    }

    // Check if room is expired (older than 1 hour)
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - room.createdAt > 3600000) {
      // Clean up expired room
      await roomRef.remove();
      return (success: false, error: 'This challenge has expired. Ask for a new PIN.', difficulty: null, seed: null);
    }

    _currentUid = _generateUid();
    _currentRoomPin = pin;

    final playerData = {
      'name': playerName,
      'progress': 0,
      'mistakes': 0,
      'status': 'waiting',
      'finishTime': null,
      'lastSeen': now,
    };

    try {
      await roomRef.child('players/$_currentUid').set(playerData);
      await _armPlayerDisconnect();
      _startListening();
      return (success: true, error: null, difficulty: room.difficulty, seed: room.seed);
    } catch (e) {
      _currentRoomPin = null;
      _currentUid = null;
      return (success: false, error: 'Failed to join room. Please try again.', difficulty: null, seed: null);
    }
  }

  /// Leave the current room
  Future<void> leaveRoom() async {
    _stopListening();

    if (_currentRoomPin != null && _currentUid != null) {
      final roomRef = _db.child('rooms/$_currentRoomPin');
      final pin = _currentRoomPin!;

      // We're leaving cleanly - drop pending server-side handlers so they
      // can't recreate a partial room after it has been deleted
      try {
        await roomRef.onDisconnect().cancel();
      } catch (_) {}
      _roomRemovalArmed = false;

      // Mark player as disconnected
      try {
        await roomRef.child('players/$_currentUid/status').set('disconnected');
      } catch (_) {}

      // Check room state and clean up if needed
      try {
        final snapshot = await roomRef.get();
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          final room = OnlineRoom.fromMap(pin, data);

          // If room is waiting and we're the only player, delete the room
          if (room.isWaiting && room.players.length == 1) {
            await roomRef.remove();
          } else {
            // Check if all players are disconnected or finished - delete the room
            bool allDone = true;
            for (final player in room.players.values) {
              if (player.status != 'disconnected' && player.status != 'finished') {
                allDone = false;
                break;
              }
            }
            if (allDone) {
              await roomRef.remove();
            }
          }
        }
      } catch (_) {}
    }

    _currentRoomPin = null;
    _currentUid = null;
    _roomStateController.add(null);
  }

  /// Mark both players as ready and start the game
  Future<void> startGame() async {
    if (_currentRoomPin == null) return;

    final roomRef = _db.child('rooms/$_currentRoomPin');
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // Read the whole room: on iOS a child get() while the room is being
      // listened to can return the room itself, which wrote every room field
      // (createdAt, seed...) in as a fake player.
      final snapshot = await roomRef.get();
      if (!snapshot.exists) return;

      final players = OnlineRoom.fromMap(_currentRoomPin!, snapshot.value as Map<dynamic, dynamic>).players;
      final updates = <String, dynamic>{
        'status': 'playing',
        'startedAt': now,
      };

      // Set all players to 'playing'
      for (final uid in players.keys) {
        updates['players/$uid/status'] = 'playing';
      }

      await roomRef.update(updates);
    } catch (_) {}
  }

  /// Update player's progress (cells filled and mistakes)
  Future<void> updateProgress(int filledCells, int mistakes) async {
    if (_currentRoomPin == null || _currentUid == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final updates = {
        'progress': filledCells,
        'mistakes': mistakes,
        'lastSeen': now,
      };
      await _db.child('rooms/$_currentRoomPin/players/$_currentUid').update(updates);
    } catch (_) {
      // Silently fail - will retry on next update
    }
  }

  /// Mark player as finished with their completion time
  Future<void> markFinished(int totalSeconds) async {
    if (_currentRoomPin == null || _currentUid == null) return;

    final roomRef = _db.child('rooms/$_currentRoomPin');
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // Update this player's status
      await roomRef.child('players/$_currentUid').update({
        'status': 'finished',
        'finishTime': totalSeconds,
        'progress': 81,
        'lastSeen': now,
      });

      // Check if both players finished to determine winner
      final snapshot = await roomRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final room = OnlineRoom.fromMap(_currentRoomPin!, data);

      // Check if all players have finished
      bool allFinished = true;
      String? winner;
      int? bestTime;

      for (final entry in room.players.entries) {
        if (!entry.value.isFinished && !entry.value.isDisconnected) {
          allFinished = false;
          break;
        }
        if (entry.value.isFinished) {
          final time = entry.value.finishTime;
          if (time != null && (bestTime == null || time < bestTime)) {
            bestTime = time;
            winner = entry.key;
          }
        }
      }

      if (allFinished && winner != null) {
        await roomRef.update({
          'status': 'finished',
          'winner': winner,
        });
      }
    } catch (_) {}
  }

  /// Mark player as lost (too many mistakes)
  Future<void> markLost() async {
    if (_currentRoomPin == null || _currentUid == null) return;

    final roomRef = _db.child('rooms/$_currentRoomPin');
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await roomRef.child('players/$_currentUid').update({
        'status': 'finished',
        'finishTime': null, // null indicates they lost
        'lastSeen': now,
      });

      // Check if opponent won by default
      final snapshot = await roomRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final room = OnlineRoom.fromMap(_currentRoomPin!, data);
      final opponentUid = room.getOpponentUid(_currentUid!);

      if (opponentUid != null) {
        final opponent = room.players[opponentUid];
        if (opponent != null && (opponent.isFinished || opponent.isDisconnected)) {
          // Determine winner
          String? winner;
          if (opponent.isFinished && opponent.finishTime != null) {
            winner = opponentUid;
          }
          await roomRef.update({
            'status': 'finished',
            'winner': winner,
          });
        }
      }
    } catch (_) {}
  }

  /// Let the server mark this player disconnected if the app dies or loses network.
  /// Replaces a client heartbeat - the server detects the dropped socket itself.
  Future<void> _armPlayerDisconnect() async {
    if (_currentRoomPin == null || _currentUid == null) return;
    try {
      await _db
          .child('rooms/$_currentRoomPin/players/$_currentUid')
          .onDisconnect()
          .update({'status': 'disconnected'});
    } catch (_) {}
  }

  /// Once the game starts, swap the host's "delete room" handler for a
  /// per-player one so a drop mid-game doesn't wipe the opponent's room
  Future<void> _onGameStarted() async {
    if (!_roomRemovalArmed || _currentRoomPin == null) return;
    _roomRemovalArmed = false;
    try {
      await _db.child('rooms/$_currentRoomPin').onDisconnect().cancel();
    } catch (_) {}
    await _armPlayerDisconnect();
  }

  void _startListening() {
    _stopListening();

    if (_currentRoomPin == null) return;

    _roomSubscription = _db.child('rooms/$_currentRoomPin').onValue.listen((event) {
      if (!event.snapshot.exists) {
        _roomStateController.add(null);
        return;
      }

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final room = OnlineRoom.fromMap(_currentRoomPin!, data);

      if (room.isPlaying) _onGameStarted();

      // Emit the room state - let the UI handle display
      // Don't auto-mark players as disconnected here to avoid race conditions
      _roomStateController.add(room);
    });
  }

  void _stopListening() {
    _roomSubscription?.cancel();
    _roomSubscription = null;
  }

  /// Clean up resources
  void dispose() {
    _stopListening();
    _roomStateController.close();
  }
}
