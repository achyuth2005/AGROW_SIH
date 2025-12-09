import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enum for user roles
enum UserRole {
  farmer,
  agronomist,
  unknown,
}

/// Provider to manage user role across the app
class UserRoleProvider extends ChangeNotifier {
  static final UserRoleProvider _instance = UserRoleProvider._internal();
  factory UserRoleProvider() => _instance;
  UserRoleProvider._internal();

  UserRole _role = UserRole.unknown;
  bool _isLoaded = false;

  UserRole get role => _role;
  bool get isFarmer => _role == UserRole.farmer;
  bool get isAgronomist => _role == UserRole.agronomist;
  bool get isLoaded => _isLoaded;

  /// Load user role from local storage or database
  Future<void> loadRole() async {
    if (_isLoaded) return;

    try {
      // First try to load from local storage
      final prefs = await SharedPreferences.getInstance();
      final savedRole = prefs.getString('user_role');
      
      if (savedRole != null) {
        _role = _parseRole(savedRole);
        _isLoaded = true;
        notifyListeners();
        return;
      }

      // If not in local storage, try to load from database
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('questionnaire_data')
            .eq('user_id', user.uid)
            .maybeSingle();

        if (profile != null && profile['questionnaire_data'] != null) {
          final questionnaire = profile['questionnaire_data'] as Map<String, dynamic>;
          final roleStr = questionnaire['role'] as String?;
          _role = _parseRole(roleStr);
          
          // Save to local storage for future
          await prefs.setString('user_role', roleStr ?? 'unknown');
        }
      }
    } catch (e) {
      debugPrint('Error loading user role: $e');
    }

    _isLoaded = true;
    notifyListeners();
  }

  /// Set the user role (called after questionnaire completion)
  Future<void> setRole(String roleString) async {
    _role = _parseRole(roleString);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', roleString);
    } catch (e) {
      debugPrint('Error saving user role: $e');
    }
    
    notifyListeners();
  }

  /// Parse role string to enum
  UserRole _parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.unknown;
    
    switch (roleStr.toLowerCase()) {
      case 'farmer':
        return UserRole.farmer;
      case 'agro-tech researcher':
      case 'agronomist':
      case 'researcher':
        return UserRole.agronomist;
      default:
        return UserRole.unknown;
    }
  }

  /// Clear role (on logout)
  Future<void> clearRole() async {
    _role = UserRole.unknown;
    _isLoaded = false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
    } catch (e) {
      debugPrint('Error clearing user role: $e');
    }
    
    notifyListeners();
  }
}
