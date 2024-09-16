import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../data/datasources/user_model.dart';
import '../../../services/firestore_services.dart';

class HomeViewModel with ChangeNotifier {
  UserModel? loggedInUserData;
  final FirebaseFireStore _fireStoreService = FirebaseFireStore();

  Future<void> loadUser(User user) async {
    loggedInUserData = await _fireStoreService.fetchUser(user.uid);
    print('loggedInUserData ${loggedInUserData?.email}');
  }
}
