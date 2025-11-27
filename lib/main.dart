import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/video_splash_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/coordinate_entry_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agri Analytics Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF0D986A),
        scaffoldBackgroundColor: Color(0xFF0D986A),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => VideoSplashScreen(),
        '/main-menu': (context) => MainMenuScreen(),
        '/coordinate-entry': (context) => CoordinateEntryScreen(),
        '/registration': (context) => RegistrationScreen(),
        '/landing': (context) => LandingScreen(),
        '/login': (context) => LoginScreen(),
      },
    );
  }
}