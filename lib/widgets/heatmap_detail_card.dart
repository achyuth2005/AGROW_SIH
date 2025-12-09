import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../services/heatmap_service.dart';
import '../services/heatmap_cache_service.dart';
import 'timeseries_chart_widget.dart';

/// A card widget that displays heatmap with average value, trend, and analysis
/// Fetches data from API and shows results in the specified layout
/// Caches results per field+metric for instant display
class HeatmapDetailCard extends StatefulWidget {
  final String title;
  final String metric;
  final String? satelliteMetric;  // For time series chart
  final double centerLat;
  final double centerLon;
  final double fieldSizeHectares;
  final Map<String, dynamic>? timeSeriesData;

  const HeatmapDetailCard({
    super.key,
    required this.title,
    required this.metric,
    this.satelliteMetric,
    required this.centerLat,
    required this.centerLon,
    this.fieldSizeHectares = 10.0,
    this.timeSeriesData,
  });

  @override
  State<HeatmapDetailCard> createState() => _HeatmapDetailCardState();
}

class _HeatmapDetailCardState extends State<HeatmapDetailCard> {
  HeatmapResult? _result;
  bool _isLoading = true;
  bool _isFromCache = false;
  String? _cacheAge;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load data - check cache first, then fetch if needed
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 1. Check cache first
    final cached = await HeatmapCacheService.getFromCache(
      lat: widget.centerLat,
      lon: widget.centerLon,
      metric: widget.metric,
    );

    if (cached != null) {
      // Use cached data
      if (mounted) {
        setState(() {
          _result = HeatmapResult(
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
            level: cached.level,
            recommendations: cached.recommendations,
          );
          _isLoading = false;
          _isFromCache = true;
          _cacheAge = cached.ageString;
        });
      }
      return;
    }

    // 2. No cache - fetch from API
    await _fetchFromApi();
  }

  /// Force refresh - clear cache and fetch fresh
  Future<void> _forceRefresh() async {
    await HeatmapCacheService.clearCache(
      lat: widget.centerLat,
      lon: widget.centerLon,
      metric: widget.metric,
    );
    setState(() {
      _isFromCache = false;
      _cacheAge = null;
    });
    await _fetchFromApi();
  }

  /// Fetch from API and save to cache
  Future<void> _fetchFromApi() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await HeatmapService.fetchHeatmap(
        centerLat: widget.centerLat,
        centerLon: widget.centerLon,
        fieldSizeHectares: widget.fieldSizeHectares,
        metric: widget.metric,
        timeSeriesData: widget.timeSeriesData,
      );
      
      // Save to cache
      await HeatmapCacheService.saveToCache(
        lat: widget.centerLat,
        lon: widget.centerLon,
        metric: widget.metric,
        meanValue: result.meanValue,
        minValue: result.minValue,
        maxValue: result.maxValue,
        imageBase64: result.imageBase64,
        analysis: result.analysis,
        level: result.level,
        recommendations: result.recommendations,
      );
      
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
          _isFromCache = false;
          _cacheAge = 'just now';
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

  /// Format value with appropriate unit
  String _formatValue(double value) {
    switch (widget.metric) {
      case 'soil_salinity':
        return '${value.toStringAsFixed(2)} dS/m';
      case 'soil_moisture':
        return '${(value * 100).toStringAsFixed(1)}%';
      case 'pest_risk':
      case 'disease_risk':
      case 'nutrient_stress':
        return '${(value * 100).toStringAsFixed(0)}%';
      default:
        return value.toStringAsFixed(3);
    }
  }

  /// Get trend description
  String _getTrend() {
    if (_result == null) return 'Loading...';
    
    // For LLM results, use analysis
    if (_result!.isLlmResult && _result!.analysis != null) {
      return _result!.analysis!;
    }
    
    // For pixelwise, derive from mean value
    final mean = _result!.meanValue;
    if (mean > 0.6) return 'Healthy levels';
    if (mean > 0.3) return 'Moderate levels';
    return 'Needs attention';
  }

  /// Check if trend is positive
  bool _isPositiveTrend() {
    if (_result == null) return true;
    if (_result!.isLlmResult) {
      return _result!.level?.toLowerCase() == 'low';
    }
    return _result!.meanValue > 0.4;
  }

  /// Get status level
  String _getLevel() {
    if (_result == null) return 'Loading...';
    if (_result!.isLlmResult && _result!.level != null) {
      return _result!.level!;
    }
    // Derive from mean value
    final mean = _result!.meanValue;
    if (mean > 0.6) return 'Good';
    if (mean > 0.3) return 'Moderate';
    return 'Low';
  }

  /// Get analysis text for description box
  String _getAnalysis() {
    if (_result == null) return 'Fetching satellite data...';
    if (_result!.isLlmResult && _result!.analysis != null) {
      return _result!.analysis!;
    }
    // Generate description from stats
    return 'Based on satellite analysis, the ${widget.title.toLowerCase()} shows a mean value of ${_result!.meanValue.toStringAsFixed(3)} '
           'with range from ${_result!.minValue.toStringAsFixed(3)} to ${_result!.maxValue.toStringAsFixed(3)}.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with refresh button
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3C33),
                  ),
                ),
              ),
              // Cache indicator
              if (_isFromCache && _cacheAge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '📦 $_cacheAge',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Refresh button
              GestureDetector(
                onTap: _isLoading ? null : _forceRefresh,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : Icon(Icons.refresh, size: 14, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Value & Heatmap Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Value, Trend, Level
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Average Value
                    if (_isLoading)
                      const Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      )
                    else if (_error != null)
                      const Text(
                        'Error',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      )
                    else
                      Text(
                        _formatValue(_result!.meanValue),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F3C33),
                        ),
                      ),
                    const SizedBox(height: 4),
                    
                    // Temporal Trend
                    Row(
                      children: [
                        Icon(
                          _isPositiveTrend() ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          color: _isPositiveTrend() ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        Expanded(
                          child: Text(
                            _getTrend(),
                            style: TextStyle(
                              fontSize: 12,
                              color: _isPositiveTrend() ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Level
                    Text(
                      _getLevel(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // Right side: Heatmap
              _buildHeatmapPreview(),
            ],
          ),
          const SizedBox(height: 24),

          // Time Series Chart (if metric available)
          if (widget.satelliteMetric != null) ...[
            TimeSeriesChartWidget(
              centerLat: widget.centerLat,
              centerLon: widget.centerLon,
              fieldSizeHectares: widget.fieldSizeHectares,
              metric: widget.satelliteMetric!,
              title: '${widget.title} Time Series (Tap for details)',
              height: 200,
            ),
            const SizedBox(height: 16),
          ],

          // Analysis Description Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getAnalysis(),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF167339),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapPreview() {
    return Container(
      width: 100,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildHeatmapContent(),
      ),
    );
  }

  Widget _buildHeatmapContent() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Icon(Icons.error_outline, color: Colors.red.shade300, size: 24),
      );
    }

    if (_result != null && _result!.imageBase64.isNotEmpty) {
      return Image.memory(
        Uint8List.fromList(_result!.imageBytes),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    return const Center(
      child: Icon(Icons.map, color: Colors.grey),
    );
  }
}
