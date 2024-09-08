import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/locale_provider.dart';
import '../themes/text_styles.dart';

class CommonDropdown<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final T? selectedItem;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final String Function(T)? displayItem;
  final IconData? prefixIcon;

  const CommonDropdown({
    Key? key,
    required this.label,
    required this.items,
    this.selectedItem,
    required this.onChanged,
    this.validator,
    this.displayItem,
    this.prefixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return DropdownButtonFormField<T>(
      value: selectedItem,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.black87) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      isExpanded: true,
      icon: Icon(Icons.arrow_drop_down),
      style: AppTextStyles.getRegularTextStyle(localeProvider.locale),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                    displayItem != null ? displayItem!(item) : item.toString(),
                    style: AppTextStyles.getRegularTextStyle(
                        localeProvider.locale)),
              ))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
