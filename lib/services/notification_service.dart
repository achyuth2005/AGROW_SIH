/// ============================================================================
/// FILE: notification_service.dart
/// ============================================================================
/// PURPOSE: Manages push notifications using Firebase Cloud Messaging (FCM).
///          Enables the app to receive alerts about crop conditions, weather
///          warnings, and other important farming updates.
/// 
/// WHAT THIS FILE DOES:
///   1. Requests notification permission from the user
///   2. Gets the FCM token (unique device identifier for push notifications)
///   3. Saves the FCM token to Supabase (for server-side targeting)
///   4. Handles foreground notifications (while app is open)
///   5. Handles background notifications (when app is minimized)
///   6. Stores notifications locally for the notification history screen
/// 
/// FCM TOKEN EXPLAINED:
///   Every device gets a unique token from Firebase. When the backend wants
///   to send a notification to a specific user, it uses this token.
///   The token can change (on app reinstall, etc.), so we listen for refreshes.
/// 
/// NOTIFICATION FLOW:
///   ┌──────────────────────────────────────────────────────────────────────┐
///   │  Backend/Firebase Console                                            │
///   │         │                                                            │
///   │         ▼ Push notification sent                                     │
///   │  Firebase Cloud Messaging (FCM)                                      │
///   │         │                                                            │
///   │         ▼                                                            │
///   │  ┌─────────────────────────────────────────────────────────────────┐ │
///   │  │ App Foreground?                                                 │ │
///   │  │   YES → onMessage callback → Show overlay + save                │ │
///   │  │   NO  → Background handler → Save to SharedPrefs                │ │
///   │  └─────────────────────────────────────────────────────────────────┘ │
///   └──────────────────────────────────────────────────────────────────────┘
/// 
/// DEPENDENCIES:
///   - firebase_messaging: FCM integration
///   - shared_preferences: Local notification storage
///   - supabase_flutter: Store FCM token in user profile
/// ============================================================================

// Firebase Cloud Messaging
import 'package:firebase_messaging/firebase_messaging.dart';

// Debug logging
import 'package:flutter/foundation.dart';

// Local storage for notification history
import 'package:shared_preferences/shared_preferences.dart';

// Backend for storing FCM token
import 'package:supabase_flutter/supabase_flutter.dart';

// JSON encoding for notification storage
import 'dart:convert';

/// ============================================================================
/// NotificationService CLASS
/// ============================================================================
/// Handles all push notification functionality.
class NotificationService {
  /// Firebase Messaging instance
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// -------------------------------------------------------------------------
  /// initialize() - Set up push notifications
  /// -------------------------------------------------------------------------
  /// Call this once during app startup (usually in main.dart).
  /// 
  /// STEPS:
  /// 1. Request permission from user
  /// 2. Get FCM token
  /// 3. Save token to backend
  /// 4. Set up foreground message handler
  Future<void> initialize() async {
    // =========================================================================
    // STEP 1: Request permission
    // =========================================================================
    // On iOS, we MUST request permission before receiving notifications.
    // On Android 13+, we also need runtime permission.
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,           // Show notification banner
      announcement: false,   // Announce via Siri (iOS)
      badge: true,           // Show badge on app icon
      carPlay: false,        // CarPlay notifications
      criticalAlert: false,  // Critical alerts bypass DND
      provisional: false,    // Provisional auth (iOS 12+)
      sound: true,           // Play sound
    );

    // Log the permission result
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // =========================================================================
    // STEP 2: Get FCM Token
    // =========================================================================
    // The token uniquely identifies this device for push notifications.
    try {
      String? token = await _firebaseMessaging.getToken();
      debugPrint("FCM Token: $token");
      if (token != null) {
        await saveTokenToBackend(token);
      }
      
      // Listen for token refresh (can happen on app reinstall, etc.)
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        saveTokenToBackend(newToken);
      });
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
    }

    // =========================================================================
    // STEP 3: Set up foreground message handler
    // =========================================================================
    // This handles notifications when the app is in the foreground.
    // We save the notification and notify the UI to show an overlay.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        saveNotification(message);
        
        // Notify listeners to show UI overlay
        // Widgets can listen to this ValueNotifier to react to new notifications
        onMessageReceived.value = message;
      }
    });
  }

  // ===========================================================================
  // STATIC MEMBERS
  // ===========================================================================
  
  /// ValueNotifier for foreground messages.
  /// Widgets can listen to this to show notification overlays.
  static final ValueNotifier<RemoteMessage?> onMessageReceived = ValueNotifier(null);

  /// -------------------------------------------------------------------------
  /// saveNotification() - Store notification in local history
  /// -------------------------------------------------------------------------
  /// Saves the notification to SharedPreferences so users can view
  /// past notifications in the notification screen.
  static Future<void> saveNotification(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Get existing notifications list
      final List<String> notifications = prefs.getStringList('notifications') ?? [];

      // Create notification object
      final newNotification = {
        'title': message.notification?.title ?? 'No Title',
        'body': message.notification?.body ?? 'No Body',
        'date': "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
        'time': "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Add to top of list (most recent first)
      notifications.insert(0, jsonEncode(newNotification));
      await prefs.setStringList('notifications', notifications);
    } catch (e) {
      debugPrint("Error saving notification: $e");
    }
  }
  
  /// -------------------------------------------------------------------------
  /// saveTokenToBackend() - Store FCM token in Supabase
  /// -------------------------------------------------------------------------
  /// Saves the FCM token to the user's profile in Supabase.
  /// This allows the backend to send targeted notifications.
  static Future<void> saveTokenToBackend(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Upsert: Update if exists, insert if not
        await Supabase.instance.client.from('user_profiles').upsert({
          'user_id': user.id,
          'fcm_token': token,
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint("FCM Token saved to backend for user: ${user.id}");
      } else {
        debugPrint("User not logged in, skipping FCM token save");
      }
    } catch (e) {
      debugPrint("Error saving FCM token to backend: $e");
    }
  }
}

// =============================================================================
// BACKGROUND MESSAGE HANDLER
// =============================================================================
// This function MUST be a top-level function (not a class method).
// It handles notifications when the app is in the background or terminated.
// The @pragma annotation ensures it's not removed by tree-shaking.

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  await NotificationService.saveNotification(message);
}
