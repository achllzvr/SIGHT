import 'package:flutter/material.dart';

/// LUMI Child Arcade Design System — Super Joyful + Clan Pro,
/// Icons8 Arcade, thick borders, hard downward shadows.
class LumiColors {
  LumiColors._();

  // Official child arcade palette
  static const primaryPurple = Color(0xFF8168AB);
  static const secondaryPurple = Color(0xFFFFDCF9);
  static const primaryGreen = Color(0xFF62B239);
  static const secondaryGreen = Color(0xFFC8E8B7);
  static const primaryLight = Color(0xFFFFFFFF);
  static const secondaryLight = Color(0xFFD4D4D4);
  static const badgeAmber = Color(0xFFFFAF03);
  static const badgeCyan = Color(0xFF40C4FF);

  /// Bottom nav fill / border (lighter green set)
  static const navFill = Color(0xFFC8E8B7);
  static const navBorder = Color(0xFFABD296);

  // Aliases kept for existing call sites
  static const greenSoft = secondaryGreen;
  static const greenMid = primaryGreen;
  static const greenBg = Color(0xFFEEF8E8);
  static const greenShell = secondaryGreen;
  static const greenNav = secondaryGreen;

  static const purpleSoft = secondaryPurple;
  static const purpleMid = primaryPurple;
  static const purplePink = secondaryPurple;
  static const purpleDeep = primaryPurple;

  static const pinkUnsafe = Color(0xFFFFE4E6);
  static const redAlert = Color(0xFFF43F5E);
  static const safeText = Color(0xFF3D6B56);

  static const outline = secondaryLight;
  static const borderSubtle = secondaryLight;
  static const textDark = Color(0xFF2D2D2D);
  static const textMuted = Color(0xFF6B6B6B);
  static const textDisabled = Color(0xFF9A9A9A);

  static const scaffoldLight = Color(0xFFFAFAFC);
  static const scaffoldMint = Color(0xFFF7FBF4);
  static const cardWhite = primaryLight;
  static const cardHighlight = secondaryGreen;
  static const gradientTop = secondaryPurple;
  static const gradientBottom = secondaryGreen;
  static const huePink = secondaryPurple;
  static const coralTrack = Color(0xFFFFE4E6);
  static const tipYellow = Color(0xFFFEF3C7);
  static const starAmber = badgeAmber;
  static const accent = badgeAmber;
  static const success = primaryGreen;
  static const warning = badgeAmber;
  static const info = primaryPurple;
  static const modalOverlay = Color(0x80000000);

  static const hardShadow = Offset(0, 4);
  static const pressShadowY = 4.0;
  static const borderWidth = 4.0;
  static const borderWidthThick = 5.0;

  static Color shadowFor(Color fill) {
    if (fill == primaryGreen || fill == secondaryGreen || fill == greenBg) {
      return primaryGreen;
    }
    if (fill == primaryPurple || fill == secondaryPurple) {
      return primaryPurple;
    }
    if (fill == badgeAmber || fill == tipYellow) {
      return badgeAmber;
    }
    if (fill == badgeCyan) {
      return badgeCyan;
    }
    if (fill == navFill || fill == navBorder) {
      return navBorder;
    }
    return secondaryLight;
  }
}

class LumiFonts {
  LumiFonts._();
  static const joyful = 'SuperJoyful';
  static const clan = 'ClanPro';
}

class LumiRadii {
  LumiRadii._();
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 24.0;
  static const pill = 100.0;
}

class LumiSpacing {
  LumiSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const xxxl = 64.0;
  static const huge = 64.0;
}

class LumiMotion {
  LumiMotion._();
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 300);
  static const ease = Curves.easeOut;
  static const easeInOut = Curves.easeInOut;
  static const easeStandard = Cubic(0.4, 0.0, 0.2, 1.0);
}

