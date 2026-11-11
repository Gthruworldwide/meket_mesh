import 'package:flutter/material.dart';

/// لوحة الألوان والثيمات التكتيكية.
///
/// تدعم وضعين:
///  * الوضع الليلي التكتيكي القياسي (خلفية داكنة + أخضر إرشادي).
///  * الوضع الأحمر التكتيكي (Red-Night Mode) الذي يحافظ على تكيّف العين
///    في الظلام الكامل (ملاجئ، أعمال ليلية، انقطاع كهرباء).
class AppColors {
  AppColors._();

  // ── الوضع الليلي القياسي ──────────────────────────────────────────────
  static const Color bg = Color(0xFF0A0F14);
  static const Color surface = Color(0xFF111820);
  static const Color surfaceAlt = Color(0xFF182230);
  static const Color primary = Color(0xFF00E5A0);
  static const Color primaryDim = Color(0xFF0B7A57);
  static const Color accent = Color(0xFFFFC94D);
  static const Color danger = Color(0xFFFF5C5C);
  static const Color warning = Color(0xFFFFA726);
  static const Color success = Color(0xFF4CD964);
  static const Color text = Color(0xFFE9EFF5);
  static const Color textDim = Color(0xFF93A3B4);
  static const Color outline = Color(0xFF243040);

  // ── الوضع الأحمر التكتيكي ─────────────────────────────────────────────
  static const Color redBg = Color(0xFF0F0202);
  static const Color redSurface = Color(0xFF1C0505);
  static const Color redSurfaceAlt = Color(0xFF260707);
  static const Color redPrimary = Color(0xFFFF453A);
  static const Color redAccent = Color(0xFFFF7A6E);
  static const Color redText = Color(0xFFFFD9D5);
  static const Color redTextDim = Color(0xFFC98F89);
  static const Color redOutline = Color(0xFF3A1111);

  /// ألوان الحالة (نفسها في الوضعين مع تفاوت بسيط).
  static Color statusColor(double score, {required bool redNight}) {
    if (redNight) return redPrimary;
    if (score >= 85) return success;
    if (score >= 60) return accent;
    return danger;
  }

  /// بناء الثيم الكامل حسب الوضع المطلوب.
  static ThemeData buildTheme({required bool redNight}) {
    final ColorScheme scheme = redNight
        ? const ColorScheme.dark(
            primary: redPrimary,
            onPrimary: Colors.black,
            secondary: redAccent,
            onSecondary: Colors.black,
            surface: redSurface,
            onSurface: redText,
            error: danger,
            outline: redOutline,
          )
        : const ColorScheme.dark(
            primary: primary,
            onPrimary: Colors.black,
            secondary: accent,
            onSecondary: Colors.black,
            surface: surface,
            onSurface: text,
            error: danger,
            outline: outline,
          );

    final Color fg = redNight ? redText : text;
    final Color fgDim = redNight ? redTextDim : textDim;
    final Color line = redNight ? redOutline : outline;
    final Color cardColor = redNight ? redSurface : surface;
    final Color fieldColor = redNight ? redSurfaceAlt : surfaceAlt;

    final OutlineInputBorder fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: line),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: redNight ? redBg : bg,
      textTheme: Typography.material2021().white.apply(
        bodyColor: fg,
        displayColor: fg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: redNight ? redBg : bg,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: line),
        ),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: fgDim),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 24)),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldColor,
        hintStyle: TextStyle(color: fgDim),
        labelStyle: TextStyle(color: fgDim),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: fieldColor,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
        inactiveTrackColor: fieldColor,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: redNight ? redSurfaceAlt : surfaceAlt,
        contentTextStyle: TextStyle(color: fg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: line),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: fg,
        unselectedLabelColor: fgDim,
        indicatorColor: scheme.primary,
        dividerColor: line,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fieldColor,
        side: BorderSide(color: line),
        labelStyle: TextStyle(color: fg, fontSize: 12),
        secondarySelectedColor: scheme.primary,
        selectedColor: scheme.primary.withValues(alpha: 0.20),
        checkmarkColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.black),
        side: BorderSide(color: fgDim, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: fgDim,
        textColor: fg,
        subtitleTextStyle: TextStyle(color: fgDim, fontSize: 12.5),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
      ),
    );
  }
}
