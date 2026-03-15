import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/theme_service.dart';
import 'services/stripe_service.dart';
import 'screens/splash_screen.dart';
import 'widgets/biometric_wrapper.dart';

//import 'screens/user/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Stripe
  try {
    await StripeService.init();
    print('✅ Stripe initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize Stripe: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          // Set system UI overlay style based on theme
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  themeService.isDarkMode ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness:
                  themeService.isDarkMode ? Brightness.light : Brightness.dark,
            ),
          );

          return MaterialApp(
            title: 'SHIFFTERS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeService.themeMode,
            home: BiometricWrapper(
              child: const SplashScreen(),
            ),
          );
        },
      ),
    );
  }
}
