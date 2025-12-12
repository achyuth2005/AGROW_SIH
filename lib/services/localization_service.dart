/// ============================================================================
/// FILE: localization_service.dart
/// ============================================================================
/// PURPOSE: Provides multi-language support for the app (English, Hindi, Bengali).
///          Farmers in India speak different regional languages, so the app
///          adapts its text to the user's preferred language.
/// 
/// WHAT THIS FILE DOES:
///   1. Defines supported languages (English, Hindi, Bengali)
///   2. Stores translations for all UI text in the app
///   3. Provides a provider (LocalizationProvider) for reactive language changes
///   4. Persists language preference to SharedPreferences
/// 
/// HOW TO USE:
///   1. Getting translations:
///      final text = context.read<LocalizationProvider>().tr('home');
///      // Returns "Home" in English, "होम" in Hindi, "হোম" in Bengali
///   
///   2. Changing language:
///      context.read<LocalizationProvider>().setLanguage(AppLanguage.hindi);
/// 
/// ADDING NEW TRANSLATIONS:
///   Add entries to the _translations map in AppTranslations class:
///   'key_name': {'en': 'English', 'hi': 'हिंदी', 'bn': 'বাংলা'},
/// 
/// DEPENDENCIES:
///   - flutter: ChangeNotifier for reactive updates
///   - shared_preferences: Persisting language choice
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// AppLanguage ENUM
/// ============================================================================
/// Defines the supported languages in the app.
/// 
/// Each language has:
///   - code: ISO language code (e.g., 'en', 'hi')
///   - nativeName: Name in its own script (e.g., 'हिंदी')
///   - englishName: Name in English (e.g., 'Hindi')
enum AppLanguage {
  english('en', 'English', 'English'),
  hindi('hi', 'हिंदी', 'Hindi'),
  bengali('bn', 'বাংলা', 'Bengali');

  /// ISO 639-1 language code
  final String code;
  
  /// Name in the language's native script
  final String nativeName;
  
  /// Name in English (for settings UI)
  final String englishName;
  
  const AppLanguage(this.code, this.nativeName, this.englishName);

  /// Get AppLanguage from ISO code
  /// Falls back to English if code not found
  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}

/// ============================================================================
/// LocalizationProvider CLASS
/// ============================================================================
/// Manages the current language and notifies widgets when it changes.
/// 
/// USAGE WITH PROVIDER:
///   // Wrap app with ChangeNotifierProvider in main.dart
///   ChangeNotifierProvider(create: (_) => LocalizationProvider())
///   
///   // In any widget:
///   final localization = context.watch<LocalizationProvider>();
///   Text(localization.tr('home')) // Shows "Home", "होम", or "হোম"
class LocalizationProvider extends ChangeNotifier {
  /// Key used to store language preference in SharedPreferences
  static const String _languageKey = 'selected_language';
  
  /// Currently selected language (defaults to English)
  AppLanguage _currentLanguage = AppLanguage.english;

  /// Get the current language
  AppLanguage get currentLanguage => _currentLanguage;
  
  /// Get the current language code (e.g., 'en', 'hi')
  String get languageCode => _currentLanguage.code;

  /// Constructor - loads saved language preference
  LocalizationProvider() {
    _loadLanguage();
  }

  /// -------------------------------------------------------------------------
  /// _loadLanguage() - Load saved language preference
  /// -------------------------------------------------------------------------
  /// Reads the language code from SharedPreferences on app startup.
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_languageKey) ?? 'en';
    _currentLanguage = AppLanguage.fromCode(code);
    notifyListeners();  // Rebuild widgets with loaded language
  }

  /// -------------------------------------------------------------------------
  /// setLanguage() - Change the app language
  /// -------------------------------------------------------------------------
  /// Saves the preference and rebuilds all listening widgets.
  /// 
  /// EXAMPLE:
  ///   context.read<LocalizationProvider>().setLanguage(AppLanguage.hindi);
  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.code);
    notifyListeners();  // Rebuild all widgets with new language
  }

  /// -------------------------------------------------------------------------
  /// tr() - Translate a key to the current language
  /// -------------------------------------------------------------------------
  /// Looks up the translation for the given key.
  /// 
  /// EXAMPLE:
  ///   localization.tr('home')  // Returns "होम" if language is Hindi
  String tr(String key) {
    return AppTranslations.get(key, _currentLanguage.code);
  }
}

