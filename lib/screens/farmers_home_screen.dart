import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sidebar_drawer.dart';
import '../widgets/farmers_bottom_nav_bar.dart';
import 'analytics_screen.dart';
import 'news_screen.dart';
import 'view_notes_screen.dart';
import 'chatbot_screen.dart';
import 'package:agroww_sih/services/sentinel2_service.dart';
import 'package:agroww_sih/services/sar_analysis_service.dart';
import 'package:agroww_sih/screens/knowledge_hub_screen.dart';
import 'package:agroww_sih/screens/notification_page.dart';
import 'package:agroww_sih/services/take_action_service.dart';
import 'package:agroww_sih/services/localization_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Farmers Home Screen - Simplified UI for farmers with soil status indicators
class FarmersHomeScreen extends StatefulWidget {
  const FarmersHomeScreen({super.key});

  @override
  State<FarmersHomeScreen> createState() => _FarmersHomeScreenState();
}

class _FarmersHomeScreenState extends State<FarmersHomeScreen> {
  final _supabase = Supabase.instance.client;
  final _auth = FirebaseAuth.instance;
  
  final _sentinelService = Sentinel2Service();
  final _sarService = SarAnalysisService();
  
  bool _isLoading = true;
  bool _isLoadingS2 = false;
  bool _isLoadingSar = false;
  
  String _userName = 'Farmer';
  String? _s2Error;
  String? _sarError;
  
  // Field data
  Map<String, dynamic>? _selectedField;
  List<Map<String, dynamic>> _fields = [];
  
  // Analysis Data
  Map<String, dynamic>? _s2LlmAnalysis;
  Map<String, dynamic>? _sarLlmAnalysis;
  List<Map<String, dynamic>>? _weatherData;
  TakeActionResult? _nutrientAnalysis;
  bool _isLoadingNutrient = false;
  
  // Carousel Controller
  final PageController _pageController = PageController(viewportFraction: 0.93);
  int _currentCarouselIndex = 0;
  
  // Soil status values
  double _soilMoisture = 0.35;
  double _soilFertility = 0.85;
  double _overallSoilHealth = 0.625;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    await _loadUserData();
    await _loadFields();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final profile = await _supabase
            .from('user_profiles')
            .select('name')
            .eq('user_id', user.uid)
            .maybeSingle();
        
        if (profile != null && mounted) {
          setState(() {
            _userName = profile['name'] ?? 'Farmer';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }
  
  Future<void> _loadFields() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final data = await _supabase
          .from('coordinates_quad')
          .select()
          .eq('user_id', user.uid)
          .order('created_at', ascending: false);
      
      if (data.isNotEmpty && mounted) {
        var fields = List<Map<String, dynamic>>.from(data);
        
        // For guest users, filter to only show fields created during this session
        if (user.isAnonymous) {
          final prefs = await SharedPreferences.getInstance();
          final sessionStart = prefs.getString('guest_session_start');
          if (sessionStart != null) {
            final sessionDateTime = DateTime.parse(sessionStart);
            fields = fields.where((field) {
              final createdAt = field['created_at'];
              if (createdAt == null) return true; // Show if no timestamp
              try {
                final fieldDateTime = DateTime.parse(createdAt.toString());
                return fieldDateTime.isAfter(sessionDateTime);
              } catch (e) {
                return true; // Show if parsing fails
              }
            }).toList();
          }
        }
        
        setState(() {
          _fields = fields;
          _selectedField = fields.isNotEmpty ? fields.first : null;
        });
        
        // Fetch data for the selected field
        if (_selectedField != null) {
          _fetchSentinel2Analysis(_selectedField!);
          _fetchSarAnalysis(_selectedField!);
          _fetchNutrientAnalysis(_selectedField!);
        }
      }
    } catch (e) {
      debugPrint('Error loading fields: $e');
    }
  }

