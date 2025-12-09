import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:agroww_sih/services/localization_service.dart';
import 'package:agroww_sih/widgets/adaptive_bottom_nav_bar.dart';
import 'package:agroww_sih/screens/field_variability_screen.dart';
import 'package:agroww_sih/screens/irrigation_scheduling_screen.dart';

/// Take Action / Recommendations Screen
/// Shows field selector, satellite preview, and 6 action category cards
class TakeActionScreen extends StatefulWidget {
  const TakeActionScreen({super.key});

  @override
  State<TakeActionScreen> createState() => _TakeActionScreenState();
}

class _TakeActionScreenState extends State<TakeActionScreen> {
  // Field data
  Map<String, dynamic>? _selectedField;
  List<Map<String, dynamic>> _farmlands = [];
  bool _isLoadingFields = true;
  int? _selectedCategoryIndex;

  // Action categories with progress values and category IDs
  List<Map<String, dynamic>> get _actionCategories {
    final loc = Provider.of<LocalizationProvider>(context, listen: false);
    return [
      {
        'title': loc.tr('field_variability'),
        'category': 'field_variability',
        'progress': 0.75,
        'icon': Icons.grid_view_rounded,
      },
      {
        'title': loc.tr('yield_stability'),
        'category': 'yield_stability',
        'progress': 0.60,
        'icon': Icons.trending_up_rounded,
      },
      {
        'title': loc.tr('irrigation_scheduling'),
        'category': 'irrigation',
        'progress': 0.85,
        'icon': Icons.water_drop_outlined,
      },
      {
        'title': loc.tr('vegetation_health'),
        'category': 'vegetation_health',
        'progress': 0.70,
        'icon': Icons.eco_rounded,
      },
      {
        'title': loc.tr('nutrient_deficiency'),
        'category': 'nutrient',
        'progress': 0.55,
        'icon': Icons.science_outlined,
      },
      {
        'title': loc.tr('pest_damage'),
        'category': 'pest_damage',
        'progress': 0.40,
        'icon': Icons.bug_report_outlined,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadFarmlands();
  }

  Future<void> _loadFarmlands() async {
    setState(() => _isLoadingFields = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('coordinates_quad')
            .select()
            .eq('user_id', user.uid);

        if (response != null && response is List) {
          setState(() {
            _farmlands = List<Map<String, dynamic>>.from(response);
            if (_farmlands.isNotEmpty) {
              _selectedField = _farmlands.first;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading farmlands: $e');
    }
    setState(() => _isLoadingFields = false);
  }

  void _navigateToDetailScreen(int index) {
    if (_selectedField == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a field first')),
      );
      return;
    }

    final category = _actionCategories[index];
    final field = _selectedField!;
    final fieldSize = (field['area_acres'] as num?)?.toDouble() ?? 1.0;

    // Build polygon from lat1/lon1 format
    List<LatLng> polygon = [];
    for (int i = 1; i <= 4; i++) {
      final cornerLat = field['lat$i'];
      final cornerLon = field['lon$i'];
      if (cornerLat != null && cornerLon != null) {
        final latVal = (cornerLat is num) ? cornerLat.toDouble() : double.tryParse(cornerLat.toString());
        final lonVal = (cornerLon is num) ? cornerLon.toDouble() : double.tryParse(cornerLon.toString());
        if (latVal != null && lonVal != null) {
          polygon.add(LatLng(latVal, lonVal));
        }
      }
    }

    // Calculate center from polygon or use stored center
    double centerLat = field['center_lat']?.toDouble() ?? 0.0;
    double centerLon = field['center_lon']?.toDouble() ?? 0.0;
    if ((centerLat == 0.0 || centerLon == 0.0) && polygon.isNotEmpty) {
      centerLat = polygon.map((p) => p.latitude).reduce((a, b) => a + b) / polygon.length;
      centerLon = polygon.map((p) => p.longitude).reduce((a, b) => a + b) / polygon.length;
    }

    // Farmer profile from field data
    final farmerProfile = {
      'crop_type': field['crop_type'] ?? 'Unknown',
      'field_size': fieldSize,
      'irrigation_method': field['irrigation_method'] ?? 'Unknown',
      'experience': 'Intermediate',
      'primary_goal': 'Maximize yield',
      'budget': 'Moderate',
    };

    // Route to specific screen based on category
    if (category['category'] == 'irrigation') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IrrigationSchedulingScreen(
            fieldName: field['name'] ?? 'Field',
            centerLat: centerLat,
            centerLon: centerLon,
            fieldSizeHectares: fieldSize * 0.4047,
            fieldPolygon: polygon.isNotEmpty ? polygon : null,
            farmerProfile: farmerProfile,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FieldVariabilityScreen(
            title: category['title'],
            category: category['category'],
            centerLat: centerLat,
            centerLon: centerLon,
            fieldSizeHectares: fieldSize * 0.4047, // Convert acres to hectares
            fieldName: field['name'] ?? 'Field',
            fieldPolygon: polygon.isNotEmpty ? polygon : null,
            farmerProfile: farmerProfile,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Custom AppBar - more compact
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Consumer<LocalizationProvider>(
                    builder: (context, loc, _) => Text(
                      loc.tr('recommendations'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      _buildFieldSelector(),
                      const SizedBox(height: 12),
                      _buildMapPreview(),
                      const SizedBox(height: 12),
                      _buildActionGrid(),
                      const SizedBox(height: 16),
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



  Widget _buildFieldSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: _isLoadingFields
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Loading fields...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedField?['name'],
                      hint: const Text(
                        'Select Field',
                        style: TextStyle(color: Colors.grey),
                      ),
                      isExpanded: true,
                      icon: const SizedBox.shrink(),
                      items: _farmlands.map((field) {
                        return DropdownMenuItem<String>(
                          value: field['name'],
                          child: Text(field['name'] ?? 'Unnamed Field'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedField = _farmlands.firstWhere(
                            (f) => f['name'] == value,
                            orElse: () => _farmlands.first,
                          );
                        });
                      },
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(Icons.tune, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    // Get field center coordinates
    double? lat, lon;
    List<LatLng> polygon = [];

    if (_selectedField != null) {
      debugPrint('[TakeAction] Selected field: ${_selectedField!['name']}');
      debugPrint('[TakeAction] Field data keys: ${_selectedField!.keys}');
      
      // Try center_lat/center_lon first, then calculate from corners
      lat = _selectedField!['center_lat']?.toDouble();
      lon = _selectedField!['center_lon']?.toDouble();

      // Build polygon from lat1/lon1, lat2/lon2, lat3/lon3, lat4/lon4 format
      for (int i = 1; i <= 4; i++) {
        final cornerLat = _selectedField!['lat$i'];
        final cornerLon = _selectedField!['lon$i'];
        if (cornerLat != null && cornerLon != null) {
          final latVal = (cornerLat is num) ? cornerLat.toDouble() : double.tryParse(cornerLat.toString());
          final lonVal = (cornerLon is num) ? cornerLon.toDouble() : double.tryParse(cornerLon.toString());
          if (latVal != null && lonVal != null) {
            polygon.add(LatLng(latVal, lonVal));
          }
        }
      }
      
      debugPrint('[TakeAction] Built polygon with ${polygon.length} points');
      
      // If no center, calculate from polygon
      if ((lat == null || lon == null) && polygon.isNotEmpty) {
        lat = polygon.map((p) => p.latitude).reduce((a, b) => a + b) / polygon.length;
        lon = polygon.map((p) => p.longitude).reduce((a, b) => a + b) / polygon.length;
        debugPrint('[TakeAction] Calculated center: $lat, $lon');
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: lat != null && lon != null
            ? Stack(
                children: [
                  GoogleMap(
                    key: ValueKey('map_${_selectedField?['name']}_$lat$lon'),
                    initialCameraPosition: CameraPosition(
                      target: LatLng(lat, lon),
                      zoom: 16,
                    ),
                    mapType: MapType.satellite,
                    polygons: polygon.length >= 3
                        ? {
                            Polygon(
                              polygonId: const PolygonId('field'),
                              points: polygon,
                              strokeColor: const Color(0xFFC6F68D),
                              strokeWidth: 3,
                              fillColor: const Color(0xFFC6F68D).withOpacity(0.2),
                            ),
                          }
                        : {},
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    liteModeEnabled: true,
                  ),
                  // Field label overlay
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedField?['name'] ?? 'FIELD',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _selectedField?['crop_type'] ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 48,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a field to view',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActionGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _actionCategories.length,
      itemBuilder: (context, index) {
        return _buildActionCard(index);
      },
    );
  }

  Widget _buildActionCard(int index) {
    final category = _actionCategories[index];
    final isSelected = _selectedCategoryIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint('[TakeAction] Card tapped: ${category['title']}');
        setState(() {
          _selectedCategoryIndex = index;
        });
        // Navigate to detail screen
        _navigateToDetailScreen(index);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF167339) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF167339)
                : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                category['title'],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: category['progress'],
                minHeight: 6,
                backgroundColor: isSelected
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isSelected ? Colors.white : const Color(0xFF167339),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
