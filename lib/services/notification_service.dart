import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // Get FCM Token
    try {
      String? token = await _firebaseMessaging.getToken();
      debugPrint("FCM Token: $token");
      if (token != null) {
        await saveTokenToBackend(token);
      }
      
      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        saveTokenToBackend(newToken);
      });
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
    }

    // Foreground Message Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        saveNotification(message);
        
        // Notify listeners to show UI overlay
        onMessageReceived.value = message;
      }
    });
  }

  // Notifier for foreground messages
  static final ValueNotifier<RemoteMessage?> onMessageReceived = ValueNotifier(null);

  static Future<void> saveNotification(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> notifications = prefs.getStringList('notifications') ?? [];

      final newNotification = {
        'title': message.notification?.title ?? 'No Title',
        'body': message.notification?.body ?? 'No Body',
        'date': "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
        'time': "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      notifications.insert(0, jsonEncode(newNotification)); // Add to top
      await prefs.setStringList('notifications', notifications);
    } catch (e) {
      debugPrint("Error saving notification: $e");
    }
  }
  static Future<void> saveTokenToBackend(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
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

// Background Message Handler (Must be a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  await NotificationService.saveNotification(message);
}
