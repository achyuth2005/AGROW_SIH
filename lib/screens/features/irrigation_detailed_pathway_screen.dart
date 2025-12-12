import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/localization_service.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import 'chatbot_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/take_action_service.dart';

class IrrigationDetailedPathwayScreen extends StatefulWidget {
  final String fieldName;
  final double centerLat;
  final double centerLon;
  final double fieldSizeHectares;
  final List<LatLng>? fieldPolygon;
  final Map<String, dynamic>? farmerProfile;
  final double? currentSMI;
  final String? moistureLevel;

  const IrrigationDetailedPathwayScreen({
    super.key,
    required this.fieldName,
    required this.centerLat,
    required this.centerLon,
    required this.fieldSizeHectares,
    this.fieldPolygon,
    this.farmerProfile,
    this.currentSMI,
    this.moistureLevel,
  });

  @override
  State<IrrigationDetailedPathwayScreen> createState() => _IrrigationDetailedPathwayScreenState();
}

class _IrrigationDetailedPathwayScreenState extends State<IrrigationDetailedPathwayScreen> {
  bool _isLoading = true;
  String _selectedPriority = 'High Priority';
  
  // Zone data from clustering
  List<ZoneInfo> _highPriorityZones = [];
  List<ZoneInfo> _midPriorityZones = [];
  List<ZoneInfo> _lowPriorityZones = [];
  
  // LLM reasoning
  String _moistureAdvice = 'Loading...';
  String _classificationReason = 'Loading classification data...';
  String _highPriorityAction = 'Loading recommendations...';
  String _midPriorityAction = '';
  String _lowPriorityAction = '';

  @override
  void initState() {
    super.initState();
    _loadClusteringData();
  }

  Future<void> _loadClusteringData() async {
    try {
      debugPrint('[IrrigationPathway] Fetching clustering data for moisture zones...');
      
      // Fetch irrigation-specific LLM reasoning with clustering
      final result = await TakeActionService.fetchReasoning(
        centerLat: widget.centerLat,
        centerLon: widget.centerLon,
        fieldSizeHectares: widget.fieldSizeHectares,
        category: 'irrigation',
        farmerProfile: widget.farmerProfile,
        indicesTimeseries: {
          'SMI': {
            'current_value': widget.currentSMI ?? 0.0,
            'moisture_level': widget.moistureLevel ?? 'Unknown',
          }
        },
      );

      if (mounted && result != null) {
        // Categorize zones by severity
        final highZones = result.highZones.where((z) => 
          z.severity.toLowerCase() == 'high' || z.severity.toLowerCase() == 'severe'
        ).toList();
        
        final midZones = result.highZones.where((z) => 
          z.severity.toLowerCase() == 'moderate'
        ).toList()..addAll(
          result.lowZones.where((z) => z.severity.toLowerCase() == 'moderate')
        );
        
        final lowZones = result.lowZones.where((z) => 
          z.severity.toLowerCase() == 'low'
        ).toList();

        setState(() {
          _highPriorityZones = highZones;
          _midPriorityZones = midZones;
          _lowPriorityZones = lowZones;
          
          _moistureAdvice = result.recommendations.isNotEmpty 
              ? result.recommendations 
              : 'Based on soil moisture analysis, prioritize irrigation in high stress zones.';
          
          _classificationReason = result.detailedAnalysis.isNotEmpty
              ? result.detailedAnalysis
              : 'Zones classified based on SMI (Soil Moisture Index) values from Sentinel-2 SWIR bands. '
                'High priority zones show significant moisture deficit requiring immediate attention.';
          
          // Generate priority-specific actions
          _highPriorityAction = highZones.isNotEmpty && highZones.first.action.isNotEmpty
              ? highZones.first.action
              : 'Immediate irrigation required. Apply 20-25mm water per hectare within 24 hours.';
          
          _midPriorityAction = midZones.isNotEmpty && midZones.first.action.isNotEmpty
              ? midZones.first.action
              : 'Schedule irrigation within 2-3 days. Monitor soil moisture levels closely.';
          
          _lowPriorityAction = lowZones.isNotEmpty && lowZones.first.action.isNotEmpty
              ? lowZones.first.action
              : 'Regular irrigation schedule sufficient. Continue water-efficient practices.';
          
          _isLoading = false;
        });
      } else {
        _setFallbackData();
      }
    } catch (e) {
      debugPrint('[IrrigationPathway] Error: $e');
      _setFallbackData();
    }
  }

