import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'text_styles.dart';

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(isDark: false);

  static ThemeData get darkTheme => _buildTheme(isDark: true);

  static ThemeData _buildTheme({required bool isDark}) {
    final dynamic colors = isDark ? AppDarkColors() : AppLightColors();

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.onPrimaryContainer,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      secondaryContainer: colors.secondaryContainer,
      onSecondaryContainer: colors.onSecondaryContainer,
      surface: colors.surface,
      onSurface: colors.onSurface,
      surfaceContainerHighest: colors.surfaceVariant,
      onSurfaceVariant: colors.onSurfaceVariant,
      error: colors.error,
      onError: colors.onError,
      errorContainer: colors.errorContainer,
      onErrorContainer: colors.onErrorContainer,
      outline: colors.outline,
      outlineVariant: colors.outlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.scaffoldBackground,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colors.appBarBackground,
        foregroundColor: colors.appBarForeground,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(
          color: colors.appBarForeground,
        ),
        iconTheme: IconThemeData(color: colors.iconPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: colors.cardBackground,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: colors.primary, width: 1.5),
          textStyle: AppTextStyles.button.copyWith(color: colors.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: AppTextStyles.labelLarge.copyWith(color: colors.primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: colors.textHint),
      ),
      textTheme: GoogleFonts.tajawalTextTheme(
        TextTheme(
          headlineLarge: AppTextStyles.headlineLarge.copyWith(
            color: colors.textPrimary,
          ),
          headlineMedium: AppTextStyles.headlineMedium.copyWith(
            color: colors.textPrimary,
          ),
          headlineSmall: AppTextStyles.headlineSmall.copyWith(
            color: colors.textPrimary,
          ),
          titleLarge: AppTextStyles.titleLarge.copyWith(
            color: colors.textPrimary,
          ),
          titleMedium: AppTextStyles.titleMedium.copyWith(
            color: colors.textPrimary,
          ),
          titleSmall: AppTextStyles.titleSmall.copyWith(
            color: colors.textPrimary,
          ),
          bodyLarge: AppTextStyles.bodyLarge.copyWith(
            color: colors.textPrimary,
          ),
          bodyMedium: AppTextStyles.bodyMedium.copyWith(
            color: colors.textPrimary,
          ),
          bodySmall: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
          labelLarge: AppTextStyles.labelLarge.copyWith(
            color: colors.textPrimary,
          ),
          labelMedium: AppTextStyles.labelMedium.copyWith(
            color: colors.textPrimary,
          ),
          labelSmall: AppTextStyles.labelSmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ),
      fontFamily: GoogleFonts.tajawal().fontFamily,
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return colors.textSecondary;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return AppColors.transparent;
        }),
        checkColor: WidgetStateColor.resolveWith((states) {
          return colors.onPrimary;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.onSurface,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: colors.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textTertiary,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
