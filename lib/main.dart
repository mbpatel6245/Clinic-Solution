import 'package:clinic_solution/services/firestore_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/platform/firebase_runtime.dart';
import 'core/design/app_theme.dart';
import 'core/design/clinic_brand.dart';
import 'core/utils/locale_provider.dart';
import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';
import 'ui/navigation/navigation.dart';
import 'services/session_controller.dart';
import 'services/sync_status_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClinicBootstrap());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ClinicBootstrap extends StatefulWidget {
  const ClinicBootstrap({super.key});

  @override
  State<ClinicBootstrap> createState() => _ClinicBootstrapState();
}

class _ClinicBootstrapState extends State<ClinicBootstrap> {
  late Future<void> _initialization = _initializeServices();

  Future<void> _initializeServices() async {
    if (!FirebaseRuntime.isSupported) {
      return;
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final firestore = FirebaseFirestore.instance;
    if (kIsWeb) {
      try {
        firestore.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          webPersistentTabManager: WebPersistentMultipleTabManager(),
        );
      } on FirebaseException catch (error) {
        // Private browsing and competing tabs can reject IndexedDB access.
        // Firestore still remains available in online-only mode.
        debugPrint('Firestore web persistence unavailable: ${error.code}');
      }
    } else if (FirebaseRuntime.supportsPersistentFirestoreCache) {
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  }

  void _retry() {
    setState(() {
      _initialization = _initializeServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapScreen();
        }

        if (snapshot.hasError) {
          return _BootstrapScreen(error: snapshot.error, onRetry: _retry);
        }

        if (!FirebaseRuntime.isSupported) {
          return const _UnsupportedLinuxApp();
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
            ChangeNotifierProvider(create: (_) => FirebaseFireStore()),
            ChangeNotifierProvider(create: (_) => SessionController()),
            ChangeNotifierProvider(create: (_) => SyncStatusService()),
          ],
          child: const MyApp(),
        );
      },
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen({this.error, this.onRetry});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          BrandedAppFrame(child: child ?? const SizedBox.shrink()),
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClinicLogo(size: 72),
                    SizedBox(height: 20),
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Starting Clinic Solution…'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 64),
                    const SizedBox(height: 16),
                    const Text('Unable to initialize online services.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _UnsupportedLinuxApp extends StatelessWidget {
  const _UnsupportedLinuxApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          BrandedAppFrame(child: child ?? const SizedBox.shrink()),
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Clinic Solution is installed successfully. Firebase services '
              'do not currently provide an official Linux Flutter SDK, so '
              'online authentication and synchronization are unavailable on '
              'Linux. Use the web application for the complete connected '
              'experience.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.select<LocaleProvider, Locale>(
      (value) => value.locale,
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          BrandedAppFrame(child: child ?? const SizedBox.shrink()),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.forLocale(locale),
      routerConfig: router,
    );
  }
}
