import 'package:flutter/material.dart';
import 'app_typography.dart';

abstract final class AppColors {
  static const primary = Color(0xFF087F83);
  static const ink = Color(0xFF17383D);
  static const inkMuted = Color(0xFF536F73);
  static const canvas = Color(0xFFF0F6F5);
  static const surface = Colors.white;
  static const line = Color(0xFFD9E5E5);
  static const soft = Color(0xFFE4F3F0);
  static const inverse = Colors.white;
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
}

abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 960;
  static const double expanded = 1200;

  static EdgeInsets pagePadding(double width) => EdgeInsets.symmetric(
    horizontal: width < compact
        ? 12
        : width < expanded
        ? 20
        : 32,
    vertical: width < compact ? 12 : 24,
  );
}

abstract final class AppTheme {
  static ThemeData forLocale(Locale locale) {
    final base = light;
    final textTheme = base.textTheme.apply(
      fontFamily: AppTypography.family(locale),
    );
    TextStyle? readable(TextStyle? style) => style?.copyWith(
      height: 1.5,
      leadingDistribution: TextLeadingDistribution.even,
      fontFamilyFallback: AppTypography.fallback,
    );
    return base.copyWith(
      textTheme: textTheme.copyWith(
        displayLarge: readable(textTheme.displayLarge),
        displayMedium: readable(textTheme.displayMedium),
        displaySmall: readable(textTheme.displaySmall),
        headlineLarge: readable(textTheme.headlineLarge),
        headlineMedium: readable(textTheme.headlineMedium),
        headlineSmall: readable(textTheme.headlineSmall),
        titleLarge: readable(textTheme.titleLarge),
        titleMedium: readable(textTheme.titleMedium),
        titleSmall: readable(textTheme.titleSmall),
        bodyLarge: readable(textTheme.bodyLarge),
        bodyMedium: readable(textTheme.bodyMedium),
        bodySmall: readable(textTheme.bodySmall),
        labelLarge: readable(textTheme.labelLarge),
        labelMedium: readable(textTheme.labelMedium),
        labelSmall: readable(textTheme.labelSmall),
      ),
    );
  }

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.inverse,
          secondary: Color(0xFF075D64),
          onSecondary: AppColors.inverse,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          outline: AppColors.line,
          error: Color(0xFF9E2A2B),
        );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.line),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Noto Sans',
      scaffoldBackgroundColor: AppColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        errorMaxLines: 3,
        prefixIconColor: AppColors.primary,
        filled: true,
        fillColor: AppColors.surface,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.inverse,
          minimumSize: const Size(44, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink),
          minimumSize: const Size(44, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary,
        selectedIconTheme: IconThemeData(color: AppColors.inverse),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.inverse
                : AppColors.ink,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.inverse
                : AppColors.inkMuted,
          ),
        ),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 48),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.soft),
        headingTextStyle: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
        dividerThickness: 0.5,
        horizontalMargin: 20,
        columnSpacing: 24,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.inkMuted,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.line,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.ink,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.soft,
        selectedColor: AppColors.soft,
        side: BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
      ),
    );
  }
}
