/// ===========================================================================
/// IRRIGATION SCHEDULING SCREEN
/// ===========================================================================
///
/// PURPOSE: Smart irrigation recommendations based on satellite data,
///          weather forecasts, and AI analysis.
///
/// KEY FEATURES:
///   - Soil Moisture Index (SMI) visualization
///   - Moisture level classification (High/Moderate/Low/Dry)
///   - 7-day weather forecast from Open-Meteo API
///   - LLM-powered irrigation recommendations
///   - Crop stage analysis
///
/// DATA SOURCES:
///   1. TimeSeriesService → SMI historical + forecast data
///   2. TakeActionService → AI reasoning for irrigation advice
///   3. Open-Meteo API → Free weather forecast (no API key)
///
/// SMI INTERPRETATION:
///   - > 0.2: High moisture (reduce irrigation)
///   - > 0.0: Moderate (continue schedule)
///   - > -0.2: Low (consider increasing)
///   - <= -0.2: Dry (urgent irrigation needed)
///
/// SECTIONS:
///   - Soil Moisture: Advice + level indicator
///   - Crop Stage Statistics: Growth phase info
///   - Predicted Weather: 7-day forecast cards
///
/// DEPENDENCIES:
///   - TimeSeriesService, TakeActionService
///   - http: Weather API calls
///   - LocalizationProvider: Multi-language support
/// ===========================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/localization_service.dart';
import '../../widgets/adaptive_bottom_nav_bar.dart';
import 'chatbot_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/timeseries_service.dart';
import '../../services/take_action_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'irrigation_detailed_pathway_screen.dart';

class IrrigationSchedulingScreen extends StatefulWidget {
  final String fieldName;
  final double centerLat;
  final double centerLon;
  final double fieldSizeHectares;
  final List<LatLng>? fieldPolygon;
  final Map<String, dynamic>? farmerProfile;

  const IrrigationSchedulingScreen({
    super.key,
    required this.fieldName,
    required this.centerLat,
    required this.centerLon,
    required this.fieldSizeHectares,
    this.fieldPolygon,
    this.farmerProfile,
  });

  @override
  State<IrrigationSchedulingScreen> createState() => _IrrigationSchedulingScreenState();
}

class _IrrigationSchedulingScreenState extends State<IrrigationSchedulingScreen> {
  bool _isLoading = true;
  String _soilMoistureAdvice = 'Loading soil moisture recommendations...';
  String _moistureLevel = '--';
  String _cropStage = 'Loading crop stage data...';
  double _smiValue = 0.0;
  List<Map<String, dynamic>> _weatherForecast = [];
  TakeActionResult? _irrigationResult;

  @override
  void initState() {
    super.initState();
    _loadRealData();
  }

