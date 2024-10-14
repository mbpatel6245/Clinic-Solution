import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../data/datasources/user_model.dart';
import '../../../services/firestore_services.dart';
import '../../../services/local/secure_data_viewmodel.dart';

class HomeViewModel with ChangeNotifier {
 // HomeViewModel(SecureDataViewModel read);
  final SecureDataViewModel _secureDataViewModel;  // Inject SecureDataViewModel

 HomeViewModel(this._secureDataViewModel);  // Constructor to pass in SecureDataViewModel
 // bool _isUserLoaded = false;
  /*Future<void> loadUser(User user) async {
    if (_isUserLoaded) return;

    // await _secureDataViewModel.loadData();
    // print('Fetched secure data: ${_secureDataViewModel.storedData}');
    _isUserLoaded = true;
    notifyListeners();  // Notify UI to update the data
  }*/

}
