import 'dart:math';

class SudokuEngine {
  late List<List<int>> puzzle;
  late List<List<int>> solution;
  Random? _rng;

  SudokuEngine({int? seed}) {
    _rng = seed != null ? Random(seed) : null;
  }

  void generate(String difficulty) {
    final grid = List.generate(9, (_) => List.filled(9, 0));
    for (int i = 0; i < 9; i += 3) {
      _fillBox(grid, i, i);
    }
    _solve(grid);
    solution = grid.map((r) => List<int>.from(r)).toList();

    final targets = {'easy': 32, 'medium': 30, 'hard': 26, 'expert': 22};
    int toRemove = 81 - (targets[difficulty] ?? 36);

    final positions = List.generate(81, (i) => i);
    _shuffle(positions);

    for (final pos in positions) {
      if (toRemove == 0) break;
      final r = pos ~/ 9, c = pos % 9;
      final backup = grid[r][c];
      grid[r][c] = 0;
      if (_countSolutions(grid, 2) != 1) {
        grid[r][c] = backup;
      } else {
        toRemove--;
      }
    }

    puzzle = grid.map((r) => List<int>.from(r)).toList();
    _rng = null;
  }

  void _fillBox(List<List<int>> grid, int r, int c) {
    final nums = _shuffle([1, 2, 3, 4, 5, 6, 7, 8, 9]);
    for (int i = 0; i < 9; i++) {
      grid[r + i ~/ 3][c + i % 3] = nums[i];
    }
  }

  List<T> _shuffle<T>(List<T> list) {
    final result = List<T>.from(list);
    final rand = _rng ?? Random();
    for (int i = result.length - 1; i > 0; i--) {
      final j = rand.nextInt(i + 1);
      final tmp = result[i];
      result[i] = result[j];
      result[j] = tmp;
    }
    return result;
  }

  bool _isValid(List<List<int>> grid, int r, int c, int n) {
    for (int i = 0; i < 9; i++) {
      if (grid[r][i] == n || grid[i][c] == n) return false;
    }
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    for (int dr = 0; dr < 3; dr++) {
      for (int dc = 0; dc < 3; dc++) {
        if (grid[br + dr][bc + dc] == n) return false;
      }
    }
    return true;
  }

  bool _solve(List<List<int>> grid) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (grid[r][c] == 0) {
          for (int n = 1; n <= 9; n++) {
            if (_isValid(grid, r, c, n)) {
              grid[r][c] = n;
              if (_solve(grid)) return true;
              grid[r][c] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  int _countSolutions(List<List<int>> grid, int limit) {
    int count = 0;
    void go(List<List<int>> g) {
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (g[r][c] == 0) {
            for (int n = 1; n <= 9; n++) {
              if (count < limit && _isValid(g, r, c, n)) {
                g[r][c] = n;
                go(g);
                g[r][c] = 0;
              }
            }
            return;
          }
        }
      }
      count++;
    }

    go(grid.map((r) => List<int>.from(r)).toList());
    return count;
  }
}

