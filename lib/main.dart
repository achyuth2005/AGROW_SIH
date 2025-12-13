/// ============================================================================
/// FILE: main.dart
/// ============================================================================
/// PURPOSE: This is the entry point of the AGROW Flutter application.
///          It initializes all required services (Firebase, Supabase, etc.)
///          and sets up the app's theme, routes, and state management.
/// 
/// WHAT THIS FILE DOES:
///   1. Initializes Firebase for authentication and push notifications
///   2. Loads environment variables from .env file
///   3. Connects to Supabase database for data storage
///   4. Creates a unique guest ID for non-logged-in users
///   5. Sets up push notification handling
///   6. Configures the app's visual theme (colors, fonts, buttons)
///   7. Defines all navigation routes (screens the user can visit)
/// 
/// DEPENDENCIES:
///   - firebase_core: Connects to Firebase services
///   - flutter_dotenv: Reads secret keys from .env file
///   - provider: Manages app-wide state (language, user role)
///   - supabase_flutter: Database and authentication
///   - google_fonts: Custom typography (Manrope font)
///   - firebase_messaging: Push notification support
/// ============================================================================

// =============================================================================
// IMPORTS - External packages and internal files needed by this file
// =============================================================================

// Flutter's core UI framework - provides widgets like Text, Button, Container
import 'package:flutter/material.dart';

// Firebase initialization - must be called before using any Firebase service
import 'package:firebase_core/firebase_core.dart';

// Loads environment variables from .env file (API keys, URLs)
import 'package:flutter_dotenv/flutter_dotenv.dart';

// State management - allows sharing data across the entire app
import 'package:provider/provider.dart';

// Internal service for multi-language support (Hindi, Tamil, etc.)
import 'services/localization_service.dart';

// Internal service for managing user roles (farmer vs researcher)
import 'services/user_role_provider.dart';

// Screen imports - organized by feature folder
// =============================================================================
// AUTH - Authentication screens
import 'screens/auth/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/registration_screen.dart';

// ONBOARDING - First-time user experience
import 'screens/onboarding/video_splash_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/intro_screen.dart';
import 'screens/onboarding/research_profile_screen.dart';
import 'screens/onboarding/location_permission_screen.dart';
import 'screens/onboarding/notification_permission_screen.dart';

// HOME - Main dashboards
import 'screens/home/home_screen.dart';
import 'screens/home/farmers_home_screen.dart';
import 'screens/home/main_menu_screen.dart';

// ANALYTICS - Data visualization
import 'screens/analytics/analytics_screen.dart';

// FIELD - Farm management
import 'screens/field/coordinate_entry_screen.dart';
import 'screens/field/farmland_map_screen.dart';
import 'screens/field/locate_farmland_screen.dart';

// SETTINGS - User preferences
import 'screens/settings/language_selection_screen.dart';
import 'screens/settings/profile_screen.dart';

// =============================================================================
// CORE PACKAGES
// =============================================================================
// Supabase - our backend database (like a spreadsheet in the cloud)
import 'package:supabase_flutter/supabase_flutter.dart';

// Google Fonts - provides beautiful typography
import 'package:google_fonts/google_fonts.dart';

// Firebase Messaging - for push notifications ("Your crop needs water!")
import 'package:firebase_messaging/firebase_messaging.dart';

// Internal service for handling push notifications
import 'services/notification_service.dart';

// SharedPreferences - stores simple data locally (like a mini database on phone)
import 'package:shared_preferences/shared_preferences.dart';

// UUID - generates unique IDs (like a fingerprint for each user/session)
import 'package:uuid/uuid.dart';

// Background refresh service for time series cache
import 'services/background_refresh_service.dart';

