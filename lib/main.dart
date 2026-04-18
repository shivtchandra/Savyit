// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'providers/transaction_provider.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/storage_service.dart';
import 'services/engagement_notifications_service.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/shad_theme_bridge.dart';
import 'ui/savyit/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Android/iOS only — web has no DefaultFirebaseOptions in this repo.
  if (!kIsWeb) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await EngagementNotificationsService.init();
  }

  final isDone = await StorageService.isOnboardingDone();
  final authSkipped = await StorageService.isAuthSkipped();
  final isLoggedIn =
      kIsWeb ? false : FirebaseAuth.instance.currentUser != null;

  final provider = TransactionProvider();

  // Go to HomeScreen if onboarding is done AND (user is logged in OR skipped auth)
  final goHome = isDone && (isLoggedIn || authSkipped);

  if (goHome) {
    await provider.init();
  }

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: SavyitApp(startScreen: goHome ? const HomeScreen() : const OnboardingScreen()),
    ),
  );
}

class SavyitApp extends StatelessWidget {
  final Widget startScreen;
  const SavyitApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    final _ = context.select<TransactionProvider, String>((p) => p.themeMode);

    return ShadApp.custom(
      theme: moneyLensShadThemeData(),
      appBuilder: (context) => SavyitTheme(
        data: SavyitThemeData.defaults(),
        child: MaterialApp(
          title: 'Savyit',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: startScreen,
          builder: (context, child) =>
              ShadAppBuilder(child: child ?? const SizedBox.shrink()),
          localizationsDelegates: const [
            GlobalShadLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US')],
        ),
      ),
    );
  }
}
