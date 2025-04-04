import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:retroachievements_organizer/controller/login_controller.dart';
import 'package:retroachievements_organizer/view/md_games_view.dart';

import 'view/about_view.dart';
import 'view/forgot_view.dart';    // Import the forgot password view
import 'view/login_view.dart';
import 'view/main_app_view.dart';
import 'view/register_view.dart';  // Import the register view

final g = GetIt.instance;

void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Register controllers using GetIt for dependency injection
  g.registerSingleton<LoginController>(LoginController());

  // Run the app with Device Preview for responsive testing
  runApp(
    DevicePreview(
      enabled: false, // Set to true only during development
      builder: (context) => const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RetroAchievements Library Organizer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFFFD700),
          secondary: const Color(0xFFFFD700),
          surface: const Color(0xFF333333),
        ),
        scaffoldBackgroundColor: const Color(0xFF262626),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      // Device preview configuration
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      // Routes
      initialRoute: 'login',
routes: {
  'login': (context) => const LoginScreen(),
  'home': (context) => const MainAppScreen(),
  'about': (context) => const AboutScreen(),
  'register': (context) => const RegisterScreen(),      
  'forgot_password': (context) => const ForgotPasswordScreen(),
  'mega_drive': (context) => const MegaDriveGamesScreen(), // Keep this route for any direct navigation
},
    );
  }
}