import 'package:clinic_solution/ui/widgets/common_text.dart';
import 'package:flutter/material.dart';
import 'package:clinic_solution/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/locale_provider.dart';
import '../../../core/utils/validator.dart';
import '../../themes/text_styles.dart';
import '../../widgets/common_button.dart';
import '../../widgets/common_textfield.dart';
import 'forgot_password_viewmodel.dart';

class ForgotPasswordScreen extends StatelessWidget {
  final ForgotPasswordViewModel viewModel = ForgotPasswordViewModel();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    var localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return ChangeNotifierProvider(
      create: (_) => ForgotPasswordViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: CommonText(
            text: AppLocalizations.of(context)!.forgotPasswordLabel,
            style: AppTextStyles.getBoldTextStyle(localeProvider.locale),
          ),
        ),
        body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Consumer<ForgotPasswordViewModel>(
                  builder: (context, viewModel, child) {
                return Form(
                  key: _formKey,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // TextFormField(
                        //     controller: _emailController,
                        //     decoration: InputDecoration(labelText: 'Email'),
                        //     keyboardType: TextInputType.emailAddress,
                        //     validator: Validator().validateEmail),
                        CommonTextField(
                          controller: _emailController,
                          labelText: AppLocalizations.of(context)!.email,
                          isPassword: false,
                          hintText: "",
                          prefixIcon: Icons.email,
                          validator: Validator().validateEmail,
                        ),
                        SizedBox(height: 20),
                        if (viewModel.isLoading)
                          CircularProgressIndicator()
                        else
                          CommonButton(
                            text: AppLocalizations.of(context)!.sendResetEmail,
                            onPressed: () {
                              if (viewModel.validateForm(_formKey)) {
                                viewModel.sendPasswordResetEmail(
                                    _emailController.text.trim());
                              }
                            },
                          ),
                        if (viewModel.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: CommonText(
                              text:viewModel.errorMessage!,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            )),
      ),
    );
  }
}
