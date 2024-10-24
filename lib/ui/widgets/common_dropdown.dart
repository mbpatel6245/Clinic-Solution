import 'package:clinic_solution/ui/widgets/common_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/locale_provider.dart';
import '../../core/utils/size_utils.dart';
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
        labelStyle: AppTextStyles.getRegularTextStyle(localeProvider.locale),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8.0, // Adjusts the height
          horizontal: 12.0, // Padding inside the field
        ),
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, color: Colors.black87) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(
            color: Colors.black12, // Border for enabled state
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
      ),
      isExpanded: true,
      isDense: false,
      icon: const Icon(Icons.arrow_drop_down),
      style: AppTextStyles.getRegularTextStyle(localeProvider.locale),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: CommonText(
                  text: displayItem != null
                      ? displayItem!(item)
                      : item.toString(),
                  style: AppTextStyles.getRegularTextStyle(
                      localeProvider.locale),
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
