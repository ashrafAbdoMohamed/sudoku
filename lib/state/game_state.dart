import 'dart:math';
import 'package:flutter/foundation.dart';
import '../engine/sudoku_engine.dart';
import '../state/game_store.dart';

enum GameStatus { playing, won, lost }

class UndoEntry {
  final int r, c;
  final String type; // 'val' or 'note'
  final int prevVal;
  final int nextVal;
  final Set<int> prevNotes;
  final Set<int> nextNotes;

  UndoEntry({
    required this.r,
    required this.c,
    required this.type,
    this.prevVal = 0,
    this.nextVal = 0,
    Set<int>? prevNotes,
    Set<int>? nextNotes,
  })  : prevNotes = prevNotes ?? {},
        nextNotes = nextNotes ?? {};
}

class GameState extends ChangeNotifier {
  List<List<int>> puzzle = [];
  List<List<int>> solution = [];
  List<List<int>> board = [];
  List<List<bool>> isGiven = [];
  List<List<Set<int>>> notes = [];
  Set<String> hintCells = {};
  List<UndoEntry> undoStack = [];

  int? selectedRow;
  int? selectedCol;
  int mistakes = 0;
  int seconds = 0;
  bool paused = false;
  bool notesMode = false;
  bool gameOver = false;
  String difficulty = 'easy';
  GameStatus status = GameStatus.playing;

  // Challenge mode
  bool challengeMode = false;
  int? challengeSeed;
  String? challengePin;

  // Online challenge mode
  bool onlineMode = false;
  void Function(int filledCells, int mistakes)? onProgressChange;
  void Function(int totalSeconds)? onGameWon;
  void Function()? onGameLost;

  // Daily challenge mode
  bool dailyMode = false;
  void Function(int totalSeconds, int mistakes)? onDailyWon;
  void Function(int totalSeconds, int mistakes)? onDailyLost;

  static const maxMistakes = 5;

  /// Analytics label for the current mode
  /// The Journey level being played, or null outside the Journey.
  int? journeyLevel;

  /// Times Hint was used this game (Magic shows in [hintCells]).
  int hintsUsed = 0;

  /// The cell a Hint pointed at ("r,c"), glowing until it is filled.
  String? hintGlow;

  /// Whether Hint or Magic helped in this game (costs a star).
  bool get usedHelp => hintsUsed > 0 || hintCells.isNotEmpty;

  String get mode => journeyLevel != null
      ? 'journey'
      : onlineMode ? 'online' : dailyMode ? 'daily' : challengeMode ? 'challenge' : 'classic';

  bool get hasSelection => selectedRow != null && selectedCol != null;
  int get selectedValue => hasSelection && board.isNotEmpty ? board[selectedRow!][selectedCol!] : 0;

  bool get isGenerating => _generating;
  bool _generating = false;

  Future<void> newGame(String diff, {int? seed, String? pin, bool online = false, bool isDaily = false, int? journeyLevel}) async {
    difficulty = diff;
    this.journeyLevel = journeyLevel;
    // Journey levels are seeded too, but they aren't challenges.
    challengeMode = seed != null && journeyLevel == null;
    challengeSeed = seed;
    challengePin = pin;
    onlineMode = online;
    dailyMode = isDaily;

    // Reset state immediately
    puzzle = [];
    solution = [];
    board = [];
    isGiven = [];
    notes = [];
    hintCells = {};
    hintsUsed = 0;
    hintGlow = null;
    undoStack = [];
    selectedRow = null;
    selectedCol = null;
    mistakes = 0;
    seconds = 0;
    paused = false;
    notesMode = false;
    gameOver = false;
    status = GameStatus.playing;
    _generating = true;
    notifyListeners();

    // Generate in isolate
    final result = await compute(_generatePuzzle, {'diff': diff, 'seed': seed});

    puzzle = result['puzzle']!;
    solution = result['solution']!;
    board = puzzle.map((r) => List<int>.from(r)).toList();
    isGiven = puzzle.map((r) => r.map((v) => v != 0).toList()).toList();
    notes = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
    _generating = false;
    notifyListeners();
  }

