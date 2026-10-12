import 'package:flutter/material.dart';
import 'board_themes.dart';

class AppColors {
  /// The cartoon look's palette: cream panels, purple accents, dark ink.
  /// Every popup and screen uses this now.
  static const cartoon = AppColorScheme(
    bg: Color(0xFFFFF8EA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFFF0D9),
    border: Color(0xFFF0DFC0),
    borderBox: Color(0xFFFF9F43),
    text: Color(0xFF3D2B7A),
    textMuted: Color(0xFF8A7A9E),
    primary: Color(0xFF8E5BEA),
    primaryLight: Color(0xFFEDE3FF),
    selBg: Color(0xFFFFC870),
    hlBg: Color(0xFFFFF0CF),
    sameBg: Color(0xFFFFDE9E),
    errColor: Color(0xFFF25A6B),
    errBg: Color(0xFFFFD6DB),
    givenColor: Color(0xFF2A3A6E),
    userColor: Color(0xFF8E3FD6),
    noteColor: Color(0xFF8A7A9E),
    hintColor: Color(0xFF3FB26B),
  );

  // Light theme (default)
  static const light = AppColorScheme(
    bg: Color(0xFFF0F4FF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF1F8),
    border: Color(0xFFD0D7E8),
    borderBox: Color(0xFF4A5080),
    text: Color(0xFF1A1D2E),
    textMuted: Color(0xFF7880A0),
    primary: Color(0xFF4F6EF7),
    primaryLight: Color(0xFFE8ECFF),
    selBg: Color(0xFFC8D4FF),
    hlBg: Color(0xFFEEF1FF),
    sameBg: Color(0xFFD6DEFF),
    errColor: Color(0xFFE63946),
    errBg: Color(0xFFFDE0E2),
    givenColor: Color(0xFF1A1D2E),
    userColor: Color(0xFF4F6EF7),
    noteColor: Color(0xFF8890B8),
    hintColor: Color(0xFF06D6A0),
  );

  // Dark theme (default)
  static const dark = AppColorScheme(
    bg: Color(0xFF0D0F1E),
    surface: Color(0xFF161826),
    surface2: Color(0xFF1E2035),
    border: Color(0xFF2A2D45),
    borderBox: Color(0xFF6870A8),
    text: Color(0xFFE8EAF6),
    textMuted: Color(0xFF7880A8),
    primary: Color(0xFF7B8FFF),
    primaryLight: Color(0xFF1E2245),
    selBg: Color(0xFF2A3268),
    hlBg: Color(0xFF1C1F38),
    sameBg: Color(0xFF232750),
    errColor: Color(0xFFFF6B6B),
    errBg: Color(0xFF3D1E22),
    givenColor: Color(0xFFE8EAF6),
    userColor: Color(0xFF8FA8FF),
    noteColor: Color(0xFF6870A0),
    hintColor: Color(0xFF06D6A0),
  );

  /// Generate AppColorScheme from a ColorTheme
  static AppColorScheme fromColorTheme(ColorTheme theme, {required bool isDark}) {
    final errColor = isDark ? const Color(0xFFFF6B6B) : const Color(0xFFE63946);
    final hintColor = const Color(0xFF06D6A0);

    if (isDark) {
      return AppColorScheme(
        bg: theme.darkBg,
        surface: theme.darkSurface,
        surface2: theme.darkSurface2,
        border: theme.darkBorder,
        borderBox: theme.darkBorderBox,
        text: theme.darkText,
        textMuted: theme.darkTextMuted,
        primary: theme.primaryColor,
        primaryLight: theme.darkPrimaryLight,
        selBg: theme.darkSelBg,
        hlBg: theme.darkHlBg,
        sameBg: theme.darkSameBg,
        errColor: errColor,
        errBg: theme.darkErrBg,
        givenColor: theme.darkText,
        userColor: theme.primaryColor,
        noteColor: theme.darkTextMuted,
        hintColor: hintColor,
      );
    } else {
      return AppColorScheme(
        bg: theme.lightBg,
        surface: theme.lightSurface,
        surface2: theme.lightSurface2,
        border: theme.lightBorder,
        borderBox: theme.lightBorderBox,
        text: theme.lightText,
        textMuted: theme.lightTextMuted,
        primary: theme.primaryColor,
        primaryLight: theme.lightPrimaryLight,
        selBg: theme.lightSelBg,
        hlBg: theme.lightHlBg,
        sameBg: theme.lightSameBg,
        errColor: errColor,
        errBg: theme.lightErrBg,
        givenColor: theme.lightText,
        userColor: theme.primaryColor,
        noteColor: theme.lightTextMuted,
        hintColor: hintColor,
      );
    }
  }
}

class AppColorScheme {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color borderBox;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color primaryLight;
  final Color selBg;
  final Color hlBg;
  final Color sameBg;
  final Color errColor;
  final Color errBg;
  final Color givenColor;
  final Color userColor;
  final Color noteColor;
  final Color hintColor;

  const AppColorScheme({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.borderBox,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.primaryLight,
    required this.selBg,
    required this.hlBg,
    required this.sameBg,
    required this.errColor,
    required this.errBg,
    required this.givenColor,
    required this.userColor,
    required this.noteColor,
    required this.hintColor,
  });
}

final List<Color> avatarColors = [
  const Color(0xFF4F6EF7),
  const Color(0xFFA855F7),
  const Color(0xFFEC4899),
  const Color(0xFF06D6A0),
  const Color(0xFFF59E0B),
  const Color(0xFFEF4444),
];

const List<Color> confettiColors = [
  Color(0xFF4F6EF7),
  Color(0xFFA855F7),
  Color(0xFFF72585),
  Color(0xFF4CC9F0),
  Color(0xFFFFD166),
  Color(0xFF06D6A0),
  Color(0xFFFF6B6B),
];

// Difficulty badge colors
class DiffBadgeColors {
  static const easy = (bg: Color(0xFFDCFCE7), text: Color(0xFF16A34A));
  static const medium = (bg: Color(0xFFFEF9C3), text: Color(0xFFCA8A04));
  static const hard = (bg: Color(0xFFFEE2E2), text: Color(0xFFDC2626));
  static const expert = (bg: Color(0xFFEDE9FE), text: Color(0xFF7C3AED));

  static const easyDark = (bg: Color(0xFF14532D), text: Color(0xFF86EFAC));
  static const mediumDark = (bg: Color(0xFF713F12), text: Color(0xFFFDE047));
  static const hardDark = (bg: Color(0xFF7F1D1D), text: Color(0xFFFCA5A5));
  static const expertDark = (bg: Color(0xFF2E1065), text: Color(0xFFC4B5FD));
}

