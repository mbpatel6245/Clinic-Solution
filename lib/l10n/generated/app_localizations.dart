import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinical Solution'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the app!'**
  String get welcomeMessage;

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'An error occurred.'**
  String get errorMessage;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @newUserRegister.
  ///
  /// In en, this message translates to:
  /// **'New User Register'**
  String get newUserRegister;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @validEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validEmail;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @validPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get validPassword;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneRequired;

  /// No description provided for @validPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit phone number'**
  String get validPhone;

  /// No description provided for @roleRequired.
  ///
  /// In en, this message translates to:
  /// **'Role is required'**
  String get roleRequired;

  /// No description provided for @registerSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Registered successfully!'**
  String get registerSuccessfully;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name required'**
  String get nameRequired;

  /// No description provided for @userAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'User authentication failed. Please try again!'**
  String get userAuthenticationFailed;

  /// No description provided for @sendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Reset email'**
  String get sendResetEmail;

  /// No description provided for @forgotPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordLabel;

  /// No description provided for @newPrescription.
  ///
  /// In en, this message translates to:
  /// **'New Prescription'**
  String get newPrescription;

  /// No description provided for @prescriptionList.
  ///
  /// In en, this message translates to:
  /// **'Prescription list'**
  String get prescriptionList;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @stockInward.
  ///
  /// In en, this message translates to:
  /// **'Stock Inward'**
  String get stockInward;

  /// No description provided for @typeOfStock.
  ///
  /// In en, this message translates to:
  /// **'Types of Stock'**
  String get typeOfStock;

  /// No description provided for @medicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get medicine;

  /// No description provided for @others.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get others;

  /// No description provided for @expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get expiryDate;

  /// No description provided for @minimumAvailability.
  ///
  /// In en, this message translates to:
  /// **'Minimum Availability'**
  String get minimumAvailability;

  /// No description provided for @maximumAvailability.
  ///
  /// In en, this message translates to:
  /// **'Maximum Availability'**
  String get maximumAvailability;

  /// No description provided for @nearestDurationDays.
  ///
  /// In en, this message translates to:
  /// **'Nearest duration Days'**
  String get nearestDurationDays;

  /// No description provided for @brandName.
  ///
  /// In en, this message translates to:
  /// **'Brand Name'**
  String get brandName;

  /// No description provided for @containsOfMedicine.
  ///
  /// In en, this message translates to:
  /// **'Contains of Medicine'**
  String get containsOfMedicine;

  /// No description provided for @purchasingPersonOrStockist.
  ///
  /// In en, this message translates to:
  /// **'Purchasing Person/Stockist Name'**
  String get purchasingPersonOrStockist;

  /// No description provided for @purchasingPerson.
  ///
  /// In en, this message translates to:
  /// **'Purchasing Person'**
  String get purchasingPerson;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @tabletsOrStrips.
  ///
  /// In en, this message translates to:
  /// **'Tablets/Stripes'**
  String get tabletsOrStrips;

  /// No description provided for @box.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get box;

  /// No description provided for @dateOfPurchase.
  ///
  /// In en, this message translates to:
  /// **'Date Of Purchase'**
  String get dateOfPurchase;

  /// No description provided for @powerOfSize.
  ///
  /// In en, this message translates to:
  /// **'Power Of Size'**
  String get powerOfSize;

  /// No description provided for @formType.
  ///
  /// In en, this message translates to:
  /// **'Form Type (Syrup/Tablets/Others)'**
  String get formType;

  /// No description provided for @manufacturerName.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer Name'**
  String get manufacturerName;

  /// No description provided for @visibilityShowOrHide.
  ///
  /// In en, this message translates to:
  /// **'Visibility (Show/Hide)'**
  String get visibilityShowOrHide;

  /// No description provided for @shortName.
  ///
  /// In en, this message translates to:
  /// **'Short Name'**
  String get shortName;

  /// No description provided for @colorOfContent.
  ///
  /// In en, this message translates to:
  /// **'Color of content'**
  String get colorOfContent;

  /// No description provided for @billNo.
  ///
  /// In en, this message translates to:
  /// **'Bill No./Invoice No.'**
  String get billNo;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @stockSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Stock saved Successfully!'**
  String get stockSavedSuccessfully;

  /// No description provided for @contentName.
  ///
  /// In en, this message translates to:
  /// **'Content name'**
  String get contentName;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @addMoreContent.
  ///
  /// In en, this message translates to:
  /// **'Add More Content'**
  String get addMoreContent;

  /// No description provided for @addStockOfData.
  ///
  /// In en, this message translates to:
  /// **'Add Stock of Data'**
  String get addStockOfData;

  /// No description provided for @updateStockOfData.
  ///
  /// In en, this message translates to:
  /// **'Update Stock of Data'**
  String get updateStockOfData;

  /// No description provided for @listOfStockData.
  ///
  /// In en, this message translates to:
  /// **'List of Stock Data'**
  String get listOfStockData;

  /// No description provided for @stockDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Stock deleted Successfully!'**
  String get stockDeletedSuccessfully;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @stockUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Stock updated Successfully!'**
  String get stockUpdatedSuccessfully;

  /// No description provided for @searchStock.
  ///
  /// In en, this message translates to:
  /// **'Search stock'**
  String get searchStock;

  /// No description provided for @rateOfPurchase.
  ///
  /// In en, this message translates to:
  /// **'Rate of purchase'**
  String get rateOfPurchase;

  /// No description provided for @mrp.
  ///
  /// In en, this message translates to:
  /// **'MRP'**
  String get mrp;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Clinic Dashboard'**
  String get dashboard;

  /// No description provided for @inventoryOverview.
  ///
  /// In en, this message translates to:
  /// **'Inventory overview'**
  String get inventoryOverview;

  /// No description provided for @createStockEntry.
  ///
  /// In en, this message translates to:
  /// **'Create stock entry'**
  String get createStockEntry;

  /// No description provided for @editStockEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit stock entry'**
  String get editStockEntry;

  /// No description provided for @allStock.
  ///
  /// In en, this message translates to:
  /// **'All stock'**
  String get allStock;

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get lowStock;

  /// No description provided for @expiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get expiringSoon;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @stockReceived.
  ///
  /// In en, this message translates to:
  /// **'Stock received'**
  String get stockReceived;

  /// No description provided for @stockUsed.
  ///
  /// In en, this message translates to:
  /// **'Stock used'**
  String get stockUsed;

  /// No description provided for @invoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get invoiceNumber;

  /// No description provided for @batchNumber.
  ///
  /// In en, this message translates to:
  /// **'Batch number'**
  String get batchNumber;

  /// No description provided for @supplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier / stockist'**
  String get supplier;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @purchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase date'**
  String get purchaseDate;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this record?'**
  String get confirmDelete;

  /// No description provided for @adjustStock.
  ///
  /// In en, this message translates to:
  /// **'Adjust stock'**
  String get adjustStock;

  /// No description provided for @addStock.
  ///
  /// In en, this message translates to:
  /// **'Add stock'**
  String get addStock;

  /// No description provided for @useStock.
  ///
  /// In en, this message translates to:
  /// **'Use stock'**
  String get useStock;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @noStock.
  ///
  /// In en, this message translates to:
  /// **'No stock entries found'**
  String get noStock;

  /// No description provided for @patientDetails.
  ///
  /// In en, this message translates to:
  /// **'Patient details'**
  String get patientDetails;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @middleName.
  ///
  /// In en, this message translates to:
  /// **'Middle name'**
  String get middleName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @clinicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Clinical details'**
  String get clinicalDetails;

  /// No description provided for @diagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get diagnosis;

  /// No description provided for @chiefComplaints.
  ///
  /// In en, this message translates to:
  /// **'Chief complaints'**
  String get chiefComplaints;

  /// No description provided for @vitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get vitals;

  /// No description provided for @investigation.
  ///
  /// In en, this message translates to:
  /// **'Investigation'**
  String get investigation;

  /// No description provided for @advice.
  ///
  /// In en, this message translates to:
  /// **'Advice'**
  String get advice;

  /// No description provided for @visitDate.
  ///
  /// In en, this message translates to:
  /// **'Visit date'**
  String get visitDate;

  /// No description provided for @followUpDate.
  ///
  /// In en, this message translates to:
  /// **'Follow-up date'**
  String get followUpDate;

  /// No description provided for @medicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get medicines;

  /// No description provided for @dosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get dosage;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @instructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// No description provided for @addMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get addMedicine;

  /// No description provided for @savePrescription.
  ///
  /// In en, this message translates to:
  /// **'Save prescription'**
  String get savePrescription;

  /// No description provided for @prescriptionSaved.
  ///
  /// In en, this message translates to:
  /// **'Prescription saved successfully'**
  String get prescriptionSaved;

  /// No description provided for @noPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'No prescriptions found'**
  String get noPrescriptions;

  /// No description provided for @searchPatient.
  ///
  /// In en, this message translates to:
  /// **'Search by patient name, phone, diagnosis or address'**
  String get searchPatient;

  /// No description provided for @allStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allStatuses;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @newVisit.
  ///
  /// In en, this message translates to:
  /// **'New visit'**
  String get newVisit;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book appointment'**
  String get bookAppointment;

  /// No description provided for @appointmentDate.
  ///
  /// In en, this message translates to:
  /// **'Appointment date'**
  String get appointmentDate;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason for visit'**
  String get reason;

  /// No description provided for @patientName.
  ///
  /// In en, this message translates to:
  /// **'Patient name'**
  String get patientName;

  /// No description provided for @appointmentBooked.
  ///
  /// In en, this message translates to:
  /// **'Appointment booked successfully'**
  String get appointmentBooked;

  /// No description provided for @noAppointments.
  ///
  /// In en, this message translates to:
  /// **'No appointments found'**
  String get noAppointments;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @booked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get booked;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @markComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get markComplete;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get invalidNumber;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No matching records'**
  String get noResults;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @finance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get finance;

  /// No description provided for @team.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get team;

  /// No description provided for @clinicOverview.
  ///
  /// In en, this message translates to:
  /// **'Clinic overview'**
  String get clinicOverview;

  /// No description provided for @todaysAppointments.
  ///
  /// In en, this message translates to:
  /// **'Today\'s appointments'**
  String get todaysAppointments;

  /// No description provided for @monthlyVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits this month'**
  String get monthlyVisits;

  /// No description provided for @totalPatients.
  ///
  /// In en, this message translates to:
  /// **'Total patients'**
  String get totalPatients;

  /// No description provided for @financialPerformance.
  ///
  /// In en, this message translates to:
  /// **'Financial performance'**
  String get financialPerformance;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @netBalance.
  ///
  /// In en, this message translates to:
  /// **'Net balance'**
  String get netBalance;

  /// No description provided for @incomeAndExpense.
  ///
  /// In en, this message translates to:
  /// **'Income & expense'**
  String get incomeAndExpense;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get addTransaction;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions found'**
  String get noTransactions;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @teamAndRoles.
  ///
  /// In en, this message translates to:
  /// **'Team & roles'**
  String get teamAndRoles;

  /// No description provided for @roleHelp.
  ///
  /// In en, this message translates to:
  /// **'Assign access based on each team member\'s responsibility.'**
  String get roleHelp;

  /// No description provided for @noTeamMembers.
  ///
  /// In en, this message translates to:
  /// **'No team members found'**
  String get noTeamMembers;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Working offline'**
  String get offlineMode;

  /// No description provided for @changesWaitingToSync.
  ///
  /// In en, this message translates to:
  /// **'Changes are waiting to sync'**
  String get changesWaitingToSync;

  /// No description provided for @allChangesSynced.
  ///
  /// In en, this message translates to:
  /// **'All changes synced'**
  String get allChangesSynced;

  /// No description provided for @checkingConnection.
  ///
  /// In en, this message translates to:
  /// **'Checking connection'**
  String get checkingConnection;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'gu', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
