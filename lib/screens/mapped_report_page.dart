import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MappedReportAnalysisScreen extends StatefulWidget {
  final List<LatLng> points;
  final LatLng center;
  final double zoom;

  const MappedReportAnalysisScreen({
    super.key,
    required this.points,
    required this.center,
    required this.zoom,
  });

  @override
  State<MappedReportAnalysisScreen> createState() =>
      _MappedReportAnalysisScreenState();
}

class _MappedReportAnalysisScreenState
    extends State<MappedReportAnalysisScreen> {
  late GoogleMapController _mapController;
  late List<LatLng> _points;
  late LatLng _center;
  late double _zoom;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _points = _sanitizePoints(widget.points);
    _center = widget.center;
    _zoom = widget.zoom;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<LatLng> _sanitizePoints(List<LatLng> pts) {
    final seen = <String>{};
    final out = <LatLng>[];
    for (final p in pts) {
      final lat = double.parse(p.latitude.toStringAsFixed(8));
      final lon = double.parse(p.longitude.toStringAsFixed(8));
      final key = '$lat,$lon';
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(LatLng(lat, lon));
    }
    return out;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_points.length >= 3) {
      _fitToPolygon(_points);
    }
  }

  void _fitToPolygon(List<LatLng> pts) {
    if (pts.isEmpty) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLon = pts.first.longitude, maxLon = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
    
    Future.delayed(const Duration(milliseconds: 200), () {
      try {
        _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 32));
      } catch (e) {
        debugPrint("Camera update failed: $e");
      }
    });
  }

  Set<Marker> get _markers => _points
      .map((pt) => Marker(
            markerId: MarkerId(pt.toString()),
            position: pt,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ))
      .toSet();

  Set<Polygon> get _polygons => _points.length >= 3
      ? {
          Polygon(
            polygonId: const PolygonId('report_polygon'),
            points: _points,
            fillColor: Colors.green.withOpacity(0.25),
            strokeColor: Colors.green,
            strokeWidth: 2,
          ),
        }
      : {};

  void _showExpandedMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ExpandedMapView(
          points: _points,
          center: _center,
          zoom: _zoom,
          markers: _markers,
          polygons: _polygons,
        ),
      ),
    );
  }

  void _showExtendedAnalytics() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ExtendedAnalyticsSheet(currentMetric: _currentPage),
    );
  }

  Widget _buildMapSection() {
    return Container(
      margin: const EdgeInsets.all(18),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          SizedBox(
            height: 220,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: _zoom,
              ),
              markers: _markers,
              polygons: _polygons,
              onMapCreated: _onMapCreated,
              zoomControlsEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              myLocationButtonEnabled: false,
              liteModeEnabled: false, // Use full map for interaction if needed
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: _showExpandedMap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Expand View',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPage(int index) {
    final metrics = [
      {
        'title': 'METRIC - 1',
        'heading': 'Crop Health Analysis',
        'description':
            'NDVI: 0.75 (Healthy)\nStress Detection: Minimal\nGrowth Stage: Flowering\nRecommendation: Continue current irrigation',
      },
      {
        'title': 'METRIC - 2',
        'heading': 'Soil Condition',
        'description':
            'Moisture: 22%\nPH Level: 6.8 (Optimal)\nNutrient Status: Good\nOrganic Matter: 3.2%',
      },
      {
        'title': 'METRIC - 3',
        'heading': 'Weather Impact',
        'description':
            'Temperature: 28°C\nHumidity: 65%\nWind Speed: 12 km/h\nRainfall (7 days): 45mm',
      },
      {
        'title': 'METRIC - 4',
        'heading': 'Yield Prediction',
        'description':
            'Projected Yield: 3.8 tons/hectare\nMarket Price: ₹2,800/quintal\nRevenue: ₹1,06,400\nProfit: 28%',
      },
      {
        'title': 'METRIC - 5',
        'heading': 'Risk Assessment',
        'description':
            'Pest Risk: Low\nDisease Risk: Very Low\nWeather Risk: Moderate\nMarket Risk: Low',
      },
    ];

    final metric = metrics[index];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Header with metric title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              metric['title'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2, end: 0),

          // Analytics content box
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF14463B), Color(0xFF031D18)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric['heading'] as String,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric['description'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ).animate().fadeIn(delay: 300.ms),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '⚠️ Note: Due to time constraints in this hackathon demo, AI model integration is pending. Current data is simulated for demonstration purposes. Full AI-powered analytics will be implemented in the next phase.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ).animate().fadeIn(delay: 400.ms),
                        ],
                      ),
                    ),
                  ),

                  // Extended Analytics button
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: _showExtendedAnalytics,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Extended Analytics',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      appBar: AppBar(
        title: const Text(
          'Analytics Page',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF0D986A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // User avatar and search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 20,
                    child: Icon(
                      Icons.person,
                      color: Color(0xFF0D986A),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 16),
                          Icon(Icons.search, color: Colors.white70, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Search',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.5, end: 0),

            // Map section
            _buildMapSection().animate().fadeIn(delay: 200.ms).slideY(begin: -0.1, end: 0),

            // PageView for analytics with proper constraints
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: 5,
                itemBuilder: (context, index) => _buildAnalyticsPage(index),
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _buildPageIndicator(),
            ).animate().fadeIn(delay: 600.ms),

            // Bottom home button
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.home,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ).animate().scale(delay: 700.ms, curve: Curves.easeOutBack),
          ],
        ),
      ),
    );
  }
}