  Future<void> _loadRealData() async {
    try {
      // 1. Fetch SMI timeseries data from cache or API
      debugPrint('[Irrigation] Fetching SMI timeseries...');
      final smiResult = await TimeSeriesService.fetchWithCache(
        centerLat: widget.centerLat,
        centerLon: widget.centerLon,
        fieldSizeHectares: widget.fieldSizeHectares,
        metric: 'SMI',
        daysHistory: 30,
        daysForecast: 7,
      );

      // Get latest SMI value from cache or fresh data
      double latestSMI = 0.0;
      Map<String, dynamic> smiTimeseries = {};
      
      if (smiResult.hasCachedData && smiResult.cached != null) {
        final smiData = smiResult.cached!.result;
        if (smiData.historical.isNotEmpty) {
          latestSMI = smiData.historical.last.value;
          smiTimeseries = {
            'historical': smiData.historical.map((p) => {'date': p.date, 'value': p.value}).toList(),
            'forecast': smiData.forecast.map((p) => {'date': p.date, 'value': p.value}).toList(),
          };
        }
      }

      debugPrint('[Irrigation] Latest SMI: $latestSMI');

      // 2. Fetch irrigation-specific LLM reasoning using TakeAction service
      // This passes SMI data to CNN+LSTM clustering and then to LLM
      debugPrint('[Irrigation] Fetching LLM reasoning with SMI context...');
      final irrigationResult = await TakeActionService.fetchReasoning(
        centerLat: widget.centerLat,
        centerLon: widget.centerLon,
        fieldSizeHectares: widget.fieldSizeHectares,
        category: 'irrigation',
        indicesTimeseries: {'SMI': smiTimeseries},
        farmerProfile: widget.farmerProfile,
      );

      // 3. Fetch weather forecast (basic implementation - can be enhanced)
      final weatherData = await _fetchWeatherForecast();

      if (mounted) {
        setState(() {
          _smiValue = latestSMI;
          _irrigationResult = irrigationResult;
          
          // Determine moisture level from SMI value
          // SMI ranges from -1 to 1, where higher = more moisture
          if (latestSMI > 0.2) {
            _moistureLevel = 'High';
          } else if (latestSMI > 0.0) {
            _moistureLevel = 'Moderate';
          } else if (latestSMI > -0.2) {
            _moistureLevel = 'Low';
          } else {
            _moistureLevel = 'Dry';
          }

          // Use LLM recommendations if available
          if (irrigationResult != null) {
            _soilMoistureAdvice = irrigationResult.recommendations.isNotEmpty
                ? irrigationResult.recommendations
                : irrigationResult.detailedAnalysis;
            
            // Extract crop stage info from detailed analysis
            _cropStage = irrigationResult.detailedAnalysis.isNotEmpty
                ? irrigationResult.detailedAnalysis
                : 'Crop stage analysis based on current SMI: $_moistureLevel (${latestSMI.toStringAsFixed(3)})';
          } else {
            // Fallback to SMI-based recommendations
            _soilMoistureAdvice = _generateSMIAdvice(latestSMI);
            _cropStage = 'Based on SMI analysis: Current soil moisture is $_moistureLevel. '
                'Monitor irrigation needs based on crop growth stage.';
          }

          _weatherForecast = weatherData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Irrigation] Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _soilMoistureAdvice = 'Unable to load real-time data. Please try again.';
          _cropStage = 'Error loading crop stage data.';
        });
      }
    }
  }

  String _generateSMIAdvice(double smi) {
    if (smi > 0.2) {
      return 'Soil moisture is currently HIGH (SMI: ${smi.toStringAsFixed(3)}). '
          'Reduce irrigation to prevent waterlogging and root stress. '
          'Allow soil to dry slightly before next watering.';
    } else if (smi > 0.0) {
      return 'Soil moisture is MODERATE (SMI: ${smi.toStringAsFixed(3)}). '
          'Continue regular irrigation schedule. '
          'Monitor for next 2-3 days before adjusting.';
    } else if (smi > -0.2) {
      return 'Soil moisture is LOW (SMI: ${smi.toStringAsFixed(3)}). '
          'Consider increasing irrigation frequency. '
          'Check for signs of water stress in crops.';
    } else {
      return 'Soil is DRY (SMI: ${smi.toStringAsFixed(3)}). '
          'URGENT: Increase irrigation immediately. '
          'Implement water conservation measures if possible.';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWeatherForecast() async {
    // Fetch real weather data from Open-Meteo API (free, no API key required)
    try {
      debugPrint('[Irrigation] Fetching weather from Open-Meteo...');
      
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${widget.centerLat}'
        '&longitude=${widget.centerLon}'
        '&daily=temperature_2m_max,precipitation_probability_max,weathercode'
        '&timezone=auto'
        '&forecast_days=7'
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final daily = data['daily'];
        
        if (daily != null) {
          final dates = List<String>.from(daily['time'] ?? []);
          final temps = List<num>.from(daily['temperature_2m_max'] ?? []);
          final rainProbs = List<num>.from(daily['precipitation_probability_max'] ?? []);
          final weatherCodes = List<num>.from(daily['weathercode'] ?? []);
          
          final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
          
          return List.generate(dates.length.clamp(0, 7), (i) {
            final date = DateTime.parse(dates[i]);
            final dayName = dayNames[date.weekday % 7];
            final temp = temps.length > i ? temps[i].round() : 25;
            final rain = rainProbs.length > i ? rainProbs[i].round() : 0;
            final code = weatherCodes.length > i ? weatherCodes[i].toInt() : 0;
            
            return {
              'day': dayName,
              'temp': '$temp°',
              'condition': _getConditionFromCode(code),
              'rain': '$rain%',
            };
          });
        }
      }
      
      debugPrint('[Irrigation] Weather API failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('[Irrigation] Weather fetch error: $e');
    }
    
    // Fallback to empty list if API fails
    return [];
  }

  /// Convert WMO weather code to condition string
  String _getConditionFromCode(int code) {
    // WMO Weather interpretation codes
    // https://open-meteo.com/en/docs
    if (code == 0) return 'Sunny';
    if (code <= 3) return 'Cloudy';
    if (code <= 49) return 'Foggy';
    if (code <= 59) return 'Drizzle';
    if (code <= 69) return 'Rainy';
    if (code <= 79) return 'Snowy';
    if (code <= 84) return 'Rainy';
    if (code <= 94) return 'Rainy';
    if (code <= 99) return 'Storm';
    return 'Cloudy';
  }


  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F3),
      bottomNavigationBar: const AdaptiveBottomNavBar(page: ActivePage.tools),
      body: Stack(
        children: [
          // Background Image (Header)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/backsmall.png',
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
          ),
          // Content
          Column(
            children: [
              // Custom AppBar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),
                      Expanded(
                        child: Consumer<LocalizationProvider>(
                          builder: (context, loc, _) => Text(
                            loc.tr('irrigation_scheduling'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Balance for back button
                    ],
                  ),
                ),
              ),
              // Main Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSoilMoistureSection(),
                            const SizedBox(height: 20),
                            _buildCropStageSection(),
                            const SizedBox(height: 20),
                            _buildWeatherSection(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildSoilMoistureSection() {
    final loc = Provider.of<LocalizationProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Soil Moisture',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Left card: How to get it better
            Expanded(
              flex: 2,
              child: Container(
                height: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to get it better',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        _soilMoistureAdvice,
                        style: const TextStyle(fontSize: 11, height: 1.4),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Right card: Moisture Level
            Expanded(
              child: Container(
                height: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Moisture Level',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getMoistureColor(),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _moistureLevel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SMI: ${_smiValue.toStringAsFixed(3)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionRow(
          onChatbot: _navigateToChatbot, 
          buttonLabel: loc.tr('detailed_pathway'),
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IrrigationDetailedPathwayScreen(
                fieldName: widget.fieldName,
                centerLat: widget.centerLat,
                centerLon: widget.centerLon,
                fieldSizeHectares: widget.fieldSizeHectares,
                fieldPolygon: widget.fieldPolygon,
                farmerProfile: widget.farmerProfile,
                currentSMI: _smiValue,
                moistureLevel: _moistureLevel,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCropStageSection() {
    final loc = Provider.of<LocalizationProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.tr('crop_stage_statistics'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F8E0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.tr('what_stage_crop_is'),
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text(
                _cropStage,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildActionRow(onChatbot: _navigateToChatbot, buttonLabel: 'Detailed Report'),
      ],
    );
  }

  Widget _buildWeatherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Left: Red accent box
            Container(
              width: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Predicted\nWeather\nData',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Coming 7 days',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right: Weather description
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weather Data for coming 7 days',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Plan your irrigation based on upcoming weather patterns.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 7-day forecast cards
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _weatherForecast.length,
            itemBuilder: (context, index) {
              final day = _weatherForecast[index];
              return Container(
                width: 70,
                margin: EdgeInsets.only(right: index < _weatherForecast.length - 1 ? 8 : 0),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8E0),
                  borderRadius: BorderRadius.circular(10),
                  border: index == 0 ? Border.all(color: const Color(0xFF167339), width: 2) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day['day'],
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      _getWeatherIcon(day['condition']),
                      size: 20,
                      color: _getWeatherIconColor(day['condition']),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      day['temp'],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '🌧 ${day['rain']}',
                      style: const TextStyle(fontSize: 9, color: Colors.blue),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow({required VoidCallback onChatbot, required String buttonLabel, VoidCallback? onAction}) {
    // Note: This method was incorrectly nested. Moving implementation to class level.
    // Also fixing specific parameters logic.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Home icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.home, size: 18, color: Color(0xFF167339)),
          ),
          const SizedBox(width: 8),
          // Chat icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF167339)),
          ),
          const SizedBox(width: 12),
          // Ask Chatbot text
          GestureDetector(
            onTap: onChatbot,
            child: const Text(
              'Ask Chatbot',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const Spacer(),
          // Action button
          GestureDetector(
            onTap: onAction ?? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$buttonLabel - Coming soon')),
                );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF167339),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Color _getMoistureColor() {
    switch (_moistureLevel.toLowerCase()) {
      case 'high':
        return Colors.blue;
      case 'moderate':
        return Colors.green;
      case 'low':
        return Colors.orange;
      case 'dry':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'sunny':
        return Icons.wb_sunny;
      case 'cloudy':
        return Icons.cloud;
      case 'foggy':
        return Icons.foggy;
      case 'drizzle':
        return Icons.grain;
      case 'rainy':
        return Icons.umbrella;
      case 'snowy':
        return Icons.ac_unit;
      case 'storm':
        return Icons.flash_on;
      default:
        return Icons.cloud;
    }
  }

  Color _getWeatherIconColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'sunny':
        return Colors.orange;
      case 'cloudy':
        return Colors.grey;
      case 'foggy':
        return Colors.blueGrey;
      case 'drizzle':
        return Colors.lightBlue;
      case 'rainy':
        return Colors.blue;
      case 'snowy':
        return Colors.cyan;
      case 'storm':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }


  void _navigateToChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatbotScreen()),
    );
  }
}
