import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/common_dropdown.dart';
import '../../widgets/common_textfield.dart';
import 'register_viewmodel.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class RegisterScreen extends StatelessWidget {
  RegisterScreen({Key? key}) : super(key: key);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.register),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Consumer<RegisterViewModel>(
            builder: (context, viewModel, child) {
              return Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Email Field
                    CommonTextField(
                      controller: viewModel.emailController,
                      keyboardType: TextInputType.emailAddress,
                      labelText: AppLocalizations.of(context)!.email,
                      hintText: '',
                      prefixIcon: Icons.email,
                      validator: viewModel.validateEmail,
                    ),
                    SizedBox(height: 16.0),

                    // Password Field
                    CommonTextField(
                      controller: viewModel.passwordController,
                      isPassword: true,
                      hintText: '',
                      labelText: AppLocalizations.of(context)!.password,
                      prefixIcon: Icons.lock,
                      validator: viewModel.validatePassword,
                    ),
                    SizedBox(height: 16.0),

                    // Phone Field
                    CommonTextField(
                      controller: viewModel.phoneController,
                      keyboardType: TextInputType.phone,
                      hintText: '',
                      labelText: AppLocalizations.of(context)!.phone,
                      prefixIcon: Icons.phone,
                      validator: viewModel.validatePhone,
                    ),
                    SizedBox(height: 16.0),
                    CommonDropdown<String>(
                      label: AppLocalizations.of(context)!.role,
                      items: viewModel.roles,
                      onChanged: viewModel.onRoleChanged,
                      validator: (value) =>
                          value == null ? AppLocalizations.of(context)!.roleRequired : null,
                      prefixIcon: Icons.person,
                    ),
                    SizedBox(height: 20.0),

                    // Register Button
                    ElevatedButton(
                      onPressed: () async {
                        if (viewModel.validateForm(_formKey)) {
                          await viewModel.saveData();
                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Registered successfully!'),
                            ),
                          );
                        }
                      },
                      child: Text('Register'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
