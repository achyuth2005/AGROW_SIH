/// ===========================================================================
/// MAPPED ANALYTICS HOME SCREEN
/// ===========================================================================
///
/// PURPOSE: Entry point for generating on-map analytics visualizations.
///          Select up to 3 categories and a field, then generate heatmaps.
///
/// AVAILABLE METRICS (15 categories):
///   PIXELWISE (direct index visualization):
///   - Greenness (NDVI), Biomass (EVI), Nitrogen (NDRE)
///   - Photosynthetic Capacity (PRI), Leaf Health (GNDVI)
///   - Soil Moisture (SMI), Organic Matter (SOMI)
///   - Soil Fertility (SFI), Soil Salinity (SASI)
///   
///   LLM-POWERED (CNN + Clustering + LLM reasoning):
///   - Stress Pattern, Nutrient Stress, Heat Stress
///   - Disease Risk, Pest Risk, Stress Zones
///
/// KEY FEATURES:
///   - Field selector dropdown (from Supabase)
///   - Expandable category picker (max 3 selections)
///   - Personalized greeting with user name
///
/// NAVIGATION:
///   - Generate → MappedAnalyticsResultsScreen with categories + field data
///
/// DEPENDENCIES:
///   - firebase_auth: User info
///   - supabase_flutter: Field data
/// ===========================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mapped_analytics_results_screen.dart';
import '../settings/sidebar_drawer.dart';
import '../../widgets/custom_bottom_nav_bar.dart';

class MappedAnalyticsHomeScreen extends StatefulWidget {
  const MappedAnalyticsHomeScreen({super.key});

  @override
  State<MappedAnalyticsHomeScreen> createState() => _MappedAnalyticsHomeScreenState();
}

class _MappedAnalyticsHomeScreenState extends State<MappedAnalyticsHomeScreen> {
  String _userName = 'User';
  Set<String> _selectedCategories = {};
  bool _isCategorySheetOpen = false;
  
  // Field data
  Map<String, dynamic>? _selectedField;
  List<Map<String, dynamic>> _farmlands = [];
  bool _isLoadingFields = true;

