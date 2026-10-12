import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'interactive_tutorial.dart';
import '../game/cartoon_dialog.dart';
import '../game/ui_kit.dart';
import '../services/sound_service.dart';

class LearningModal extends StatefulWidget {
  final AppColorScheme colors;
  final VoidCallback? onTutorialComplete;

  const LearningModal({super.key, required this.colors, this.onTutorialComplete});

  @override
  State<LearningModal> createState() => _LearningModalState();
}

class _LearningModalState extends State<LearningModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  AppColorScheme get c => widget.colors;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * 0.72).clamp(380.0, 620.0);
    return CartoonPanel(
      title: 'HOW TO PLAY',
      color: const Color(0xFF3FB26B),
      onClose: () => Navigator.pop(context),
      width: 440,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: CartoonButton(
                label: 'TRY THE TUTORIAL',
                color: const Color(0xFF8E5BEA),
                icon: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => InteractiveTutorial(
                      colors: c,
                      onComplete: () => widget.onTutorialComplete?.call(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: const Color(0xFFF3E4C8), borderRadius: BorderRadius.circular(23)),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF8A7A9E),
                labelStyle: const TextStyle(fontFamily: kTitleFont, fontSize: 14, letterSpacing: 0.5),
                unselectedLabelStyle: const TextStyle(fontFamily: kTitleFont, fontSize: 14, letterSpacing: 0.5),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: const Color(0xFF3FB26B),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0xFF1F6E3F), offset: Offset(0, 3))],
                ),
                dividerColor: Colors.transparent,
                onTap: (_) => SoundService().playTap(),
                tabs: const [
                  Tab(child: FittedBox(child: Text('BASICS'))),
                  Tab(child: FittedBox(child: Text('TRICKS'))),
                  Tab(child: FittedBox(child: Text('TIPS'))),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicsTab(),
                  _buildTechniquesTab(),
                  _buildTipsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            '🎯',
            'The Goal',
            'Fill every row, column, and 3x3 box with the numbers 1-9, without repeating any number.',
          ),
          const SizedBox(height: 12),
          _sectionCard(
            '📐',
            'The Rules',
            '• Each row must contain 1-9 (no repeats)\n'
            '• Each column must contain 1-9 (no repeats)\n'
            '• Each 3x3 box must contain 1-9 (no repeats)',
          ),
          const SizedBox(height: 12),
          _sectionCard(
            '🎮',
            'Controls',
            '• Tap a cell to select it\n'
            '• Tap a number to fill the cell\n'
            '• Notes: mark the numbers a cell could be\n'
            '• Undo and Erase fix mistakes (5 mistakes ends the game)\n'
            '• Hint (25 coins): shows the easiest cell to solve next\n'
            '• Magic (60 coins): fills the selected cell for you',
          ),
          const SizedBox(height: 12),
          _sectionCard(
            '⌨️',
            'Keyboard Shortcuts',
            '• 1-9: Enter numbers\n'
            '• Arrow keys: Move selection\n'
            '• N: Toggle notes mode\n'
            '• Z: Undo\n'
            '• H: Hint\n'
            '• Space: Pause/Resume',
          ),
        ],
      ),
    );
  }

  Widget _buildTechniquesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _techniqueCard(
            '1️⃣',
            'Single Candidate',
            'If a cell can only contain one possible number, fill it in!',
            'Look for cells where 8 of the 9 numbers are already in the same row, column, or box.',
            DifficultyLevel.beginner,
          ),
          const SizedBox(height: 12),
          _techniqueCard(
            '🔍',
            'Hidden Single',
            'If a number can only go in one cell within a row, column, or box, place it there.',
            'Scan each row/column/box and ask "Where can this number go?"',
            DifficultyLevel.beginner,
          ),
          const SizedBox(height: 12),
          _techniqueCard(
            '👀',
            'Scanning',
            'Look across rows and down columns to eliminate possibilities.',
            'If 7 is in row 1 and row 2 of a box, it must be in row 3 of that box.',
            DifficultyLevel.intermediate,
          ),
          const SizedBox(height: 12),
          _techniqueCard(
            '✏️',
            'Pencil Marks',
            'Use notes to track possible numbers for each cell.',
            'Write small numbers in cells to remember what could go there.',
            DifficultyLevel.intermediate,
          ),
          const SizedBox(height: 12),
          _techniqueCard(
            '👯',
            'Naked Pairs',
            'If two cells in a group can only contain the same two numbers, eliminate those numbers from other cells.',
            'Example: If cells A and B can only be 4 or 7, no other cell in that row/column/box can be 4 or 7.',
            DifficultyLevel.advanced,
          ),
          const SizedBox(height: 12),
          _techniqueCard(
            '🔗',
            'Pointing Pairs',
            'If a number in a box is confined to one row/column, eliminate it from that row/column in other boxes.',
            'Use the constraint of boxes to limit possibilities in rows/columns.',
            DifficultyLevel.advanced,
          ),
        ],
      ),
    );
  }

  Widget _buildTipsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tipCard(
            '🌟',
            'Start with Easy',
            'Begin with Easy puzzles to learn patterns before moving to harder difficulties.',
          ),
          const SizedBox(height: 12),
          _tipCard(
            '✏️',
            'Use Notes Wisely',
            'Notes are your friend! Mark possible numbers to avoid losing track of your deductions.',
          ),
          const SizedBox(height: 12),
          _tipCard(
            '🔢',
            'Count Numbers',
            'Look at which numbers appear most. Numbers that appear 8 times only have one spot left!',
          ),
          const SizedBox(height: 12),
          _tipCard(
            '📦',
            'Focus on Boxes',
            'Solving 3x3 boxes often reveals numbers in adjacent boxes.',
          ),
          const SizedBox(height: 12),
          _tipCard(
            '🚫',
            'Avoid Guessing',
            "Don't guess! Every cell has a logical solution. If you're stuck, use notes more thoroughly.",
          ),
          const SizedBox(height: 12),
          _tipCard(
            '⏸️',
            'Take Breaks',
            'If stuck, pause and come back later. Fresh eyes often spot what you missed.',
          ),
          const SizedBox(height: 12),
          _tipCard(
            '📅',
            'Daily Challenges',
            'Play the daily challenge to build a streak and improve consistently.',
          ),
          const SizedBox(height: 12),
          _tipCard(
            '🏆',
            'Track Progress',
            'Watch your statistics improve over time. Celebrate your best times!',
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String emoji, String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: c.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _techniqueCard(String emoji, String title, String description, String howTo, DifficultyLevel level) {
    final levelColors = {
      DifficultyLevel.beginner: const Color(0xFF10B981),
      DifficultyLevel.intermediate: const Color(0xFF3B82F6),
      DifficultyLevel.advanced: const Color(0xFFF59E0B),
    };
    final levelNames = {
      DifficultyLevel.beginner: 'Beginner',
      DifficultyLevel.intermediate: 'Intermediate',
      DifficultyLevel.advanced: 'Advanced',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColors[level]!.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  levelNames[level]!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: levelColors[level],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    howTo,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipCard(String emoji, String title, String content) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum DifficultyLevel { beginner, intermediate, advanced }