  void loadFromSaved(SavedGame saved) {
    puzzle = saved.puzzle;
    solution = saved.solution;
    board = saved.board;
    isGiven = saved.isGiven;
    notes = saved.notes.map((r) => r.map((c) => Set<int>.from(c)).toList()).toList();
    hintCells = Set<String>.from(saved.hintCells);
    hintsUsed = 0;
    hintGlow = null;
    difficulty = saved.difficulty;
    seconds = saved.seconds;
    mistakes = saved.mistakes;
    undoStack = [];
    selectedRow = null;
    selectedCol = null;
    paused = false;
    notesMode = false;
    gameOver = false;
    challengeMode = false;
    dailyMode = false;
    journeyLevel = saved.journeyLevel;
    status = GameStatus.playing;
    notifyListeners();
  }

  SavedGame toSavedGame() => SavedGame(
    puzzle: puzzle,
    solution: solution,
    board: board,
    isGiven: isGiven,
    notes: notes.map((r) => r.map((s) => s.toList()).toList()).toList(),
    difficulty: difficulty,
    seconds: seconds,
    mistakes: mistakes,
    hintCells: hintCells.toList(),
    journeyLevel: journeyLevel,
  );

  void selectCell(int r, int c) {
    if (paused || gameOver || _generating) return;
    selectedRow = r;
    selectedCol = c;
    notifyListeners();
  }

  void inputNumber(int n) {
    if (!hasSelection || gameOver || paused || _generating) return;
    final r = selectedRow!, c = selectedCol!;
    if (isGiven[r][c]) return;

    if (notesMode) {
      if (board[r][c] != 0) return;
      final prev = Set<int>.from(notes[r][c]);
      if (notes[r][c].contains(n)) {
        notes[r][c].remove(n);
      } else {
        notes[r][c].add(n);
      }
      undoStack.add(UndoEntry(r: r, c: c, type: 'note', prevNotes: prev, nextNotes: Set.from(notes[r][c])));
    } else {
      final prevVal = board[r][c];
      final prevNotes = Set<int>.from(notes[r][c]);
      board[r][c] = n;
      notes[r][c].clear();
      undoStack.add(UndoEntry(r: r, c: c, type: 'val', prevVal: prevVal, nextVal: n, prevNotes: prevNotes));

      if (n != solution[r][c]) {
        mistakes++;
        if (mistakes >= maxMistakes) {
          gameOver = true;
          status = GameStatus.lost;
          // Reveal solution
          for (int rr = 0; rr < 9; rr++) {
            for (int cc = 0; cc < 9; cc++) {
              if (!isGiven[rr][cc]) board[rr][cc] = solution[rr][cc];
            }
          }
          // Trigger online lost callback
          if (onlineMode) onGameLost?.call();
          // Trigger daily lost callback
          if (dailyMode) onDailyLost?.call(seconds, mistakes);
        }
      } else {
        if (hintGlow == '$r,$c') hintGlow = null;
        _checkWin();
      }
    }
    // Notify progress change for online sync
    _notifyProgressChange();
    notifyListeners();
  }

  void _notifyProgressChange() {
    if (!onlineMode || onProgressChange == null) return;
    final filled = _countFilledCells();
    onProgressChange!(filled, mistakes);
  }

  int _countFilledCells() {
    if (board.isEmpty) return 0;
    int count = 0;
    for (var row in board) {
      for (var cell in row) {
        if (cell != 0) count++;
      }
    }
    return count;
  }

  void eraseCell() {
    if (!hasSelection || gameOver || paused || _generating) return;
    final r = selectedRow!, c = selectedCol!;
    if (isGiven[r][c]) return;

    if (board[r][c] != 0) {
      undoStack.add(UndoEntry(r: r, c: c, type: 'val', prevVal: board[r][c], nextVal: 0, prevNotes: Set.from(notes[r][c])));
      board[r][c] = 0;
      _notifyProgressChange();
    } else if (notes[r][c].isNotEmpty) {
      undoStack.add(UndoEntry(r: r, c: c, type: 'note', prevNotes: Set.from(notes[r][c]), nextNotes: {}));
      notes[r][c].clear();
    }
    notifyListeners();
  }

  void undo() {
    if (undoStack.isEmpty || gameOver) return;
    final mv = undoStack.removeLast();
    if (mv.type == 'val') {
      if (mv.nextVal != 0 && mv.nextVal != solution[mv.r][mv.c]) {
        mistakes = (mistakes - 1).clamp(0, maxMistakes);
      }
      board[mv.r][mv.c] = mv.prevVal;
      notes[mv.r][mv.c] = mv.prevNotes;
    } else {
      notes[mv.r][mv.c] = mv.prevNotes;
    }
    selectedRow = mv.r;
    selectedCol = mv.c;
    notifyListeners();
  }

