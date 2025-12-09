import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/localization_service.dart';
import 'services/user_role_provider.dart';
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
import 'screens/analytics_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';

import 'screens/home_screen.dart';
import 'screens/farmers_home_screen.dart';
import 'screens/locate_farmland_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Guest ID
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey('guest_user_id')) {
    final guestId = const Uuid().v4();
    await prefs.setString('guest_user_id', guestId);
    debugPrint("Generated new Guest ID: $guestId");
  } else {
    debugPrint("Existing Guest ID: ${prefs.getString('guest_user_id')}");
  }

  // Initialize Notifications
  final notificationService = NotificationService();
  await notificationService.initialize();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
        ChangeNotifierProvider(create: (_) => UserRoleProvider()..loadRole()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to language changes to rebuild app
    context.watch<LocalizationProvider>();
    
    return MaterialApp(
      title: 'Agrow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF0D986A),
          onPrimary: Colors.white,
          secondary: Color(0xFF0F3C33),
          onSecondary: Colors.white,
          tertiary: Color(0xFFC6F68D),
          onTertiary: Color(0xFF0F3C33),
          error: Color(0xFFBA1A1A),
          onError: Colors.white,
          surface: Color(0xFFE1EFEF),
          onSurface: Color(0xFF0F3C33),
        ),
        scaffoldBackgroundColor: const Color(0xFFE1EFEF),
        textTheme: GoogleFonts.manropeTextTheme().apply(
          bodyColor: const Color(0xFF0F3C33),
          displayColor: const Color(0xFF0F3C33),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D986A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D986A),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0D986A), width: 1.5),
          ),
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 16),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingScreen(),
        '/login': (context) => const LoginScreen(),
        '/registration': (context) => const RegistrationScreen(),
        '/main-menu': (context) => const HomeScreen(),
        '/main-menu-list': (context) => const MainMenuScreen(),
        '/location-permission': (context) => const LocationPermissionScreen(),
        '/notification-permission': (context) => const NotificationPermissionScreen(),
        '/intro': (context) => const IntroScreen(),
        '/research-profile': (context) => const ResearchProfileScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/coordinate-entry': (context) => const CoordinateEntryScreen(),
        '/language-selection': (context) => const LanguageSelectionScreen(),
        '/farmland-map': (context) => const FarmlandMapScreen(),
        '/analytics': (context) => const AnalyticsScreen(),
        '/farmers-home': (context) => const FarmersHomeScreen(),
        '/locate-farmland': (context) => const LocateFarmlandScreen(),
      },
    );
  }
}