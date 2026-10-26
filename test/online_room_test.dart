import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/online_room.dart';

void main() {
  test('stray entries under players are not opponents', () {
    // What an iOS host wrote before the startGame fix.
    final room = OnlineRoom.fromMap('531100', {
      'difficulty': 'medium',
      'seed': 19252,
      'status': 'playing',
      'createdAt': 1,
      'players': {
        'createdAt': {'status': 'playing'},
        'difficulty': {'status': 'playing'},
        'f8dpcfd2qdv7c34i': {'name': 'Ana', 'status': 'playing', 'progress': 40},
        'seed': {'status': 'playing'},
        '5pe0i7j97guh0a1z': {'name': 'Ben', 'status': 'playing', 'progress': 30},
      },
    });
    expect(room.players.length, 2);
    expect(room.getOpponent('5pe0i7j97guh0a1z')?.name, 'Ana');
    expect(room.getOpponentUid('f8dpcfd2qdv7c34i'), '5pe0i7j97guh0a1z');
  });
}
