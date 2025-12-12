/// ============================================================================
/// FILE: heatmap_detail_card.dart
/// ============================================================================
/// PURPOSE: Rich card widget combining heatmap visualization with time series
///          and AI analysis. Used on soil/crop detail screens.
/// 
/// FEATURES:
///   - Shows average value with trend indicator
///   - Displays mini heatmap preview (tap to expand)
///   - Integrates TimeSeriesChartWidget for temporal data
///   - AI-generated analysis in description box
///   - CACHING: Uses HeatmapCacheService for instant display
///   - Refresh button to force fresh data
/// 
/// LAYOUT:
///   ┌──────────────────────────────────────────────────────┐
///   │ Title                           📦 2h ago   🔄      │
///   ├────────────────────────────────────────────┬─────────┤
///   │ 0.453                                       │ [MAP]  │
///   │ ▲ Healthy levels                           │        │
///   │ Good                                        │        │
///   ├────────────────────────────────────────────┴─────────┤
///   │             [TIME SERIES CHART]                      │
///   ├──────────────────────────────────────────────────────┤
///   │ Based on satellite analysis, the soil moisture...    │
///   └──────────────────────────────────────────────────────┘
/// 
/// DEPENDENCIES:
///   - heatmap_service.dart: Fetch heatmap images
///   - heatmap_cache_service.dart: Local caching
///   - timeseries_chart_widget.dart: Time series graphs
/// ============================================================================

import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../services/heatmap_service.dart';
import '../services/heatmap_cache_service.dart';
import 'timeseries_chart_widget.dart';

/// A card widget that displays heatmap with average value, trend, and analysis.
/// Fetches data from API and shows results in the specified layout.
/// Caches results per field+metric for instant display.
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
    return GestureDetector(
      onTap: _result != null ? _showFullScreenHeatmap : null,
      child: Container(
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
      ),
    );
  }

  void _showFullScreenHeatmap() {
    if (_result == null) return;

    showDialog(
      context: context,
      builder: (context) => _FullScreenHeatmapDialog(
        result: _result!,
        title: widget.title,
        metric: widget.metric,
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
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            Uint8List.fromList(_result!.imageBytes),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Tap to expand',
                style: TextStyle(color: Colors.white, fontSize: 7),
              ),
            ),
          ),
        ],
      );
    }

    return const Center(
      child: Icon(Icons.map, color: Colors.grey),
    );
  }
}

/// Full screen dialog to display heatmap with details
class _FullScreenHeatmapDialog extends StatelessWidget {
  final HeatmapResult result;
  final String title;
  final String metric;

  const _FullScreenHeatmapDialog({
    required this.result,
    required this.title,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final isLlmResult = result.isLlmResult;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF167339),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Index: ${result.indexUsed}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // LLM Analysis (if available)
              if (isLlmResult && result.level != null) ...[
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getLevelColor(result.level!).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getLevelColor(result.level!)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getLevelColor(result.level!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              result.level!.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (result.stressScore != null)
                            Text(
                              'Stress: ${(result.stressScore! * 100).toInt()}%',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      if (result.analysis != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          result.analysis!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                      if (result.recommendations != null && 
                          result.recommendations!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Recommendations:', 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ...result.recommendations!.map((r) => 
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontSize: 12)),
                                Expanded(child: Text(r, style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              
              // Heatmap image
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    Uint8List.fromList(result.imageBytes),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              // Statistics
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem('Min', result.minValue.toStringAsFixed(2), Colors.red),
                    _buildStatItem('Mean', result.meanValue.toStringAsFixed(2), Colors.orange),
                    _buildStatItem('Max', result.maxValue.toStringAsFixed(2), Colors.green),
                  ],
                ),
              ),
              
              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Based on Sentinel-2 satellite data${result.imageDate != null ? ' (${result.imageDate})' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
