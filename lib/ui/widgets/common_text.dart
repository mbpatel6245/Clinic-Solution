import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/locale_provider.dart';
import '../themes/text_styles.dart';

class CommonText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? height;
  final double? fontSize;

  const CommonText({
    Key? key,
    required this.text,
    this.style,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontSize,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    if (height == null) {
      return Text(
        text,
        style:
            style?.copyWith(color: color ?? Colors.black87) ??
            AppTextStyles.getRegularTextStyle(
              localeProvider.locale,
              fontSize: fontSize ?? 20,
            ).copyWith(color: color ?? Colors.black87),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.ellipsis,
      );
    } else {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: height!),
        child: Text(
          text,
          style:
              style?.copyWith(color: color ?? Colors.black87) ??
              AppTextStyles.getRegularTextStyle(
                localeProvider.locale,
                fontSize: fontSize ?? 20,
              ).copyWith(color: color ?? Colors.black87),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow ?? TextOverflow.ellipsis,
        ),
      );
    }
  }
}
