import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Numeric/Monospace styles for stats/scores
  static TextStyle monoBold(BuildContext context, {double fontSize = 17, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
    );
  }

  // Display text styles for headers
  static TextStyle displayBold(BuildContext context, {double fontSize = 20, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
    );
  }

  // Inter text styles for body
  static TextStyle body(BuildContext context, {double fontSize = 14, FontWeight fontWeight = FontWeight.w400, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
    );
  }
  
  static TextStyle bodySecondary(BuildContext context, {double fontSize = 13, FontWeight fontWeight = FontWeight.w400, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
    );
  }
}
