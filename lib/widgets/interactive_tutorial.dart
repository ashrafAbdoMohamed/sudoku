import 'package:flutter/material.dart';
import '../game/cartoon_dialog.dart';
import '../game/ui_kit.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Interactive tutorial where users practice basic Sudoku actions
class InteractiveTutorial extends StatefulWidget {
  final AppColorScheme colors;
  final VoidCallback onComplete;

  const InteractiveTutorial({
    super.key,
    required this.colors,
    required this.onComplete,
  });

  @override
  State<InteractiveTutorial> createState() => _InteractiveTutorialState();
}

class _InteractiveTutorialState extends State<InteractiveTutorial>
    with TickerProviderStateMixin {
  AppColorScheme get c => widget.colors;

  int _currentStep = 0;
  bool _stepCompleted = false;

  // Mini 4x4 grid for tutorial (simpler than 9x9)
  final List<List<int>> _puzzle = [
    [1, 0, 3, 4],
    [0, 4, 0, 2],
    [4, 0, 2, 0],
    [2, 3, 0, 1],
  ];

  late List<List<int>> _board;
  late List<List<bool>> _isGiven;
  late List<List<Set<int>>> _notes;

  int? _selectedRow;
  int? _selectedCol;
  bool _notesMode = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _highlightController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _highlightAnimation;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: 'Select a Cell',
      instruction: 'Tap the highlighted empty cell to select it',
      targetRow: 0,
      targetCol: 1,
      action: TutorialAction.selectCell,
    ),
    TutorialStep(
      title: 'Enter a Number',
      instruction: 'Now tap the number 2 below to fill the cell',
      targetNumber: 2,
      action: TutorialAction.inputNumber,
    ),
    TutorialStep(
      title: 'Great! Try Another',
      instruction: 'Select this empty cell',
      targetRow: 1,
      targetCol: 0,
      action: TutorialAction.selectCell,
    ),
    TutorialStep(
      title: 'Fill It In',
      instruction: 'Enter the number 3',
      targetNumber: 3,
      action: TutorialAction.inputNumber,
    ),
    TutorialStep(
      title: 'Notes Mode',
      instruction: 'Tap the Notes button to toggle notes mode',
      action: TutorialAction.toggleNotes,
    ),
    TutorialStep(
      title: 'Add a Note',
      instruction: 'Select this cell and add note 1',
      targetRow: 1,
      targetCol: 2,
      targetNumber: 1,
      action: TutorialAction.addNote,
    ),
    TutorialStep(
      title: 'Exit Notes Mode',
      instruction: 'Tap Notes again to exit notes mode',
      action: TutorialAction.toggleNotes,
    ),
    TutorialStep(
      title: 'You\'re Ready!',
      instruction: 'You\'ve learned the basics. Tap Continue to start playing!',
      action: TutorialAction.complete,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initBoard();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _highlightAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut),
    );
  }

  void _initBoard() {
    _board = List.generate(4, (r) => List.from(_puzzle[r]));
    _isGiven = List.generate(
        4, (r) => List.generate(4, (c) => _puzzle[r][c] != 0));
    _notes = List.generate(4, (r) => List.generate(4, (c) => <int>{}));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  TutorialStep get _step => _steps[_currentStep];

  void _onCellTap(int r, int c) {
    if (_isGiven[r][c]) return;

    HapticFeedback.selectionClick();
    setState(() {
      _selectedRow = r;
      _selectedCol = c;
    });

    // Check if this completes the step
    if (_step.action == TutorialAction.selectCell &&
        _step.targetRow == r &&
        _step.targetCol == c) {
      _completeStep();
    } else if (_step.action == TutorialAction.addNote &&
        _step.targetRow == r &&
        _step.targetCol == c &&
        !_stepCompleted) {
      // Cell selected for note, now waiting for number
    }
  }

  void _onNumberTap(int n) {
    if (_selectedRow == null || _selectedCol == null) return;

    HapticFeedback.lightImpact();

    setState(() {
      if (_notesMode) {
        if (_notes[_selectedRow!][_selectedCol!].contains(n)) {
          _notes[_selectedRow!][_selectedCol!].remove(n);
        } else {
          _notes[_selectedRow!][_selectedCol!].add(n);
        }
      } else {
        _board[_selectedRow!][_selectedCol!] = n;
        _notes[_selectedRow!][_selectedCol!].clear();
      }
    });

    // Check if this completes the step
    if (_step.action == TutorialAction.inputNumber &&
        _step.targetNumber == n &&
        !_notesMode) {
      _completeStep();
    } else if (_step.action == TutorialAction.addNote &&
        _step.targetNumber == n &&
        _notesMode) {
      _completeStep();
    }
  }

  void _onNotesToggle() {
    HapticFeedback.selectionClick();
    setState(() {
      _notesMode = !_notesMode;
    });

    if (_step.action == TutorialAction.toggleNotes) {
      _completeStep();
    }
  }

  void _completeStep() {
    setState(() => _stepCompleted = true);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
          _stepCompleted = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CartoonPanel(
      title: 'TUTORIAL',
      color: const Color(0xFF8E5BEA),
      icon: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
      onClose: () => Navigator.pop(context),
      scrollable: true,
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProgressIndicator(),
          const SizedBox(height: 12),
          _buildInstructions(),
          const SizedBox(height: 14),
          _buildMiniBoard(),
          const SizedBox(height: 14),
          _buildNumpad(),
          const SizedBox(height: 10),
          _buildActions(),
          const SizedBox(height: 12),
          if (_step.action == TutorialAction.complete) _buildCompleteButton() else _buildSkipButton(),
        ],
      ),
    );
  }

  static const _keyColors = [Color(0xFFF25A6B), Color(0xFFFF9F43), Color(0xFF3FB26B), Color(0xFF4D7CFE)];

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 10,
              margin: EdgeInsets.only(right: i < _steps.length - 1 ? 5 : 0),
              decoration: BoxDecoration(
                color: i < _currentStep
                    ? const Color(0xFF3FB26B)
                    : i == _currentStep
                        ? const Color(0xFFFFC23D)
                        : const Color(0xFFF3E4C8),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInstructions() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey('$_currentStep$_stepCompleted'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _stepCompleted ? const Color(0xFF3FB26B) : const Color(0xFFF0DFC0), width: 2),
        ),
        child: Column(
          children: [
            Text(_step.title.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontFamily: kTitleFont, fontSize: 19, color: Color(0xFF8E5BEA))),
            const SizedBox(height: 4),
            PanelText(_step.instruction, size: 15),
            if (_stepCompleted) ...[
              const SizedBox(height: 6),
              const OutlinedText('GREAT JOB!', size: 18, color: Color(0xFF7CE08A), stroke: Color(0xFF1F6E3F)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBoard() {
    return Container(
      width: 220,
      height: 220,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9F43),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0xFFB4561A), offset: Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: const Color(0xFFFFFBF2),
          child: Column(
            children: [
              for (var r = 0; r < 4; r++)
                Expanded(
                  child: Row(
                    children: [for (var col = 0; col < 4; col++) Expanded(child: _buildCell(r, col))],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int r, int col) {
    final val = _board[r][col];
    final given = _isGiven[r][col];
    final isSelected = r == _selectedRow && col == _selectedCol;
    final isTarget = _step.targetRow == r && _step.targetCol == col;
    final shouldHighlight = isTarget && (_step.action == TutorialAction.selectCell || _step.action == TutorialAction.addNote);

    final rightBorder = col == 1
        ? const BorderSide(color: Color(0xFFFF9F43), width: 3)
        : col < 3
            ? const BorderSide(color: Color(0xFFF2DDB8), width: 1.2)
            : BorderSide.none;
    final bottomBorder = r == 1
        ? const BorderSide(color: Color(0xFFFF9F43), width: 3)
        : r < 3
            ? const BorderSide(color: Color(0xFFF2DDB8), width: 1.2)
            : BorderSide.none;

    Widget cellContent = AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, child) {
        Color bg = Colors.transparent;
        if (isSelected) {
          bg = const Color(0xFFFFC870);
        } else if (shouldHighlight && !_stepCompleted) {
          bg = const Color(0xFF6FDC8C).withValues(alpha: _highlightAnimation.value.clamp(0.0, 1.0));
        }
        return Container(
          decoration: BoxDecoration(color: bg, border: Border(right: rightBorder, bottom: bottomBorder)),
          alignment: Alignment.center,
          child: val != 0
              ? Text(
                  '$val',
                  style: TextStyle(
                    fontFamily: kBodyFont,
                    fontSize: 26,
                    fontWeight: given ? FontWeight.w700 : FontWeight.w600,
                    color: given ? const Color(0xFF2A3A6E) : const Color(0xFF8E3FD6),
                  ),
                )
              : _notes[r][col].isNotEmpty
                  ? _buildNotes(r, col)
                  : null,
        );
      },
    );

    if (shouldHighlight && !_stepCompleted) {
      cellContent = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(scale: _pulseAnimation.value, child: child),
        child: cellContent,
      );
    }

    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _onCellTap(r, col), child: cellContent);
  }

  Widget _buildNotes(int r, int col) {
    const style = TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A7A9E));
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Expanded(
            child: Row(
              children: [
                for (var j = 0; j < 2; j++)
                  Expanded(child: Center(child: Text(_notes[r][col].contains(i * 2 + j + 1) ? '${i * 2 + j + 1}' : '', style: style))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNumpad() {
    return Row(
      children: List.generate(4, (i) {
        final n = i + 1;
        final isTarget = _step.targetNumber == n &&
            (_step.action == TutorialAction.inputNumber || _step.action == TutorialAction.addNote) &&
            !_stepCompleted;
        final color = _notesMode ? Color.lerp(_keyColors[i], Colors.white, 0.35)! : _keyColors[i];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(scale: isTarget ? _pulseAnimation.value : 1.0, child: child),
              child: ChunkyButton(
                color: color,
                height: 54,
                radius: 16,
                depth: 5,
                border: isTarget,
                onTap: () => _onNumberTap(n),
                child: OutlinedText('$n', size: 28, stroke: Color.lerp(_keyColors[i], Colors.black, 0.45)!),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActions() {
    final isNotesTarget = _step.action == TutorialAction.toggleNotes && !_stepCompleted;
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Transform.scale(scale: isNotesTarget ? _pulseAnimation.value : 1.0, child: child),
      child: SizedBox(
        width: 180,
        child: ChunkyButton(
          color: const Color(0xFF8E5BEA),
          height: 50,
          radius: 16,
          depth: 5,
          border: isNotesTarget,
          onTap: _onNotesToggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 6),
              const OutlinedText('NOTES', size: 18, stroke: Color(0xFF4A2896)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _notesMode ? const Color(0xFF3FB26B) : const Color(0xFF7C8DB5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(_notesMode ? 'ON' : 'OFF', style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return CartoonButton(
      label: 'START PLAYING!',
      onTap: () {
        widget.onComplete();
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSkipButton() {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text(
        'Skip tutorial',
        style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF8A7A9E)),
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String instruction;
  final int? targetRow;
  final int? targetCol;
  final int? targetNumber;
  final TutorialAction action;

  const TutorialStep({
    required this.title,
    required this.instruction,
    this.targetRow,
    this.targetCol,
    this.targetNumber,
    required this.action,
  });
}

enum TutorialAction {
  selectCell,
  inputNumber,
  toggleNotes,
  addNote,
  complete,
}
