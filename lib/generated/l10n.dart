// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class AppLocalizations {
  AppLocalizations();

  static AppLocalizations? _current;

  static AppLocalizations get current {
    assert(_current != null,
        'No instance of AppLocalizations was loaded. Try to initialize the AppLocalizations delegate before accessing AppLocalizations.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<AppLocalizations> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = AppLocalizations();
      AppLocalizations._current = instance;

      return instance;
    });
  }

  static AppLocalizations of(BuildContext context) {
    final instance = AppLocalizations.maybeOf(context);
    assert(instance != null,
        'No instance of AppLocalizations present in the widget tree. Did you add AppLocalizations.delegate in localizationsDelegates?');
    return instance!;
  }

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// `My Flutter App`
  String get appTitle {
    return Intl.message(
      'My Flutter App',
      name: 'appTitle',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get login {
    return Intl.message(
      'Login',
      name: 'login',
      desc: '',
      args: [],
    );
  }

  /// `Logout`
  String get logout {
    return Intl.message(
      'Logout',
      name: 'logout',
      desc: '',
      args: [],
    );
  }

  /// `Welcome to the app!`
  String get welcomeMessage {
    return Intl.message(
      'Welcome to the app!',
      name: 'welcomeMessage',
      desc: '',
      args: [],
    );
  }

  /// `An error occurred.`
  String get errorMessage {
    return Intl.message(
      'An error occurred.',
      name: 'errorMessage',
      desc: '',
      args: [],
    );
  }

  /// `Email`
  String get email {
    return Intl.message(
      'Email',
      name: 'email',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get password {
    return Intl.message(
      'Password',
      name: 'password',
      desc: '',
      args: [],
    );
  }

  /// `Forgot Password?`
  String get forgotPassword {
    return Intl.message(
      'Forgot Password?',
      name: 'forgotPassword',
      desc: '',
      args: [],
    );
  }

  /// `New User Register`
  String get newUserRegister {
    return Intl.message(
      'New User Register',
      name: 'newUserRegister',
      desc: '',
      args: [],
    );
  }

  /// `Phone`
  String get phone {
    return Intl.message(
      'Phone',
      name: 'phone',
      desc: '',
      args: [],
    );
  }

  /// `Role`
  String get role {
    return Intl.message(
      'Role',
      name: 'role',
      desc: '',
      args: [],
    );
  }

  /// `Register`
  String get register {
    return Intl.message(
      'Register',
      name: 'register',
      desc: '',
      args: [],
    );
  }

  /// `Email is required`
  String get emailRequired {
    return Intl.message(
      'Email is required',
      name: 'emailRequired',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid email`
  String get validEmail {
    return Intl.message(
      'Enter a valid email',
      name: 'validEmail',
      desc: '',
      args: [],
    );
  }

  /// `Password is required`
  String get passwordRequired {
    return Intl.message(
      'Password is required',
      name: 'passwordRequired',
      desc: '',
      args: [],
    );
  }

  /// `Password must be at least 6 characters`
  String get validPassword {
    return Intl.message(
      'Password must be at least 6 characters',
      name: 'validPassword',
      desc: '',
      args: [],
    );
  }

  /// `Phone number is required`
  String get phoneRequired {
    return Intl.message(
      'Phone number is required',
      name: 'phoneRequired',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid 10-digit phone number`
  String get validPhone {
    return Intl.message(
      'Enter a valid 10-digit phone number',
      name: 'validPhone',
      desc: '',
      args: [],
    );
  }

  /// `Role is required`
  String get roleRequired {
    return Intl.message(
      'Role is required',
      name: 'roleRequired',
      desc: '',
      args: [],
    );
  }

  /// `Registered successfully!`
  String get registerSuccessfully {
    return Intl.message(
      'Registered successfully!',
      name: 'registerSuccessfully',
      desc: '',
      args: [],
    );
  }

  /// `Name`
  String get name {
    return Intl.message(
      'Name',
      name: 'name',
      desc: '',
      args: [],
    );
  }

  /// `Name required`
  String get nameRequired {
    return Intl.message(
      'Name required',
      name: 'nameRequired',
      desc: '',
      args: [],
    );
  }

  /// `User authentication failed. Please try again!`
  String get userAuthenticationFailed {
    return Intl.message(
      'User authentication failed. Please try again!',
      name: 'userAuthenticationFailed',
      desc: '',
      args: [],
    );
  }

  /// `Send Reset email`
  String get sendResetEmail {
    return Intl.message(
      'Send Reset email',
      name: 'sendResetEmail',
      desc: '',
      args: [],
    );
  }

  /// `Forgot Password`
  String get forgotPasswordLabel {
    return Intl.message(
      'Forgot Password',
      name: 'forgotPasswordLabel',
      desc: '',
      args: [],
    );
  }

  /// `New Prescription`
  String get newPrescription {
    return Intl.message(
      'New Prescription',
      name: 'newPrescription',
      desc: '',
      args: [],
    );
  }

  /// `Prescription list`
  String get prescriptionList {
    return Intl.message(
      'Prescription list',
      name: 'prescriptionList',
      desc: '',
      args: [],
    );
  }

  /// `Appointments`
  String get appointments {
    return Intl.message(
      'Appointments',
      name: 'appointments',
      desc: '',
      args: [],
    );
  }

  /// `Stock Inward`
  String get stockInward {
    return Intl.message(
      'Stock Inward',
      name: 'stockInward',
      desc: '',
      args: [],
    );
  }

  /// `Types of Stock`
  String get typeOfStock {
    return Intl.message(
      'Types of Stock',
      name: 'typeOfStock',
      desc: '',
      args: [],
    );
  }

  /// `Medicine`
  String get medicine {
    return Intl.message(
      'Medicine',
      name: 'medicine',
      desc: '',
      args: [],
    );
  }

  /// `Others`
  String get others {
    return Intl.message(
      'Others',
      name: 'others',
      desc: '',
      args: [],
    );
  }

  /// `Expiry Date`
  String get expiryDate {
    return Intl.message(
      'Expiry Date',
      name: 'expiryDate',
      desc: '',
      args: [],
    );
  }

  /// `Minimum Availability`
  String get minimumAvailability {
    return Intl.message(
      'Minimum Availability',
      name: 'minimumAvailability',
      desc: '',
      args: [],
    );
  }

  /// `Maximum Availability`
  String get maximumAvailability {
    return Intl.message(
      'Maximum Availability',
      name: 'maximumAvailability',
      desc: '',
      args: [],
    );
  }

  /// `Nearest duration Days`
  String get nearestDurationDays {
    return Intl.message(
      'Nearest duration Days',
      name: 'nearestDurationDays',
      desc: '',
      args: [],
    );
  }

  /// `Brand Name`
  String get brandName {
    return Intl.message(
      'Brand Name',
      name: 'brandName',
      desc: '',
      args: [],
    );
  }

  /// `Contains of Medicine`
  String get containsOfMedicine {
    return Intl.message(
      'Contains of Medicine',
      name: 'containsOfMedicine',
      desc: '',
      args: [],
    );
  }

  /// `Purchasing Person/Stockist Name`
  String get purchasingPersonOrStockist {
    return Intl.message(
      'Purchasing Person/Stockist Name',
      name: 'purchasingPersonOrStockist',
      desc: '',
      args: [],
    );
  }

  /// `Quantity`
  String get quantity {
    return Intl.message(
      'Quantity',
      name: 'quantity',
      desc: '',
      args: [],
    );
  }

  /// `Tablets/Stripes`
  String get tabletsOrStrips {
    return Intl.message(
      'Tablets/Stripes',
      name: 'tabletsOrStrips',
      desc: '',
      args: [],
    );
  }

  /// `Box`
  String get box {
    return Intl.message(
      'Box',
      name: 'box',
      desc: '',
      args: [],
    );
  }

  /// `Date Of Purchase`
  String get dateOfPurchase {
    return Intl.message(
      'Date Of Purchase',
      name: 'dateOfPurchase',
      desc: '',
      args: [],
    );
  }

  /// `Power Of Size`
  String get powerOfSize {
    return Intl.message(
      'Power Of Size',
      name: 'powerOfSize',
      desc: '',
      args: [],
    );
  }

  /// `Form Type (Syrup/Tablets/Others)`
  String get formType {
    return Intl.message(
      'Form Type (Syrup/Tablets/Others)',
      name: 'formType',
      desc: '',
      args: [],
    );
  }

  /// `Manufacturer Name`
  String get manufacturerName {
    return Intl.message(
      'Manufacturer Name',
      name: 'manufacturerName',
      desc: '',
      args: [],
    );
  }

  /// `Visibility (Show/Hide)`
  String get visibilityShowOrHide {
    return Intl.message(
      'Visibility (Show/Hide)',
      name: 'visibilityShowOrHide',
      desc: '',
      args: [],
    );
  }

  /// `Short Name`
  String get shortName {
    return Intl.message(
      'Short Name',
      name: 'shortName',
      desc: '',
      args: [],
    );
  }

  /// `Color of content`
  String get colorOfContent {
    return Intl.message(
      'Color of content',
      name: 'colorOfContent',
      desc: '',
      args: [],
    );
  }

  /// `Bill No./Invoice No.`
  String get billNo {
    return Intl.message(
      'Bill No./Invoice No.',
      name: 'billNo',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'gu'),
      Locale.fromSubtags(languageCode: 'hi'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
