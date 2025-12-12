/// ===========================================================================
/// SENTINEL-2 ANALYSIS SCREEN
/// ===========================================================================
///
/// PURPOSE: Comprehensive field analysis using Sentinel-2 optical data.
///          Provides vegetation indices and LLM-powered insights.
///
/// KEY FEATURES:
///   - Input form for coordinates, crop type, date, field size
///   - Multi-minute processing with progress indicator
///   - Detailed results with LLM analysis
///   - Debug mode showing request payload
///
/// ANALYSIS OUTPUT:
///   - Overall Crop Health status
///   - Soil Status (moisture, salinity, organic matter, fertility)
///   - Bio Risk (pest, disease, nutrient stress, stress zones)
///   - Score indicators (Bio Risk, Soil Health)
///   - Vegetation Indices grid (NDVI, EVI, etc.)
///
/// API FLOW:
///   1. Build request with farmer context
///   2. Call Sentinel2Service.analyzeField()
///   3. Parse LLM analysis and indices summary
///
/// DEPENDENCIES:
///   - Sentinel2Service: HuggingFace Space API
///   - intl: Date formatting
/// ===========================================================================

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:agroww_sih/services/sentinel2_service.dart';
import 'package:intl/intl.dart';

class Sentinel2AnalysisScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFieldData;

  const Sentinel2AnalysisScreen({super.key, this.initialFieldData});

  @override
  State<Sentinel2AnalysisScreen> createState() => _Sentinel2AnalysisScreenState();
}

