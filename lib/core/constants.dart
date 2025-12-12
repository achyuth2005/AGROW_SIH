/// ===========================================================================
/// CORE CONSTANTS
/// ===========================================================================
///
/// PURPOSE: Centralized configuration for API URLs, color palette, and
///          application-wide constants. Single source of truth.
///
/// USAGE:
///   import 'package:agroww_sih/core/constants.dart';
///   final url = ApiUrls.chatbot;
///   final color = AppColors.primary;
/// ===========================================================================

/// API endpoints for Hugging Face Space deployments
class ApiUrls {
  ApiUrls._(); // Private constructor - prevents instantiation

  /// Chatbot service - SSE streaming for agricultural advice
  static const String chatbot = 'https://Aniket2006-Chatbot.hf.space';

  /// Sentinel-2 analysis - Vegetation indices and LLM insights
  static const String sentinel2 = 'https://aniket2006-agrow-sentinel2.hf.space';

  /// Heatmap generation - Pixel-wise and CNN+LLM modes
  static const String heatmap = 'https://aniket2006-heatmap.hf.space';

  /// Time series forecasting - AutoNHITS predictions
  static const String timeseries = 'https://aniket2006-timeseries.hf.space';

  /// Voice transcription - Groq Whisper
  static const String voice = 'https://aniket2006-voice.hf.space';

  /// SAR analysis backup (if different from sentinel2)
  static const String sar = 'https://aniket2006-agrow.hf.space';
}

/// Application color palette - matches Material 3 theme
class AppColors {
  AppColors._();

  /// Primary brand green - buttons, links, active states
  static const int primaryValue = 0xFF0D986A;

  /// Dark forest green - headers, text
  static const int secondaryValue = 0xFF0F3C33;

  /// Light lime accent - highlights, badges
  static const int tertiaryValue = 0xFFC6F68D;

  /// Light teal background - scaffolds, surfaces
  static const int surfaceValue = 0xFFE1EFEF;

  /// Error red
  static const int errorValue = 0xFFBA1A1A;
}

/// Duration constants for timeouts and animations
class AppDurations {
  AppDurations._();

  /// API request timeout
  static const Duration apiTimeout = Duration(seconds: 120);

  /// Cache expiration
  static const Duration cacheExpiry = Duration(hours: 24);

  /// Animation duration
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 350);
}

/// Supabase table names
class SupabaseTables {
  SupabaseTables._();

  static const String userProfiles = 'user_profiles';
  static const String coordinatesQuad = 'coordinates_quad';
  static const String fieldNotes = 'field_notes';
  static const String fieldImages = 'field_images';
}