  Future<void> _fetchNutrientAnalysis(Map<String, dynamic> field) async {
    if (!mounted) return;
    setState(() => _isLoadingNutrient = true);

    try {
      // Extract coordinates
      double lat = 20.5937;
      double lon = 78.9629;
      final coords = field['coordinates'];
      if (coords is List && coords.isNotEmpty) {
           final first = coords[0];
           if (first is Map) {
              lat = (first['lat'] ?? lat).toDouble();
              lon = (first['lng'] ?? first['lon'] ?? lon).toDouble();
           } else if (first is List) {
             lat = (first as List)[1].toDouble();
             lon = first[0].toDouble();
           }
      }
      
      double area = 10.0;
      if (field['area_acres'] != null) {
         area = double.tryParse(field['area_acres'].toString()) ?? 10.0;
      }
      double hectares = area * 0.4047;

      // Mock farmer profile for context
      final farmerProfile = {
        'crop_type': field['crop_type'] ?? 'General',
        'field_size': hectares,
      };

      final result = await TakeActionService.fetchReasoning(
        centerLat: lat,
        centerLon: lon,
        fieldSizeHectares: hectares,
        category: 'nutrient', // Fetch nutrient stress specific data (includes stress zones)
        farmerProfile: farmerProfile,
      );

      if (mounted) {
        setState(() {
          _nutrientAnalysis = result;
          _isLoadingNutrient = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching nutrient analysis: $e");
      if (mounted) setState(() => _isLoadingNutrient = false);
    }
  }

  Future<void> _fetchSentinel2Analysis(Map<String, dynamic> field) async {
    if (!mounted) return;
    setState(() {
      _isLoadingS2 = true;
      _s2Error = null;
    });

    try {
      // Extract data
      double lat = 20.5937;
      double lon = 78.9629;
      final coords = field['coordinates'];
      if (coords is List && coords.isNotEmpty) {
           final first = coords[0];
           if (first is Map) {
              lat = (first['lat'] ?? lat).toDouble();
              lon = (first['lng'] ?? first['lon'] ?? lon).toDouble();
           } else if (first is List) {
             lat = (first as List)[1].toDouble();
             lon = first[0].toDouble();
           }
      }
      
      double area = 10.0;
      if (field['area_acres'] != null) {
         area = double.tryParse(field['area_acres'].toString()) ?? 10.0;
      }
      double hectares = area * 0.4047;
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final result = await _sentinelService.analyzeField(
        centerLat: lat,
        centerLon: lon,
        cropType: field['crop_type'] ?? 'Farming',
        analysisDate: today,
        fieldSizeHectares: hectares,
        farmerContext: {},
      );

      if (mounted) {
        setState(() {
          _s2LlmAnalysis = result['llm_analysis'] is String 
              ? {} // handle parsing if needed or simplify
              : result['llm_analysis']; 
              // Note: Sentinel2Service might return String or Map depending on implementation/backend.
              // Assuming Map based on usage. 
          if (_s2LlmAnalysis == null && result['summary'] != null) {
             _s2LlmAnalysis = {'pest_risk': result['summary']}; // Fallback
          }
          _isLoadingS2 = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching Sentinel-2 analysis: $e");
      if (mounted) {
        setState(() {
          _s2Error = e.toString();
          _isLoadingS2 = false;
        });
      }
    }
  }

  Future<void> _fetchSarAnalysis(Map<String, dynamic> field) async {
    if (!mounted) return;
    setState(() {
      _isLoadingSar = true;
      _sarError = null;
    });

    try {
      // Extract bounding box from lat1/lon1 format (same as home_screen.dart)
      List<double> bbox = _parseCoordinatesToBbox(field);
      
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final result = await _sarService.analyzeField(
        coordinates: bbox,
        date: today,
        cropType: field['crop_type'] ?? 'Farming',
        context: {},
      );

      if (mounted) {
        setState(() {
          _sarLlmAnalysis = result['llm_analysis'];
          if (result['weather_data'] != null) {
             if (result['weather_data'] is List) {
                _weatherData = List<Map<String, dynamic>>.from(result['weather_data']);
             } else {
                _weatherData = [result['weather_data']];
             }
          }
          _isLoadingSar = false;
        });
      }
    } catch (e) {
       debugPrint("Error fetching SAR analysis: $e");
       if (mounted) {
        setState(() {
          _sarError = e.toString();
          _isLoadingSar = false;
        });
      }
    }
  }
  
  // Get color based on health value (0.0 to 1.0)
  Color _getHealthColor(double value) {
    if (value <= 0) return Colors.grey.shade300; // No data
    if (value <= 0.2) return const Color(0xFFE53935); // Red - Critical
    if (value <= 0.4) return const Color(0xFFFF9800); // Orange - Low
    if (value <= 0.6) return const Color(0xFFFFEB3B); // Yellow - Moderate
    if (value <= 0.8) return const Color(0xFF4CAF50); // Green - Good
    return const Color(0xFF7CFC00); // Bright Green - Excellent
  }
  
  // Get label based on health value
  String _getHealthLabel(double value) {
    if (value <= 0) return 'No Data';
    if (value <= 0.2) return 'Critical';
    if (value <= 0.4) return 'Low';
    if (value <= 0.6) return 'Moderate';
    if (value <= 0.8) return 'Good';
    return 'Excellent';
  }
  
  // Get simple description for farmers
  String _getSoilDescription(String type, double value) {
    if (value <= 0) return 'Data not available';
    
    switch (type) {
      case 'moisture':
        if (value <= 0.4) return 'Needs watering';
        if (value <= 0.7) return 'Water level is okay';
        return 'Well watered';
      case 'fertility':
        if (value <= 0.4) return 'Add fertilizer soon';
        if (value <= 0.7) return 'Fertility is moderate';
        return 'Soil is very fertile';
      case 'organic':
        if (value <= 0.4) return 'Add compost';
        if (value <= 0.7) return 'Organic matter okay';
        return 'Rich in organic matter';
      case 'salinity':
        if (value <= 0.4) return 'Salt level is high';
        if (value <= 0.7) return 'Salt level moderate';
        return 'Salt level is good';
      case 'greenness':
        if (value <= 0.4) return 'Low vegetation';
        if (value <= 0.7) return 'Moderate vegetation';
        return 'Healthy vegetation';
      case 'growth':
        if (value <= 0.4) return 'Slow growth';
        if (value <= 0.7) return 'Steady growth';
        return 'Rapid growth';
      case 'nitrogen':
        if (value <= 0.4) return 'Low nitrogen';
        if (value <= 0.7) return 'Moderate nitrogen';
        return 'Optimal nitrogen';
      case 'photosynthesis':
        if (value <= 0.4) return 'Low activity';
        if (value <= 0.7) return 'Moderate activity';
        return 'High activity';
      case 'risk_low_good':
        if (value <= 0.4) return 'High Risk / Alert';
        if (value <= 0.7) return 'Moderate Risk';
        return 'Low Risk / Safe';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      drawer: const SidebarDrawer(),
      bottomNavigationBar: const FarmersBottomNavBar(selectedIndex: 0),
      body: Stack(
        children: [
          // Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/backsmall.png',
              fit: BoxFit.fitWidth, // Changed to fitWidth to prevent overflow on wide screens
              alignment: Alignment.topCenter,
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(context),
                
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        
                        // Search bar
                        _buildSearchBar(),
                        
                        const SizedBox(height: 20),
                        
                        // Carousel for Soil, Crop, Weather, Bio Risk
                        _buildStatusCarousel(),
                        
                        const SizedBox(height: 20),
                        
                        // Action Buttons
                        _buildActionButtons(),
                        
                        const SizedBox(height: 100), // Space for bottom nav
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF1B4D3E)),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0.0),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 28),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Expanded(
            child: Center(
              child: Image.asset('assets/Frame 5.png', height: 40),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationPage()),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    if (_fields.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PopupMenuButton<Map<String, dynamic>>(
        offset: const Offset(0, 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedField?['name'] ?? 'Select Field',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF0F3C33),
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Color(0xFF167339)),
            ],
          ),
        ),
        onSelected: (Map<String, dynamic> selection) {
          if (selection != _selectedField) {
            setState(() {
              _selectedField = selection;
            });
            _fetchSarAnalysis(selection);
            _fetchSentinel2Analysis(selection);
          }
        },
        itemBuilder: (BuildContext context) {
          return _fields.map((Map<String, dynamic> field) {
            return PopupMenuItem<Map<String, dynamic>>(
              value: field,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field['name'] ?? 'Unnamed Field',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F3C33),
                    ),
                  ),
                  Text(
                    "${field['crop_type'] ?? 'Crop'} • ${field['area_acres']?.toStringAsFixed(2) ?? '0.0'} acres",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        },
      ),
    );
  }
  
  Widget _buildStatusCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 420, // Adjusted height for content
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentCarouselIndex = page;
              });
            },
            itemCount: 4,
            itemBuilder: (context, index) {
               return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.2)).clamp(0.0, 1.0);
                  } else {
                    value = (index == _currentCarouselIndex) ? 1.0 : 0.9;
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 420,
                      width: Curves.easeOut.transform(value) * 450,
                      child: child,
                    ),
                  );
                },
                child: [
                  _buildSoilStatusSlide(),
                  _buildCropStatusSlide(),
                  _buildWeatherStatusSlide(),
                  _buildBioRiskSlide(),
                ][index],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _currentCarouselIndex == index ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _currentCarouselIndex == index ? const Color(0xFF1B4D3E) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  // --- SLIDE BUILDERS ---
  
  // 1. Soil Status (Refactored existing card)
  Widget _buildSoilStatusSlide() {
    final loc = context.watch<LocalizationProvider>();
    final llm = _s2LlmAnalysis;
    // Extract real values if available, else use mock/default
    double moisture = 0.4;
    double fertility = 0.7;
    double organic = 0.5;
    double salinity = 0.3;
    
    if (llm != null) {
      if (llm['soil_moisture'] != null) moisture = _parseLevel(llm['soil_moisture']['level']);
      if (llm['soil_fertility'] != null) fertility = _parseLevel(llm['soil_fertility']['level']);
      if (llm['organic_matter'] != null) organic = _parseLevel(llm['organic_matter']['level']);
      if (llm['soil_salinity'] != null) salinity = _parseLevel(llm['soil_salinity']['level'], invert: true);
    }
  
    return _buildFarmerCard(
      title: loc.tr('soil_status'),
      icon: Icons.layers,
      isLoading: _isLoadingS2,
      child: Column(
        children: [
          _buildSoilIndexRow(icon: Icons.water_drop_outlined, title: loc.tr('soil_moisture'), value: moisture, type: 'moisture'),
          const Divider(height: 16),
          _buildSoilIndexRow(icon: Icons.eco_outlined, title: loc.tr('soil_fertility'), value: fertility, type: 'fertility'),
          const Divider(height: 16),
          _buildSoilIndexRow(icon: Icons.grass_outlined, title: loc.tr('organic_matter'), value: organic, type: 'organic'),
          const Divider(height: 16),
          _buildSoilIndexRow(icon: Icons.science_outlined, title: loc.tr('salinity'), value: salinity, type: 'salinity'),
          const Spacer(),
          _buildOverallHeathBar((moisture + fertility + organic + (1-salinity))/4, label: loc.tr('overall_health')),
        ],
      ),
    );
  }
  
  // 2. Crop Status
  Widget _buildCropStatusSlide() {
    final loc = context.watch<LocalizationProvider>();
    final llm = _sarLlmAnalysis;
    double greenness = 0.5;
    double growth = 0.5;
    double nitrogen = 0.5;
    double photosynthesis = 0.5;
    
    if (llm != null) {
       if (llm['greenness'] != null) greenness = _parseLevel(llm['greenness']['level']);
       if (llm['biomass'] != null) growth = _parseLevel(llm['biomass']['level']);
       if (llm['nitrogen'] != null) nitrogen = _parseLevel(llm['nitrogen']['level']);
       if (llm['photosynthesis'] != null) photosynthesis = _parseLevel(llm['photosynthesis']['level']);
    }
    
    return _buildFarmerCard(
      title: loc.tr('crop_status'),
      icon: Icons.grass,
      isLoading: _isLoadingSar,
      child: Column(
        children: [
          _buildSoilIndexRow(icon: Icons.eco, title: loc.tr('greenness'), value: greenness, type: 'greenness'),
          const Divider(height: 16),
          _buildSoilIndexRow(icon: Icons.show_chart, title: loc.tr('growth_rate'), value: growth, type: 'growth'),
          const Divider(height: 16),
          _buildSoilIndexRow(icon: Icons.science, title: loc.tr('nitrogen_level'), value: nitrogen, type: 'nitrogen'),
          const Divider(height: 16),
          _buildSoilIndexRow(icon: Icons.wb_sunny, title: loc.tr('photosynthesis'), value: photosynthesis, type: 'photosynthesis'),
          const Spacer(),
          _buildOverallHeathBar((greenness + growth + nitrogen + photosynthesis)/4, label: loc.tr('crop_health')),
        ],
      ),
    );
  }

  // 3. Weather Status
  Widget _buildWeatherStatusSlide() {
      final loc = context.watch<LocalizationProvider>();
      // Extract from _weatherData
      String temp = "--";
      String rain = "--";
      String humidity = "--";
      String wind = "--";
      
      if (_weatherData != null && _weatherData!.isNotEmpty) {
         final w = _weatherData!.last;
         temp = "${w['temp_mean']?.toInt() ?? w['temp']?.toInt() ?? '--'}°C";
         rain = "${w['precipitation']?.toStringAsFixed(1) ?? '--'} mm";
         humidity = "${w['humidity']?.toInt() ?? '--'}%";
         wind = "${w['wind_speed']?.toInt() ?? '--'} km/h";
      }

      return _buildFarmerCard(
      title: loc.tr('weather_status'),
      icon: Icons.wb_sunny,
      isLoading: _isLoadingSar,
      child: Column(
        children: [
          _buildWeatherRow(Icons.thermostat, loc.tr('temperature'), temp, loc.tr('warm_sunny')),
          const Divider(height: 16),
          _buildWeatherRow(Icons.cloudy_snowing, loc.tr('precipitation'), rain, loc.tr('light_rain')),
          const Divider(height: 16),
          _buildWeatherRow(Icons.water_drop, loc.tr('humidity'), humidity, loc.tr('normal_levels')),
          const Divider(height: 16),
          _buildWeatherRow(Icons.air, loc.tr('wind_speed'), wind, loc.tr('gentle_breeze')),
          const Spacer(),
          Text("${loc.tr('weather_condition')}: ${loc.tr('good')}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B4D3E))),
        ],
      ),
    );
  }

  // 4. Bio Risk & Stress
  Widget _buildBioRiskSlide() {
    final loc = context.watch<LocalizationProvider>();
    double pestRisk = 0.8; // Default Safe
    double diseaseRisk = 0.8; // Default Safe
    double nutrientStress = 0.8; // Default Safe (High Score = Low Stress)
    int stressZonesCount = 0;
    
    final llm = _s2LlmAnalysis;
    if (llm != null) {
       if (llm['pest_risk'] != null) pestRisk = _parseLevel(llm['pest_risk']['level'], invert: true);
       if (llm['disease_risk'] != null) diseaseRisk = _parseLevel(llm['disease_risk']['level'], invert: true);
    }
    
    if (_nutrientAnalysis != null) {
      // Stress Score: 0 (Low Stress/Good) to 1 (High Stress/Bad)
      // We want High Score = Good. So invert.
      nutrientStress = 1.0 - (_nutrientAnalysis!.stressScore.clamp(0.0, 1.0));
      
      // Count zones with High/Moderate severity
      stressZonesCount = _nutrientAnalysis!.highZones.length + _nutrientAnalysis!.lowZones.length; 
      // Note: lowZones in TakeActionResult means Low performance/High Stress? 
      // Let's check ZoneInfo.severity. 
      // Actually highZones usually means High Performance or High Stress depending on context.
      // Heatmap app.py extract_top_stress_zones: 
      // High Stress (Red) -> high_indices
      // Moderate Stress (Yellow) -> moderate_indices
      // Low Stress (Green) -> low_indices
      // TakeActionResult maps these. 
      // Let's assume highZones = High Stress Zones.
      stressZonesCount = _nutrientAnalysis!.highZones.length;
    }
    
    return _buildFarmerCard(
      title: loc.tr('crop_stress_risk'),
      icon: Icons.warning_amber_rounded,
      isLoading: _isLoadingS2 || _isLoadingNutrient,
      child: Column(
        children: [
          _buildSoilIndexRow(icon: Icons.bug_report, title: loc.tr('pest_risk'), value: pestRisk, type: 'risk_low_good'),
          const Divider(height: 12),
          _buildSoilIndexRow(icon: Icons.coronavirus, title: loc.tr('disease_risk'), value: diseaseRisk, type: 'risk_low_good'),
          const Divider(height: 12),
           _buildSoilIndexRow(icon: Icons.science, title: loc.tr('nutrient_stress'), value: nutrientStress, type: 'risk_low_good'),
          const Divider(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: stressZonesCount > 0 ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.layers_outlined,
                  size: 20,
                  color: stressZonesCount > 0 ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.tr('stress_zones'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    stressZonesCount > 0 ? "$stressZonesCount ${loc.tr('areas_detected')}" : loc.tr('none_detected'),
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold,
                      color: stressZonesCount > 0 ? Colors.red : const Color(0xFF1B4D3E),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const Spacer(),
           _buildOverallHeathBar((pestRisk + diseaseRisk + nutrientStress)/3, label: loc.tr('safety_score')),
        ],
      ),
    );
  }

  // --- HELPERS ---
  
  double _parseLevel(String? level, {bool invert = false}) {
    if (level == null) return 0.5;
    level = level.toLowerCase();
    double val = 0.5;
    if (level == 'high') val = 0.8;
    else if (level == 'moderate') val = 0.5;
    else val = 0.2;
    return invert ? (1.0 - val) : val;
  }

  Widget _buildFarmerCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B4D3E)))
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFB8D4B8),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFF1B4D3E), size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B4D3E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
  
  Widget _buildWeatherRow(IconData icon, String title, String value, String desc) {
     return Row(
       children: [
         Icon(icon, color: const Color(0xFF1B4D3E), size: 24),
         const SizedBox(width: 12),
         Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
             Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B4D3E))),
           ],
         ),
         const Spacer(),
         Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
       ],
     );
  }

  Widget _buildOverallHeathBar(double score, {String label = "Overall Health"}) {
    final color = _getHealthColor(score);
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B4D3E))),
        const SizedBox(height: 4),
        Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: List.generate(10, (index) {
             final isFilled = index < (score * 10).ceil();
             return Container(
               width: 20,
               height: 8,
               margin: const EdgeInsets.symmetric(horizontal: 1),
               decoration: BoxDecoration(
                 color: isFilled ? color : Colors.grey.shade200,
                 borderRadius: BorderRadius.circular(2),
               ),
             );
           }),
        ),
      ],
    );
  }
  
  Widget _buildSoilIndexRow({
    required IconData icon,
    required String title,
    required double value,
    required String type,
  }) {
    final color = _getHealthColor(value);
    final label = _getHealthLabel(value);
    final description = _getSoilDescription(type, value);
    
    return Row(
      children: [
        // Icon
        Icon(icon, color: const Color(0xFF1B4D3E), size: 22),
        const SizedBox(width: 10),
        
        // Title, label and description
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B4D3E),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color == Colors.grey.shade300 ? Colors.grey : color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Health bar
        SizedBox(
          width: 90,
          child: _buildHealthBar(value, color),
        ),
      ],
    );
  }
  
  Widget _buildHealthBar(double value, Color color) {
    const int totalSegments = 10;
    final int filledSegments = value <= 0 ? 0 : (value * totalSegments).ceil().clamp(0, totalSegments);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: List.generate(totalSegments, (index) {
        final isFilled = index < filledSegments;
        return Container(
          width: 7,
          height: 20,
          margin: const EdgeInsets.only(left: 1),
          decoration: BoxDecoration(
            color: isFilled ? color : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
  
  
  
  Widget _buildActionButtons() {
    final loc = context.watch<LocalizationProvider>();
    return Column(
      children: [
        Row(
          children: [
            // Knowledge Hub
            Expanded(
              child: _buildActionButton(
                icon: Icons.menu_book_outlined,
                label: loc.tr('knowledge_hub'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KnowledgeHubPlaceholderScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Visual Analytics
            Expanded(
              child: _buildActionButton(
                icon: Icons.bar_chart_outlined,
                label: loc.tr('visual_analytics'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Newsletter
            Expanded(
              child: _buildActionButton(
                icon: Icons.newspaper_outlined,
                label: loc.tr('newsletter'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewsScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Notes
            Expanded(
              child: _buildActionButton(
                icon: Icons.note_alt_outlined,
                label: loc.tr('notes'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ViewNotesScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1B4D3E), size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B4D3E),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Parse coordinates from field data (lat1/lon1 format from Supabase) to bounding box
  /// Returns [minLon, minLat, maxLon, maxLat] format expected by SAR service
  List<double> _parseCoordinatesToBbox(Map<String, dynamic> data) {
    List<double> lats = [];
    List<double> lons = [];

    // Check for flat structure (lat1, lon1, etc.) - this is how Supabase stores it
    for (int i = 1; i <= 4; i++) {
      if (data.containsKey('lat$i') && data.containsKey('lon$i')) {
        final lat = data['lat$i'];
        final lon = data['lon$i'];
        if (lat != null && lon != null) {
          lats.add((lat as num).toDouble());
          lons.add((lon as num).toDouble());
        }
      }
    }

    // Fallback: if lat/lon columns not found, try 'coordinates' array format
    if (lats.isEmpty || lons.isEmpty) {
      final coords = data['coordinates'];
      if (coords is List && coords.isNotEmpty) {
        for (var point in coords) {
          if (point is Map) {
            final lat = point['lat'] ?? point['latitude'];
            final lon = point['lng'] ?? point['lon'] ?? point['longitude'];
            if (lat != null && lon != null) {
              lats.add((lat as num).toDouble());
              lons.add((lon as num).toDouble());
            }
          } else if (point is List && point.length >= 2) {
            lats.add((point[1] as num).toDouble());
            lons.add((point[0] as num).toDouble());
          }
        }
      }
    }

    // If still empty, use default India coordinates
    if (lats.isEmpty || lons.isEmpty) {
      debugPrint("Warning: No valid coordinates found, using defaults");
      return [78.95, 20.58, 78.97, 20.60]; // Default near India
    }

    double minLat = lats.reduce((curr, next) => curr < next ? curr : next);
    double maxLat = lats.reduce((curr, next) => curr > next ? curr : next);
    double minLon = lons.reduce((curr, next) => curr < next ? curr : next);
    double maxLon = lons.reduce((curr, next) => curr > next ? curr : next);

    // Return bounding box: [minLon, minLat, maxLon, maxLat]
    return [minLon, minLat, maxLon, maxLat];
  }
}
