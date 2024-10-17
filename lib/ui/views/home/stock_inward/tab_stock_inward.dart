import 'package:clinic_solution/core/utils/size_utils.dart';
import 'package:clinic_solution/ui/views/home/stock_inward/stock_inward_viewmodel.dart';
import 'package:clinic_solution/ui/widgets/common_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/locale_provider.dart';
import '../../../../core/utils/validator.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_dropdown.dart';
import '../../../widgets/common_radio_group.dart';
import '../../../widgets/common_textfield.dart';

class TabStockInward extends StatefulWidget {
  //TabStockInward({super.key});

  @override
  State<TabStockInward> createState() => _TabStockInwardState();
}

class _TabStockInwardState extends State<TabStockInward> {
  var localeProvider = LocaleProvider();

  String? _selectedOption;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize _selectedOption here where AppLocalizations is available
    _selectedOption ??= AppLocalizations.of(context)!.medicine;
  }

  @override
  Widget build(BuildContext context) {
    var localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) => StockInwardViewmodel(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Consumer<StockInwardViewmodel>(
            builder: (context, viewModel, child) {
              return Form(
                key: _formKey,
                child: isTableOrDesktop(context)
                    ? GridView(
                        gridDelegate:  SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          // Show 2 columns on tablets and larger devices
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio:
                          (MediaQuery.of(context).size.width) /
                              (MediaQuery.of(context).size.height / 5), // Adjust the height/width ratio as needed
                        ),
                        children: stockListOfContent(context, viewModel).map((widget) {
                          return IntrinsicHeight( // Ensures each item adjusts to its content height
                            child: widget,
                          );
                        }).toList(),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        children: stockListOfContent(context, viewModel),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool isTableOrDesktop(BuildContext context) {
    // Get the screen width and orientation
    var screenWidth = MediaQuery.of(context).size.width;
    var orientation = MediaQuery.of(context).orientation;

    // Determine whether to use 1 or 2 columns based on screen width and orientation
    bool isTabletOrDesktop =
        screenWidth >= 600 && orientation == Orientation.landscape;
    return isTabletOrDesktop;
  }

  List<Widget> stockListOfContent(
      BuildContext context, StockInwardViewmodel viewModel) {
    return [
      CommonRadioGroup<String>(
        title: AppLocalizations.of(context)!.typeOfStock,
        options: [
          AppLocalizations.of(context)!.medicine,
          AppLocalizations.of(context)!.others
        ],
        labels: [
          AppLocalizations.of(context)!.medicine,
          AppLocalizations.of(context)!.others
        ],
        // Labels for each radio
        selectedValue: _selectedOption,
        onChanged: (value) {
          setState(() {
            _selectedOption = value;
          });
        },
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.nameController,
        keyboardType: TextInputType.datetime,
        labelText: AppLocalizations.of(context)!.expiryDate,
        hintText: '',
        prefixIcon: Icons.calendar_today,
        validator: Validator().validateName,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),

      CommonTextField(
        controller: viewModel.emailController,
        keyboardType: TextInputType.number,
        labelText: AppLocalizations.of(context)!.minimumAvailability,
        hintText: '',
        prefixIcon: Icons.hourglass_empty,
        validator: Validator().validateEmail,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),

      // Password Field
      CommonTextField(
        controller: viewModel.passwordController,
        keyboardType: TextInputType.number,
        hintText: '',
        labelText: AppLocalizations.of(context)!.maximumAvailability,
        prefixIcon: Icons.hourglass_empty,
        validator: Validator().validatePassword,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),

      // Phone Field
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.datetime,
        hintText: '',
        labelText: AppLocalizations.of(context)!.nearestDurationDays,
        prefixIcon: Icons.calendar_month,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.brandName,
        prefixIcon: Icons.branding_watermark,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.containsOfMedicine,
        prefixIcon: FontAwesomeIcons.pills,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.purchasingPersonOrStockist,
        prefixIcon: FontAwesomeIcons.person,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      Column(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonText(text: AppLocalizations.of(context)!.quantity,fontSize: 16,height: 30,),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: CommonTextField(
                  controller: viewModel.phoneController,
                  keyboardType: TextInputType.text,
                  hintText: '',
                  labelText: AppLocalizations.of(context)!.medicine,
                  validator: Validator().validatePhone,
                  height: getSize(40),
                  fontSize: getSize(16),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: CommonTextField(
                  controller: viewModel.phoneController,
                  keyboardType: TextInputType.text,
                  hintText: '',
                  labelText: AppLocalizations.of(context)!.tabletsOrStrips,
                  validator: Validator().validatePhone,
                  height: getSize(40),
                  fontSize: getSize(16),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: CommonTextField(
                  controller: viewModel.phoneController,
                  keyboardType: TextInputType.text,
                  hintText: '',
                  labelText: AppLocalizations.of(context)!.box,
                  validator: Validator().validatePhone,
                  height: getSize(40),
                  fontSize: getSize(16),
                ),
              ),
            ],
          ),
        ],
      ),


      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.datetime,
        hintText: '',
        labelText: AppLocalizations.of(context)!.dateOfPurchase,
        prefixIcon: Icons.date_range_rounded,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.powerOfSize,
        prefixIcon: Icons.stream,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.formType,
        prefixIcon: Icons.medical_information,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.manufacturerName,
        prefixIcon: Icons.precision_manufacturing,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.visibilityShowOrHide,
        prefixIcon: Icons.visibility,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.shortName,
        prefixIcon: Icons.short_text,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.colorOfContent,
        prefixIcon: Icons.color_lens,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonTextField(
        controller: viewModel.phoneController,
        keyboardType: TextInputType.text,
        hintText: '',
        labelText: AppLocalizations.of(context)!.billNo,
        prefixIcon: Icons.inventory_outlined,
        validator: Validator().validatePhone,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonDropdown<String>(
        label: AppLocalizations.of(context)!.role,
        items: viewModel.roles,
        onChanged: viewModel.onRoleChanged,
        validator: (value) =>
            value == null ? AppLocalizations.of(context)!.roleRequired : null,
        prefixIcon: Icons.person,
      ),
      if (!isTableOrDesktop(context)) const SizedBox(height: 10.0),
      CommonButton(
        onPressed: () async {
          if (viewModel.validateForm(_formKey)) {
            await viewModel.registerUser();
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.registerSuccessfully),
              ),
            );
          }
        },
        text: AppLocalizations.of(context)!.register,
      ),
    ];
  }
}
