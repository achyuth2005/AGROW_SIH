/// ===========================================================================
/// SAR ANALYSIS SCREEN
/// ===========================================================================
///
/// PURPOSE: Synthetic Aperture Radar analysis for crop health monitoring.
///          Uses SAR backscatter data for all-weather field assessment.
///
/// KEY FEATURES:
///   - Input form for coordinates, crop type, date
///   - SAR analysis via SarAnalysisService
///   - Results display: greenness, nitrogen, biomass, heat stress
///   - Weather conditions card
///
/// API FLOW:
///   1. Create bounding box around input coordinates
///   2. Call SarAnalysisService.analyzeField()
///   3. Display health summary and weather data
///
/// UI SECTIONS:
///   - Analysis Parameters form
///   - Crop Health Summary card
///   - Weather Conditions card
///
/// DEPENDENCIES:
///   - SarAnalysisService: Backend API calls
///   - intl: Date formatting
/// ===========================================================================

import 'package:flutter/material.dart';
import 'package:agroww_sih/services/sar_analysis_service.dart';
import 'package:intl/intl.dart';

class SarAnalysisScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFieldData;

  const SarAnalysisScreen({super.key, this.initialFieldData});

  @override
  State<SarAnalysisScreen> createState() => _SarAnalysisScreenState();
}

class _SarAnalysisScreenState extends State<SarAnalysisScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SarAnalysisService();
  
  late TextEditingController _latController;
  late TextEditingController _lonController;
  late TextEditingController _cropController;
  late TextEditingController _dateController;

  bool _isLoading = false;
  Map<String, dynamic>? _results;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Parse coordinates from initial data if available
    String lat = '30.9060';
    String lon = '75.8350';
    
    if (widget.initialFieldData != null) {
      try {
        // Try to get center point or first point of polygon
        if (widget.initialFieldData!.containsKey('lat1')) {
           lat = widget.initialFieldData!['lat1'].toString();
           lon = widget.initialFieldData!['lon1'].toString();
        }
      } catch (e) {
        debugPrint("Error parsing initial coordinates: $e");
      }
    }

    _latController = TextEditingController(text: lat);
    _lonController = TextEditingController(text: lon);
    _cropController = TextEditingController(text: widget.initialFieldData?['crop_type'] ?? 'Wheat');
    _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _cropController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _results = null;
    });

    try {
      // Create a small bounding box around the point for SAR analysis
      // SAR service expects [minLon, minLat, maxLon, maxLat]
      final lat = double.parse(_latController.text);
      final lon = double.parse(_lonController.text);
      final bbox = [lon - 0.001, lat - 0.001, lon + 0.001, lat + 0.001];

      final results = await _service.analyzeField(
        coordinates: bbox,
        cropType: _cropController.text,
        date: _dateController.text,
        context: {
          'role': 'Owner-Operator', // Default context
        },
      );

      if (mounted) {
        setState(() {
          _results = results;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EFEF),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputForm(),
                  const SizedBox(height: 20),
                  if (_isLoading) _buildLoadingState(),
                  if (_error != null) _buildErrorState(),
                  if (_results != null) _buildResultsView(),
                ],
              ),
            ),
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
          left: 20,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
            ),
          ),
        ),
        const Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              "SAR Analysis",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputForm() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Analysis Parameters", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField(_latController, "Latitude", isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_lonController, "Longitude", isNumber: true)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField(_cropController, "Crop Type")),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_dateController, "Date (YYYY-MM-DD)")),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _runAnalysis,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF167339),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_isLoading ? "Analyzing..." : "Run Analysis"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(color: Color(0xFF167339)),
          SizedBox(height: 16),
          Text("Processing SAR data...\nAnalyzing radar backscatter...", textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text("Error: $_error", style: TextStyle(color: Colors.red.shade800)),
    );
  }

  Widget _buildResultsView() {
    final summary = _results!['health_summary'];
    final weather = _results!['weather_data'] != null && (_results!['weather_data'] as List).isNotEmpty 
        ? _results!['weather_data'].last 
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultCard("Crop Health Summary", summary),
        const SizedBox(height: 16),
        if (weather != null) _buildWeatherCard(weather),
      ],
    );
  }

  Widget _buildResultCard(String title, Map<String, dynamic> data) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF167339))),
            const SizedBox(height: 16),
            _buildStatRow("Greenness", data['greenness_level'], data['greenness_status']),
            const Divider(),
            _buildStatRow("Nitrogen", data['nitrogen_level'], data['nitrogen_status']),
            const Divider(),
            _buildStatRow("Biomass", data['biomass_level'], data['biomass_status']),
            const Divider(),
            _buildStatRow("Heat Stress", data['heat_stress_level'], data['heat_stress_status']),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String? level, String? status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                level?.toUpperCase() ?? 'UNKNOWN',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getColorForLevel(level),
                ),
              ),
              if (status != null)
                Text(status, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(Map<String, dynamic> weather) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Weather Conditions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF167339))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherItem(Icons.thermostat, "${weather['temp_mean']?.toStringAsFixed(1)}°C", "Temp"),
                _buildWeatherItem(Icons.water_drop, "${weather['humidity']?.toStringAsFixed(0)}%", "Humidity"),
                _buildWeatherItem(Icons.air, "${weather['wind_speed']?.toStringAsFixed(1)} km/h", "Wind"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF597872), size: 28),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Color _getColorForLevel(String? level) {
    if (level == null) return Colors.black;
    final l = level.toLowerCase();
    if (l == 'high') return const Color(0xFF39E639);
    if (l == 'moderate') return Colors.orange;
    return Colors.red;
  }
}