  void toggleNotes() {
    notesMode = !notesMode;
    notifyListeners();
  }

  /// Magic: fills the selected cell with its answer, or a random empty cell
  /// when nothing fillable is selected.
  void magicFill() {
    if (gameOver || paused || _generating) return;
    if (hasSelection) {
      final r = selectedRow!, c = selectedCol!;
      if (!isGiven[r][c] && board[r][c] != solution[r][c]) {
        undoStack.add(UndoEntry(r: r, c: c, type: 'val', prevVal: board[r][c], nextVal: solution[r][c], prevNotes: Set.from(notes[r][c])));
        board[r][c] = solution[r][c];
        notes[r][c].clear();
        hintCells.add('$r,$c');
        if (hintGlow == '$r,$c') hintGlow = null;
        _notifyProgressChange();
        _checkWin();
        notifyListeners();
        return;
      }
    }
    giveHint();
  }

  /// Hint: points at the easiest cell to solve now (the empty cell with the
  /// fewest possible numbers) and selects it, without giving its number.
  /// Returns false if there is nothing to point at.
  bool pointHint() {
    if (gameOver || paused || _generating) return false;
    int? bestR, bestC;
    var fewest = 10;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (isGiven[r][c] || board[r][c] == solution[r][c]) continue;
        final n = _candidates(r, c);
        if (n < fewest) {
          fewest = n;
          bestR = r;
          bestC = c;
        }
      }
    }
    if (bestR == null || bestC == null) return false;
    hintsUsed++;
    hintGlow = '$bestR,$bestC';
    selectedRow = bestR;
    selectedCol = bestC;
    notifyListeners();
    return true;
  }

  /// How many numbers could go in (r, c) given the numbers already placed
  /// correctly in its row, column and box.
  int _candidates(int r, int c) {
    final used = <int>{};
    for (var i = 0; i < 9; i++) {
      if (board[r][i] != 0 && board[r][i] == solution[r][i]) used.add(board[r][i]);
      if (board[i][c] != 0 && board[i][c] == solution[i][c]) used.add(board[i][c]);
    }
    final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
    for (var i = br; i < br + 3; i++) {
      for (var j = bc; j < bc + 3; j++) {
        if (board[i][j] != 0 && board[i][j] == solution[i][j]) used.add(board[i][j]);
      }
    }
    return 9 - used.length;
  }

  void giveHint() {
    if (gameOver || paused || _generating) return;
    final empty = <Point<int>>[];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (!isGiven[r][c] && board[r][c] == 0) empty.add(Point(r, c));
      }
    }
    if (empty.isEmpty) return;
    final p = empty[Random().nextInt(empty.length)];
    final r = p.x, c = p.y;
    undoStack.add(UndoEntry(r: r, c: c, type: 'val', prevVal: 0, nextVal: solution[r][c], prevNotes: Set.from(notes[r][c])));
    board[r][c] = solution[r][c];
    notes[r][c].clear();
    hintCells.add('$r,$c');
    selectedRow = r;
    selectedCol = c;
    _notifyProgressChange();
    _checkWin();
    notifyListeners();
  }

  void togglePause() {
    if (gameOver) return;
    paused = !paused;
    notifyListeners();
  }

  void tick() {
    if (!paused && !gameOver && !_generating) {
      seconds++;
      notifyListeners();
    }
  }

  void _checkWin() {
    if (board.isEmpty || solution.isEmpty) return;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] != solution[r][c]) return;
      }
    }
    gameOver = true;
    status = GameStatus.won;
    // Trigger online win callback
    if (onlineMode) onGameWon?.call(seconds);
    // Trigger daily win callback
    if (dailyMode) onDailyWon?.call(seconds, mistakes);
  }

  int countForNumber(int n) {
    if (board.isEmpty) return 0;
    int count = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == n) count++;
      }
    }
    return count;
  }
}

// Top-level function for compute isolate
Map<String, List<List<int>>> _generatePuzzle(Map<String, dynamic> params) {
  final diff = params['diff'] as String;
  final seed = params['seed'] as int?;
  final engine = SudokuEngine(seed: seed);
  engine.generate(diff);
  return {'puzzle': engine.puzzle, 'solution': engine.solution};
}
