import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'view/about_view.dart';
import 'view/forgot_view.dart';
import 'view/login_view.dart';
import 'view/main_app_view.dart';
import 'view/md5_games_view.dart';
import 'view/register_view.dart';

void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Run the app with Device Preview for responsive testing
  runApp(
    ProviderScope(
      child: DevicePreview(
        enabled: false, // Set to true only during development
        builder: (context) => const MainApp(),
      ),
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
        // Specific console routes can be added dynamically through MaterialPageRoute or nested navigation
      },
      onGenerateRoute: (settings) {
        // Handle dynamic routes for consoles
        if (settings.name?.startsWith('console/') == true) {
          final parts = settings.name!.split('/');
          if (parts.length >= 3) {
            final consoleId = int.tryParse(parts[1]);
            final consoleName = parts[2];
            
            if (consoleId != null) {
              return MaterialPageRoute(
                builder: (context) => MD5GamesScreen(
                  consoleId: consoleId,
                  consoleName: consoleName,
                ),
              );
            }
          }
        }
        return null;
      },
    );
  }
}