import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/text_styles.dart';

enum ButtonVariant { primary, secondary, ghost, amber }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool isFullWidth;
  final bool isSmall;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.isFullWidth = false,
    this.isSmall = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    Color backgroundColor;
    Color textColor;
    BorderSide? borderSide;

    switch (variant) {
      case ButtonVariant.primary:
        backgroundColor = AppColors.primary;
        textColor = Colors.white;
        break;
      case ButtonVariant.secondary:
        backgroundColor = isDark
            ? AppColors.primary.withOpacity(0.2)
            : AppColors.primaryLight;
        textColor = AppColors.primary;
        break;
      case ButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        textColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;
        borderSide = BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        );
        break;
      case ButtonVariant.amber:
        backgroundColor = AppColors.accentAmber;
        textColor = const Color(0xFF241300);
        break;
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      disabledBackgroundColor: backgroundColor.withOpacity(0.45),
      disabledForegroundColor: textColor.withOpacity(0.45),
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 14 : 18,
        vertical: isSmall ? 8 : 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: borderSide ?? BorderSide.none,
      ),
      minimumSize: isFullWidth ? const Size(double.infinity, 0) : null,
    );

    final textWidget = Text(
      text,
      style: AppTextStyles.body(
        context,
        fontSize: isSmall ? 13 : 15,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        style: buttonStyle,
        icon: Icon(icon, size: isSmall ? 15 : 18, color: textColor),
        label: textWidget,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: buttonStyle,
      child: textWidget,
    );
  }
}
