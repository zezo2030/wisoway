import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get headlineLarge => _headlineLarge();
  static TextStyle headlineLargeWithContext(BuildContext context) =>
      _headlineLarge(context);

  static TextStyle get headlineMedium => _headlineMedium();
  static TextStyle headlineMediumWithContext(BuildContext context) =>
      _headlineMedium(context);

  static TextStyle get headlineSmall => _headlineSmall();
  static TextStyle headlineSmallWithContext(BuildContext context) =>
      _headlineSmall(context);

  static TextStyle get titleLarge => _titleLarge();
  static TextStyle titleLargeWithContext(BuildContext context) =>
      _titleLarge(context);

  static TextStyle get titleMedium => _titleMedium();
  static TextStyle titleMediumWithContext(BuildContext context) =>
      _titleMedium(context);

  static TextStyle get titleSmall => _titleSmall();
  static TextStyle titleSmallWithContext(BuildContext context) =>
      _titleSmall(context);

  static TextStyle get bodyLarge => _bodyLarge();
  static TextStyle bodyLargeWithContext(BuildContext context) =>
      _bodyLarge(context);

  static TextStyle get bodyMedium => _bodyMedium();
  static TextStyle bodyMediumWithContext(BuildContext context) =>
      _bodyMedium(context);

  static TextStyle get bodySmall => _bodySmall();
  static TextStyle bodySmallWithContext(BuildContext context) =>
      _bodySmall(context);

  static TextStyle get labelLarge => _labelLarge();
  static TextStyle labelLargeWithContext(BuildContext context) =>
      _labelLarge(context);

  static TextStyle get labelMedium => _labelMedium();
  static TextStyle labelMediumWithContext(BuildContext context) =>
      _labelMedium(context);

  static TextStyle get labelSmall => _labelSmall();
  static TextStyle labelSmallWithContext(BuildContext context) =>
      _labelSmall(context);

  static TextStyle get button => _button();
  static TextStyle buttonWithContext(BuildContext context) => _button(context);

  static TextStyle get caption => _caption();
  static TextStyle captionWithContext(BuildContext context) =>
      _caption(context);

  static TextStyle get overline => _overline();
  static TextStyle overlineWithContext(BuildContext context) =>
      _overline(context);

  static TextStyle _headlineLarge([BuildContext? context]) =>
      GoogleFonts.tajawal(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: _textPrimary(context),
        height: 1.2,
      );

  static TextStyle _headlineMedium([BuildContext? context]) =>
      GoogleFonts.tajawal(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: _textPrimary(context),
        height: 1.2,
      );

  static TextStyle _headlineSmall([BuildContext? context]) =>
      GoogleFonts.tajawal(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: _textPrimary(context),
        height: 1.3,
      );

  static TextStyle _titleLarge([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: _textPrimary(context),
    height: 1.3,
  );

  static TextStyle _titleMedium([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: _textPrimary(context),
    height: 1.4,
  );

  static TextStyle _titleSmall([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: _textPrimary(context),
    height: 1.4,
  );

  static TextStyle _bodyLarge([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: _textPrimary(context),
    height: 1.5,
  );

  static TextStyle _bodyMedium([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: _textPrimary(context),
    height: 1.5,
  );

  static TextStyle _bodySmall([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: _textSecondary(context),
    height: 1.5,
  );

  static TextStyle _labelLarge([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _textPrimary(context),
    height: 1.4,
  );

  static TextStyle _labelMedium([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: _textPrimary(context),
    height: 1.4,
  );

  static TextStyle _labelSmall([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: _textSecondary(context),
    height: 1.4,
  );

  static TextStyle _button([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.teal950,
    letterSpacing: 0.5,
  );

  static TextStyle _caption([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: _textSecondary(context),
    height: 1.4,
  );

  static TextStyle _overline([BuildContext? context]) => GoogleFonts.tajawal(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: _textSecondary(context),
    letterSpacing: 1.5,
    height: 1.4,
  );

  static Color _textPrimary(BuildContext? context) {
    if (context == null) return AppColors.slate900;
    return T.onSurface(context);
  }

  static Color _textSecondary(BuildContext? context) {
    if (context == null) return AppColors.slate600;
    return T.onSurfaceVariant(context);
  }
}
