import 'package:clinic_solution/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/locale_key.dart';
import '../../../core/utils/locale_provider.dart';
import '../../themes/text_styles.dart';
import '../../widgets/common_textfield.dart';
import 'login_viewmodel.dart';

class LoginScreen extends StatelessWidget {
  // final TextEditingController _emailController = TextEditingController();
  // final TextEditingController _passwordController = TextEditingController();
  final LoginViewModel _viewModel = LoginViewModel();
  var localeProvider = LocaleProvider();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    return Scaffold(
      body: Center(
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
                  style: AppTextStyles.getBoldTextStyle(localeProvider.locale)
                      .copyWith(fontSize: 32),
                ),
                const SizedBox(height: 30),
                CommonTextField(
                  controller: _viewModel.emailController,
                  labelText: AppLocalizations.of(context)!.email,
                  isPassword: false,
                  hintText: "",
                  prefixIcon: Icons.email,
                ),
                // _buildTextField(
                //   controller: _viewModel.emailController,
                //   labelText: AppLocalizations.of(context)!.email,
                //   icon: Icons.email,
                //   isPassword: false,
                // ),
                const SizedBox(height: 20),
                CommonTextField(
                  controller: _viewModel.passwordController,
                  labelText: AppLocalizations.of(context)!.password,
                  isPassword: true,
                  hintText: "",
                  prefixIcon: Icons.lock,
                ),
                /*_buildTextField(
                  controller: _viewModel.passwordController,
                  labelText: AppLocalizations.of(context)!.password,
                  icon: Icons.lock,
                  isPassword: true,
                ),*/
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => _viewModel.login(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.login,
                      style: AppTextStyles.getBoldTextStyle(
                          localeProvider.locale)),
                ),
                StreamBuilder<String?>(
                  stream: _viewModel.errorStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text(
                        snapshot.data!,
                        style: const TextStyle(color: Colors.red),
                      );
                    }
                    return Container();
                  },
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    // Handle forgot password logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Forgot Password Clicked')),
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

/*void _login(BuildContext context) {
    final email = _emailController.text;
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    // Add your login logic here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logging in...')),
    );
  }*/
}