// =============================================================================
// MAIN FUNCTION - The app starts here!
// =============================================================================
/// The main() function is called when the app launches.
/// It's like pressing the "power on" button for the app.
/// 
/// This function is ASYNC because it needs to wait for several services
/// to initialize before the app can run (database connection, Firebase, etc.)
Future<void> main() async {
  // ---------------------------------------------------------------------------
  // STEP 1: Initialize Flutter's core systems
  // ---------------------------------------------------------------------------
  // This MUST be called first before any other initialization.
  // It ensures Flutter is ready to run native platform code.
  WidgetsFlutterBinding.ensureInitialized();
  
  // ---------------------------------------------------------------------------
  // STEP 2: Initialize Firebase
  // ---------------------------------------------------------------------------
  // Firebase provides: user authentication, push notifications, analytics.
  // This connects our app to our Firebase project in the cloud.
  await Firebase.initializeApp();
  
  // ---------------------------------------------------------------------------
  // STEP 3: Load Environment Variables
  // ---------------------------------------------------------------------------
  // The .env file contains secret keys and URLs that shouldn't be in code.
  // Example contents: SUPABASE_URL=https://..., GOOGLE_MAPS_API_KEY=...
  await dotenv.load(fileName: ".env");
  
  // ---------------------------------------------------------------------------
  // STEP 4: Initialize Supabase (Our Database)
  // ---------------------------------------------------------------------------
  // Supabase is our backend database where we store:
  //   - User profiles (name, phone, farm details)
  //   - Farm coordinates (GPS locations)
  //   - Analysis results (soil health, crop status)
  // 
  // We read the URL and key from the .env file for security.
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,      // The database server address
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!, // Public access key
  );

  // ---------------------------------------------------------------------------
  // STEP 5: Create or Load Guest User ID
  // ---------------------------------------------------------------------------
  // Even if a user doesn't log in, we need a way to identify them.
  // This creates a unique ID that persists across app restarts.
  // 
  // WHY: So we can save their preferences and farm data locally.
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey('guest_user_id')) {
    // No guest ID exists - create a new one
    final guestId = const Uuid().v4(); // Generates: "550e8400-e29b-41d4-a716-446655440000"
    await prefs.setString('guest_user_id', guestId);
    debugPrint("Generated new Guest ID: $guestId");
  } else {
    // Guest ID already exists - reuse it
    debugPrint("Existing Guest ID: ${prefs.getString('guest_user_id')}");
  }

  // ---------------------------------------------------------------------------
  // STEP 6: Initialize Push Notifications
  // ---------------------------------------------------------------------------
  // This sets up the ability to receive alerts like:
  //   - "Warning: Low soil moisture detected!"
  //   - "New satellite imagery available for your farm"
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Handle notifications that arrive when the app is closed/background
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // ---------------------------------------------------------------------------
  // STEP 7: Initialize Background Refresh Service
  // ---------------------------------------------------------------------------
  // This refreshes stale time series cache for ALL fields every 5 days.
  // Runs in background, doesn't block app startup.
  // Existing cache is preserved until new data is fully fetched.
  BackgroundRefreshService.init(); // Don't await - runs in background

  // ---------------------------------------------------------------------------
  // STEP 8: Launch the App!
  // ---------------------------------------------------------------------------
  // runApp() takes our root widget and displays it on screen.
  // 
  // MultiProvider wraps the app with state management:
  //   - LocalizationProvider: Manages current language (English, Hindi, etc.)
  //   - UserRoleProvider: Manages user type (Farmer or Researcher)
  runApp(
    MultiProvider(
      providers: [
        // Language state - rebuilds UI when user switches language
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
        
        // User role state - determines which screens/features are shown
        // ..loadRole() immediately loads the saved role from storage
        ChangeNotifierProvider(create: (_) => UserRoleProvider()..loadRole()),
      ],
      child: const MyApp(), // Our main app widget
    ),
  );
}