/// ============================================================================
/// AppTranslations CLASS
/// ============================================================================
/// Static storage for all app translations.
/// 
/// STRUCTURE:
///   {
///     'key': {
///       'en': 'English text',
///       'hi': 'हिंदी पाठ',
///       'bn': 'বাংলা পাঠ'
///     }
///   }
/// 
/// FALLBACK: If a translation is missing, returns English. If English is
/// missing too, returns the key itself.
class AppTranslations {
  /// Main translation dictionary
  /// Organized by feature/section for easier maintenance
  static final Map<String, Map<String, String>> _translations = {
    // =========================================================================
    // COMMON / GENERAL
    // =========================================================================
    'app_name': {'en': 'AGROW', 'hi': 'अग्रो', 'bn': 'এগ্রো'},
    'loading': {'en': 'Loading...', 'hi': 'लोड हो रहा है...', 'bn': 'লোড হচ্ছে...'},
    'error': {'en': 'Error', 'hi': 'त्रुटि', 'bn': 'ত্রুটি'},
    'success': {'en': 'Success', 'hi': 'सफल', 'bn': 'সফল'},
    'cancel': {'en': 'Cancel', 'hi': 'रद्द करें', 'bn': 'বাতিল'},
    'save': {'en': 'Save', 'hi': 'सहेजें', 'bn': 'সংরক্ষণ'},
    'ok': {'en': 'OK', 'hi': 'ठीक है', 'bn': 'ঠিক আছে'},
    'yes': {'en': 'Yes', 'hi': 'हाँ', 'bn': 'হ্যাঁ'},
    'no': {'en': 'No', 'hi': 'नहीं', 'bn': 'না'},
    'retry': {'en': 'Retry', 'hi': 'पुनः प्रयास करें', 'bn': 'পুনরায় চেষ্টা করুন'},
    
    // =========================================================================
    // HOME SCREEN
    // =========================================================================
    'home': {'en': 'Home', 'hi': 'होम', 'bn': 'হোম'},
    'welcome': {'en': 'Welcome', 'hi': 'स्वागत है', 'bn': 'স্বাগতম'},
    'soil_status': {'en': 'Soil Status', 'hi': 'मिट्टी की स्थिति', 'bn': 'মাটির অবস্থা'},
    'weather_status': {'en': 'Weather Status', 'hi': 'मौसम की स्थिति', 'bn': 'আবহাওয়ার অবস্থা'},
    'crop_status': {'en': 'Crop Status', 'hi': 'फसल की स्थिति', 'bn': 'ফসলের অবস্থা'},
    'pest_risk': {'en': 'Pest Risk', 'hi': 'कीट जोखिम', 'bn': 'কীট ঝুঁকি'},
    'view_details': {'en': 'View Details', 'hi': 'विवरण देखें', 'bn': 'বিস্তারিত দেখুন'},
    'take_action': {'en': 'Take Action', 'hi': 'कार्रवाई करें', 'bn': 'পদক্ষেপ নিন'},
    
    // =========================================================================
    // SIDEBAR / SETTINGS
    // =========================================================================
    'settings_activity': {'en': 'Settings & Activity', 'hi': 'सेटिंग्स और गतिविधि', 'bn': 'সেটিংস এবং কার্যক্রম'},
    'profile': {'en': 'Profile', 'hi': 'प्रोफ़ाइल', 'bn': 'প্রোফাইল'},
    'export_reports': {'en': 'Export Detailed Reports', 'hi': 'विस्तृत रिपोर्ट निर्यात करें', 'bn': 'বিস্তারিত রিপোর্ট রপ্তানি'},
    'language_preference': {'en': 'Language Preference', 'hi': 'भाषा प्राथमिकता', 'bn': 'ভাষা পছন্দ'},
    'permissions': {'en': 'Permissions', 'hi': 'अनुमतियाँ', 'bn': 'অনুমতি'},
    'privacy_security': {'en': 'Privacy and Security', 'hi': 'गोपनीयता और सुरक्षा', 'bn': 'গোপনীয়তা এবং নিরাপত্তা'},
    'feedback': {'en': 'Feedback', 'hi': 'प्रतिक्रिया', 'bn': 'প্রতিক্রিয়া'},
    'help_support': {'en': 'Help and Support', 'hi': 'सहायता और समर्थन', 'bn': 'সাহায্য এবং সহায়তা'},
    'app_tutorial': {'en': 'App Tutorial', 'hi': 'ऐप ट्यूटोरियल', 'bn': 'অ্যাপ টিউটোরিয়াল'},
    'faqs': {'en': 'FAQs', 'hi': 'सामान्य प्रश्न', 'bn': 'প্রায়শই জিজ্ঞাসিত প্রশ্ন'},
    'logout': {'en': 'Log Out', 'hi': 'लॉग आउट', 'bn': 'লগ আউট'},
    
    // =========================================================================
    // TAKE ACTION / RECOMMENDATIONS
    // =========================================================================
    'recommendations': {'en': 'Recommendations', 'hi': 'सिफारिशें', 'bn': 'সুপারিশ'},
    'select_field': {'en': 'Select Field', 'hi': 'खेत चुनें', 'bn': 'মাঠ নির্বাচন'},
    'field_variability': {'en': 'Field Variability', 'hi': 'खेत परिवर्तनशीलता', 'bn': 'মাঠের পরিবর্তনশীলতা'},
    'yield_stability': {'en': 'Yield Stability', 'hi': 'उपज स्थिरता', 'bn': 'ফলন স্থিতিশীলতা'},
    'irrigation_scheduling': {'en': 'Irrigation Scheduling', 'hi': 'सिंचाई शेड्यूलिंग', 'bn': 'সেচ সময়সূচী'},
    'vegetation_health': {'en': 'Vegetation Health', 'hi': 'वनस्पति स्वास्थ्य', 'bn': 'উদ্ভিদ স্বাস্থ্য'},
    'nutrient_deficiency': {'en': 'Nutrient Deficiency', 'hi': 'पोषक तत्व की कमी', 'bn': 'পুষ্টির ঘাটতি'},
    'pest_damage': {'en': 'Pest Damage', 'hi': 'कीट क्षति', 'bn': 'কীট ক্ষতি'},
    
    // =========================================================================
    // IRRIGATION SCREEN
    // =========================================================================
    'soil_moisture': {'en': 'Soil Moisture', 'hi': 'मिट्टी की नमी', 'bn': 'মাটির আর্দ্রতা'},
    'crop_moisture_content': {'en': 'Crop Moisture Content', 'hi': 'फसल नमी सामग्री', 'bn': 'ফসলের আর্দ্রতা'},
    'how_to_make_better': {'en': 'How to make it better', 'hi': 'इसे बेहतर कैसे बनाएं', 'bn': 'এটি কীভাবে উন্নত করবেন'},
    'moisture_level': {'en': 'Moisture Level', 'hi': 'नमी का स्तर', 'bn': 'আর্দ্রতার মাত্রা'},
    'high': {'en': 'High', 'hi': 'उच्च', 'bn': 'উচ্চ'},
    'moderate': {'en': 'Moderate', 'hi': 'मध्यम', 'bn': 'মধ্যম'},
    'low': {'en': 'Low', 'hi': 'निम्न', 'bn': 'নিম্ন'},
    'dry': {'en': 'Dry', 'hi': 'सूखा', 'bn': 'শুষ্ক'},
    'crop_stage_statistics': {'en': 'Crop Stage Statistics', 'hi': 'फसल चरण सांख्यिकी', 'bn': 'ফসল পর্যায়ের পরিসংখ্যান'},
    'predicted_weather': {'en': 'Predicted Weather Data', 'hi': 'अनुमानित मौसम डेटा', 'bn': 'পূর্বাভাসিত আবহাওয়া'},
    'coming_7_days': {'en': 'Coming 7 days', 'hi': 'आने वाले 7 दिन', 'bn': 'আগামী ৭ দিন'},
    'ask_chatbot': {'en': 'Ask Chatbot', 'hi': 'चैटबॉट से पूछें', 'bn': 'চ্যাটবট জিজ্ঞাসা'},
    'detailed_pathway': {'en': 'Detailed Pathway', 'hi': 'विस्तृत मार्ग', 'bn': 'বিস্তারিত পথ'},
    'detailed_report': {'en': 'Detailed Report', 'hi': 'विस्तृत रिपोर्ट', 'bn': 'বিস্তারিত রিপোর্ট'},
    
    // =========================================================================
    // PRIORITY ZONES
    // =========================================================================
    'irrigation_priority_zones': {'en': 'Irrigation Priority Zones', 'hi': 'सिंचाई प्राथमिकता क्षेत्र', 'bn': 'সেচ অগ্রাধিকার অঞ্চল'},
    'high_priority': {'en': 'High Priority', 'hi': 'उच्च प्राथमिकता', 'bn': 'উচ্চ অগ্রাধিকার'},
    'mid_priority': {'en': 'Mid Priority', 'hi': 'मध्य प्राथमिकता', 'bn': 'মধ্যম অগ্রাধিকার'},
    'low_priority': {'en': 'Low Priority', 'hi': 'निम्न प्राथमिकता', 'bn': 'নিম্ন অগ্রাধিকার'},
    'classification_reason': {'en': 'Major Reason behind Classification', 'hi': 'वर्गीकरण का मुख्य कारण', 'bn': 'শ্রেণীবিভাগের প্রধান কারণ'},
    'how_to_act': {'en': 'How to act upon High Priority Areas', 'hi': 'उच्च प्राथमिकता क्षेत्रों पर कैसे कार्य करें', 'bn': 'উচ্চ অগ্রাধিকার এলাকায় কীভাবে কাজ করবেন'},
    'zones': {'en': 'zones', 'hi': 'क्षेत्र', 'bn': 'অঞ্চল'},
    
    // =========================================================================
    // CHATBOT
    // =========================================================================
    'agrow_ai': {'en': 'AGROW AI', 'hi': 'अग्रो AI', 'bn': 'এগ্রো AI'},
    'ask_anything': {'en': 'Ask anything...', 'hi': 'कुछ भी पूछें...', 'bn': 'যেকোনো কিছু জিজ্ঞাসা করুন...'},
    'thinking': {'en': 'Thinking...', 'hi': 'सोच रहा है...', 'bn': 'ভাবছে...'},
    'how_can_help': {'en': 'How can I help you today?', 'hi': 'आज मैं आपकी कैसे मदद कर सकता हूं?', 'bn': 'আজ আমি আপনাকে কীভাবে সাহায্য করতে পারি?'},
    'whats_crop_health': {'en': "What's my crop health?", 'hi': 'मेरी फसल का स्वास्थ्य कैसा है?', 'bn': 'আমার ফসলের স্বাস্থ্য কেমন?'},
    'irrigation_advice': {'en': 'Irrigation advice', 'hi': 'सिंचाई सलाह', 'bn': 'সেচ পরামর্শ'},
    'pest_tips': {'en': 'Pest management tips', 'hi': 'कीट प्रबंधन सुझाव', 'bn': 'কীট ব্যবস্থাপনা টিপস'},
    
    // =========================================================================
    // ANALYTICS
    // =========================================================================
    'mapped_analytics': {'en': 'Mapped Analytics', 'hi': 'मैप किया गया विश्लेषण', 'bn': 'ম্যাপ করা বিশ্লেষণ'},
    'visual_analytics': {'en': 'Visual Analytics', 'hi': 'दृश्य विश्लेषण', 'bn': 'ভিজ্যুয়াল বিশ্লেষণ'},
    'newsletter': {'en': 'Newsletter', 'hi': 'समाचार पत्र', 'bn': 'নিউজলেটার'},
    'notes': {'en': 'Notes', 'hi': 'नोट्स', 'bn': 'নোট'},
    'analytics': {'en': 'Analytics', 'hi': 'विश्लेषण', 'bn': 'বিশ্লেষণ'},
    'greenness': {'en': 'Greenness', 'hi': 'हरापन', 'bn': 'সবুজ'},
    'biomass_growth': {'en': 'Biomass Growth', 'hi': 'बायोमास वृद्धि', 'bn': 'বায়োমাস বৃদ্ধি'},
    'nitrogen_level': {'en': 'Nitrogen Level', 'hi': 'नाइट्रोजन स्तर', 'bn': 'নাইট্রোজেন স্তর'},
    'photosynthesis': {'en': 'Photosynthesis Capacity', 'hi': 'प्रकाश संश्लेषण क्षमता', 'bn': 'সালোকসংশ্লেষণ ক্ষমতা'},
    
    // =========================================================================
    // WEATHER PARAMETERS
    // =========================================================================
    'temperature': {'en': 'Temperature', 'hi': 'तापमान', 'bn': 'তাপমাত্রা'},
    'humidity': {'en': 'Humidity', 'hi': 'नमी', 'bn': 'আর্দ্রতা'},
    'wind_speed': {'en': 'Wind Speed', 'hi': 'हवा की गति', 'bn': 'বাতাসের গতি'},
    'uv_index': {'en': 'UV Index', 'hi': 'UV सूचकांक', 'bn': 'UV সূচক'},
    'precipitation': {'en': 'Precipitation', 'hi': 'वर्षा', 'bn': 'বৃষ্টিপাত'},
    'evapotranspiration': {'en': 'Evapotrans.', 'hi': 'वाष्पोत्सर्जन', 'bn': 'বাষ্পীভবন'},
    'avg_daily': {'en': 'Avg daily', 'hi': 'दैनिक औसत', 'bn': 'গড় দৈনিক'},
    'max_daily': {'en': 'Max daily', 'hi': 'दैनिक अधिकतम', 'bn': 'সর্বোচ্চ দৈনিক'},
    'total_sum': {'en': 'Total sum', 'hi': 'कुल योग', 'bn': 'মোট যোগ'},
    
    // =========================================================================
    // LANGUAGE SELECTION
    // =========================================================================
    'select_language': {'en': 'Select Language', 'hi': 'भाषा चुनें', 'bn': 'ভাষা নির্বাচন'},
    'language_changed': {'en': 'Language changed', 'hi': 'भाषा बदली गई', 'bn': 'ভাষা পরিবর্তিত'},
    
    // =========================================================================
    // FIELD VARIABILITY
    // =========================================================================
    'high_low_zones': {'en': 'High and Low Performing Zones', 'hi': 'उच्च और निम्न प्रदर्शन वाले क्षेत्र', 'bn': 'উচ্চ এবং নিম্ন পারফর্মিং অঞ্চল'},
    'analyzing_ai': {'en': 'Analyzing field data with AI...', 'hi': 'AI के साथ खेत डेटा का विश्लेषण...', 'bn': 'AI দিয়ে মাঠের তথ্য বিশ্লেষণ...'},
    'loading_zones': {'en': 'Loading zones...', 'hi': 'क्षेत्र लोड हो रहे हैं...', 'bn': 'অঞ্চল লোড হচ্ছে...'},
    'stress_zones': {'en': 'Stress Zones', 'hi': 'तनाव क्षेत्र', 'bn': 'চাপ অঞ্চল'},
    
    // =========================================================================
    // FARMERS HOME SCREEN
    // =========================================================================
    'soil_fertility': {'en': 'Soil Fertility', 'hi': 'मिट्टी की उर्वरता', 'bn': 'মাটির উর্বরতা'},
    'organic_matter': {'en': 'Organic Matter', 'hi': 'जैविक पदार्थ', 'bn': 'জৈব পদার্থ'},
    'salinity': {'en': 'Salinity', 'hi': 'लवणता', 'bn': 'লবণাক্ততা'},
    'overall_health': {'en': 'Overall Health', 'hi': 'समग्र स्वास्थ्य', 'bn': 'সামগ্রিক স্বাস্থ্য'},
    'crop_health': {'en': 'Crop Health', 'hi': 'फसल स्वास्थ्य', 'bn': 'ফসলের স্বাস্থ্য'},
    'growth_rate': {'en': 'Growth Rate', 'hi': 'वृद्धि दर', 'bn': 'বৃদ্ধির হার'},
    'warm_sunny': {'en': 'Warm and sunny', 'hi': 'गर्म और धूप', 'bn': 'উষ্ণ এবং রৌদ্রোজ্জ্বল'},
    'light_rain': {'en': 'Light rain expected', 'hi': 'हल्की बारिश संभव', 'bn': 'হালকা বৃষ্টি প্রত্যাশিত'},
    'normal_levels': {'en': 'Normal levels', 'hi': 'सामान्य स्तर', 'bn': 'স্বাভাবিক মাত্রা'},
    'gentle_breeze': {'en': 'Gentle breeze', 'hi': 'हल्की हवा', 'bn': 'মৃদু বাতাস'},
    'weather_condition': {'en': 'Weather Condition', 'hi': 'मौसम की स्थिति', 'bn': 'আবহাওয়ার অবস্থা'},
    'good': {'en': 'Good', 'hi': 'अच्छा', 'bn': 'ভালো'},
    'crop_stress_risk': {'en': 'Crop Stress & Risk', 'hi': 'फसल तनाव और जोखिम', 'bn': 'ফসলের চাপ ও ঝুঁকি'},
    'disease_risk': {'en': 'Disease Risk', 'hi': 'रोग जोखिम', 'bn': 'রোগের ঝুঁকি'},
    'nutrient_stress': {'en': 'Nutrient Stress', 'hi': 'पोषक तत्व तनाव', 'bn': 'পুষ্টি চাপ'},
    'areas_detected': {'en': 'Areas Detected', 'hi': 'क्षेत्र पाए गए', 'bn': 'এলাকা সনাক্ত'},
    'none_detected': {'en': 'None Detected', 'hi': 'कोई नहीं मिला', 'bn': 'কিছু পাওয়া যায়নি'},
    'safety_score': {'en': 'Safety Score', 'hi': 'सुरक्षा स्कोर', 'bn': 'নিরাপত্তা স্কোর'},
    'knowledge_hub': {'en': 'Knowledge Hub', 'hi': 'ज्ञान केंद्र', 'bn': 'জ্ঞান কেন্দ্র'},
    
    // =========================================================================
    // ADD FARMLANDS SCREENS
    // =========================================================================
    'locate_farmland': {'en': 'Locate your Farmland', 'hi': 'अपना खेत खोजें', 'bn': 'আপনার জমি খুঁজুন'},
    'how_to_locate': {'en': 'How to locate?', 'hi': 'कैसे खोजें?', 'bn': 'কিভাবে খুঁজবেন?'},
    'locate_instruction_1': {'en': '1. Tap on the map to select four corners of your farmland.', 'hi': '1. अपने खेत के चार कोनों को चुनने के लिए मानचित्र पर टैप करें।', 'bn': '1. আপনার জমির চার কোণা নির্বাচন করতে মানচিত্রে ট্যাপ করুন।'},
    'locate_instruction_2': {'en': '2. Input the geographical coordinates (e.g., latitude/longitude) of your farm boundary manually.', 'hi': '2. अपने खेत की सीमा के भौगोलिक निर्देशांक (जैसे अक्षांश/देशांतर) मैन्युअल रूप से दर्ज करें।', 'bn': '2. আপনার জমির সীমানার ভৌগলিক স্থানাঙ্ক (যেমন অক্ষাংশ/দ্রাঘিমাংশ) ম্যানুয়ালি লিখুন।'},
    'enter_coordinates': {'en': 'Enter Co-ordinates', 'hi': 'निर्देशांक दर्ज करें', 'bn': 'স্থানাঙ্ক লিখুন'},
    'your_fields': {'en': 'Your Fields', 'hi': 'आपके खेत', 'bn': 'আপনার মাঠ'},
    'field_details': {'en': 'Field Details', 'hi': 'खेत का विवरण', 'bn': 'মাঠের বিবরণ'},
    'enter_field_name': {'en': 'Enter Field Name', 'hi': 'खेत का नाम दर्ज करें', 'bn': 'মাঠের নাম লিখুন'},
    'select_crop_type': {'en': 'Select Crop Type', 'hi': 'फसल का प्रकार चुनें', 'bn': 'ফসলের ধরন নির্বাচন করুন'},
    'enter_crop_name': {'en': 'Enter Crop Name', 'hi': 'फसल का नाम दर्ज करें', 'bn': 'ফসলের নাম লিখুন'},
    'submit': {'en': 'Submit', 'hi': 'जमा करें', 'bn': 'জমা দিন'},
    'field_added_success': {'en': 'Field added successfully!', 'hi': 'खेत सफलतापूर्वक जोड़ा गया!', 'bn': 'মাঠ সফলভাবে যোগ করা হয়েছে!'},
    'point': {'en': 'Point', 'hi': 'बिंदु', 'bn': 'পয়েন্ট'},
    'only_4_corners': {'en': 'You can only select 4 corners.', 'hi': 'आप केवल 4 कोने चुन सकते हैं।', 'bn': 'আপনি শুধুমাত্র ৪টি কোণা নির্বাচন করতে পারেন।'},
    
    // =========================================================================
    // BOTTOM NAVIGATION
    // =========================================================================
    'nav_home': {'en': 'Home', 'hi': 'होम', 'bn': 'হোম'},
    'nav_action': {'en': 'Action', 'hi': 'कार्रवाई', 'bn': 'পদক্ষেপ'},
    'nav_analytics': {'en': 'Analytics', 'hi': 'विश्लेषण', 'bn': 'বিশ্লেষণ'},
    'nav_chat': {'en': 'Chat', 'hi': 'चैट', 'bn': 'চ্যাট'},
    'nav_camera': {'en': 'Camera', 'hi': 'कैमरा', 'bn': 'ক্যামেরা'},
    
    // =========================================================================
    // ADDITIONAL IRRIGATION SCREEN
    // =========================================================================
    'what_stage_crop_is': {'en': 'What stage the crop is', 'hi': 'फसल किस चरण में है', 'bn': 'ফসল কোন পর্যায়ে আছে'},
    'weather_forecast': {'en': 'Weather Forecast', 'hi': 'मौसम पूर्वानुमान', 'bn': 'আবহাওয়ার পূর্বাভাস'},
    'weather_upcoming': {'en': 'Weather Data for coming 7 days', 'hi': 'आने वाले 7 दिनों का मौसम डेटा', 'bn': 'আগামী ৭ দিনের আবহাওয়া তথ্য'},
  };

  /// -------------------------------------------------------------------------
  /// get() - Retrieve translation for a key
  /// -------------------------------------------------------------------------
  /// Looks up the translation in the given language.
  /// Falls back to English, then to the key itself if not found.
  static String get(String key, String languageCode) {
    if (_translations.containsKey(key)) {
      // Try requested language first
      return _translations[key]![languageCode] ?? 
             // Fall back to English
             _translations[key]!['en'] ?? 
             // Fall back to key itself
             key;
    }
    return key;  // Key not found, return as-is
  }

  /// -------------------------------------------------------------------------
  /// addTranslation() - Add or update a translation at runtime
  /// -------------------------------------------------------------------------
  /// Useful for dynamic content or testing new translations.
  static void addTranslation(String key, Map<String, String> translations) {
    _translations[key] = translations;
  }
}
