import 'package:clinic_solution/core/utils/validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/locale_provider.dart';
import '../../themes/text_styles.dart';
import '../../widgets/common_button.dart';
import '../../widgets/common_dropdown.dart';
import '../../widgets/common_text.dart';
import '../../widgets/common_textfield.dart';
import 'register_viewmodel.dart';

class RegisterScreen extends StatelessWidget {
  RegisterScreen({Key? key}) : super(key: key);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    var localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return ChangeNotifierProvider(
      create: (_) => RegisterViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: CommonText(
            text: AppLocalizations.of(context)!.register,
            style: AppTextStyles.getBoldTextStyle(localeProvider.locale),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Consumer<RegisterViewModel>(
              builder: (context, viewModel, child) {
                return Form(
                  key: _formKey,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: ListView(
                      children: [
                        CommonTextField(
                          controller: viewModel.nameController,
                          keyboardType: TextInputType.text,
                          labelText: AppLocalizations.of(context)!.name,
                          hintText: '',
                          prefixIcon: Icons.text_fields,
                          validator: Validator().validateName,
                        ),
                        const SizedBox(height: 16.0),

                        CommonTextField(
                          controller: viewModel.emailController,
                          keyboardType: TextInputType.emailAddress,
                          labelText: AppLocalizations.of(context)!.email,
                          hintText: '',
                          prefixIcon: Icons.email,
                          validator: Validator().validateEmail,
                        ),
                        const SizedBox(height: 16.0),

                        // Password Field
                        CommonTextField(
                          controller: viewModel.passwordController,
                          isPassword: true,
                          hintText: '',
                          labelText: AppLocalizations.of(context)!.password,
                          prefixIcon: Icons.lock,
                          validator: Validator().validatePassword,
                        ),
                        const SizedBox(height: 16.0),

                        // Phone Field
                        CommonTextField(
                          controller: viewModel.phoneController,
                          keyboardType: TextInputType.phone,
                          hintText: '',
                          labelText: AppLocalizations.of(context)!.phone,
                          prefixIcon: Icons.phone,
                          validator: Validator().validatePhone,
                        ),
                        const SizedBox(height: 16.0),
                        CommonDropdown<String>(
                          label: AppLocalizations.of(context)!.role,
                          items: viewModel.roles,
                          onChanged: viewModel.onRoleChanged,
                          validator: (value) => value == null
                              ? AppLocalizations.of(context)!.roleRequired
                              : null,
                          prefixIcon: Icons.person,
                        ),
                        const SizedBox(height: 20.0),
                        CommonButton(
                          onPressed: () async {
                            if (viewModel.validateForm(_formKey)) {
                              await viewModel.registerUser();
                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: CommonText(
                                      text: AppLocalizations.of(context)!
                                          .registerSuccessfully),
                                ),
                              );
                            }
                          },
                          text: AppLocalizations.of(context)!.register,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
