/// ===========================================================================
/// FIELD VARIABILITY SCREEN
/// ===========================================================================
///
/// PURPOSE: Detailed zonal analysis showing high/low stress zones
///          within a field using CNN+Clustering+LLM analysis.
///
/// KEY FEATURES:
///   - Interactive map with stress zone markers (color-coded)
///   - Swipe-able zone carousel with detailed info
///   - Risk suggestions from AI analysis
///   - Direct link to Mapped Analytics for deeper dive
///
/// ZONE ANALYSIS:
///   - High zones (Red markers): Severe stress areas
///   - Moderate zones (Yellow markers): Caution areas
///   - Low zones (Green markers): Healthy areas
///
/// DATA FLOW:
///   1. Fetch time series (NDVI, NDRE, SMI) for context
///   2. Call TakeActionService with category and indices
///   3. Backend runs CNN model → clusters → LLM reasoning
///   4. Returns zone coordinates, scores, recommendations
///
/// MAP FEATURES:
///   - Google Maps satellite view
///   - Field polygon overlay with stroke
///   - Stress markers with InfoWindow
///   - Camera animation to selected zone
///
/// CACHING:
///   - Results cached in SharedPreferences per field
///   - Refresh button to force re-fetch
///
/// DEPENDENCIES:
///   - TakeActionService: AI analysis
///   - TimeSeriesService: Index data
///   - google_maps_flutter: Map display
///   - SharedPreferences: Cache
/// ===========================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../services/localization_service.dart';
import '../../services/take_action_service.dart';
import '../../services/timeseries_service.dart';
import '../../widgets/adaptive_bottom_nav_bar.dart';
import '../features/chatbot_screen.dart';
import 'mapped_analytics_home_screen.dart';

class FieldVariabilityScreen extends StatefulWidget {
  final String title;
  final String category;
  final double centerLat;
  final double centerLon;
  final double fieldSizeHectares;
  final String fieldName;
  final List<LatLng>? fieldPolygon;
  final Map<String, dynamic>? farmerProfile;

  const FieldVariabilityScreen({
    super.key,
    required this.title,
    required this.category,
    required this.centerLat,
    required this.centerLon,
    required this.fieldSizeHectares,
    required this.fieldName,
    this.fieldPolygon,
    this.farmerProfile,
  });

  @override
  State<FieldVariabilityScreen> createState() => _FieldVariabilityScreenState();
}

class _FieldVariabilityScreenState extends State<FieldVariabilityScreen> {
  bool _isLoading = true;
  TakeActionResult? _result;
  String? _error;
  int _selectedStressZoneIndex = 0;
  GoogleMapController? _mapController;
  final PageController _zoomedMapPageController = PageController();
  bool _isAnimatingCarousel = false; // Prevent recursive sync

  // Top 4 stress zones sorted by score
  List<ZoneInfo> _top4StressZones = [];