  void _setFallbackData() {
    if (mounted) {
      setState(() {
        _moistureAdvice = 'Unable to load real-time data. Check connectivity.';
        _classificationReason = 'Classification data unavailable.';
        _highPriorityAction = 'Check field conditions manually and apply irrigation as needed.';
        _midPriorityAction = 'Monitor soil moisture and irrigate if signs of stress appear.';
        _lowPriorityAction = 'Maintain current irrigation schedule.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F3),
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 1),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          loc.tr('irrigation_scheduling'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Balance for back button
                    ],
                  ),
                ),
              ),
              // Main Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCropMoistureSection(),
                            const SizedBox(height: 20),
                            _buildPriorityZonesSection(),
                            const SizedBox(height: 20),
                            _buildClassificationReasonSection(),
                            const SizedBox(height: 20),
                            _buildActionSection(),
                            const SizedBox(height: 20),
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


  Widget _buildCropMoistureSection() {
    final loc = Provider.of<LocalizationProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.tr('crop_moisture_content'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Left card: How to make it better
            Expanded(
              flex: 2,
              child: Container(
                height: 130,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.tr('how_to_make_better'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        _moistureAdvice,
                        style: const TextStyle(fontSize: 11, height: 1.4),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Right card: Moisture Level
            Expanded(
              child: Container(
                height: 130,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      loc.tr('moisture_level'),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getMoistureLevelColor(),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.moistureLevel ?? '--',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SMI: ${(widget.currentSMI ?? 0).toStringAsFixed(3)}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionRow(onChatbot: _navigateToChatbot, buttonLabel: loc.tr('detailed_pathway')),
      ],
    );
  }

  Widget _buildPriorityZonesSection() {
    final loc = Provider.of<LocalizationProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.tr('irrigation_priority_zones'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildPriorityZoneCard(
              loc.tr('high_priority'),
              _highPriorityZones.length,
              const Color(0xFFE74C3C),
            ),
            const SizedBox(width: 8),
            _buildPriorityZoneCard(
              loc.tr('mid_priority'),
              _midPriorityZones.length,
              const Color(0xFFF39C12),
            ),
            const SizedBox(width: 8),
            _buildPriorityZoneCard(
              loc.tr('low_priority'),
              _lowPriorityZones.length,
              const Color(0xFF27AE60),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriorityZoneCard(String label, int count, Color color) {
    final loc = Provider.of<LocalizationProvider>(context);
    return Expanded(
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F8E0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Colored header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Zone count
            Expanded(
              child: Center(
                child: Text(
                  '$count ${loc.tr('zones')}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassificationReasonSection() {
    final loc = Provider.of<LocalizationProvider>(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.tr('classification_reason'),
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            _classificationReason,
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    final loc = Provider.of<LocalizationProvider>(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Action description
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.tr('how_to_act'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Text(
                  _getActionForPriority(),
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Right: Priority selector
        Container(
          width: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildPriorityButton('High Priority', const Color(0xFFE74C3C), displayLabel: loc.tr('high_priority')),
              _buildPriorityButton('Mid Priority', const Color(0xFFF39C12), displayLabel: loc.tr('mid_priority')),
              _buildPriorityButton('Low Priority', const Color(0xFF27AE60), displayLabel: loc.tr('low_priority')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityButton(String label, Color color, {String? displayLabel}) {
    final isSelected = _selectedPriority == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPriority = label;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          displayLabel ?? label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  String _getActionForPriority() {
    switch (_selectedPriority) {
      case 'High Priority':
        return _highPriorityAction;
      case 'Mid Priority':
        return _midPriorityAction;
      case 'Low Priority':
        return _lowPriorityAction;
      default:
        return _highPriorityAction;
    }
  }

  Widget _buildActionRow({required VoidCallback onChatbot, required String buttonLabel}) {
    final loc = Provider.of<LocalizationProvider>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.home, size: 18, color: Color(0xFF167339)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF167339)),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onChatbot,
            child: Text(
              loc.tr('ask_chatbot'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF167339),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMoistureLevelColor() {
    switch ((widget.moistureLevel ?? '').toLowerCase()) {
      case 'high':
        return Colors.blue;
      case 'moderate':
        return Colors.green;
      case 'low':
        return Colors.orange;
      case 'dry':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _navigateToChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatbotScreen()),
    );
  }
}
