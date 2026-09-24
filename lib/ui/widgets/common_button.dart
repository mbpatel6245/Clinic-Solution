// common_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/locale_provider.dart';
import '../themes/text_styles.dart';

class CommonButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? borderRadius;
  final double? verticalPadding;
  final double? horizontalPadding;
  final bool isDisabled;

  const CommonButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = 8.0,
    this.verticalPadding = 15.0,
    this.horizontalPadding = 40.0,
    this.isDisabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
              ? Colors.grey
              : backgroundColor ?? Colors.white70,
          padding: EdgeInsets.symmetric(
            vertical: verticalPadding ?? 15.0,
            horizontal: horizontalPadding ?? 40.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 8.0),
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.getBoldTextStyle(localeProvider.locale),
        ),
      ),
    );
  }
}
