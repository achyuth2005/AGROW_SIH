import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/coordinate_entry_screen.dart';

void main() => runApp(MyApp());

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
