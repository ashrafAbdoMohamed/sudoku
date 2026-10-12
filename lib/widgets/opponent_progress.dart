import 'package:flutter/material.dart';
import '../game/ui_kit.dart';
import '../theme/app_theme.dart';
import '../models/online_room.dart';

/// Widget showing opponent's progress during online challenge
class OpponentProgressBar extends StatelessWidget {
  final PlayerState opponent;
  final AppColorScheme colors;

  const OpponentProgressBar({
    super.key,
    required this.opponent,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final progress = opponent.progressPercent.clamp(0.0, 1.0);
    final statusColor = _getStatusColor();
    var detail = _getStatusText();
    if (opponent.isPlaying) detail += ' · ${opponent.mistakes} ✗';
    if (opponent.isFinished && opponent.finishTime != null) detail += ' · ${_formatTime(opponent.finishTime!)}';

    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            alignment: Alignment.center,
            child: OutlinedText(
              opponent.name.isNotEmpty ? opponent.name[0].toUpperCase() : '?',
              size: 16,
              stroke: Color.lerp(statusColor, Colors.black, 0.45)!,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 14, height: 1.1, color: Color(0xFF3D2B7A)),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 11, height: 1.1, color: statusColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 16,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: const Color(0xFFF3EBDD), borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress == 0 ? 0.02 : progress,
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFFFF8A3D), borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(progress * 100).toInt()}%', style: const TextStyle(fontFamily: kTitleFont, fontSize: 16, color: Color(0xFFFF8A3D))),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (opponent.isFinished) {
      return opponent.finishTime != null
          ? const Color(0xFF3FB26B) // Green for finished
          : const Color(0xFFF25A6B); // Red for lost
    }
    if (opponent.isDisconnected) return const Color(0xFF7C8DB5); // Gray
    if (opponent.isPlaying) return const Color(0xFF4D7CFE); // Blue
    return const Color(0xFFFF9F43); // Orange for waiting
  }

  String _getStatusText() {
    if (opponent.isFinished) {
      return opponent.finishTime != null ? 'Finished' : 'Game Over';
    }
    if (opponent.isDisconnected) return 'Disconnected';
    if (opponent.isPlaying) return 'Playing';
    return 'Waiting';
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Compact waiting indicator for online challenge
class OnlineWaitingIndicator extends StatelessWidget {
  final String pin;
  final int playerCount;
  final AppColorScheme colors;
  final VoidCallback onCancel;

  const OnlineWaitingIndicator({
    super.key,
    required this.pin,
    required this.playerCount,
    required this.colors,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for opponent...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                Text(
                  'PIN: ${_formatPin(pin)} • $playerCount/2 players',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.errColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.errColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPin(String pin) {
    if (pin.length != 6) return pin;
    return '${pin.substring(0, 3)} ${pin.substring(3)}';
  }
}
