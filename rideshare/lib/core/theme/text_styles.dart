import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get headlineLarge => GoogleFonts.tajawal(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF0F172A),
    height: 1.2,
  );

  static TextStyle get headlineMedium => GoogleFonts.tajawal(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF0F172A),
    height: 1.2,
  );

  static TextStyle get headlineSmall => GoogleFonts.tajawal(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF0F172A),
    height: 1.3,
  );

  static TextStyle get titleLarge => GoogleFonts.tajawal(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF0F172A),
    height: 1.3,
  );

  static TextStyle get titleMedium => GoogleFonts.tajawal(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF0F172A),
    height: 1.4,
  );

  static TextStyle get titleSmall => GoogleFonts.tajawal(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF0F172A),
    height: 1.4,
  );

  static TextStyle get bodyLarge => GoogleFonts.tajawal(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: const Color(0xFF0F172A),
    height: 1.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.tajawal(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: const Color(0xFF0F172A),
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.tajawal(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: const Color(0xFF475569),
    height: 1.5,
  );

  static TextStyle get labelLarge => GoogleFonts.tajawal(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF0F172A),
    height: 1.4,
  );

  static TextStyle get labelMedium => GoogleFonts.tajawal(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF0F172A),
    height: 1.4,
  );

  static TextStyle get labelSmall => GoogleFonts.tajawal(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF475569),
    height: 1.4,
  );

  static TextStyle get button => GoogleFonts.tajawal(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: const Color(0xFFFFFFFF),
    letterSpacing: 0.5,
  );

  static TextStyle get caption => GoogleFonts.tajawal(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: const Color(0xFF475569),
    height: 1.4,
  );

  static TextStyle get overline => GoogleFonts.tajawal(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF475569),
    letterSpacing: 1.5,
    height: 1.4,
  );
}
