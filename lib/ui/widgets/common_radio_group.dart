import 'package:clinic_solution/core/utils/size_utils.dart';
import 'package:clinic_solution/ui/widgets/common_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/locale_provider.dart';
import '../themes/text_styles.dart';

class CommonRadioGroup<T> extends StatefulWidget {
  final List<T> options;
  final T? selectedValue;
  final ValueChanged<T?> onChanged;
 // final List<String> labels;
  final String title;

  const CommonRadioGroup({
    Key? key,
    required this.options,
    //required this.labels,
    required this.selectedValue,
    required this.onChanged,
    required this.title,
  }) : super(key: key);

  @override
  _CommonRadioGroupState<T> createState() => _CommonRadioGroupState<T>();
}

class _CommonRadioGroupState<T> extends State<CommonRadioGroup<T>> {
  @override
  Widget build(BuildContext context) {
    var localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: CommonText(
            text:widget.title,
            fontSize: getSize(16),
            height: getSize(25),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: widget.options.asMap().entries.map((entry) {
            int index = entry.key;
            T value = entry.value;

            return GestureDetector(
              onTap: () => widget.onChanged(value),
              child: Row(
                children: [
                  Radio<T>(
                    value: value,
                    groupValue: widget.selectedValue,
                    onChanged: widget.onChanged,
                  ),
                  Text(
                    widget.options[index].toString(),
                    style: AppTextStyles.getRegularTextStyle(
                        localeProvider.locale,
                        fontSize: 14),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
