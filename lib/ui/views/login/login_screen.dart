import 'package:clinic_solution/core/utils/validator.dart';
import 'package:clinic_solution/ui/widgets/common_text.dart';
import 'package:flutter/material.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/locale_key.dart';
import '../../../core/utils/locale_provider.dart';
import '../../../services/local/secure_data_viewmodel.dart';
import '../../themes/text_styles.dart';
import '../../widgets/common_button.dart';
import '../../widgets/common_textfield.dart';
import 'login_viewmodel.dart';

class LoginScreen extends StatelessWidget {
  var localeProvider = LocaleProvider();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SecureDataViewModel()),
        ChangeNotifierProxyProvider<SecureDataViewModel, LoginViewModel>(
          create: (context) =>
              LoginViewModel(context.read<SecureDataViewModel>()),
          update: (context, secureDataViewModel, loginViewModel) =>
              loginViewModel ?? LoginViewModel(secureDataViewModel),
        ),
      ],
      child: Scaffold(
        body: Center(child:
            Consumer<LoginViewModel>(builder: (context, viewModel, child) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 80, color: Colors.black38),
                    const SizedBox(height: 20),
                    CommonText(
                      text: AppLocalizations.of(context)!.login,
                      style:
                          AppTextStyles.getBoldTextStyle(localeProvider.locale)
                              .copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 30),
                    CommonTextField(
                      controller: viewModel.emailController,
                      labelText: AppLocalizations.of(context)!.email,
                      isPassword: false,
                      hintText: "",
                      prefixIcon: Icons.email,
                      validator: Validator().validateEmail,
                    ),
                    const SizedBox(height: 20),
                    CommonTextField(
                      controller: viewModel.passwordController,
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
                        if (viewModel.validateForm(_formKey)) {
                          //
                          viewModel.signIn((user) {
                            context.go('/${Constants.navHome}');
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.go('/${Constants.navAppointment}');
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        AppLocalizations.of(context)!.bookAppointment,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        context.go('/${Constants.navForgot}');
                      },
                      child: CommonText(
                          text:AppLocalizations.of(context)!.forgotPassword,
                          style: AppTextStyles.getSemiBoldTextStyle(
                              localeProvider.locale)),
                    ),
                    const SizedBox(height: 40),
                    languageBar(),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: () {
                        context.go('/${Constants.navRegister}');
                      },
                      child: CommonText(
                          text:AppLocalizations.of(context)!.newUserRegister,
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
            child: CommonText(
                text:'English',
                style: AppTextStyles.getRegularTextStyle(localeProvider.locale)
                    .copyWith(decoration: TextDecoration.underline)),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () {
              localeProvider.setLocale(const Locale('hi', ''));
            },
            child: CommonText(
                text:'हिंदी',
                style: AppTextStyles.getRegularTextStyle(localeProvider.locale)
                    .copyWith(decoration: TextDecoration.underline)),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () {
              localeProvider.setLocale(const Locale('gu', ''));
            },
            child: CommonText(
                text:'ગુજરાતી',
                style: AppTextStyles.getRegularTextStyle(localeProvider.locale)
                    .copyWith(decoration: TextDecoration.underline)),
          ),
          // Add more buttons for other languages if needed
        ],
      ),
    );
  }
}
