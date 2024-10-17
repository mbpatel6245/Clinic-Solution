import 'package:clinic_solution/core/utils/size_utils.dart';
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
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final Function(String)? onChanged;
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
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.validator,
    this.height,
    this.fontSize
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return SizedBox(height: height??getSize(55),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword,
        onChanged: onChanged,
        validator: validator,
        style: AppTextStyles.getRegularTextStyle(localeProvider.locale,fontSize: fontSize??getSize(20)),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          filled: true,
          fillColor: Colors.transparent,
          // Background color with M3 surface variant
          labelStyle: AppTextStyles.getRegularTextStyle(localeProvider.locale,fontSize: fontSize??getSize(20)),
          hintStyle: AppTextStyles.getRegularTextStyle(localeProvider.locale)
              .copyWith(color: Colors.white38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(
              color: Colors.black12, // Outline color matching M3
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(
              color: Colors.black, // Border for enabled state
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(
              color: Colors.black, // Border for focused state
              width: 2.0,
            ),
          ),
          prefixIcon:
              prefixIcon != null ? Icon(prefixIcon, color: Colors.black87) : null,
          suffixIcon:
              suffixIcon != null ? Icon(suffixIcon, color: Colors.black87) : null,
        ),
      ),
    );
  }
}
