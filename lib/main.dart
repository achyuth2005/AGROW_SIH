import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/video_splash_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/coordinate_entry_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/farmland_map_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/location_permission_screen.dart';
import 'screens/notification_permission_screen.dart';
import 'package:agroww_sih/screens/research_profile_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/intro_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Notifications
  final notificationService = NotificationService();
  await notificationService.initialize();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agrow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        textTheme: GoogleFonts.manropeTextTheme(),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingScreen(),
        '/login': (context) => const LoginScreen(),
        '/registration': (context) => const RegistrationScreen(),
        '/main-menu': (context) => const MainMenuScreen(),
        '/location-permission': (context) => const LocationPermissionScreen(),
        '/notification-permission': (context) => const NotificationPermissionScreen(),
        '/intro': (context) => const IntroScreen(),
        '/research-profile': (context) => const ResearchProfileScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/coordinate-entry': (context) => const CoordinateEntryScreen(),
        '/language-selection': (context) => const LanguageSelectionScreen(),
        '/farmland-map': (context) => const FarmlandMapScreen(),
      },
    );
  }
}