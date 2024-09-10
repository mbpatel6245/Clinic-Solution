import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/locale_key.dart';
import '../../core/utils/locale_provider.dart';
import '../../main.dart';
import '../themes/text_styles.dart';
import '../views/home/home_screen.dart';
import '../views/login/login_screen.dart';
import '../views/register/register_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

final GoRouter router = GoRouter(
  //initialLocation: LoginPage(),
  navigatorKey: navigatorKey,
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return LoginScreen();
      },
      routes: <RouteBase>[
        GoRoute(
          path: Strings.navRegister,
          builder: (BuildContext context, GoRouterState state) {
            return RegisterScreen();
          },
        ),
        GoRoute(
          path: Strings.navLogin,
          builder: (BuildContext context, GoRouterState state) {
            return LoginScreen();
          },
        ),
        GoRoute(
            path: Strings.navHome,
            builder: (BuildContext context, GoRouterState state) {
              final localeProvider = Provider.of<LocaleProvider>(context);
              final user = state.extra as User?;
              if (user == null) {
                // Handle the case where the object was not passed correctly
                // return ErrorScreen();
              }
              return HomeScreen(user: user!);
            })
      ],
    ),
  ],
);
