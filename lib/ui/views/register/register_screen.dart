import 'package:clinic_solution/core/utils/validator.dart';
import 'package:flutter/material.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/locale_key.dart';
import '../../widgets/auth_layout.dart';
import 'register_viewmodel.dart';

class RegisterScreen extends StatelessWidget {
  RegisterScreen({super.key});

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterViewModel(),
      child: AuthLayout(
        child: SafeArea(
          child: Center(
            child: Consumer<RegisterViewModel>(
              builder: (context, viewModel, child) {
                return Form(
                  key: _formKey,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        const Text(
                          'GET STARTED',
                          style: TextStyle(
                            color: authTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          viewModel.isPatient
                              ? 'Create patient account'
                              : 'Request enterprise access',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: authInk,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          viewModel.isPatient
                              ? 'Register immediately, choose a clinic and book appointments.'
                              : 'For clinic owners and independent doctors. Your workspace starts after Platform Owner approval.',
                          style: const TextStyle(
                            color: Color(0xFF627C80),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthTextField(
                          controller: viewModel.nameController,
                          keyboardType: TextInputType.text,
                          labelText: AppLocalizations.of(context)!.name,
                          hintText: '',
                          prefixIcon: Icons.text_fields,
                          validator: Validator().validateName,
                        ),
                        const SizedBox(height: 16.0),

                        AuthTextField(
                          controller: viewModel.emailController,
                          keyboardType: TextInputType.emailAddress,
                          labelText: AppLocalizations.of(context)!.email,
                          hintText: '',
                          prefixIcon: Icons.email,
                          validator: Validator().validateEmail,
                        ),
                        const SizedBox(height: 16.0),

                        // Password Field
                        AuthTextField(
                          controller: viewModel.passwordController,
                          isPassword: true,
                          hintText: '',
                          labelText: AppLocalizations.of(context)!.password,
                          prefixIcon: Icons.lock,
                          validator: Validator().validatePassword,
                        ),
                        const SizedBox(height: 16.0),

                        // Phone Field
                        AuthTextField(
                          controller: viewModel.phoneController,
                          keyboardType: TextInputType.phone,
                          hintText: '',
                          labelText: AppLocalizations.of(context)!.phone,
                          prefixIcon: Icons.phone,
                          validator: Validator().validatePhone,
                        ),
                        const SizedBox(height: 16.0),
                        DropdownButtonFormField<String>(
                          initialValue: viewModel.selectedRole,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Request type',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: viewModel.roles
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role),
                                ),
                              )
                              .toList(),
                          onChanged: viewModel.onRoleChanged,
                          validator: (value) => value == null
                              ? AppLocalizations.of(context)!.roleRequired
                              : null,
                        ),
                        const SizedBox(height: 16.0),
                        if (!viewModel.isPatient)
                          AuthTextField(
                            controller: viewModel.clinicNameController,
                            keyboardType: TextInputType.text,
                            labelText: 'Clinic / practice name',
                            hintText: '',
                            prefixIcon: Icons.local_hospital_outlined,
                            validator: Validator().validateName,
                          ),
                        const SizedBox(height: 20.0),
                        AuthButton(
                          onPressed: () async {
                            if (viewModel.validateForm(_formKey)) {
                              try {
                                await viewModel.registerUser(
                                  locale: Localizations.localeOf(
                                    context,
                                  ).languageCode,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      viewModel.isPatient
                                          ? 'Patient account created. You can sign in now.'
                                          : 'Request submitted. Sign-in will work after Platform Owner approval.',
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
                          text: viewModel.isPatient
                              ? 'Create patient account'
                              : 'Submit approval request',
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
