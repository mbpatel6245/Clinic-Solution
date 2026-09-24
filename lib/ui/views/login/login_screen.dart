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
import '../../widgets/auth_layout.dart';
import 'login_viewmodel.dart';

class LoginScreen extends StatelessWidget {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

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
      child: AuthLayout(
        child: Center(
          child: Consumer<LoginViewModel>(
            builder: (context, viewModel, child) {
              return Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'WELCOME BACK',
                          style: TextStyle(
                            color: authTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        CommonText(
                          text: AppLocalizations.of(context)!.login,
                          style: AppTextStyles.getBoldTextStyle(
                            localeProvider.locale,
                          ).copyWith(fontSize: 32),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to continue to your clinic workspace.',
                          style: TextStyle(
                            color: Color(0xFF627C80),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 30),
                        AuthTextField(
                          controller: viewModel.emailController,
                          keyboardType: TextInputType.emailAddress,
                          labelText: AppLocalizations.of(context)!.email,
                          isPassword: false,
                          hintText: "",
                          prefixIcon: Icons.email,
                          validator: Validator().validateEmail,
                        ),
                        const SizedBox(height: 20),
                        AuthTextField(
                          controller: viewModel.passwordController,
                          labelText: AppLocalizations.of(context)!.password,
                          isPassword: true,
                          hintText: "",
                          prefixIcon: Icons.lock,
                          validator: Validator().validatePassword,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                context.go('/${Constants.navForgot}'),
                            child: Text(
                              AppLocalizations.of(context)!.forgotPassword,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AuthButton(
                          text: AppLocalizations.of(context)!.login,
                          onPressed: () {
                            if (viewModel.validateForm(_formKey)) {
                              //
                              viewModel.signIn((user) {
                                if (!context.mounted) return;
                                context.go('/${Constants.navHome}');
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            context.go('/${Constants.navRegister}');
                          },
                          icon: const Icon(Icons.add_business_outlined),
                          label: const Text('Request clinic access'),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: Color(0xFFE3ECEB)),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            context.go('/${Constants.navAppointment}');
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            AppLocalizations.of(context)!.bookAppointment,
                          ),
                        ),
                        const SizedBox(height: 24),
                        languageBar(localeProvider),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Center languageBar(LocaleProvider localeProvider) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              localeProvider.setLocale(const Locale('en', ''));
            },
            child: CommonText(
              text: 'English',
              style: AppTextStyles.getRegularTextStyle(
                localeProvider.locale,
              ).copyWith(decoration: TextDecoration.underline),
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () {
              localeProvider.setLocale(const Locale('hi', ''));
            },
            child: CommonText(
              text: 'हिंदी',
              style: AppTextStyles.getRegularTextStyle(
                localeProvider.locale,
              ).copyWith(decoration: TextDecoration.underline),
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () {
              localeProvider.setLocale(const Locale('gu', ''));
            },
            child: CommonText(
              text: 'ગુજરાતી',
              style: AppTextStyles.getRegularTextStyle(
                localeProvider.locale,
              ).copyWith(decoration: TextDecoration.underline),
            ),
          ),
          // Add more buttons for other languages if needed
        ],
      ),
    );
  }
}
