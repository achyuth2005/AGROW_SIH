import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/heatmap_service.dart';
import '../services/heatmap_cache_service.dart';
import '../services/timeseries_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';

/// Mapped Analytics Results Screen
/// Shows horizontal swipe view with Google Maps + heatmap overlay + LLM analysis
class MappedAnalyticsResultsScreen extends StatefulWidget {
  final List<Map<String, String>> categories;
  final double centerLat;
  final double centerLon;
  final double fieldSizeHectares;
  final String fieldName;
  final List<List<double>> fieldPolygon; // [[lat1, lon1], [lat2, lon2], ...]

  const MappedAnalyticsResultsScreen({
    super.key,
    required this.categories,
    required this.centerLat,
    required this.centerLon,
    required this.fieldSizeHectares,
    required this.fieldName,
    required this.fieldPolygon,
  });

  @override
  State<MappedAnalyticsResultsScreen> createState() => _MappedAnalyticsResultsScreenState();
}

class _MappedAnalyticsResultsScreenState extends State<MappedAnalyticsResultsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Cache for heatmap results
  final Map<String, HeatmapResult?> _heatmapResults = {};
  final Map<String, bool> _isLoading = {};
  final Map<String, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _loadAllHeatmaps();
  }

  Future<void> _loadAllHeatmaps() async {
    for (final category in widget.categories) {
      final metric = category['metric']!;
      _loadHeatmap(metric);
    }
  }

  Future<void> _loadHeatmap(String metric) async {
    setState(() {
      _isLoading[metric] = true;
      _errors[metric] = null;
    });

    try {
      // Check cache first
      final cached = await HeatmapCacheService.getFromCache(
        lat: widget.centerLat,
        lon: widget.centerLon,
        metric: metric,
      );

      if (cached != null) {
        if (mounted) {
          setState(() {
            _heatmapResults[metric] = HeatmapResult(
              success: true,
              metric: cached.metric,
              mode: 'cached',
              indexUsed: cached.metric,
              meanValue: cached.meanValue,
              minValue: cached.minValue,
              maxValue: cached.maxValue,
              imageBase64: cached.imageBase64,
              timestamp: cached.cachedAt.toIso8601String(),
              analysis: cached.analysis,
              detailedAnalysis: cached.detailedAnalysis,
              level: cached.level,
              recommendations: cached.recommendations,
            );
            _isLoading[metric] = false;
          });
        }
        return;
      }

      // Fetch from API with overlay mode for clean heatmap
      // Fetch timeseries data for key indices IN PARALLEL for faster loading
      Map<String, dynamic> timeSeriesData = {};
      Map<String, dynamic>? weatherData;
      
      try {
        // Fetch only essential indices in parallel with timeout
        final keyIndices = ['NDVI', 'NDRE', 'SMI'];  // Reduced to 3 key indices for speed
        
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
            debugPrint('Failed to fetch $indexName timeseries: $e');
          }
          return null;
        }).toList();
        
        // Wait for all in parallel with overall timeout
        final results = await Future.wait(futures).timeout(
          const Duration(seconds: 20),
          onTimeout: () => futures.map((_) => null).toList(),
        );
        
        for (final result in results) {
          if (result != null) {
            timeSeriesData[result.key] = result.value;
          }
        }
      } catch (e) {
        debugPrint('Timeseries fetch failed: $e');
      }
      
      // Fetch weather data
      try {
        // Use cached weather if available, or simple placeholder
        // TODO: Integrate with actual weather service
        weatherData = {
          'temperature': 28,
          'humidity': 65,
          'conditions': 'Clear skies',
          'precipitation': 0,
          'forecast': 'Warm and dry for next 3 days',
        };
      } catch (e) {
        debugPrint('Weather fetch failed: $e');
      }
      
      final result = await HeatmapService.fetchHeatmap(
        centerLat: widget.centerLat,
        centerLon: widget.centerLon,
        fieldSizeHectares: widget.fieldSizeHectares,
        metric: metric,
        overlayMode: true, // Clean heatmap without colorbar/title
        timeSeriesData: timeSeriesData.isNotEmpty ? timeSeriesData : null,
        weatherData: weatherData,
      );

      // Save to cache
      await HeatmapCacheService.saveToCache(
        lat: widget.centerLat,
        lon: widget.centerLon,
        metric: metric,
        meanValue: result.meanValue,
        minValue: result.minValue,
        maxValue: result.maxValue,
        imageBase64: result.imageBase64,
        analysis: result.analysis,
        detailedAnalysis: result.detailedAnalysis,
        level: result.level,
        recommendations: result.recommendations,
      );

      if (mounted) {
        setState(() {
          _heatmapResults[metric] = result;
          _isLoading[metric] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errors[metric] = e.toString();
          _isLoading[metric] = false;
        });
      }
    }
  }

  /// Force refresh a specific heatmap, clearing cache first
  Future<void> _forceRefreshHeatmap(String metric) async {
    // Clear cache for this metric
    await HeatmapCacheService.clearCache(
      lat: widget.centerLat,
      lon: widget.centerLon,
      metric: metric,
    );
    
    // Clear local result and reload
    setState(() {
      _heatmapResults[metric] = null;
    });
    
    // Reload from API
    await _loadHeatmap(metric);
  }

  @override
  Widget build(BuildContext context) {
    final currentCategory = widget.categories[_currentPage];
    
    return Scaffold(
      backgroundColor: const Color(0xFFE1EFEF),
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
              _buildHeader(context, currentCategory['name']!),
              
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: widget.categories.length,
                  itemBuilder: (context, index) {
                    final category = widget.categories[index];
                    return _buildCategoryPage(category);
                  },
                ),
              ),
              
              // Page dots
              _buildPageDots(),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String categoryName) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
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
          const SizedBox(height: 8),
          
          // Category title bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      categoryName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F3C33),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCategoryPage(Map<String, String> category) {
    final metric = category['metric']!;
    final isLoading = _isLoading[metric] ?? true;
    final error = _errors[metric];
    final result = _heatmapResults[metric];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Heatmap container with refresh button
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildHeatmapContent(isLoading, error, result),
                  ),
                ),
                // Refresh button
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: isLoading ? null : () => _forceRefreshHeatmap(metric),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLoading ? Icons.hourglass_empty : Icons.refresh,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Colorbar (horizontal, between map and description)
          if (result != null && result.colorbarBase64 != null && result.colorbarBase64!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(
                Uint8List.fromList(result.colorbarBytes!),
                fit: BoxFit.contain,
                height: 40,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 8),
          
          // Description box
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF167339).withOpacity(0.3)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _getAnalysisText(isLoading, error, result, category['name']!),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0F3C33),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapContent(bool isLoading, String? error, HeatmapResult? result) {
    // Create polygon from field coordinates
    final List<LatLng> polygonPoints = widget.fieldPolygon
        .map((coord) => LatLng(coord[0], coord[1]))
        .toList();
    
    // Close the polygon by adding first point at end if needed
    if (polygonPoints.isNotEmpty && polygonPoints.first != polygonPoints.last) {
      polygonPoints.add(polygonPoints.first);
    }
    
    // Use bbox from result for camera positioning if available
    LatLngBounds? cameraBounds;
    if (result?.bbox != null && result!.bbox!.length == 4) {
      final bbox = result.bbox!;
      // bbox format: [sw_lon, sw_lat, ne_lon, ne_lat]
      cameraBounds = LatLngBounds(
        southwest: LatLng(bbox[1], bbox[0]),
        northeast: LatLng(bbox[3], bbox[2]),
      );
    }
    
    // Calculate center from bbox or use widget center
    final center = cameraBounds != null
        ? LatLng(
            (cameraBounds.southwest.latitude + cameraBounds.northeast.latitude) / 2,
            (cameraBounds.southwest.longitude + cameraBounds.northeast.longitude) / 2,
          )
        : LatLng(widget.centerLat, widget.centerLon);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base layer: Google Maps with field polygon
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: 17,
          ),
          mapType: MapType.satellite,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          scrollGesturesEnabled: false, // Lock map to prevent scrolling
          zoomGesturesEnabled: false,   // Lock zoom to keep alignment
          onMapCreated: (controller) {
            // Fit camera to bbox bounds for precise alignment
            if (cameraBounds != null) {
              Future.delayed(const Duration(milliseconds: 100), () {
                controller.animateCamera(
                  CameraUpdate.newLatLngBounds(cameraBounds!, 80), // Large padding for polygon to be strictly within
                );
              });
            }
          },
          polygons: {
            Polygon(
              polygonId: const PolygonId('field_boundary'),
              points: polygonPoints,
              strokeWidth: 3,
              strokeColor: Colors.white,
              fillColor: Colors.transparent,
            ),
          },
        ),
        
        // Overlay layer: Heatmap positioned to fill entire container (matches bbox camera bounds)
        if (result != null && result.imageBase64.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.55,
                child: Image.memory(
                  Uint8List.fromList(result.imageBytes),
                  fit: BoxFit.fill, // Fill exactly to match bbox bounds
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        
        // Loading overlay
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Generating heatmap...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        
        // Error overlay
        if (error != null)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load heatmap',
                    style: TextStyle(color: Colors.red.shade200),
                  ),
                ],
              ),
            ),
          ),
        
        // Bottom label
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.fieldName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getAnalysisText(bool isLoading, String? error, HeatmapResult? result, String categoryName) {
    if (isLoading) {
      return 'Loading analysis for $categoryName...\n\nAnalyzing satellite data, time series trends, and weather conditions...';
    }
    
    if (error != null) {
      return 'Unable to load analysis. Please try again.';
    }
    
    // Prioritize detailed_analysis from LLM
    if (result?.detailedAnalysis != null && result!.detailedAnalysis!.isNotEmpty) {
      final buffer = StringBuffer();
      
      // Add summary and status
      if (result.analysis != null && result.analysis!.isNotEmpty) {
        buffer.writeln('Status: ${result.level ?? "Moderate"} - ${result.analysis}');
        buffer.writeln();
      }
      
      // Add detailed analysis
      buffer.writeln(result.detailedAnalysis);
      
      // Add recommendations if available
      if (result.recommendations != null && result.recommendations!.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Recommendations:');
        for (final rec in result.recommendations!) {
          buffer.writeln('• $rec');
        }
      }
      
      return buffer.toString();
    }
    
    // Fallback to simple analysis
    if (result?.analysis != null && result!.analysis!.isNotEmpty) {
      return '${result.level ?? "Moderate"}: ${result.analysis}';
    }
    
    // Generate default description
    if (result != null) {
      return 'Description of the $categoryName.\n\n'
          '• The analysis shows a mean value of ${result.meanValue.toStringAsFixed(3)}.\n'
          '• Values range from ${result.minValue.toStringAsFixed(3)} to ${result.maxValue.toStringAsFixed(3)}.\n'
          '• Status: ${result.level ?? "Moderate"}\n\n'
          'This map visualizes the spatial distribution of $categoryName across your field, '
          'helping identify areas that may need attention.';
    }
    
    return 'Analysis data not available.';
  }

  Widget _buildPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.categories.length, (index) {
        return Container(
          width: _currentPage == index ? 12 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _currentPage == index
                ? const Color(0xFF167339)
                : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