/// Mobile-scaled arcade chrome sizes (snippet prototypes were larger).
class ArcadeSizes {
  ArcadeSizes._();
  static const badgeHeight = 40.0;
  static const badgePadH = 10.0;
  static const badgePadV = 6.0;
  static const badgeBorder = 3.0;
  static const badgeShadowY = 3.0;
  static const badgeIcon = 18.0;
  static const badgeFont = 13.0;

  static const buttonPadH = 28.0;
  static const buttonPadV = 12.0;
  static const buttonBorder = 4.0;
  static const buttonShadowY = 5.0;
  static const buttonFont = 16.0;

  static const cardRadius = 24.0;
  static const cardBorder = 4.0;
  static const cardShadowY = 6.0;

  static const fieldBorder = 4.0;
  static const codeBoxW = 44.0;
  static const codeBoxH = 54.0;

  static const navIcon = 36.0;
  static const navBorder = 4.0;
  static const navShadow = Offset(2, 6);
}

class LumiShadows {
  LumiShadows._();

  static List<BoxShadow> hard({
    Color? color,
    Offset offset = const Offset(0, 4),
  }) =>
      [
        BoxShadow(
          color: color ?? LumiColors.secondaryLight,
          offset: offset,
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> card([Color? tint]) => hard(
        color: tint ?? LumiColors.secondaryLight,
        offset: const Offset(0, ArcadeSizes.cardShadowY),
      );

  static List<BoxShadow> cardPressed([Color? tint]) => hard(
        color: tint ?? LumiColors.secondaryLight,
        offset: const Offset(0, 2),
      );

  static List<BoxShadow> cardHover([Color? tint]) => hard(
        color: tint ?? LumiColors.secondaryLight,
        offset: const Offset(0, 8),
      );

  static List<BoxShadow> float([Color? tint]) => hard(
        color: tint ?? LumiColors.primaryGreen,
        offset: ArcadeSizes.navShadow,
      );

  static List<BoxShadow> modal([Color? tint]) => hard(
        color: tint ?? LumiColors.secondaryLight,
        offset: const Offset(0, 8),
      );

  static List<BoxShadow> badge(Color accent) => hard(
        color: accent,
        offset: const Offset(0, ArcadeSizes.badgeShadowY),
      );

  static List<BoxShadow> button([Color? accent]) => hard(
        color: accent ?? LumiColors.primaryPurple,
        offset: const Offset(0, ArcadeSizes.buttonShadowY),
      );
}

class LumiTheme {
  LumiTheme._();

  /// Headers / display — Super Joyful, always ALL CAPS.
  static TextStyle joyful(double size, {Color? color, double? height, double? letterSpacing}) =>
      TextStyle(
        fontFamily: LumiFonts.joyful,
        fontSize: size,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? LumiColors.textDark,
        fontWeight: FontWeight.w400,
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      );

  /// Convenience: wraps [text] in ALL CAPS for Super Joyful labels.
  static String caps(String text) => text.toUpperCase();

  /// Live countdown from remaining seconds — `M:SS` or `H:MM:SS`.
  static String formatRemaining(int seconds) {
    final s = seconds <= 0 ? 0 : seconds;
    final hours = s ~/ 3600;
    final mins = (s % 3600) ~/ 60;
    final secs = s % 60;
    final secPart = secs.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${mins.toString().padLeft(2, '0')}:$secPart';
    }
    return '$mins:$secPart';
  }

  /// Spoken/friendly remaining label for overlays (uses live remaining seconds).
  static String formatRemainingFriendly(int seconds) {
    final s = seconds <= 0 ? 0 : seconds;
    final hours = s ~/ 3600;
    final mins = (s % 3600) ~/ 60;
    final secs = s % 60;
    if (hours > 0) {
      final hrPart = hours == 1 ? '1 hour' : '$hours hours';
      if (mins == 0) return hrPart;
      final minPart = mins == 1 ? '1 minute' : '$mins minutes';
      return '$hrPart $minPart';
    }
    if (mins > 0) {
      final minPart = mins == 1 ? '1 minute' : '$mins minutes';
      if (secs == 0) return minPart;
      return '$minPart ${secs}s';
    }
    return secs == 1 ? '1 second' : '$secs seconds';
  }

  /// Primary text — Clan Pro Medium
  static TextStyle clanMedium(double size, {Color? color, double? height, double? letterSpacing}) =>
      TextStyle(
        fontFamily: LumiFonts.clan,
        fontSize: size,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? LumiColors.textDark,
        fontWeight: FontWeight.w500,
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      );

  /// Secondary text — Clan Pro Regular
  static TextStyle clanRegular(double size, {Color? color, double? height, double? letterSpacing}) =>
      TextStyle(
        fontFamily: LumiFonts.clan,
        fontSize: size,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? LumiColors.textMuted,
        fontWeight: FontWeight.w400,
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      );

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: joyful(40, color: primary, height: 1.1),
      displayMedium: joyful(36, color: primary, height: 1.15),
      displaySmall: joyful(32, color: primary, height: 1.2),
      headlineLarge: joyful(28, color: primary, height: 1.2),
      headlineMedium: joyful(24, color: primary, height: 1.25),
      headlineSmall: joyful(20, color: primary, height: 1.3),
      titleLarge: clanMedium(20, color: primary, height: 1.3),
      titleMedium: clanMedium(18, color: primary, height: 1.3),
      titleSmall: clanMedium(16, color: primary, height: 1.3),
      bodyLarge: clanRegular(16, color: primary, height: 1.5),
      bodyMedium: clanRegular(14, color: secondary, height: 1.5),
      bodySmall: clanRegular(12, color: secondary, height: 1.4),
      labelLarge: clanMedium(14, color: primary, height: 1.4),
      labelMedium: clanMedium(12, color: primary, height: 1.4),
      labelSmall: clanRegular(11, color: secondary, height: 1.3, letterSpacing: 0.4),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: LumiColors.primaryPurple,
      surface: LumiColors.cardWhite,
      brightness: Brightness.light,
    ).copyWith(
      primary: LumiColors.primaryPurple,
      onPrimary: Colors.white,
      secondary: LumiColors.primaryGreen,
      error: LumiColors.redAlert,
      outline: LumiColors.secondaryLight,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: LumiFonts.clan,
      textTheme: _textTheme(LumiColors.textDark, LumiColors.textMuted),
      cardTheme: CardThemeData(
        color: LumiColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumiRadii.lg),
          side: const BorderSide(color: LumiColors.secondaryLight, width: ArcadeSizes.cardBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: LumiColors.cardWhite,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LumiColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleTextStyle: joyful(20, color: LumiColors.textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LumiColors.secondaryPurple,
          foregroundColor: LumiColors.primaryPurple,
          disabledBackgroundColor: LumiColors.secondaryLight,
          disabledForegroundColor: LumiColors.textDisabled,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LumiRadii.pill),
            side: const BorderSide(color: LumiColors.primaryPurple, width: ArcadeSizes.buttonBorder),
          ),
          textStyle: clanMedium(16, color: LumiColors.primaryPurple, letterSpacing: 1.0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LumiColors.primaryPurple,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: LumiColors.primaryPurple, width: ArcadeSizes.buttonBorder),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LumiRadii.pill)),
          textStyle: clanMedium(16, color: LumiColors.primaryPurple, letterSpacing: 1.0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LumiColors.primaryPurple,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LumiRadii.pill)),
          textStyle: clanMedium(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LumiColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumiRadii.pill),
          borderSide: const BorderSide(color: LumiColors.secondaryLight, width: ArcadeSizes.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumiRadii.pill),
          borderSide: const BorderSide(color: LumiColors.secondaryLight, width: ArcadeSizes.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumiRadii.pill),
          borderSide: const BorderSide(color: LumiColors.primaryPurple, width: ArcadeSizes.fieldBorder),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumiRadii.pill),
          borderSide: const BorderSide(color: LumiColors.redAlert, width: ArcadeSizes.fieldBorder),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumiRadii.pill),
          borderSide: const BorderSide(color: LumiColors.redAlert, width: ArcadeSizes.fieldBorder),
        ),
        errorStyle: clanRegular(12, color: LumiColors.redAlert),
        labelStyle: clanMedium(14),
        hintStyle: clanRegular(14, color: LumiColors.textMuted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: LumiColors.secondaryGreen,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(clanMedium(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: LumiColors.cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumiRadii.lg),
          side: const BorderSide(color: LumiColors.secondaryLight, width: ArcadeSizes.cardBorder),
        ),
        elevation: 0,
        titleTextStyle: joyful(22, color: LumiColors.textDark),
        contentTextStyle: clanRegular(14, color: LumiColors.textMuted),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: LumiColors.cardWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumiRadii.lg),
          side: const BorderSide(color: LumiColors.secondaryLight, width: ArcadeSizes.cardBorder),
        ),
        headerBackgroundColor: LumiColors.secondaryPurple,
        headerForegroundColor: LumiColors.primaryPurple,
        headerHeadlineStyle: joyful(24, color: LumiColors.primaryPurple),
        headerHelpStyle: clanMedium(13, color: LumiColors.primaryPurple),
        weekdayStyle: clanMedium(12, color: LumiColors.textMuted),
        dayStyle: clanMedium(14, color: LumiColors.textDark),
        yearStyle: clanMedium(14, color: LumiColors.textDark),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return LumiColors.textDisabled;
          if (states.contains(WidgetState.selected)) return Colors.white;
          return LumiColors.textDark;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return LumiColors.primaryPurple;
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return LumiColors.primaryPurple;
        }),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return LumiColors.primaryPurple;
          return LumiColors.secondaryPurple;
        }),
        todayBorder: const BorderSide(color: LumiColors.primaryPurple, width: 1.5),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return LumiColors.textDisabled;
          if (states.contains(WidgetState.selected)) return Colors.white;
          return LumiColors.textDark;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return LumiColors.primaryPurple;
          return Colors.transparent;
        }),
        rangePickerHeaderBackgroundColor: LumiColors.secondaryPurple,
        rangePickerHeaderForegroundColor: LumiColors.primaryPurple,
        dividerColor: LumiColors.outline,
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: LumiColors.primaryPurple,
          textStyle: clanMedium(14, color: LumiColors.primaryPurple, letterSpacing: 0.6),
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: LumiColors.textMuted,
          textStyle: clanMedium(14, color: LumiColors.textMuted, letterSpacing: 0.6),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: LumiColors.primaryPurple,
      brightness: Brightness.dark,
      surface: const Color(0xFF1E1A24),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF121016),
      fontFamily: LumiFonts.clan,
      textTheme: _textTheme(const Color(0xFFF8FAFC), const Color(0xFFB0A8BC)),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1A24),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumiRadii.lg),
          side: const BorderSide(color: Color(0xFF4A4458), width: ArcadeSizes.cardBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF121016),
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        titleTextStyle: joyful(20, color: Colors.white),
      ),
    );
  }

  /// Themed Material date picker matching LUMI arcade surfaces and typography.
  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    String? helpText,
    String? cancelText,
    String? confirmText,
  }) {
    final clampedInitial = initialDate.isBefore(firstDate)
        ? firstDate
        : (initialDate.isAfter(lastDate) ? lastDate : initialDate);

    return showDatePicker(
      context: context,
      initialDate: clampedInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      cancelText: cancelText ?? 'CANCEL',
      confirmText: confirmText ?? 'OK',
      builder: (context, child) {
        final base = light();
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              primary: LumiColors.primaryPurple,
              onPrimary: Colors.white,
              secondary: LumiColors.primaryGreen,
              surface: LumiColors.cardWhite,
              onSurface: LumiColors.textDark,
              outline: LumiColors.outline,
            ),
            textTheme: base.textTheme,
            dialogTheme: base.dialogTheme,
            datePickerTheme: base.datePickerTheme,
            textButtonTheme: base.textButtonTheme,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