// =============================================================================
// MyApp CLASS - The root widget of our application
// =============================================================================
/// MyApp is a StatelessWidget because the app's basic structure doesn't change.
/// It configures:
///   - The app's visual theme (colors, fonts, button styles)
///   - All navigation routes (which URL goes to which screen)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // -------------------------------------------------------------------------
    // Listen for Language Changes
    // -------------------------------------------------------------------------
    // When the user changes language, this causes the entire app to rebuild
    // with the new translations.
    context.watch<LocalizationProvider>();
    
    // -------------------------------------------------------------------------
    // MaterialApp - The foundation of our app
    // -------------------------------------------------------------------------
    // MaterialApp provides:
    //   - Navigation (moving between screens)
    //   - Theme (colors, fonts)
    //   - Localization infrastructure
    return MaterialApp(
      title: 'Agrow', // Shown in task switcher on Android
      debugShowCheckedModeBanner: false, // Hides the "DEBUG" banner in corner
      
      // -----------------------------------------------------------------------
      // THEME CONFIGURATION - Colors and Styles
      // -----------------------------------------------------------------------
      // ThemeData controls how EVERY widget looks by default.
      // This creates a consistent visual experience.
      theme: ThemeData(
        useMaterial3: true, // Use Google's latest design system
        
        // ---------------------------------------------------------------------
        // Color Scheme - The app's color palette
        // ---------------------------------------------------------------------
        // These colors are used throughout the app automatically:
        //   - primary: Main brand color (green for agriculture)
        //   - secondary: Supporting color (dark green)
        //   - tertiary: Accent color (light lime green)
        //   - surface: Background color for cards and sheets
        colorScheme: const ColorScheme(
          brightness: Brightness.light,      // Light theme (not dark mode)
          primary: Color(0xFF0D986A),        // Vibrant green - buttons, links
          onPrimary: Colors.white,           // Text color on primary
          secondary: Color(0xFF0F3C33),      // Dark forest green - headers
          onSecondary: Colors.white,         // Text color on secondary
          tertiary: Color(0xFFC6F68D),       // Lime green - highlights
          onTertiary: Color(0xFF0F3C33),     // Text color on tertiary
          error: Color(0xFFBA1A1A),          // Red - error states
          onError: Colors.white,             // Text color on errors
          surface: Color(0xFFE1EFEF),        // Light teal - backgrounds
          onSurface: Color(0xFF0F3C33),      // Text color on surface
        ),
        
        // Default background color for all screens
        scaffoldBackgroundColor: const Color(0xFFE1EFEF),
        
        // ---------------------------------------------------------------------
        // Typography - Font styles for text
        // ---------------------------------------------------------------------
        // Manrope is a clean, modern font that's easy to read.
        // We apply our color scheme to the text theme.
        textTheme: GoogleFonts.manropeTextTheme().apply(
          bodyColor: const Color(0xFF0F3C33),    // Regular text color
          displayColor: const Color(0xFF0F3C33), // Headline color
        ),
        
        // ---------------------------------------------------------------------
        // AppBar Style - The top navigation bar
        // ---------------------------------------------------------------------
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D986A), // Green background
          foregroundColor: Colors.white,      // White text and icons
          elevation: 0,                       // No shadow (flat design)
          centerTitle: true,                  // Title centered (iOS style)
        ),
        
        // ---------------------------------------------------------------------
        // Button Style - How ElevatedButtons look
        // ---------------------------------------------------------------------
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D986A), // Green background
            foregroundColor: Colors.white,            // White text
            elevation: 0,                             // No shadow
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Rounded corners
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600, // Semi-bold
              fontSize: 16,
            ),
          ),
        ),
        
        // ---------------------------------------------------------------------
        // Input Field Style - How TextFields look
        // ---------------------------------------------------------------------
        inputDecorationTheme: InputDecorationTheme(
          filled: true,                   // Has a background color
          fillColor: Colors.white,        // White background
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          // Default border (when not focused)
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // No visible border
          ),
          // Border when enabled but not focused
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          // Border when user is typing
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0D986A), width: 1.5),
          ),
          // Placeholder text style
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
        
        // ---------------------------------------------------------------------
        // Card Style - How Card widgets look
        // ---------------------------------------------------------------------
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,                              // Subtle shadow
          shadowColor: Colors.black.withOpacity(0.05), // Very light shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Very rounded corners
          ),
          clipBehavior: Clip.antiAlias, // Smooth clipping for images
          margin: const EdgeInsets.only(bottom: 16),
        ),
      ),
      
      // -----------------------------------------------------------------------
      // NAVIGATION ROUTES - URL to Screen Mapping
      // -----------------------------------------------------------------------
      // These define which screen shows when you navigate to a route.
      // Example: Navigator.pushNamed(context, '/login') -> LoginScreen
      initialRoute: '/', // Start at the landing screen
      routes: {
        // Authentication & Onboarding
        '/': (context) => const LandingScreen(),       // First screen (login/signup choice)
        '/login': (context) => const LoginScreen(),    // User login form
        '/registration': (context) => const RegistrationScreen(), // New user signup
        
        // Main App Screens
        '/main-menu': (context) => const HomeScreen(), // Primary dashboard
        '/main-menu-list': (context) => const MainMenuScreen(), // Menu list view
        
        // Permissions
        '/location-permission': (context) => const LocationPermissionScreen(),
        '/notification-permission': (context) => const NotificationPermissionScreen(),
        
        // Onboarding & Profile
        '/intro': (context) => const IntroScreen(),    // App introduction slides
        '/research-profile': (context) => const ResearchProfileScreen(),
        '/profile': (context) => const ProfileScreen(),
        
        // Farm Management
        '/coordinate-entry': (context) => const CoordinateEntryScreen(),
        '/language-selection': (context) => const LanguageSelectionScreen(),
        '/farmland-map': (context) => const FarmlandMapScreen(),
        
        // Analytics
        '/analytics': (context) => const AnalyticsScreen(),
        
        // Alternative Home Screens
        '/farmers-home': (context) => const FarmersHomeScreen(),
        '/locate-farmland': (context) => const LocateFarmlandScreen(),
      },
    );
  }
}