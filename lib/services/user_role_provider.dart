/// ============================================================================
/// FILE: user_role_provider.dart
/// ============================================================================
/// PURPOSE: Manages user roles (Farmer vs Agronomist/Researcher) across the app.
///          Different roles see different screens and features.
/// 
/// WHAT THIS FILE DOES:
///   1. Stores the current user's role (farmer or agronomist)
///   2. Loads the role from local storage or database on app startup
///   3. Notifies the app when the role changes so UI can update
///   4. Provides helper methods to check role (isFarmer, isAgronomist)
/// 
/// WHY THIS MATTERS:
///   - Farmers see simplified dashboards with actionable advice
///   - Agronomists/Researchers see detailed technical data and tools
/// 
/// USAGE EXAMPLE:
///   // In any widget:
///   final roleProvider = context.watch<UserRoleProvider>();
///   if (roleProvider.isFarmer) {
///     return FarmerDashboard();
///   } else {
///     return ResearcherDashboard();
///   }
/// 
/// PATTERN: Singleton + ChangeNotifier
///   - Singleton: Only one instance exists (all screens share same role)
///   - ChangeNotifier: UI rebuilds automatically when role changes
/// ============================================================================

// Flutter's core framework - provides ChangeNotifier for state management
import 'package:flutter/material.dart';

// SharedPreferences - stores data locally on device (persists across app restarts)
import 'package:shared_preferences/shared_preferences.dart';

// Firebase Auth - to get current logged-in user
import 'package:firebase_auth/firebase_auth.dart';

// Supabase - our cloud database where user profiles are stored
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// UserRole ENUM
// =============================================================================
/// Represents the type of user using the app.
/// 
/// ENUM EXPLAINED:
///   An enum is a fixed list of possible values.
///   Instead of using strings like "farmer" or "researcher" (which can be misspelled),
///   we use this enum for type-safety.
enum UserRole {
  /// A farmer who uses the app to monitor their crops
  farmer,
  
  /// An agricultural researcher or agronomist who needs detailed data
  agronomist,
  
  /// User hasn't completed the questionnaire yet, or role is unknown
  unknown,
}

