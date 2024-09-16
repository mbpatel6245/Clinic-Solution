import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/locale_key.dart';
import 'home_viewmodel.dart';

class HomeScreen extends StatelessWidget {
  final User user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Home Screen'),
          actions: [
            IconButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                context.go('/${Strings.navLogin}');
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Center(
          child: Consumer<HomeViewModel>(
            builder: (context, viewModel, child) {
              return FutureBuilder(
                future: viewModel.loadUser(user), // Call loadUser as a future
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator(); // Show loading indicator
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else {
                    return Text(
                      'Welcome, ${viewModel.loggedInUserData?.name} '
                      '(${viewModel.loggedInUserData?.email})',
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
