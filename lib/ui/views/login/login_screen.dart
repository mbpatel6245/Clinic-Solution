import 'package:clinic_solution/core/utils/validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/locale_key.dart';
import '../../../core/utils/locale_provider.dart';
import '../../themes/text_styles.dart';
import '../../widgets/common_button.dart';
import '../../widgets/common_textfield.dart';
import 'login_viewmodel.dart';

class LoginScreen extends StatelessWidget {

  final LoginViewModel _viewModel = LoginViewModel();
  var localeProvider = LocaleProvider();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: Scaffold(
        body: Center(child:
            Consumer<LoginViewModel>(builder: (context, viewModel, child) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 80, color: Colors.black38),
                    const SizedBox(height: 20),
                    Text(
                      AppLocalizations.of(context)!.login,
                      style:
                          AppTextStyles.getBoldTextStyle(localeProvider.locale)
                              .copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 30),
                    CommonTextField(
                      controller: _viewModel.emailController,
                      labelText: AppLocalizations.of(context)!.email,
                      isPassword: false,
                      hintText: "",
                      prefixIcon: Icons.email,
                      validator: Validator().validateEmail,
                    ),
                    const SizedBox(height: 20),
                    CommonTextField(
                      controller: _viewModel.passwordController,
                      labelText: AppLocalizations.of(context)!.password,
                      isPassword: true,
                      hintText: "",
                      prefixIcon: Icons.lock,
                      validator: Validator().validatePassword,
                    ),
                    const SizedBox(height: 30),
                    CommonButton(
                      text: AppLocalizations.of(context)!.login,
                      onPressed: () {
                        if (_viewModel.validateForm(_formKey)) {
                          //
                          _viewModel.signIn((user) {
                            context.go('/${Strings.navHome}', extra: user);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        // Handle forgot password logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Forgot Password Clicked')),
                        );
                      },
                      child: Text(AppLocalizations.of(context)!.forgotPassword,
                          style: AppTextStyles.getSemiBoldTextStyle(
                              localeProvider.locale)),
                    ),
                    const SizedBox(height: 40),
                    languageBar(),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: () {
                        context.go('/${Strings.navRegister}');
                      },
                      child: Text(AppLocalizations.of(context)!.newUserRegister,
                          style: AppTextStyles.getRegularTextStyle(
                                  localeProvider.locale)
                              .copyWith(decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
            ),
          );
        })),
      ),
    );
  }

  Center languageBar() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              localeProvider.setLocale(const Locale('en', ''));
            },
            child: Text('English',
                style: AppTextStyles.getRegularTextStyle(localeProvider.locale)
                    .copyWith(decoration: TextDecoration.underline)),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () {
              localeProvider.setLocale(const Locale('hi', ''));
            },
            child: Text('हिंदी',
                style: AppTextStyles.getRegularTextStyle(localeProvider.locale)
                    .copyWith(decoration: TextDecoration.underline)),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () {
              localeProvider.setLocale(const Locale('gu', ''));
            },
            child: Text('ગુજરાતી',
                style: AppTextStyles.getRegularTextStyle(localeProvider.locale)
                    .copyWith(decoration: TextDecoration.underline)),
          ),
          // Add more buttons for other languages if needed
        ],
      ),
    );
  }
}
