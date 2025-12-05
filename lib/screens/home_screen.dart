import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:agroww_sih/screens/sidebar_drawer.dart';
import 'package:agroww_sih/screens/notification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agroww_sih/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:agroww_sih/screens/locate_farmland_screen.dart';
import 'package:agroww_sih/screens/coming_soon_screen.dart';
import 'package:agroww_sih/screens/full_screen_map_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agroww_sih/services/sar_analysis_service.dart';
import 'package:agroww_sih/services/sentinel2_service.dart';
import 'package:agroww_sih/screens/camera_screen.dart';
import 'package:agroww_sih/screens/gallery_screen.dart';
import 'package:agroww_sih/screens/news_screen.dart';
import 'package:agroww_sih/screens/export_reports_screen.dart';
import 'package:agroww_sih/screens/settings_screen.dart';
import 'package:agroww_sih/screens/infographics_screen.dart';
import 'package:agroww_sih/screens/chatbot_screen.dart';
import 'package:agroww_sih/screens/take_action_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _avatarUrl;
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;
  Timer? _timer;

  // SAR Data State
  bool _isLoadingSar = true;
  Map<String, dynamic>? _sarData;
  Map<String, dynamic>? _healthSummary;
  List<dynamic>? _stressedPatches;
  List<dynamic>? _weatherData;
  String? _sarError;

  // Sentinel-2 Data State
  bool _isLoadingS2 = false;
  Map<String, dynamic>? _s2Data;
  Map<String, dynamic>? _s2LlmAnalysis;
  String? _s2Error;

  // Loading Messages State
  int _currentLoadingMessageIndex = 0;
  Timer? _loadingMessageTimer;
  final List<String> _loadingMessages = [
    "Analyzing satellite imagery...",
    "Calculating vegetation indices...",
    "Checking for pest risks...",
    "Evaluating soil moisture levels...",
    "Generating crop health report..."
  ];
  final TextEditingController _fieldSearchController = TextEditingController();
  final List<String> _menuItems = const [
    "Add a Farmland", "Add a Farmland 2", "Camera", "My Gallery",
    "News", "View Previous Analytics", "AI Chatbot", "Predicted Analytics & Data",
    "Analytics Page", "Mapped Analytics", "Infographics",
    "Export Analytic Report", "Download Raw Data",
    "View Map", "View Profile", "Settings"
  ];

  // Field Selection State
  List<Map<String, dynamic>> _farmlands = [];
  Map<String, dynamic>? _selectedField;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _setupNotifications();
    _startAutoScroll();
    _checkFarmlands();
  }

  Future<void> _checkFarmlands() async {
    // Small delay to ensure build context is ready
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    try {
      final supabase = Supabase.instance.client;
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final guestId = prefs.getString('guest_user_id');

      dynamic query = supabase.from('coordinates_quad').select('id, name, crop_type, area_acres, lat1, lon1, lat2, lon2, lat3, lon3, lat4, lon4');

      if (user != null) {
        query = query.eq('user_id', user.uid);
      } else if (guestId != null) {
        query = query.eq('user_id', guestId);
      } else {
        if (mounted) setState(() => _isLoadingSar = false);
        return;
      }

      final response = await query;
      final List data = response as List;

      if (data.isEmpty && mounted) {
        // No farmlands found, redirect to Add Farmland
        setState(() => _isLoadingSar = false); // Stop loading
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LocateFarmlandScreen()),
        );
      } else if (data.isNotEmpty) {
        // Fetch user profile for context
        Map<String, dynamic>? userContext;
        if (user != null) {
          try {
            final profile = await supabase
                .from('user_profiles')
                .select('questionnaire_data')
                .eq('user_id', user.uid)
                .single();
            
            if (profile['questionnaire_data'] != null) {
              userContext = profile['questionnaire_data'] as Map<String, dynamic>;
            }
          } catch (e) {
            debugPrint("Error fetching user profile: $e");
          }
        }

        // Farmlands exist, store them and select the first one
        setState(() {
          _farmlands = List<Map<String, dynamic>>.from(data);
          _selectedField = _farmlands.first;
          _fieldSearchController.text = _selectedField!['name'] ?? '';
        });
        
        // Fetch analysis for the selected field
        _fetchSarAnalysis(_selectedField!, userContext: userContext);
      } else {
         if (mounted) setState(() => _isLoadingSar = false);
      }
    } catch (e) {
      debugPrint("Error checking farmlands: $e");
      if (mounted) setState(() => _isLoadingSar = false);
    }
  }

  Future<void> _fetchSarAnalysis(Map<String, dynamic> fieldData, {Map<String, dynamic>? userContext}) async {
    try {
      // Parse coordinates from field data
      List<double> bbox;
      try {
        bbox = _parseCoordinates(fieldData);
      } catch (e) {
        debugPrint("Error parsing coordinates, using default: $e");
        bbox = [75.8350, 30.9060, 75.8370, 30.9090];
      }

      final service = SarAnalysisService();
    
    if (mounted) {
       setState(() {
         _isLoadingSar = true;
         _sarError = null;
       });
       _startLoadingMessages();
    }

    final result = await service.analyzeField(
      coordinates: bbox,
      date: DateTime.now().toIso8601String().split('T')[0], // Today
      cropType: fieldData['crop_type'] ?? 'Wheat',
      context: userContext,
    );

    if (mounted) {
      debugPrint("SAR Analysis Result Keys: ${result.keys.toList()}");
      debugPrint("Health Summary: ${result['health_summary']}");
      debugPrint("Stressed Patches: ${result['stressed_patches']}");
      
      _stopLoadingMessages();
      setState(() {
        _sarData = result;
        _healthSummary = result['health_summary'];
        _stressedPatches = result['stressed_patches'];
        _weatherData = result['weather_data'];
        _isLoadingSar = false;
      });
      
      // Also fetch Sentinel-2 analysis for soil data
      _fetchSentinel2Analysis(fieldData);
      
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Field Analysis Updated")),
        );
      }
    } catch (e) {
    debugPrint("Error fetching SAR analysis: $e");
    if (mounted) {
      _stopLoadingMessages();
      setState(() {
        _isLoadingSar = false;
        _sarError = e.toString();
      });
      // Still try Sentinel-2 even if SAR fails
      _fetchSentinel2Analysis(fieldData);
    }
  }
}

  Future<void> _fetchSentinel2Analysis(Map<String, dynamic> fieldData) async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingS2 = true;
      _s2Error = null;
    });

    try {
      // Calculate center lat/lon from field coordinates
      double centerLat = 0;
      double centerLon = 0;
      int count = 0;
      
      for (int i = 1; i <= 4; i++) {
        if (fieldData['lat$i'] != null && fieldData['lon$i'] != null) {
          centerLat += (fieldData['lat$i'] as num).toDouble();
          centerLon += (fieldData['lon$i'] as num).toDouble();
          count++;
        }
      }
      
      if (count > 0) {
        centerLat /= count;
        centerLon /= count;
      } else {
        // Default coordinates if none found
        centerLat = 30.9060;
        centerLon = 75.8350;
      }

      final service = Sentinel2Service();
      final result = await service.analyzeField(
        centerLat: centerLat,
        centerLon: centerLon,
        cropType: fieldData['crop_type'] ?? 'Wheat',
        analysisDate: DateTime.now().toIso8601String().split('T')[0],
        fieldSizeHectares: (fieldData['area_acres'] ?? 0.04) * 0.404686, // Convert acres to hectares
        farmerContext: {
          'role': 'Owner-Operator',
          'years_farming': 10,
          'irrigation_method': 'Standard',
          'farming_goal': 'Optimize Yield'
        },
      );

      if (mounted) {
        debugPrint("Sentinel-2 Analysis Result Keys: ${result.keys.toList()}");
        debugPrint("Sentinel-2 LLM Analysis: ${result['llm_analysis']}");
        
        setState(() {
          _s2Data = result;
          _s2LlmAnalysis = result['llm_analysis'];
          _isLoadingS2 = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching Sentinel-2 analysis: $e");
      if (mounted) {
        setState(() {
          _isLoadingS2 = false;
          _s2Error = e.toString();
        });
      }
    }
  }


  @override
  void dispose() {
    _timer?.cancel();
    _loadingMessageTimer?.cancel();
    _fieldSearchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _startLoadingMessages() {
    _currentLoadingMessageIndex = 0;
    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentLoadingMessageIndex = (_currentLoadingMessageIndex + 1) % _loadingMessages.length;
        });
      }
    });
  }

  void _stopLoadingMessages() {
    _loadingMessageTimer?.cancel();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentPage < 3) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
  }

  void _stopAutoScroll() {
    _timer?.cancel();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _avatarUrl = prefs.getString('user_avatar_url');
    });
  }

  void _setupNotifications() {
    NotificationService.onMessageReceived.addListener(() {
      final message = NotificationService.onMessageReceived.value;
      if (message != null && message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification!.title ?? 'New Notification'),
            backgroundColor: const Color(0xFF167339),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPage()),
              ),
            ),
          ),
        );
      }
    });
    _syncFcmToken();
  }

  Future<void> _syncFcmToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await NotificationService.saveTokenToBackend(token);
      }
    } catch (e) {
      debugPrint("Error syncing FCM token: $e");
    }
  }

  void _navigateToItem(String item) {
    if (item == "Add a Farmland") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LocateFarmlandScreen(),
        ),
      );
    } else if (item == "Add a Farmland 2") {
      Navigator.pushNamed(context, '/farmland-map');
    } else if (item == "Camera") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CameraScreen(),
        ),
      );
    } else if (item == "My Gallery") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryScreen(),
        ),
      );
    } else if (item == "Export Analytic Report") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExportReportsScreen(),
        ),
      );
    } else if (item == "News") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsScreen(),
        ),
      );
    } else if (item == "View Previous Analytics" || 
               item == "Predicted Analytics & Data") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ComingSoonScreen(),
        ),
      );
    } else if (item == "AI Chatbot") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatbotScreen(),
        ),
      );
    } else if (item == "Mapped Analytics") {
      Navigator.pushNamed(context, '/coordinate-entry');
    } else if (item == "Settings") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsScreen(),
        ),
      );
    } else if (item == "View Map") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const FullScreenMapPage(),
        ),
      );
    } else if (item == "View Profile") {
      Navigator.pushNamed(context, '/profile').then((_) => _loadAvatar()); // Refresh avatar on return
    } else if (item == "Infographics") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InfographicsScreen(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ComingSoonScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EFEF), // Light mint background
      drawer: const SidebarDrawer(),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 100), // Space for bottom nav
                    child: Column(
                      children: [
                        _buildFieldSelector(),
                        const SizedBox(height: 10),
                        _buildStatusCarousel(),
                        const SizedBox(height: 10),
                        _buildPageIndicator(),
                        const SizedBox(height: 20),
                        _buildActionGrid(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Image.asset(
          'assets/backsmall.png',
          width: double.infinity,
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
        ),
        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Menu Button (Left)
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.menu, color: Colors.white, size: 28),
                  ),
                ),
              ),
              
              // Logo (Center)
              Image.asset('assets/Frame 5.png', height: 40),
              
              // Notification Button (Right)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationPage()),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

    Widget _buildFieldSelector() {
    if (_farmlands.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
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
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final result = await showSearch(
                  context: context,
                  delegate: HomeMenuSearchDelegate(_menuItems),
                );
                if (result != null && result.isNotEmpty) {
                  _navigateToItem(result);
                }
              },
              child: Container(
                color: Colors.transparent, // Hit test
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      "Search...",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 24,
            width: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          PopupMenuButton<Map<String, dynamic>>(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    _selectedField?['name'] ?? 'Select',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F3C33),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF167339)),
              ],
            ),
            onSelected: (Map<String, dynamic> selection) {
              if (selection != _selectedField) {
                setState(() {
                  _selectedField = selection;
                  _isLoadingSar = true;
                  _fieldSearchController.text = selection['name'] ?? '';
                });
                _fetchSarAnalysis(selection);
              }
            },
            itemBuilder: (BuildContext context) {
              return _farmlands.map((Map<String, dynamic> field) {
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
        ],
      ),
    );
  }
  Widget _buildStatusCarousel() {
    return SizedBox(
      height: 400,
      child: GestureDetector(
        onPanDown: (_) => _stopAutoScroll(),
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (int page) {
            setState(() {
              _currentPage = page;
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
                  // Initial state or when controller not ready
                  value = (index == _currentPage) ? 1.0 : 0.8;
                }
                return Center(
                  child: SizedBox(
                    height: Curves.easeOut.transform(value) * 400,
                    width: Curves.easeOut.transform(value) * 450,
                    child: child,
                  ),
                );
              },
              child: [
                _buildSoilStatusCard(),
                _buildWeatherStatusCard(),
                _buildCropStatusCard(),
                _buildPestRiskCard(),
              ][index],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index ? const Color(0xFF167339) : Colors.grey.shade400,
          ),
        );
      }),
    );
  }

  Widget _buildSoilStatusCard() {
    // Show loading state while Sentinel-2 data is being fetched
    if (_isLoadingS2) {
      return _buildCard(
        title: "Soil Status",
        headerColor: const Color(0xFFC6F68D),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF167339)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _loadingMessages[_currentLoadingMessageIndex],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF0F3C33),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Get Sentinel-2 LLM analysis data
    final llm = _s2LlmAnalysis;
    
    // Extract soil data from LLM analysis
    final soilMoisture = llm?['soil_moisture'];
    final soilSalinity = llm?['soil_salinity'];
    final organicMatter = llm?['organic_matter'];
    final soilFertility = llm?['soil_fertility'];
    
    // Calculate overall soil health score
    double soilHealthScore = 0.5; // Default
    if (llm != null && llm['overall_soil_health'] != null) {
      soilHealthScore = (llm['overall_soil_health'] as num).toDouble().clamp(0.0, 1.0);
    } else {
      // Calculate from individual components
      int score = 0;
      int count = 0;
      for (var item in [soilMoisture, soilSalinity, organicMatter, soilFertility]) {
        if (item != null && item['level'] != null) {
          String level = item['level'].toString().toLowerCase();
          if (level == 'high' || level == 'good') score += 3;
          else if (level == 'moderate') score += 2;
          else if (level == 'low') score += 1;
          count++;
        }
      }
      if (count > 0) soilHealthScore = (score / (count * 3)).clamp(0.0, 1.0);
    }

    return _buildCard(
      title: "Soil Status",
      headerColor: const Color(0xFFC6F68D),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildNewStatItem(
                  "Moisture", 
                  _capitalize(soilMoisture?['level'] ?? 'N/A'), 
                  Icons.water_drop_outlined,
                  soilMoisture?['analysis'] ?? 'Analyzing...', 
                  valueColor: _getColorForLevel(soilMoisture?['level'])
                ),
                const SizedBox(width: 8),
                _buildNewStatItem(
                  "Organic", 
                  _capitalize(organicMatter?['level'] ?? 'N/A'), 
                  Icons.eco_outlined,
                  organicMatter?['analysis'] ?? 'Analyzing...', 
                  valueColor: _getColorForLevel(organicMatter?['level'])
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                _buildNewStatItem(
                  "Salinity", 
                  _capitalize(soilSalinity?['level'] ?? 'N/A'), 
                  Icons.grain_outlined,
                  soilSalinity?['analysis'] ?? 'Analyzing...', 
                  valueColor: _getColorForLevel(soilSalinity?['level'], invert: true) // Low salinity is good
                ),
                const SizedBox(width: 8),
                _buildNewStatItem(
                  "Fertility", 
                  _capitalize(soilFertility?['level'] ?? 'N/A'), 
                  Icons.spa_outlined,
                  soilFertility?['analysis'] ?? 'Analyzing...', 
                  valueColor: _getColorForLevel(soilFertility?['level'])
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text("Overall Soil Health", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F3C33), fontSize: 14)),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Container(
                    height: 10,
                    width: constraints.maxWidth * soilHealthScore,
                    decoration: BoxDecoration(
                      color: soilHealthScore > 0.6 ? const Color(0xFF4ADE80) : (soilHealthScore > 0.3 ? Colors.orange : Colors.red),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              );
            }
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("Bad", style: TextStyle(fontSize: 10, color: Color(0xFF0F3C33)))),
                Expanded(child: Center(child: FittedBox(child: Text("Moderate", style: TextStyle(fontSize: 10, color: Color(0xFF0F3C33)))))),
                Expanded(child: Text("Good", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: Color(0xFF0F3C33)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStatusCard() {
  if (_isLoadingSar) {
    return _buildCard(
      title: "Weather Status",
      headerColor: const Color(0xFFC6F68D),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF167339)),
            const SizedBox(height: 12), // Reduced spacing
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16), // Reduced padding
              child: Text(
                _loadingMessages[_currentLoadingMessageIndex],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F3C33),
                  fontSize: 13, // Reduced font size
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2, // Limit lines
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

    // Use the last day of weather data if available
    final weather = (_weatherData != null && _weatherData!.isNotEmpty) 
        ? _weatherData!.last 
        : null;

    String dateStr = "";
    if (weather != null && weather['date'] != null) {
      dateStr = " (${DateTime.parse(weather['date']).toString().split(' ')[0]})";
    }

    return _buildCard(
      title: "Weather Status$dateStr",
      headerColor: const Color(0xFFC6F68D),
      child: Column(
        children: [
          // Row 1: Temperature & Humidity
          Expanded(
            child: Row(
              children: [
                _buildDetailedStatItem(
                  "Temperature", 
                  weather != null ? "${weather['temp_mean']?.toStringAsFixed(1) ?? '--'}°C" : "--", 
                  Icons.thermostat, 
                  weather != null ? "Max ${weather['temp_max']}°C" : "--", 
                  weather != null ? "Min ${weather['temp_min']}°C" : "--"
                ),
                const SizedBox(width: 8),
                _buildDetailedStatItem(
                  "Humidity", 
                  weather != null ? "${weather['humidity']?.toStringAsFixed(1) ?? '--'}%" : "--", 
                  Icons.water_drop, 
                  "Avg daily", 
                  ""
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Row 2: Wind Speed & UV Index
          Expanded(
            child: Row(
              children: [
                _buildDetailedStatItem(
                  "Wind Speed", 
                  weather != null ? "${weather['wind_speed']?.toStringAsFixed(1) ?? '--'} km/h" : "--", 
                  Icons.air, 
                  "Max daily", 
                  ""
                ),
                const SizedBox(width: 8),
                _buildDetailedStatItem(
                  "UV Index", 
                  weather != null ? "${weather['uv_index']?.toStringAsFixed(1) ?? '--'}" : "--", 
                  Icons.wb_sunny_outlined, 
                  "Max daily", 
                  ""
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Row 3: Precipitation & Evapotranspiration
          Expanded(
            child: Row(
              children: [
                _buildDetailedStatItem(
                  "Precipitation", 
                  weather != null ? "${weather['precipitation']?.toStringAsFixed(1) ?? '--'} mm" : "--", 
                  Icons.cloudy_snowing, 
                  "Total sum", 
                  ""
                ),
                const SizedBox(width: 8),
                _buildDetailedStatItem(
                  "Evapotrans.", 
                  weather != null ? "${weather['evapotranspiration']?.toStringAsFixed(2) ?? '--'} mm" : "--", 
                  Icons.cloud, 
                  "ET0 FAO", 
                  ""
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropStatusCard() {
  if (_isLoadingSar) {
    return _buildCard(
      title: "Crop Status",
      headerColor: const Color(0xFFC6F68D),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF167339)),
            const SizedBox(height: 12), // Reduced spacing
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16), // Reduced padding
              child: Text(
                _loadingMessages[_currentLoadingMessageIndex],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F3C33),
                  fontSize: 13, // Reduced font size
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2, // Limit lines
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
    final summary = _healthSummary;
    if (summary == null) {
       return _buildCard(
        title: "Crop Status",
        headerColor: const Color(0xFFC6F68D),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                Text(
                  _sarError ?? "No data available",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildCard(
      title: "Crop Status",
      headerColor: const Color(0xFFC6F68D),
      child: Column(
        children: [
          // Row 1: Greenness & Nitrogen
          Expanded(
            child: Row(
              children: [
                _buildNewStatItem(
                  "Greenness", 
                  _capitalize(summary['greenness_level'] ?? 'N/A'), 
                  Icons.grass, 
                  summary['greenness_status'] ?? 'No data', 
                  valueColor: _getColorForLevel(summary['greenness_level'])
                ),
                const SizedBox(width: 8),
                _buildNewStatItem(
                  "Nitrogen", 
                  _capitalize(summary['nitrogen_level'] ?? 'N/A'), 
                  Icons.science, 
                  summary['nitrogen_status'] ?? 'No data', 
                  valueColor: _getColorForLevel(summary['nitrogen_level'])
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row 2: Biomass & Heat Stress
          Expanded(
            child: Row(
              children: [
                _buildNewStatItem(
                  "Biomass", 
                  _capitalize(summary['biomass_level'] ?? 'N/A'), 
                  Icons.forest, 
                  summary['biomass_status'] ?? 'No data', 
                  valueColor: _getColorForLevel(summary['biomass_level'])
                ),
                const SizedBox(width: 8),
                _buildNewStatItem(
                  "Heat Stress", 
                  _capitalize(summary['heat_stress_level'] ?? 'N/A'), 
                  Icons.wb_sunny, 
                  summary['heat_stress_status'] ?? 'No data', 
                  valueColor: _getColorForLevel(summary['heat_stress_level'], invert: true)
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text("Overall Field Health", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F3C33), fontSize: 14)),
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              // Calculate health score (1.0 - stress_score)
              double stressScore = (_sarData != null && _sarData!['average_stress_score'] != null) 
                  ? (_sarData!['average_stress_score'] as num).toDouble() 
                  : 0.5; // Default to moderate if missing
              
              // Clamp to 0.0 - 1.0
              stressScore = stressScore.clamp(0.0, 1.0);
              
              double healthScore = 1.0 - stressScore;
              
              return Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            height: 10,
                            width: constraints.maxWidth * healthScore,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ADE80),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text("Bad", style: TextStyle(fontSize: 10, color: Color(0xFF0F3C33)))),
                        Expanded(child: Center(child: FittedBox(child: Text("Moderate", style: TextStyle(fontSize: 10, color: Color(0xFF0F3C33)))))),
                        Expanded(child: Text("Good", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: Color(0xFF0F3C33)))),
                      ],
                    ),
                  ),
                ],
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildPestRiskCard() {
    // Show loading state while Sentinel-2 data is being fetched
    if (_isLoadingS2 || _isLoadingSar) {
      return _buildCard(
        title: "Bio Risk Status",
        headerColor: const Color(0xFFC6F68D),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF167339)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _loadingMessages[_currentLoadingMessageIndex],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF0F3C33),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Get Sentinel-2 LLM analysis data for bio risk
    final llm = _s2LlmAnalysis;
    
    // Extract bio risk data - handle different possible key names from the API
    final pestRisk = llm?['Pest Rsk'] ?? llm?['pest_risk'];
    final nutrientStress = llm?['Nutrient Stress'] ?? llm?['nutrient_stress'];
    final diseaseRisk = llm?['Disease Risk'] ?? llm?['disease_risk'];
    final stressZone = llm?['Stress Zone'] ?? llm?['stress_zone'];
    
    // Calculate overall bio risk score
    double bioRiskScore = 0.3; // Default to low
    if (llm != null && llm['overall_biorisk'] != null) {
      bioRiskScore = (llm['overall_biorisk'] as num).toDouble().clamp(0.0, 1.0);
    } else {
      // Calculate from individual components
      int riskCount = 0;
      int totalRisk = 0;
      for (var item in [pestRisk, nutrientStress, diseaseRisk, stressZone]) {
        if (item != null && item['level'] != null) {
          String level = item['level'].toString().toLowerCase();
          if (level == 'high' || level == 'alert') totalRisk += 3;
          else if (level == 'moderate') totalRisk += 2;
          else if (level == 'low') totalRisk += 1;
          riskCount++;
        }
      }
      if (riskCount > 0) bioRiskScore = (totalRisk / (riskCount * 3)).clamp(0.0, 1.0);
    }

    return _buildCard(
      title: "Bio Risk Status",
      headerColor: const Color(0xFFC6F68D),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildNewStatItem(
                  "Pest Risk", 
                  _capitalize(pestRisk?['level'] ?? 'N/A'), 
                  Icons.bug_report, 
                  pestRisk?['analysis'] ?? 'Analyzing...', 
                  valueColor: _getColorForLevel(pestRisk?['level'], invert: true)
                ),
                const SizedBox(width: 8),
                _buildNewStatItem(
                  "Nutrient", 
                  _capitalize(nutrientStress?['level'] ?? 'N/A'), 
                  Icons.local_florist, 
                  nutrientStress?['analysis'] ?? 'Analyzing...', 
                  valueColor: _getColorForLevel(nutrientStress?['level'], invert: true)
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                _buildNewStatItem(
                  "Disease", 
                  _capitalize(diseaseRisk?['level'] ?? 'N/A'), 
                  Icons.coronavirus, 
                  diseaseRisk?['analysis'] ?? 'Analyzing...', 
                  valueColor: _getColorForLevel(diseaseRisk?['level'], invert: true)
                ),
                const SizedBox(width: 8),
                _buildNewStatItem(
                  "Stress Zone", 
                  _capitalize(stressZone?['level'] ?? 'N/A'), 
                  Icons.warning_amber, 
                  stressZone?['analysis'] ?? 'Analyzing...', 
                  valueColor: _getColorForLevel(stressZone?['level'], invert: true)
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text("Overall Bio Risk", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F3C33), fontSize: 14)),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Container(
                    height: 10,
                    width: constraints.maxWidth * bioRiskScore,
                    decoration: BoxDecoration(
                      color: bioRiskScore < 0.3 ? const Color(0xFF4ADE80) : (bioRiskScore < 0.6 ? Colors.orange : Colors.red),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              );
            }
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("Low", style: TextStyle(fontSize: 10, color: Color(0xFF0F3C33)))),
                Expanded(child: Center(child: FittedBox(child: Text("Moderate", style: TextStyle(fontSize: 10, color: Color(0xFF0F3C33)))))),
                Expanded(child: Text("High", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: Color(0xFF0F3C33)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Color headerColor, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material( // Add Material for InkWell
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
             _stopAutoScroll(); // Stop scroll on tap
             // Add any specific card tap logic here if needed
          },
          splashColor: const Color(0xFFC6F68D).withOpacity(0.3), // Light green splash
          highlightColor: const Color(0xFFC6F68D).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18, // Larger font
                    color: Color(0xFF0F3C33),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedStatItem(String label, String value, IconData icon, String sub1, String sub2, {Color? valueColor}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _stopAutoScroll(); // Stop carousel on tap
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFFC6F68D).withOpacity(0.4),
          highlightColor: const Color(0xFFC6F68D).withOpacity(0.2),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE1EFEF).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0F3C33), fontWeight: FontWeight.bold, height: 1.1),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(icon, size: 30, color: const Color(0xFF597872)),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 3,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: valueColor ?? const Color(0xFF0F3C33),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      flex: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(sub1, style: const TextStyle(fontSize: 11, color: Color(0xFF597872), fontWeight: FontWeight.w600)),
                          ),
                          if (sub2.isNotEmpty)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(sub2, style: const TextStyle(fontSize: 11, color: Color(0xFF597872), fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewStatItem(String label, String value, IconData icon, String description, {Color? valueColor}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _stopAutoScroll(); // Stop carousel on tap
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFFC6F68D).withOpacity(0.4),
          highlightColor: const Color(0xFFC6F68D).withOpacity(0.2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE1EFEF).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 20, color: const Color(0xFF597872)),
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0F3C33),
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0F3C33),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? const Color(0xFF0F3C33),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              _buildActionButton(
                "Locate\nFarmland",
                Icons.add_location_alt_outlined,
                () => Navigator.pushNamed(context, '/farmland-map'),
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                "Summarized\nAnalytics",
                Icons.analytics_outlined,
                () => Navigator.pushNamed(context, '/analytics'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                "Mapped\nAnalytics",
                Icons.calendar_today_outlined, // Changed icon to match image (calendar/grid)
                () => Navigator.pushNamed(context, '/coordinate-entry'),
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                "Take Action\nNow",
                Icons.hub_outlined, // Changed to hub/network icon
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TakeActionScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 90, // Slightly more compact
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF597872), size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF0F3C33),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          padding: const EdgeInsets.only(bottom: 20, top: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE1EFEF).withOpacity(0.8), // Semi-transparent
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              _buildNavCircle(Colors.white.withOpacity(0.8)),
              const SizedBox(width: 12),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF167339),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF167339).withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.home, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              _buildNavCircle(Colors.white.withOpacity(0.8)),
              const SizedBox(width: 12),
              _buildNavCircle(Colors.white.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavCircle(Color color) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
  String _capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

  Color _getColorForLevel(String? level, {bool invert = false}) {
    if (level == null) return Colors.black;
    final l = level.toLowerCase();
    // invert=true: For risk/stress metrics where High/Alert = bad (red), Low = good (green)
    // invert=false: For health metrics where High = good (green), Low = bad (red)
    if (invert) {
      if (l == 'high' || l == 'alert') return Colors.red;
      if (l == 'moderate') return Colors.orange;
      return const Color(0xFF39E639); // Low = green (good)
    } else {
      if (l == 'high') return const Color(0xFF39E639); // High = green (good)
      if (l == 'moderate') return Colors.orange;
      return Colors.red; // Low = red (bad)
    }
  }

  List<double> _parseCoordinates(Map<String, dynamic> data) {
    List<double> lats = [];
    List<double> lons = [];

    // Check for flat structure (lat1, lon1, etc.)
    for (int i = 1; i <= 4; i++) {
      if (data.containsKey('lat$i') && data.containsKey('lon$i')) {
        lats.add((data['lat$i'] as num).toDouble());
        lons.add((data['lon$i'] as num).toDouble());
      }
    }

    if (lats.isEmpty || lons.isEmpty) {
      // Fallback for legacy 'coordinates' list if it exists (though we know it doesn't in DB)
      if (data['coordinates'] != null && data['coordinates'] is List) {
        final list = data['coordinates'] as List;
        for (var point in list) {
          if (point is Map) {
            lats.add((point['lat'] ?? point['latitude'] ?? 0).toDouble());
            lons.add((point['lng'] ?? point['longitude'] ?? 0).toDouble());
          } else if (point is List && point.length >= 2) {
            lats.add(point[0].toDouble());
            lons.add(point[1].toDouble());
          }
        }
      }
    }

    if (lats.isEmpty) throw Exception("No valid coordinates found");

    double minLat = lats.reduce((curr, next) => curr < next ? curr : next);
    double maxLat = lats.reduce((curr, next) => curr > next ? curr : next);
    double minLon = lons.reduce((curr, next) => curr < next ? curr : next);
    double maxLon = lons.reduce((curr, next) => curr > next ? curr : next);

    return [minLon, minLat, maxLon, maxLat];
  }
}

class HomeMenuSearchDelegate extends SearchDelegate<String> {
  final List<String> menuItems;

  HomeMenuSearchDelegate(this.menuItems);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context, query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context, query);
  }

  Widget _buildList(BuildContext context, String query) {
    final List<String> suggestions = query.isEmpty
        ? menuItems
        : menuItems.where((item) => item.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final String item = suggestions[index];
        return ListTile(
          title: Text(item),
          onTap: () {
            close(context, item);
          },
        );
      },
    );
  }
}
