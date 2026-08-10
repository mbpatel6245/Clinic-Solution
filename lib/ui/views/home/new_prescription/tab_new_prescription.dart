import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/locale_provider.dart';
import '../../../themes/text_styles.dart';

class TabNewPrescription extends StatelessWidget {
  var localeProvider = LocaleProvider();

  @override
  Widget build(BuildContext context) {
    localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return Center(
      child: Text(
        "Content for Tab 1",
        style: AppTextStyles.getRegularTextStyle(localeProvider.locale),
      ),
    );
  }
}
