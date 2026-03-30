import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color teal50 = Color(0xFFF0FDFA);
  static const Color teal100 = Color(0xFFCCFBF1);
  static const Color teal200 = Color(0xFF99F6E4);
  static const Color teal300 = Color(0xFF5EEAD4);
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal700 = Color(0xFF0F766E);
  static const Color teal800 = Color(0xFF115E59);
  static const Color teal900 = Color(0xFF134E4A);
  static const Color teal950 = Color(0xFF042F2E);

  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF020617);

  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFF4ADE80);
  static const Color successDark = Color(0xFF16A34A);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFCA5A5);
  static const Color errorDark = Color(0xFFDC2626);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFCD34D);
  static const Color warningDark = Color(0xFFD97706);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF93C5FD);
  static const Color infoDark = Color(0xFF2563EB);

  static const Color statusPending = Color(0xFFFFA726);
  static const Color statusPendingLight = Color(0xFFFFCC80);
  static const Color statusActive = Color(0xFF00C9A7);
  static const Color statusActiveLight = Color(0xFF80CBC4);
  static const Color statusCompleted = Color(0xFF22C55E);
  static const Color statusCompletedLight = Color(0xFFA5D6A7);
  static const Color statusCancelled = Color(0xFFEF4444);
  static const Color statusCancelledLight = Color(0xFFEF9A9A);
  static const Color statusInProgress = Color(0xFF3B82F6);
  static const Color statusInProgressLight = Color(0xFF90CAF9);

  static const Color accentPink = Color(0xFFE91E63);
  static const Color accentOrange = Color(0xFFFB8500);

  static const Color surfaceLight = Color(0xFFF8F9FE);

  static const Color transparent = Colors.transparent;

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  static Color primaryAlpha(BuildContext context, double opacity) =>
      Theme.of(context).colorScheme.primary.withValues(alpha: opacity);

  static Color onSurfaceAlpha(BuildContext context, double opacity) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: opacity);

  static Color surfaceAlpha(BuildContext context, double opacity) =>
      Theme.of(context).colorScheme.surface.withValues(alpha: opacity);
}

class AppLightColors {
  AppLightColors();

  final Color primary = AppColors.teal600;
  final Color onPrimary = AppColors.white;
  final Color primaryContainer = AppColors.teal50;
  final Color onPrimaryContainer = AppColors.teal900;

  final Color secondary = AppColors.teal400;
  final Color onSecondary = AppColors.teal950;
  final Color secondaryContainer = AppColors.teal100;
  final Color onSecondaryContainer = AppColors.teal800;

  final Color background = AppColors.slate50;
  final Color onBackground = AppColors.slate900;
  final Color surface = AppColors.white;
  final Color onSurface = AppColors.slate800;
  final Color surfaceVariant = AppColors.slate100;
  final Color onSurfaceVariant = AppColors.slate600;

  final Color error = AppColors.error;
  final Color onError = AppColors.white;
  final Color errorContainer = Color(0xFFFEE2E2);
  final Color onErrorContainer = AppColors.errorDark;

  final Color outline = AppColors.slate200;
  final Color outlineVariant = AppColors.slate300;

  final Color textPrimary = AppColors.slate900;
  final Color textSecondary = AppColors.slate600;
  final Color textTertiary = AppColors.slate500;
  final Color textDisabled = AppColors.slate300;
  final Color textHint = AppColors.slate400;
  final Color textOnPrimary = AppColors.teal950;

  final Color border = AppColors.slate200;
  final Color borderStrong = AppColors.slate300;

  final Color scaffoldBackground = AppColors.slate50;
  final Color cardBackground = AppColors.white;
  final Color inputFill = AppColors.white;
  final Color divider = AppColors.slate200;

  final Color appBarBackground = AppColors.white;
  final Color appBarForeground = AppColors.slate800;

  final Color seatAvailable = AppColors.success;
  final Color seatBooked = AppColors.slate400;
  final Color seatSelected = AppColors.teal600;
  final Color seatUnavailable = AppColors.error;

  final Color shadow = Color(0x1A000000);
  final Color shadowStrong = Color(0x33000000);
  final Color overlay = Color(0x52000000);

  final Color iconPrimary = AppColors.slate800;
  final Color iconSecondary = AppColors.slate500;
  final Color iconDisabled = AppColors.slate300;
}

class AppDarkColors {
  AppDarkColors();

  final Color primary = AppColors.teal400;
  final Color onPrimary = AppColors.teal950;
  final Color primaryContainer = AppColors.teal800;
  final Color onPrimaryContainer = AppColors.teal100;

  final Color secondary = AppColors.teal300;
  final Color onSecondary = AppColors.teal900;
  final Color secondaryContainer = AppColors.teal700;
  final Color onSecondaryContainer = AppColors.teal200;

  final Color background = AppColors.slate950;
  final Color onBackground = AppColors.slate100;
  final Color surface = AppColors.slate900;
  final Color onSurface = AppColors.slate100;
  final Color surfaceVariant = AppColors.slate800;
  final Color onSurfaceVariant = AppColors.slate400;

  final Color error = AppColors.errorLight;
  final Color onError = AppColors.slate900;
  final Color errorContainer = Color(0xFF7F1D1D);
  final Color onErrorContainer = AppColors.errorLight;

  final Color outline = AppColors.slate700;
  final Color outlineVariant = AppColors.slate600;

  final Color textPrimary = AppColors.slate50;
  final Color textSecondary = AppColors.slate400;
  final Color textTertiary = AppColors.slate500;
  final Color textDisabled = AppColors.slate600;
  final Color textHint = AppColors.slate500;
  final Color textOnPrimary = AppColors.teal950;

  final Color border = AppColors.slate700;
  final Color borderStrong = AppColors.slate600;

  final Color scaffoldBackground = AppColors.slate950;
  final Color cardBackground = AppColors.slate900;
  final Color inputFill = AppColors.slate800;
  final Color divider = AppColors.slate700;

  final Color appBarBackground = AppColors.slate900;
  final Color appBarForeground = AppColors.slate100;

  final Color seatAvailable = AppColors.successDark;
  final Color seatBooked = AppColors.slate600;
  final Color seatSelected = AppColors.teal400;
  final Color seatUnavailable = AppColors.errorLight;

  final Color shadow = Color(0x0DFFFFFF);
  final Color shadowStrong = Color(0x1AFFFFFF);
  final Color overlay = Color(0x52000000);

  final Color iconPrimary = AppColors.slate100;
  final Color iconSecondary = AppColors.slate400;
  final Color iconDisabled = AppColors.slate500;
}

class T {
  T._();

  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color onPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;
  static Color primaryContainer(BuildContext context) =>
      Theme.of(context).colorScheme.primaryContainer;
  static Color onPrimaryContainer(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimaryContainer;
  static Color secondary(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;
  static Color onSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSecondary;
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  static Color surfaceVariant(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;
  static Color onSurfaceVariant(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  static Color background(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color error(BuildContext context) =>
      Theme.of(context).colorScheme.error;
  static Color onError(BuildContext context) =>
      Theme.of(context).colorScheme.onError;
  static Color outline(BuildContext context) =>
      Theme.of(context).colorScheme.outline;
  static Color outlineVariant(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;
}
