import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/coordinate_entry_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://lcsknocxwjmfceahzfhl.supabase.co',            // Settings → API → Project URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxjc2tub2N4d2ptZmNlYWh6ZmhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg2MTc2MzcsImV4cCI6MjA3NDE5MzYzN30.pAhHhBkCDWxryVIIowInhqSfIrn7G_bwJfKA6ST7nLM',   // Settings → API → anon (public) key
  );
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
        '/': (context) => SplashScreen(),
        '/main-menu': (context) => MainMenuScreen(),
        '/coordinate-entry': (context) => CoordinateEntryScreen(),
      },
    );
  }
}
