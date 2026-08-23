import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/text_styles.dart';

class CustomChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final Color? activeColor;

  const CustomChip({
    super.key,
    required this.label,
    this.isActive = false,
    this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultActiveColor = activeColor ?? AppColors.primary;
    final borderColor = isActive
        ? defaultActiveColor
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final backgroundColor = isActive
        ? defaultActiveColor.withOpacity(0.15)
        : (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final textColor = isActive
        ? defaultActiveColor
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Text(
            label,
            style: AppTextStyles.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
