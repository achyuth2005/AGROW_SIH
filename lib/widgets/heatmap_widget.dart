import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/heatmap_service.dart';

/// A widget that displays a mini heatmap preview and supports full-screen viewing
class HeatmapWidget extends StatefulWidget {
  final double centerLat;
  final double centerLon;
  final double fieldSizeHectares;
  final String metric;  // New: use metric instead of indexType
  final String title;
  final double width;
  final double height;

  const HeatmapWidget({
    super.key,
    required this.centerLat,
    required this.centerLon,
    this.fieldSizeHectares = 10.0,
    this.metric = 'greenness',  // Default to greenness (NDVI)
    this.title = 'Heatmap',
    this.width = 100,
    this.height = 80,
  });
  
  /// Legacy constructor for backward compatibility with indexType
  factory HeatmapWidget.fromIndex({
    Key? key,
    required double centerLat,
    required double centerLon,
    double fieldSizeHectares = 10.0,
    String indexType = 'NDVI',
    String title = 'Heatmap',
    double width = 100,
    double height = 80,
  }) {
    // Map indexType to metric
    final metricMap = {
      'SMI': 'soil_moisture',
      'SOMI': 'soil_organic_matter',
      'SFI': 'soil_fertility',
      'SASI': 'soil_salinity',
      'NDVI': 'greenness',
      'NDRE': 'nitrogen_level',
      'PRI': 'photosynthetic_capacity',
      'EVI': 'greenness',
      'NDWI': 'soil_moisture',
    };
    
    return HeatmapWidget(
      key: key,
      centerLat: centerLat,
      centerLon: centerLon,
      fieldSizeHectares: fieldSizeHectares,
      metric: metricMap[indexType] ?? 'greenness',
      title: title,
      width: width,
      height: height,
    );
  }

  @override
  State<HeatmapWidget> createState() => _HeatmapWidgetState();
}

class _HeatmapWidgetState extends State<HeatmapWidget> {
  HeatmapResult? _heatmapResult;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHeatmap();
  }

  Future<void> _fetchHeatmap() async {
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
      );
      if (mounted) {
        setState(() {
          _heatmapResult = result;
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

  void _showFullScreenHeatmap() {
    if (_heatmapResult == null) return;

    showDialog(
      context: context,
      builder: (context) => _FullScreenHeatmapDialog(
        heatmapResult: _heatmapResult!,
        title: widget.title,
        metric: widget.metric,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _heatmapResult != null ? _showFullScreenHeatmap : null,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade200,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
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

    if (_heatmapResult != null && _heatmapResult!.imageBase64.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            Uint8List.fromList(_heatmapResult!.imageBytes),
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
                'Tap to view',
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
  final HeatmapResult heatmapResult;
  final String title;
  final String metric;

  const _FullScreenHeatmapDialog({
    required this.heatmapResult,
    required this.title,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final isLlmResult = heatmapResult.isLlmResult;
    
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
                            'Index: ${heatmapResult.indexUsed}',
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
              if (isLlmResult && heatmapResult.level != null) ...[
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getLevelColor(heatmapResult.level!).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getLevelColor(heatmapResult.level!)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getLevelColor(heatmapResult.level!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              heatmapResult.level!.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (heatmapResult.stressScore != null)
                            Text(
                              'Stress: ${(heatmapResult.stressScore! * 100).toInt()}%',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      if (heatmapResult.analysis != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          heatmapResult.analysis!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                      if (heatmapResult.recommendations != null && 
                          heatmapResult.recommendations!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Recommendations:', 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ...heatmapResult.recommendations!.map((r) => 
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
                    Uint8List.fromList(heatmapResult.imageBytes),
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
                    _buildStatItem('Min', heatmapResult.minValue.toStringAsFixed(2), Colors.red),
                    _buildStatItem('Mean', heatmapResult.meanValue.toStringAsFixed(2), Colors.orange),
                    _buildStatItem('Max', heatmapResult.maxValue.toStringAsFixed(2), Colors.green),
                  ],
                ),
              ),
              
              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Based on Sentinel-2 satellite data${heatmapResult.imageDate != null ? ' (${heatmapResult.imageDate})' : ''}',
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
