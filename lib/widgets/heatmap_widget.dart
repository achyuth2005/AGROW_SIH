import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/heatmap_service.dart';

/// A widget that displays a mini heatmap preview and supports full-screen viewing
class HeatmapWidget extends StatefulWidget {
  final double centerLat;
  final double centerLon;
  final double fieldSizeHectares;
  final String indexType;
  final String title;
  final double width;
  final double height;

  const HeatmapWidget({
    super.key,
    required this.centerLat,
    required this.centerLon,
    this.fieldSizeHectares = 10.0,
    this.indexType = 'NDVI',
    this.title = 'Heatmap',
    this.width = 100,
    this.height = 80,
  });

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
        indexType: widget.indexType,
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
        indexType: widget.indexType,
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
  final String indexType;

  const _FullScreenHeatmapDialog({
    required this.heatmapResult,
    required this.title,
    required this.indexType,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
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
                    child: Text(
                      '$title - $indexType',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Heatmap image
            Container(
              constraints: const BoxConstraints(maxHeight: 350),
              margin: const EdgeInsets.all(16),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('Min', heatmapResult.minValue.toStringAsFixed(2), Colors.red),
                  _buildStatItem('Mean', heatmapResult.meanValue.toStringAsFixed(2), Colors.orange),
                  _buildStatItem('Max', heatmapResult.maxValue.toStringAsFixed(2), Colors.green),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Timestamp
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Based on Sentinel-2 satellite data',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
