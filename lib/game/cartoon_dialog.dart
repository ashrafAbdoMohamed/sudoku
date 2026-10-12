import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import 'fx.dart';
import 'ui_kit.dart';

/// Opens [builder] as a cartoon popup: a dimmed backdrop and a bouncy zoom.
Future<T?> showCartoonDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
  );
}

/// The card every popup sits on: a coloured header with an outlined title,
/// an optional close button, and a cream body.
class CartoonPanel extends StatelessWidget {
  final String title;
  final Color color;
  final Widget child;
  final Widget? icon;
  final VoidCallback? onClose;
  final double width;
  final EdgeInsets padding;

  /// Lets the body scroll when it is taller than the screen.
  final bool scrollable;

  const CartoonPanel({
    super.key,
    required this.title,
    required this.child,
    this.color = const Color(0xFF8E5BEA),
    this.icon,
    this.onClose,
    this.width = 340,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
    this.scrollable = false,
  });

  static const cream = Color(0xFFFFF8EA);
  static const ink = Color(0xFF3D2B7A);

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(color, Colors.black, 0.45)!;
    final body = Padding(padding: padding, child: child);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: Container(
                decoration: BoxDecoration(
                  color: cream,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(color: dark, offset: const Offset(0, 7)),
                    const BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 14)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 40, child: icon),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: OutlinedText(title, size: 28, stroke: dark),
                            ),
                          ),
                          SizedBox(width: 40, child: onClose == null ? null : CloseBubble(onTap: onClose!)),
                        ],
                      ),
                    ),
                    if (scrollable) Flexible(child: SingleChildScrollView(child: body)) else body,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round red "X" in a panel's corner.
class CloseBubble extends StatelessWidget {
  final VoidCallback onTap;
  const CloseBubble({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: GestureDetector(
        onTap: () {
          SoundService().playTap();
          onTap();
        },
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF25A6B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0xFF9A2B3A), offset: Offset(0, 3))],
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// A full-width chunky button with an outlined label (and optional icon).
class CartoonButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final Widget? icon;
  final double height;
  final double size;
  const CartoonButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF3FB26B),
    this.icon,
    this.height = 56,
    this.size = 22,
  });

  /// Plain grey "secondary" button.
  const CartoonButton.secondary({super.key, required this.label, required this.onTap, this.icon, this.height = 50, this.size = 19})
    : color = const Color(0xFF7C8DB5);

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = enabled ? color : const Color(0xFFA9AFBF);
    return ChunkyButton(
      color: c,
      height: height,
      radius: 18,
      onTap: enabled
          ? () {
              SoundService().playTap();
              onTap!();
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              OutlinedText(label, size: size, stroke: Color.lerp(c, Colors.black, 0.5)!),
            ],
          ),
        ),
      ),
    );
  }
}

/// A white rounded tile with a big value and a small caption under it.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Widget? icon;
  final Color color;
  const StatTile({super.key, required this.value, required this.label, this.icon, this.color = CartoonPanel.ink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0DFC0), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(height: 2)],
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontFamily: kTitleFont, fontSize: 22, color: color, height: 1.1),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF8A7A9E)),
          ),
        ],
      ),
    );
  }
}

/// A row of [StatTile]s with even gaps.
class StatRow extends StatelessWidget {
  final List<Widget> tiles;
  const StatRow(this.tiles, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: tiles[i])],
      ],
    );
  }
}

/// Body text inside a panel.
class PanelText extends StatelessWidget {
  final String text;
  final double size;
  final TextAlign align;
  const PanelText(this.text, {super.key, this.size = 16, this.align = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: size, color: const Color(0xFF5B4B7A), height: 1.3),
    );
  }
}

/// A two-button "are you sure?" popup. Pops true for [confirm].
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  String cancel = 'CANCEL',
  Color color = const Color(0xFFF25A6B),
  bool confirmIsDanger = true,
}) async {
  final ok = await showCartoonDialog<bool>(
    context,
    builder: (context) => CartoonPanel(
      title: title,
      color: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelText(message),
          const SizedBox(height: 18),
          CartoonButton(label: cancel, color: const Color(0xFF3FB26B), onTap: () => Navigator.of(context).pop(false)),
          const SizedBox(height: 6),
          CartoonButton(
            label: confirm,
            color: confirmIsDanger ? const Color(0xFFF25A6B) : const Color(0xFF4D7CFE),
            height: 48,
            size: 18,
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}

/// A small heading between groups of rows in a panel.
class PanelSection extends StatelessWidget {
  final String title;
  const PanelSection(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontFamily: kTitleFont, fontSize: 16, letterSpacing: 1, color: Color(0xFFB07A2A)),
      ),
    );
  }
}

/// A white rounded row: a coloured icon bubble, a title and subtitle, and a
/// trailing widget (a switch, a chevron...). Tappable when [onTap] is set.
class PanelRow extends StatelessWidget {
  final Widget icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const PanelRow({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor = const Color(0xFF8E5BEA),
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  /// An emoji in the icon bubble.
  PanelRow.emoji(
    String emoji, {
    Key? key,
    required String title,
    Color iconColor = const Color(0xFF8E5BEA),
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) : this(
         key: key,
         icon: Text(emoji, style: const TextStyle(fontSize: 20)),
         title: title,
         iconColor: iconColor,
         subtitle: subtitle,
         trailing: trailing,
         onTap: onTap,
       );

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0DFC0), width: 2),
        boxShadow: const [BoxShadow(color: Color(0xFFF0DFC0), offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 16, color: CartoonPanel.ink),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFF8A7A9E)),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB9A9CF), size: 28),
        ],
      ),
    );
    if (onTap == null) return row;
    return PressScale(
      pressed: 0.96,
      child: GestureDetector(
        onTap: () {
          SoundService().playTap();
          onTap!();
        },
        child: row,
      ),
    );
  }
}