// Expanded Map View Screen
class _ExpandedMapView extends StatelessWidget {
  final List<LatLng> points;
  final LatLng center;
  final double zoom;
  final Set<Marker> markers;
  final Set<Polygon> polygons;

  const _ExpandedMapView({
    required this.points,
    required this.center,
    required this.zoom,
    required this.markers,
    required this.polygons,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Expanded Map View'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: center,
          zoom: zoom,
        ),
        markers: markers,
        polygons: polygons,
        zoomControlsEnabled: true,
        myLocationButtonEnabled: false,
      ),
    );
  }
}

// Extended Analytics Bottom Sheet
class _ExtendedAnalyticsSheet extends StatelessWidget {
  final int currentMetric;

  const _ExtendedAnalyticsSheet({required this.currentMetric});

  @override
  Widget build(BuildContext context) {
    final extendedData = [
      // Metric 1 - Crop Health
      {
        'title': 'Extended Crop Health Analysis',
        'sections': [
          {
            'heading': 'NDVI Analysis',
            'data':
                'Current NDVI: 0.75\nHistorical Average: 0.68\nTrend: ↑ Improving\nVariability: Low (0.05 std dev)'
          },
          {
            'heading': 'Chlorophyll Content',
            'data':
                'Content Level: High (45.2 SPAD)\nOptimal Range: 40-50 SPAD\nDeficiency Risk: Very Low\nSeasonal Comparison: Above average'
          },
          {
            'heading': 'Growth Metrics',
            'data':
                'Plant Height: 85cm (Target: 80-90cm)\nLeaf Area Index: 4.2\nBiomass: 2.1 tons/hectare\nGrowth Rate: 2.3cm/week'
          },
          {
            'heading': 'Stress Indicators',
            'data':
                'Water Stress: Minimal\nNutrient Stress: None detected\nDisease Pressure: Very Low\nPest Activity: Below threshold'
          }
        ]
      },
      // Metric 2 - Soil Condition
      {
        'title': 'Extended Soil Analysis',
        'sections': [
          {
            'heading': 'Physical Properties',
            'data':
                'Texture: Loamy Clay\nBulk Density: 1.35 g/cm³\nPorosity: 48%\nPenetration Resistance: 1.8 MPa'
          },
          {
            'heading': 'Chemical Analysis',
            'data':
                'pH: 6.8 (Slightly Acidic)\nEC: 0.85 dS/m\nCEC: 18.5 cmol/kg\nBase Saturation: 78%'
          },
          {
            'heading': 'Nutrient Profile',
            'data':
                'Nitrogen: 45 ppm (Adequate)\nPhosphorus: 12 ppm (Low - needs attention)\nPotassium: 180 ppm (High)\nSulfur: 15 ppm (Adequate)'
          },
          {
            'heading': 'Micronutrients',
            'data':
                'Iron: 4.2 ppm (Good)\nZinc: 1.8 ppm (Marginal)\nManganese: 12 ppm (Adequate)\nBoron: 0.8 ppm (Good)'
          }
        ]
      },
      // Metric 3 - Weather Impact
      {
        'title': 'Extended Weather Analysis',
        'sections': [
          {
            'heading': 'Current Conditions',
            'data':
                'Temperature: 28°C (Min: 22°C, Max: 34°C)\nHumidity: 65% (Optimal range)\nWind: 12 km/h NW\nPressure: 1013.2 hPa'
          },
          {
            'heading': '7-Day Forecast',
            'data':
                'Rainfall Expected: 15mm (Days 3-4)\nTemperature Range: 24-36°C\nHumidity: 55-75%\nWind Patterns: Variable, mostly light'
          },
          {
            'heading': 'Growing Degree Days',
            'data':
                'Accumulated GDD: 1,245°C\nDaily GDD: 18.5°C\nSeasonal Target: 1,400°C\nDays to Maturity: 42 days'
          },
          {
            'heading': 'Stress Factors',
            'data':
                'Heat Stress Risk: Low\nDrought Stress: None\nExcess Moisture: None\nFrost Risk: Zero (seasonal)'
          }
        ]
      },
      // Metric 4 - Yield Prediction
      {
        'title': 'Extended Yield Prediction',
        'sections': [
          {
            'heading': 'Yield Components',
            'data':
                'Plants/m²: 22\nHeads/plant: 1.2\nGrains/head: 485\nThousand grain weight: 38.5g'
          },
          {
            'heading': 'Quality Parameters',
            'data':
                'Protein Content: 12.8%\nMoisture: 13.5%\nTest Weight: 78.2 kg/hl\nFalling Number: 285 seconds'
          },
          {
            'heading': 'Economic Analysis',
            'data':
                'Cost of Production: ₹75,600/hectare\nBreakeven Yield: 2.7 tons/hectare\nProjected Profit: ₹30,800/hectare\nROI: 40.7%'
          },
          {
            'heading': 'Market Intelligence',
            'data':
                'Current Price: ₹2,800/quintal\nPrice Trend: Stable (+2% from last month)\nDemand: High\nSupply Forecast: Moderate'
          }
        ]
      },
      // Metric 5 - Risk Assessment
      {
        'title': 'Extended Risk Assessment',
        'sections': [
          {
            'heading': 'Pest & Disease Risk',
            'data':
                'Aphid Pressure: Low (2% threshold)\nFungal Disease: Very Low\nNematode Activity: None detected\nBird Damage Risk: Moderate (harvest time)'
          },
          {
            'heading': 'Weather Risks',
            'data':
                'Hail Risk: Low (5% probability)\nDrought Risk: Very Low\nFlood Risk: None\nWind Damage: Low'
          },
          {
            'heading': 'Market Risks',
            'data':
                'Price Volatility: Low\nDemand Uncertainty: Low\nSupply Chain: Stable\nStorage Costs: ₹85/quintal/month'
          },
          {
            'heading': 'Mitigation Strategies',
            'data':
                'Insurance Coverage: 85% of input costs\nStorage Facilities: Available\nAlternate Markets: 3 identified\nEmergency Protocols: Active'
          }
        ]
      },
    ];

    final data = extendedData[currentMetric];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF347454), Color(0xFF031D18)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data['title'] as String,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // AI Note
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI Model Integration Pending: This extended analytics data is simulated for hackathon demonstration. Real-time AI-powered insights will be available in the production version.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideX(),

              // Content
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: (data['sections'] as List).length,
                  itemBuilder: (context, index) {
                    final section = (data['sections'] as List)[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section['heading'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            section['data'],
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (300 + index * 100).ms).slideX(begin: 0.1, end: 0);
                  },
                ),
              ),

              // Go back button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Go back',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms).slideY(begin: 1, end: 0),
            ],
          ),
        );
      },
    );
  }
}
