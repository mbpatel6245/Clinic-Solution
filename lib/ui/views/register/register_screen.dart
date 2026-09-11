import 'package:clinic_solution/core/utils/validator.dart';
import 'package:flutter/material.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/locale_key.dart';
import '../../../core/utils/locale_provider.dart';
import '../../themes/text_styles.dart';
import '../../widgets/common_button.dart';
import '../../widgets/common_dropdown.dart';
import '../../widgets/common_text.dart';
import '../../widgets/common_textfield.dart';
import 'register_viewmodel.dart';

class RegisterScreen extends StatelessWidget {
  RegisterScreen({super.key});

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
        body: SafeArea(
          child: Center(
            child: Consumer<RegisterViewModel>(
              builder: (context, viewModel, child) {
                return Form(
                  key: _formKey,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        Text(
                          'Request enterprise access',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'For clinic owners and independent doctors. Your workspace starts after Platform Owner approval.',
                        ),
                        const SizedBox(height: 24),
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
                          label: 'Request type',
                          items: viewModel.roles,
                          onChanged: viewModel.onRoleChanged,
                          validator: (value) => value == null
                              ? AppLocalizations.of(context)!.roleRequired
                              : null,
                          prefixIcon: Icons.person,
                        ),
                        const SizedBox(height: 16.0),
                        CommonTextField(
                          controller: viewModel.clinicNameController,
                          keyboardType: TextInputType.text,
                          labelText: 'Clinic / practice name',
                          hintText: '',
                          prefixIcon: Icons.local_hospital_outlined,
                          validator: Validator().validateName,
                        ),
                        const SizedBox(height: 20.0),
                        CommonButton(
                          onPressed: () async {
                            if (viewModel.validateForm(_formKey)) {
                              try {
                                await viewModel.registerUser();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Request submitted. Sign-in will work after Platform Owner approval.',
                                    ),
                                  ),
                                );
                                context.go('/${Constants.navLogin}');
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                    content: Text(
                                      'Registration failed: $error',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onError,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          text: 'Submit approval request',
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/${Constants.navLogin}'),
                          child: const Text('Back to sign in'),
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