// =============================================================================
// UserRoleProvider CLASS
// =============================================================================
/// Manages and provides user role state across the entire app.
/// 
/// SINGLETON PATTERN:
///   We use a singleton (single instance) because:
///   - There should only be ONE user role at a time
///   - All screens need to see the SAME role
///   - Saves memory by not creating multiple instances
/// 
/// CHANGENOTIFIER:
///   When the role changes, all widgets listening to this provider
///   automatically rebuild with the new role.
class UserRoleProvider extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Singleton Implementation
  // ---------------------------------------------------------------------------
  // Private static instance - the ONE and ONLY instance of this class
  static final UserRoleProvider _instance = UserRoleProvider._internal();
  
  // Factory constructor - always returns the same instance
  // When you call UserRoleProvider(), you get the existing instance
  factory UserRoleProvider() => _instance;
  
  // Private constructor - prevents creating new instances from outside
  UserRoleProvider._internal();

  // ---------------------------------------------------------------------------
  // State Variables
  // ---------------------------------------------------------------------------
  
  /// The current user's role. Starts as 'unknown' until loaded.
  UserRole _role = UserRole.unknown;
  
  /// Whether we've already loaded the role from storage/database.
  /// Prevents unnecessary repeated loading.
  bool _isLoaded = false;

  // ---------------------------------------------------------------------------
  // Getters - Read-only access to state
  // ---------------------------------------------------------------------------
  
  /// Get the current user role
  UserRole get role => _role;
  
  /// Quick check: Is the current user a farmer?
  /// Example: if (provider.isFarmer) showFarmerUI();
  bool get isFarmer => _role == UserRole.farmer;
  
  /// Quick check: Is the current user an agronomist/researcher?
  /// Example: if (provider.isAgronomist) showResearcherUI();
  bool get isAgronomist => _role == UserRole.agronomist;
  
  /// Has the role been loaded from storage yet?
  bool get isLoaded => _isLoaded;

  // ---------------------------------------------------------------------------
  // loadRole() - Load user role on app startup
  // ---------------------------------------------------------------------------
  /// Loads the user role from local storage or database.
  /// 
  /// LOADING PRIORITY:
  ///   1. First, check local storage (fast, works offline)
  ///   2. If not found, check database (requires internet)
  ///   3. If still not found, keep role as 'unknown'
  /// 
  /// This method is called automatically in main.dart during app startup.
  Future<void> loadRole() async {
    // Skip if already loaded (prevents double-loading)
    if (_isLoaded) return;

    try {
      // STEP 1: Try loading from local storage first (fast!)
      final prefs = await SharedPreferences.getInstance();
      final savedRole = prefs.getString('user_role');
      
      if (savedRole != null) {
        // Found role locally - use it
        _role = _parseRole(savedRole);
        _isLoaded = true;
        notifyListeners(); // Tell all widgets to rebuild
        return;
      }

      // STEP 2: Not found locally - try loading from database
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // User is logged in - fetch their profile from Supabase
        final profile = await Supabase.instance.client
            .from('user_profiles')          // Table name in database
            .select('questionnaire_data')   // Column containing role info
            .eq('user_id', user.uid)        // Match current user
            .maybeSingle();                 // Get one result or null

        if (profile != null && profile['questionnaire_data'] != null) {
          // Found profile with questionnaire data
          final questionnaire = profile['questionnaire_data'] as Map<String, dynamic>;
          final roleStr = questionnaire['role'] as String?;
          _role = _parseRole(roleStr);
          
          // Save to local storage for faster loading next time
          await prefs.setString('user_role', roleStr ?? 'unknown');
        }
      }
    } catch (e) {
      // Something went wrong - log it but don't crash the app
      debugPrint('Error loading user role: $e');
    }

    // Mark as loaded (even if we couldn't find a role)
    _isLoaded = true;
    notifyListeners(); // Tell all widgets to rebuild with whatever we found
  }

  // ---------------------------------------------------------------------------
  // setRole() - Save user role after questionnaire
  // ---------------------------------------------------------------------------
  /// Sets the user role (usually called after completing the onboarding questionnaire).
  /// 
  /// PARAMETERS:
  ///   roleString: The role as a string, e.g., "farmer" or "agro-tech researcher"
  /// 
  /// WHAT IT DOES:
  ///   1. Parses the string to our enum
  ///   2. Saves to local storage for persistence
  ///   3. Notifies all widgets to update their UI
  Future<void> setRole(String roleString) async {
    // Convert string to enum
    _role = _parseRole(roleString);
    
    try {
      // Save to local storage so it persists across app restarts
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', roleString);
    } catch (e) {
      debugPrint('Error saving user role: $e');
    }
    
    // Tell all listening widgets to rebuild with new role
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // _parseRole() - Convert string to UserRole enum
  // ---------------------------------------------------------------------------
  /// Converts a role string from database/storage to our UserRole enum.
  /// 
  /// HANDLES VARIATIONS:
  ///   - "farmer" → UserRole.farmer
  ///   - "agro-tech researcher" → UserRole.agronomist
  ///   - "agronomist" → UserRole.agronomist
  ///   - anything else → UserRole.unknown
  UserRole _parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.unknown;
    
    switch (roleStr.toLowerCase()) {
      case 'farmer':
        return UserRole.farmer;
      case 'agro-tech researcher':  // From questionnaire
      case 'agronomist':             // Alternative name
      case 'researcher':             // Short form
        return UserRole.agronomist;
      default:
        return UserRole.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // clearRole() - Reset role on logout
  // ---------------------------------------------------------------------------
  /// Clears the user role when the user logs out.
  /// 
  /// WHAT IT DOES:
  ///   1. Resets role to 'unknown'
  ///   2. Removes saved role from local storage
  ///   3. Allows loadRole() to be called again on next login
  Future<void> clearRole() async {
    _role = UserRole.unknown;
    _isLoaded = false; // Allow reloading on next login
    
    try {
      // Remove from local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
    } catch (e) {
      debugPrint('Error clearing user role: $e');
    }
    
    // Tell all widgets to rebuild (they'll now see 'unknown' role)
    notifyListeners();
  }
}