  // All 15 categories - Pixelwise + LLM metrics
  static const List<Map<String, String>> _allCategories = [
    // Pixelwise metrics (direct index visualization)
    {'id': 'greenness', 'name': 'Greenness (NDVI)', 'metric': 'greenness'},
    {'id': 'biomass', 'name': 'Biomass Growth (EVI)', 'metric': 'biomass'},
    {'id': 'nitrogen_level', 'name': 'Nitrogen Level (NDRE)', 'metric': 'nitrogen_level'},
    {'id': 'photosynthetic_capacity', 'name': 'Photosynthetic Capacity (PRI)', 'metric': 'photosynthetic_capacity'},
    {'id': 'leaf_health', 'name': 'Leaf Health (GNDVI)', 'metric': 'leaf_health'},
    {'id': 'soil_moisture', 'name': 'Soil Moisture (SMI)', 'metric': 'soil_moisture'},
    {'id': 'soil_organic_matter', 'name': 'Soil Organic Matter (SOMI)', 'metric': 'soil_organic_matter'},
    {'id': 'soil_fertility', 'name': 'Soil Fertility (SFI)', 'metric': 'soil_fertility'},
    {'id': 'soil_salinity', 'name': 'Soil Salinity (SASI)', 'metric': 'soil_salinity'},
    // LLM metrics (CNN + Clustering + LLM reasoning)
    {'id': 'stress_pattern', 'name': 'Stress Pattern Analysis', 'metric': 'stress_pattern'},
    {'id': 'nutrient_stress', 'name': 'Nutrient Stress Detection', 'metric': 'nutrient_stress'},
    {'id': 'heat_stress', 'name': 'Heat Stress Analysis', 'metric': 'heat_stress'},
    {'id': 'disease_risk', 'name': 'Disease Risk Assessment', 'metric': 'disease_risk'},
    {'id': 'pest_risk', 'name': 'Pest Risk Assessment', 'metric': 'pest_risk'},
    {'id': 'stress_zones', 'name': 'Stress Zones Mapping', 'metric': 'stress_zones'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadFarmlands();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
      });
    }
  }

  Future<void> _loadFarmlands() async {
    setState(() => _isLoadingFields = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final response = await Supabase.instance.client
          .from('coordinates_quad')
          .select()
          .eq('user_id', user.uid);
      
      if (mounted) {
        setState(() {
          _farmlands = List<Map<String, dynamic>>.from(response);
          if (_farmlands.isNotEmpty) {
            _selectedField = _farmlands.first;
          }
          _isLoadingFields = false;
        });
      }
    } catch (e) {
      print('Error loading farmlands: $e');
      if (mounted) setState(() => _isLoadingFields = false);
    }
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (_selectedCategories.contains(categoryId)) {
        _selectedCategories.remove(categoryId);
      } else if (_selectedCategories.length < 3) {
        _selectedCategories.add(categoryId);
      }
    });
  }

  void _navigateToResults() {
    if (_selectedCategories.isEmpty || _selectedField == null) return;
    
    // Get field coordinates (4 corners for polygon)
    List<List<double>> polygonCoords = [];
    double centerLat = 0, centerLon = 0;
    int count = 0;
    for (int i = 1; i <= 4; i++) {
      if (_selectedField!['lat$i'] != null && _selectedField!['lon$i'] != null) {
        final lat = (_selectedField!['lat$i'] as num).toDouble();
        final lon = (_selectedField!['lon$i'] as num).toDouble();
        polygonCoords.add([lat, lon]);
        centerLat += lat;
        centerLon += lon;
        count++;
      }
    }
    if (count > 0) {
      centerLat /= count;
      centerLon /= count;
    }
    final fieldSizeHa = (_selectedField!['area_acres'] ?? 0.04) * 0.404686;
    
    // Get selected category details
    final selectedCategoryDetails = _allCategories
        .where((c) => _selectedCategories.contains(c['id']))
        .toList();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MappedAnalyticsResultsScreen(
          categories: selectedCategoryDetails,
          centerLat: centerLat,
          centerLon: centerLon,
          fieldSizeHectares: fieldSizeHa,
          fieldName: _selectedField!['name'] ?? 'Field',
          fieldPolygon: polygonCoords,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EFEF),
      drawer: const SidebarDrawer(),
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: -1),
      body: Stack(
        children: [
          // Background header
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
              _buildHeader(context),
              
              // Field selector at TOP (like homepage)
              if (!_isLoadingFields && _farmlands.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: _selectedField,
                        isExpanded: true,
                        hint: const Text('Select Field'),
                        items: _farmlands.map((field) {
                          return DropdownMenuItem(
                            value: field,
                            child: Text(field['name'] ?? 'Unnamed'),
                          );
                        }).toList(),
                        onChanged: (field) {
                          if (field != null) setState(() => _selectedField = field);
                        },
                      ),
                    ),
                  ),
                ),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 2),
                      
                      // Greeting
                      Text(
                        'Hi $_userName',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Title
                      const Text(
                        'Generate On-Map\nAnalytics.',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F3C33),
                          height: 1.2,
                        ),
                      ),
                      
                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Bottom category selector
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: _buildCategorySelector(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Text(
                'Mapped Analytics',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return GestureDetector(
      onTap: () => setState(() => _isCategorySheetOpen = !_isCategorySheetOpen),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedCategories.isEmpty 
                        ? 'Select categories'
                        : '${_selectedCategories.length} selected',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F3C33),
                    ),
                  ),
                ),
                Icon(
                  _isCategorySheetOpen ? Icons.keyboard_arrow_down : Icons.more_horiz,
                  color: Colors.grey,
                ),
              ],
            ),
            
            if (!_isCategorySheetOpen) ...[
              const SizedBox(height: 4),
              Text(
                'Choose upto 3 categories at one time.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            
            // Expanded category list
            if (_isCategorySheetOpen) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _allCategories.length,
                  itemBuilder: (context, index) {
                    final category = _allCategories[index];
                    final isSelected = _selectedCategories.contains(category['id']);
                    final canSelect = _selectedCategories.length < 3 || isSelected;
                    
                    return ListTile(
                      dense: true,
                      title: Text(
                        category['name']!,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: canSelect ? const Color(0xFF0F3C33) : Colors.grey,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Color(0xFF167339))
                          : Icon(Icons.circle_outlined, color: Colors.grey.shade400),
                      onTap: canSelect ? () => _toggleCategory(category['id']!) : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              
              // Generate button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedCategories.isNotEmpty && _selectedField != null
                      ? _navigateToResults
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF167339),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Generate Analytics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