class _Sentinel2AnalysisScreenState extends State<Sentinel2AnalysisScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = Sentinel2Service();
  
  late TextEditingController _latController;
  late TextEditingController _lonController;
  late TextEditingController _cropController;
  late TextEditingController _dateController;
  late TextEditingController _sizeController;

  bool _isLoading = false;
  Map<String, dynamic>? _results;
  String? _error;
  Map<String, dynamic>? _requestPayload;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(text: widget.initialFieldData?['lat']?.toString() ?? '30.9060');
    _lonController = TextEditingController(text: widget.initialFieldData?['lon']?.toString() ?? '75.8350');
    _cropController = TextEditingController(text: widget.initialFieldData?['crop_type'] ?? 'Wheat');
    _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    _sizeController = TextEditingController(text: widget.initialFieldData?['area_acres']?.toString() ?? '0.04');
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _cropController.dispose();
    _dateController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _results = null;
      _requestPayload = {
        'center_lat': double.parse(_latController.text),
        'center_lon': double.parse(_lonController.text),
        'crop_type': _cropController.text,
        'analysis_date': _dateController.text,
        'field_size_hectares': double.parse(_sizeController.text),
        'farmer_context': {
          'role': 'Owner-Operator',
          'years_farming': 10,
          'irrigation_method': 'Standard',
          'farming_goal': 'Optimize Yield'
        },
      };
    });

    try {
      final results = await _service.analyzeField(
        centerLat: double.parse(_latController.text),
        centerLon: double.parse(_lonController.text),
        cropType: _cropController.text,
        analysisDate: _dateController.text,
        fieldSizeHectares: double.parse(_sizeController.text), // Assuming input is hectares for now, or convert
        farmerContext: {
          'role': 'Owner-Operator',
          'years_farming': 10,
          'irrigation_method': 'Standard',
          'farming_goal': 'Optimize Yield'
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
                  if (_requestPayload != null) _buildDebugInfo(),
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
              "Sentinel-2 Analysis",
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
              const SizedBox(height: 16),
              _buildTextField(_sizeController, "Field Size (Hectares)", isNumber: true),
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
          Text("Processing satellite imagery...\nThis may take up to 2-3 minutes.", textAlign: TextAlign.center),
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
    final llm = _results!['llm_analysis'];
    final indices = _results!['vegetation_indices_summary']['indices'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall Health Section
        _buildSectionTitle("Overall Crop Health"),
        _buildOverallHealthCard(llm['overall_health']),
        
        const SizedBox(height: 20),
        
        // Soil Status Section
        _buildSectionTitle("Soil Status"),
        _buildResultCard("Soil Moisture", llm['soil_moisture']['level'], llm['soil_moisture']['analysis']),
        const SizedBox(height: 10),
        _buildResultCard("Soil Salinity", llm['soil_salinity']['level'], llm['soil_salinity']['analysis']),
        const SizedBox(height: 10),
        _buildResultCard("Organic Matter", llm['organic_matter']['level'], llm['organic_matter']['analysis']),
        const SizedBox(height: 10),
        _buildResultCard("Soil Fertility", llm['soil_fertility']['level'], llm['soil_fertility']['analysis']),
        
        const SizedBox(height: 20),

        // Bio Risk & Stress Section
        _buildSectionTitle("Bio Risk & Stress Analysis"),
        Row(
          children: [
            Expanded(child: _buildResultCard("Pest Risk", llm['pest_risk']?['level'] ?? 'Unknown', llm['pest_risk']?['analysis'] ?? 'No data')),
            const SizedBox(width: 10),
            Expanded(child: _buildResultCard("Disease Risk", llm['disease_risk']?['level'] ?? 'Unknown', llm['disease_risk']?['analysis'] ?? 'No data')),
          ],
        ),
        const SizedBox(height: 10),
        _buildResultCard("Nutrient Stress", llm['nutrient_stress']?['level'] ?? 'Unknown', llm['nutrient_stress']?['analysis'] ?? 'No data'),
        const SizedBox(height: 10),
        _buildResultCard("Stress Zones", llm['stress_zone']?['level'] ?? 'Unknown', llm['stress_zone']?['analysis'] ?? 'No data'),

        const SizedBox(height: 20),
        
        // Scores
        _buildSectionTitle("Overall Scores"),
        _buildScoreIndicator("Bio Risk Score", llm['overall_biorisk']),
        const SizedBox(height: 10),
        _buildScoreIndicator("Soil Health Score", llm['overall_soil_health']),

        const SizedBox(height: 20),

        // Indices Grid
        _buildSectionTitle("Vegetation Indices"),
        const SizedBox(height: 8),
        _buildIndicesGrid(indices),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F3C33))),
    );
  }

  Widget _buildOverallHealthCard(Map<String, dynamic> health) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getColorForLevel(health['status']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (health['status'] ?? 'Unknown').toString().toUpperCase(),
                    style: TextStyle(color: _getColorForLevel(health['status']), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text("Key Concerns:", style: TextStyle(fontWeight: FontWeight.w600)),
            ...(health['key_concerns'] as List? ?? []).map((c) => Text("• $c", style: TextStyle(color: Colors.grey.shade700))),
            const SizedBox(height: 8),
            const Text("Recommendations:", style: TextStyle(fontWeight: FontWeight.w600)),
            ...(health['recommendations'] as List? ?? []).map((r) => Text("• $r", style: TextStyle(color: Colors.grey.shade700))),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, String subtitle, String details) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF167339))),
            const SizedBox(height: 4),
            Text(details, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreIndicator(String label, dynamic scoreVal) {
    double score = (scoreVal as num?)?.toDouble() ?? 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: score,
          backgroundColor: Colors.grey.shade300,
          color: score > 0.7 ? Colors.red : (score > 0.4 ? Colors.orange : Colors.green),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        Text("${(score * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Color _getColorForLevel(String? level) {
    switch (level?.toLowerCase()) {
      case 'high': return Colors.red;
      case 'moderate': return Colors.orange;
      case 'low': return Colors.green;
      case 'good': return Colors.green;
      case 'excellent': return Colors.green;
      case 'fair': return Colors.orange;
      case 'poor': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildResultCard(String title, String status, String details) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1EFEF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status, style: const TextStyle(color: Color(0xFF167339), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(details, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicesGrid(Map<String, dynamic> indices) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: indices.length,
      itemBuilder: (context, index) {
        final key = indices.keys.elementAt(index);
        final value = indices[key]['latest']['mean'];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value.toStringAsFixed(3), style: const TextStyle(fontSize: 18, color: Color(0xFF167339))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDebugInfo() {
    return Card(
      color: Colors.grey.shade200,
      margin: const EdgeInsets.only(bottom: 20),
      child: ExpansionTile(
        title: const Text("Debug: Request Payload", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(_requestPayload),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
