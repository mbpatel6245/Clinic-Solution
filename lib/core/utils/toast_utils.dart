import 'package:clinic_solution/core/utils/size_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../ui/themes/text_styles.dart';
import 'locale_provider.dart';

showToast(String message) {
  var localeProvider =
      Provider.of<LocaleProvider>(navigatorKey.currentContext!, listen: false);
  ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: AppTextStyles.getRegularTextStyle(localeProvider.locale,
            fontSize: getSize(20),).copyWith(color: Colors.white),
      ),
    ),
  );
}
