import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/locale_provider.dart';
import '../themes/text_styles.dart';

class CommonTextField extends StatelessWidget {
  final String labelText;
  final String hintText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool isReadOnly;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final Function(String)? onChanged;
  final Function()? onTap;
  final Function()? suffixOnTap;
  final String? Function(String?)? validator;
  final double? height;
  final double? fontSize;

  const CommonTextField({
    Key? key,
    required this.labelText,
    required this.hintText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.isReadOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onTap,
    this.suffixOnTap,
    this.validator,
    this.height,
    this.fontSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height ?? 56),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword,
        onChanged: onChanged,
        validator: validator,
        readOnly: isReadOnly,
        onTap: onTap,
        style: AppTextStyles.getRegularTextStyle(
          localeProvider.locale,
          fontSize: fontSize ?? 16,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          errorMaxLines: 3,
          labelText: labelText,
          hintText: hintText,
          filled: true,

          // Background color with M3 surface variant
          labelStyle: AppTextStyles.getRegularTextStyle(
            localeProvider.locale,
            fontSize: fontSize ?? 16,
          ),
          hintStyle: AppTextStyles.getRegularTextStyle(
            localeProvider.locale,
          ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: Theme.of(context).colorScheme.primary)
              : null,
          suffixIcon: suffixIcon != null
              ? GestureDetector(
                  onTap: suffixOnTap,
                  child: Icon(
                    suffixIcon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
