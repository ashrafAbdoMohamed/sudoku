// Data models for online multiplayer rooms

class OnlineRoom {
  final String pin;
  final String difficulty;
  final int seed;
  final String status; // 'waiting', 'playing', 'finished'
  final Map<String, PlayerState> players;
  final int createdAt;
  final int? startedAt;
  final String? winner;

  OnlineRoom({
    required this.pin,
    required this.difficulty,
    required this.seed,
    required this.status,
    required this.players,
    required this.createdAt,
    this.startedAt,
    this.winner,
  });

  factory OnlineRoom.fromMap(String pin, Map<dynamic, dynamic> data) {
    final playersData = data['players'] as Map<dynamic, dynamic>? ?? {};
    final players = <String, PlayerState>{};
    playersData.forEach((key, value) {
      // Only real players (they always have a name); skips stray entries.
      if (value is Map && value['name'] != null) {
        players[key.toString()] = PlayerState.fromMap(value);
      }
    });

    return OnlineRoom(
      pin: pin,
      difficulty: data['difficulty'] as String? ?? 'medium',
      seed: data['seed'] as int? ?? 0,
      status: data['status'] as String? ?? 'waiting',
      players: players,
      createdAt: data['createdAt'] as int? ?? 0,
      startedAt: data['startedAt'] as int?,
      winner: data['winner'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'difficulty': difficulty,
      'seed': seed,
      'status': status,
      'players': players.map((k, v) => MapEntry(k, v.toMap())),
      'createdAt': createdAt,
      'startedAt': startedAt,
      'winner': winner,
    };
  }

  bool get isFull => players.length >= 2;
  bool get isWaiting => status == 'waiting';
  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';

  PlayerState? getOpponent(String myUid) {
    for (final entry in players.entries) {
      if (entry.key != myUid) return entry.value;
    }
    return null;
  }

  String? getOpponentUid(String myUid) {
    for (final uid in players.keys) {
      if (uid != myUid) return uid;
    }
    return null;
  }
}

class PlayerState {
  final String name;
  final int progress; // cells filled (0-81)
  final int mistakes;
  final String status; // 'waiting', 'playing', 'finished', 'disconnected'
  final int? finishTime; // seconds when finished
  final int lastSeen; // timestamp

  PlayerState({
    required this.name,
    this.progress = 0,
    this.mistakes = 0,
    this.status = 'waiting',
    this.finishTime,
    required this.lastSeen,
  });

  factory PlayerState.fromMap(Map<dynamic, dynamic> data) {
    return PlayerState(
      name: data['name'] as String? ?? 'Player',
      progress: data['progress'] as int? ?? 0,
      mistakes: data['mistakes'] as int? ?? 0,
      status: data['status'] as String? ?? 'waiting',
      finishTime: data['finishTime'] as int?,
      lastSeen: data['lastSeen'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'progress': progress,
      'mistakes': mistakes,
      'status': status,
      'finishTime': finishTime,
      'lastSeen': lastSeen,
    };
  }

  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';
  bool get isDisconnected => status == 'disconnected';
  bool get isWaiting => status == 'waiting';

  double get progressPercent => progress / 81;
}