  /// Animate main map camera to focus on a specific zone
  void _animateToZone(int index) {
    if (index < 0 || index >= _top4StressZones.length) return;
    final zone = _top4StressZones[index];
    if (zone.lat == 0 && zone.lon == 0) return;
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(zone.lat, zone.lon), 17),
    );
  }

  /// Sync both carousels to a specific index
  void _syncToZone(int index) {
    if (_isAnimatingCarousel) return;
    _isAnimatingCarousel = true;
    
    setState(() => _selectedStressZoneIndex = index);
    
    // Animate bottom PageView if needed
    if (_zoomedMapPageController.hasClients) {
      final currentPage = _zoomedMapPageController.page?.round() ?? 0;
      if (currentPage != index) {
        _zoomedMapPageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
    
    // Animate main map camera
    _animateToZone(index);
    
    // Reset flag after animation
    Future.delayed(const Duration(milliseconds: 350), () {
      _isAnimatingCarousel = false;
    });
  }


  @override
  void initState() {
    super.initState();
    debugPrint('[FieldVariability] initState - center: (${widget.centerLat}, ${widget.centerLon})');
    debugPrint('[FieldVariability] initState - polygon points: ${widget.fieldPolygon?.length ?? 0}');
    if (widget.fieldPolygon != null) {
      for (int i = 0; i < widget.fieldPolygon!.length; i++) {
        debugPrint('[FieldVariability] Polygon[$i]: (${widget.fieldPolygon![i].latitude}, ${widget.fieldPolygon![i].longitude})');
      }
    }
    _loadFromCacheOrFetch();
  }

  @override
  void dispose() {
    _zoomedMapPageController.dispose();
    super.dispose();
  }

  String get _cacheKey => 'take_action_${widget.category}_${widget.centerLat}_${widget.centerLon}';

  Future<void> _loadFromCacheOrFetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Try loading from cache first
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      
      if (cached != null) {
        final data = jsonDecode(cached);
        final cachedResult = TakeActionResult.fromJson(data);
        setState(() {
          _result = cachedResult;
          _updateAllStressZones();
          _isLoading = false;
        });
        debugPrint('[TakeAction] Loaded from cache');
        return;
      }
    } catch (e) {
      debugPrint('[TakeAction] Cache load failed: $e');
    }

    // Fetch fresh data
    await _fetchReasoning();
  }

  Future<void> _refreshData() async {
    // Clear cache and fetch fresh
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
    await _fetchReasoning();
  }

  String get _timeseriesCacheKey => 'ts_cache_${widget.centerLat}_${widget.centerLon}';

  Future<void> _fetchReasoning() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch timeseries for key indices in parallel
      Map<String, dynamic> indicesData = {};
      final keyIndices = ['NDVI', 'NDRE', 'SMI'];
      
      final futures = keyIndices.map((indexName) async {
        try {
          final tsResult = await TimeSeriesService.fetchTimeSeries(
            centerLat: widget.centerLat,
            centerLon: widget.centerLon,
            fieldSizeHectares: widget.fieldSizeHectares,
            metric: indexName,
          ).timeout(const Duration(seconds: 15));

          if (tsResult != null) {
            return MapEntry(indexName, {
              'historical': tsResult.historical.map((p) => {
                'date': p.date.toIso8601String(),
                'value': p.value,
              }).toList(),
              'forecast': tsResult.forecast.map((p) => {
                'date': p.date.toIso8601String(),
                'value': p.value,
              }).toList(),
            });
          }
        } catch (e) {
          debugPrint('Failed to fetch $indexName: $e');
        }
        return null;
      }).toList();

      final results = await Future.wait(futures);
      for (final result in results) {
        if (result != null) {
          indicesData[result.key] = result.value;
        }
      }

      // If we got timeseries data, cache it for this field
      if (indicesData.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_timeseriesCacheKey, jsonEncode(indicesData));
          debugPrint('[TakeAction] Cached timeseries data for field');
        } catch (e) {
          debugPrint('[TakeAction] Failed to cache timeseries: $e');
        }
      } else {
        // Live fetch failed - try loading from cache
        debugPrint('[TakeAction] Live timeseries fetch failed, trying cache...');
        try {
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString(_timeseriesCacheKey);
          if (cached != null) {
            indicesData = Map<String, dynamic>.from(jsonDecode(cached));
            debugPrint('[TakeAction] Loaded cached timeseries: ${indicesData.keys}');
          }
        } catch (e) {
          debugPrint('[TakeAction] Cache load failed: $e');
        }
      }

      // Placeholder weather data
      final weatherData = {
        'temperature': 28,
        'humidity': 65,
        'conditions': 'Clear',
        'precipitation': 0,
        'forecast': 'Warm and dry',
      };

      // Call take action reasoning API
      final result = await TakeActionService.fetchReasoning(
        centerLat: widget.centerLat,
        centerLon: widget.centerLon,
        fieldSizeHectares: widget.fieldSizeHectares,
        category: widget.category,
        indicesTimeseries: indicesData.isNotEmpty ? indicesData : null,
        farmerProfile: widget.farmerProfile,
        weatherData: weatherData,
      );

      if (result != null && mounted) {
        // Save to cache
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, jsonEncode({
            'success': result.success,
            'category': result.category,
            'high_zones': result.highZones.map((z) => {
              'lat': z.lat, 'lon': z.lon, 'score': z.score, 'label': z.label
            }).toList(),
            'low_zones': result.lowZones.map((z) => {
              'lat': z.lat, 'lon': z.lon, 'score': z.score, 'label': z.label
            }).toList(),
            'recommendations': result.recommendations,
            'risk_suggestions': result.riskSuggestions,
            'detailed_analysis': result.detailedAnalysis,
            'stress_score': result.stressScore,
            'cluster_distribution': result.clusterDistribution,
          }));
          debugPrint('[TakeAction] Saved to cache');
        } catch (e) {
          debugPrint('[TakeAction] Cache save failed: $e');
        }

        setState(() {
          _result = result;
          _updateAllStressZones();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _error = 'Failed to load analysis';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _updateAllStressZones() {
    if (_result == null) return;

    // Combine all zones from API (should have 12: 4 high, 4 moderate, 4 low)
    List<ZoneInfo> allZones = [..._result!.highZones, ..._result!.lowZones];
    
    // Filter out invalid zones (lat=0, lon=0)
    allZones = allZones.where((z) => z.lat != 0.0 && z.lon != 0.0).toList();
    
    // Keep all zones (up to 12) - sorted by score descending
    allZones.sort((a, b) => b.score.compareTo(a.score));
    _top4StressZones = allZones; // Now contains up to 12 zones
    
    debugPrint('[FieldVariability] Valid zones from API: ${_top4StressZones.length}');
    
    // If no valid zones from API, generate fallback zones using field polygon
    if (_top4StressZones.isEmpty && widget.fieldPolygon != null && widget.fieldPolygon!.isNotEmpty) {
      debugPrint('[FieldVariability] Generating fallback zones from field polygon');
      // Use field corners as stress zone candidates
      for (int i = 0; i < widget.fieldPolygon!.length && i < 4; i++) {
        final point = widget.fieldPolygon![i];
        _top4StressZones.add(ZoneInfo(
          lat: point.latitude,
          lon: point.longitude,
          score: 0.5 + (i * 0.1), // Vary scores slightly
          label: 'Zone ${i + 1} (estimated)',
        ));
      }
    } else if (_top4StressZones.isEmpty) {
      // Ultimate fallback: use center coordinates
      debugPrint('[FieldVariability] Using center as fallback zone');
      _top4StressZones.add(ZoneInfo(
        lat: widget.centerLat,
        lon: widget.centerLon,
        score: 0.5,
        label: 'Center zone',
      ));
    }
    
    // Debug: Print all stress zones
    debugPrint('[FieldVariability] === FINAL STRESS ZONES (${_top4StressZones.length}) ===');
    for (int i = 0; i < _top4StressZones.length; i++) {
      final z = _top4StressZones[i];
      debugPrint('[FieldVariability] Zone $i: (${z.lat}, ${z.lon}) score=${z.score} severity="${z.severity}"');
    }
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
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Refresh button
                      IconButton(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _isLoading ? null : _refreshData,
                      ),
                    ],
                  ),
                ),
              ),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildMainCard(),
                      const SizedBox(height: 12),
                      _buildRiskSuggestionButton(),
                      const SizedBox(height: 16),
                      _buildTabBar(),
                      const SizedBox(height: 16),
                      _buildBottomCards(),
                      const SizedBox(height: 16),
                      _buildMappedAnalyticsButton(),
                      const SizedBox(height: 24),
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


  Widget _buildMainCard() {
    final loc = Provider.of<LocalizationProvider>(context);
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          if (_top4StressZones.isEmpty) return;
          // Swipe left = next zone, swipe right = previous zone
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -200) {
              // Swipe left - go to next zone
              final nextIndex = (_selectedStressZoneIndex + 1) % _top4StressZones.length;
              _syncToZone(nextIndex);
            } else if (details.primaryVelocity! > 200) {
              // Swipe right - go to previous zone
              final prevIndex = (_selectedStressZoneIndex - 1 + _top4StressZones.length) % _top4StressZones.length;
              _syncToZone(prevIndex);
            }
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.tr('high_low_zones'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  // Swipe hint icon
                  const Row(
                    children: [
                      Icon(Icons.swipe, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Swipe', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            // High/Low count button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF167339),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _result != null
                      ? '${loc.tr('high')}: ${_result!.highZones.length} | ${loc.tr('low')}: ${_result!.lowZones.length}'
                      : loc.tr('loading_zones'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            // Map section with stress markers
            Container(
              height: 220,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildMainMap(),
              ),
            ),
            // Zone selector indicators
            if (_top4StressZones.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_top4StressZones.length, (index) {
                    final isSelected = _selectedStressZoneIndex == index;
                    return GestureDetector(
                      onTap: () => _syncToZone(index),
                      child: Container(
                        width: isSelected ? 24 : 12,
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF167339) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: isSelected
                            ? Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
                ),
              ),
            const SizedBox(height: 12),
            // Recommendation text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _isLoading
                    ? loc.tr('analyzing_ai')
                    : 'Your farmland is divided into ${_top4StressZones.length} ${loc.tr('stress_zones')}.',
                style: TextStyle(
                  color: _isLoading ? Colors.grey : const Color(0xFFD4A656),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMainMap() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading stress zones...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Build markers for all stress zones with color-coded by severity
    Set<Marker> markers = {};

    for (int i = 0; i < _top4StressZones.length; i++) {
      final zone = _top4StressZones[i];
      if (zone.lat != 0 && zone.lon != 0) {
        // Color based on severity: High=red, Moderate=yellow, Low=green
        double hue;
        if (zone.severity == 'High' || zone.severity == 'Severe') {
          hue = BitmapDescriptor.hueRed;
        } else if (zone.severity == 'Moderate') {
          hue = BitmapDescriptor.hueYellow;
        } else {
          hue = BitmapDescriptor.hueGreen;
        }
        
        markers.add(Marker(
          markerId: MarkerId('stress_$i'),
          position: LatLng(zone.lat, zone.lon),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: '${zone.severity} Zone ${(i % 4) + 1}',
            snippet: 'Score: ${zone.score.toStringAsFixed(2)} - ${zone.label}',
          ),
        ));
      }
    }

    // Field polygon (bounding box)
    Set<Polygon> polygons = {};
    LatLngBounds? bounds;
    
    if (widget.fieldPolygon != null && widget.fieldPolygon!.length >= 3) {
      polygons.add(Polygon(
        polygonId: const PolygonId('field'),
        points: widget.fieldPolygon!,
        strokeColor: const Color(0xFFC6F68D),
        strokeWidth: 4,
        fillColor: const Color(0xFFC6F68D).withOpacity(0.2),
      ));
      
      // Calculate bounds from field polygon
      double minLat = widget.fieldPolygon!.first.latitude;
      double maxLat = widget.fieldPolygon!.first.latitude;
      double minLon = widget.fieldPolygon!.first.longitude;
      double maxLon = widget.fieldPolygon!.first.longitude;
      
      for (final point in widget.fieldPolygon!) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLon) minLon = point.longitude;
        if (point.longitude > maxLon) maxLon = point.longitude;
      }
      
      // Add padding to bounds
      const padding = 0.001; // ~100m padding
      bounds = LatLngBounds(
        southwest: LatLng(minLat - padding, minLon - padding),
        northeast: LatLng(maxLat + padding, maxLon + padding),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.centerLat, widget.centerLon),
        zoom: 15, // Lower zoom to show more area initially
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        // Fit camera to field bounds after map is created
        if (bounds != null) {
          Future.delayed(const Duration(milliseconds: 300), () {
            controller.animateCamera(CameraUpdate.newLatLngBounds(bounds!, 40));
          });
        }
      },
      mapType: MapType.satellite,
      markers: markers,
      polygons: polygons,
      zoomControlsEnabled: true,  // Enable zoom controls
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,  // Enable pinch zoom
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
    );
  }

  Widget _buildRiskSuggestionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          if (_result != null && _result!.riskSuggestions.isNotEmpty) {
            _showRiskSuggestions();
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF167339),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Risk Suggestion',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showRiskSuggestions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Risk Suggestions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ..._result!.riskSuggestions.map((suggestion) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(suggestion, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.home, size: 20, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.copy, size: 20, color: Colors.grey),
            ),
            const Spacer(),
            Flexible(
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
                child: const Text('Chatbot', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF167339)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Analytics', style: TextStyle(color: Color(0xFF167339), fontWeight: FontWeight.w600, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            // Left: Horizontally slidable zoomed stress zone maps
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Stress Zone ${_selectedStressZoneIndex + 1}/${_top4StressZones.length}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          const Icon(Icons.swipe, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        child: _top4StressZones.isEmpty
                            ? const Center(child: Text('No zones', style: TextStyle(color: Colors.grey)))
                            : PageView.builder(
                                controller: _zoomedMapPageController,
                                itemCount: _top4StressZones.length,
                                onPageChanged: (index) => _syncToZone(index),
                                itemBuilder: (context, index) {
                                  return _buildZoomedMapForZone(index);
                                },
                              ),
                      ),
                    ),
                    // Page indicators
                    if (_top4StressZones.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_top4StressZones.length, (index) {
                            return Container(
                              width: _selectedStressZoneIndex == index ? 16 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: _selectedStressZoneIndex == index
                                    ? const Color(0xFF167339)
                                    : Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Right: Zone-Specific Action Recommendations
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: _getZoneSeverityColor(),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Zone ${_selectedStressZoneIndex + 1} Action',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: _getZoneSeverityColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Severity badge
                    if (_top4StressZones.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getZoneSeverityColor().withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getZoneSeverity(),
                          style: TextStyle(
                            fontSize: 9,
                            color: _getZoneSeverityColor(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _getZoneAction(),
                          style: const TextStyle(fontSize: 11, height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getZoneAction() {
    if (_isLoading) {
      return 'Analyzing zone ${_selectedStressZoneIndex + 1}...';
    }
    if (_top4StressZones.isEmpty) {
      return 'No zones available';
    }
    final zone = _top4StressZones[_selectedStressZoneIndex];
    // Return zone-specific action, fallback to general analysis
    if (zone.action.isNotEmpty) {
      return zone.action;
    }
    // Generate a contextual action based on zone data
    final severity = zone.score > 0.7 ? 'high' : (zone.score > 0.4 ? 'moderate' : 'low');
    return 'Zone ${_selectedStressZoneIndex + 1} shows $severity stress (score: ${zone.score.toStringAsFixed(2)}). ${zone.label}. '
        'Based on current analysis: ${_result?.detailedAnalysis ?? "Monitor this area closely."}';
  }

  String _getZoneSeverity() {
    if (_top4StressZones.isEmpty) return 'Unknown';
    final zone = _top4StressZones[_selectedStressZoneIndex];
    if (zone.severity.isNotEmpty) return zone.severity;
    if (zone.score > 0.7) return 'High Stress';
    if (zone.score > 0.4) return 'Moderate';
    return 'Low Stress';
  }

  Color _getZoneSeverityColor() {
    if (_top4StressZones.isEmpty) return const Color(0xFF167339);
    final zone = _top4StressZones[_selectedStressZoneIndex];
    // Use severity field for color
    if (zone.severity == 'High' || zone.severity == 'Severe') return Colors.red;
    if (zone.severity == 'Moderate') return Colors.orange;
    return const Color(0xFF167339); // Green for Low
  }

  Widget _buildZoomedMapForZone(int index) {
    if (index >= _top4StressZones.length) {
      return const Center(child: Text('Invalid zone'));
    }
    
    final zone = _top4StressZones[index];
    debugPrint('[FieldVariability] Building zoomed map for zone $index: (${zone.lat}, ${zone.lon}) severity=${zone.severity}');

    // Circle color based on severity: High=red, Moderate=orange, Low=green
    Color circleColor;
    if (zone.severity == 'High' || zone.severity == 'Severe') {
      circleColor = Colors.red;
    } else if (zone.severity == 'Moderate') {
      circleColor = Colors.orange;
    } else {
      circleColor = Colors.green;
    }

    Set<Circle> circles = {
      Circle(
        circleId: CircleId('zone_$index'),
        center: LatLng(zone.lat, zone.lon),
        radius: 15,
        fillColor: circleColor.withOpacity(0.5),
        strokeColor: circleColor,
        strokeWidth: 3,
      ),
    };

    return Stack(
      children: [
        GoogleMap(
          key: ValueKey('zoomed_map_$index'),
          initialCameraPosition: CameraPosition(
            target: LatLng(zone.lat, zone.lon),
            zoom: 18,
          ),
          mapType: MapType.satellite,
          circles: circles,
          zoomControlsEnabled: true,  // Enable zoom buttons
          scrollGesturesEnabled: true,  // Enable pan
          zoomGesturesEnabled: true,  // Enable pinch zoom
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          liteModeEnabled: false,  // Disable for interactivity
        ),
        // Zone number badge with severity label
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: circleColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${zone.severity} ${(index % 4) + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // Score badge
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Score: ${zone.score.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 9),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildMappedAnalyticsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MappedAnalyticsHomeScreen())),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F8E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF167339)),
          ),
          child: const Text(
            'Go to Mapped Analytics',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF167339), fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
