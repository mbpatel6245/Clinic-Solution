import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/locale_key.dart';
import '../../main.dart';
import '../views/forgot/forgot_password_screen.dart';
import '../views/home/home_screen.dart';
import '../views/home/appointment/tab_appointments.dart';
import '../views/login/login_screen.dart';
import '../views/register/register_screen.dart';
import 'initial_location.dart';

NoTransitionPage<void> _page(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

final GoRouter router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: initialClinicLocation(web: kIsWeb, uri: Uri.base),
  overridePlatformDefaultLocation: kIsWeb,
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final isAuthenticationRoute = <String>{
      '/${Constants.navLogin}',
      '/staff',
      '/${Constants.navRegister}',
      '/${Constants.navForgot}',
      '/${Constants.navAppointment}',
    }.contains(state.matchedLocation);

    if (!isLoggedIn && !isAuthenticationRoute) {
      return '/${Constants.navLogin}';
    }

    if (isLoggedIn &&
        ['/${Constants.navLogin}', '/staff'].contains(state.matchedLocation)) {
      return '/${Constants.navHome}';
    }

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/staff',
      pageBuilder: (context, state) =>
          _page(state, LoginScreen(staffPortal: true)),
    ),
    GoRoute(
      path: '/${Constants.navLogin}',
      pageBuilder: (context, state) => _page(state, LoginScreen()),
    ),
    GoRoute(
      path: '/${Constants.navRegister}',
      pageBuilder: (context, state) => _page(state, RegisterScreen()),
    ),
    GoRoute(
      path: '/${Constants.navForgot}',
      pageBuilder: (context, state) => _page(state, ForgotPasswordScreen()),
    ),
    GoRoute(
      path: '/${Constants.navHome}',
      pageBuilder: (context, state) => _page(state, HomeScreen()),
    ),
    GoRoute(
      path: '/${Constants.navAppointment}',
      pageBuilder: (context, state) =>
          _page(state, const PatientAppointmentScreen()),
    ),
  ],
);
