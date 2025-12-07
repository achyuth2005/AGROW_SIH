import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/timeseries_service.dart';

/// Interactive Time Series Chart Widget
/// Shows cached data immediately while fetching fresh predictions in background
class TimeSeriesChartWidget extends StatefulWidget {
  final double centerLat;
  final double centerLon;
  final double fieldSizeHectares;
  final String metric;
  final String title;
  final double height;
  final Color historicalColor;
  final Color forecastColor;

  const TimeSeriesChartWidget({
    super.key,
    required this.centerLat,
    required this.centerLon,
    this.fieldSizeHectares = 10.0,
    this.metric = 'VV',
    this.title = 'Time Series',
    this.height = 200,
    this.historicalColor = const Color(0xFF167339),
    this.forecastColor = const Color(0xFF2196F3),
  });

  @override
  State<TimeSeriesChartWidget> createState() => _TimeSeriesChartWidgetState();
}

class _TimeSeriesChartWidgetState extends State<TimeSeriesChartWidget> 
    with SingleTickerProviderStateMixin {
  TimeSeriesResult? _result;
  bool _isLoading = true;
  bool _isRefreshing = false;  // Background refresh in progress
  bool _isFromCache = false;   // Current data is from cache
  String? _cacheAge;           // "2h ago" style string
  String? _error;
  int? _selectedIndex;
  
  // Loading state
  String _loadingStage = 'Connecting to server...';
  int _loadingProgress = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(_pulseController);
    _fetchData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    // If force refresh, show refreshing indicator but keep current data
    if (forceRefresh && _result != null) {
      setState(() {
        _isRefreshing = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
        _loadingStage = 'Checking cache...';
        _loadingProgress = 10;
      });
    }

    try {
      // Use cache-aware fetch
      final cacheResult = await TimeSeriesService.fetchWithCache(
        centerLat: widget.centerLat,
        centerLon: widget.centerLon,
        fieldSizeHectares: widget.fieldSizeHectares,
        metric: widget.metric,
        forceRefresh: forceRefresh,
        onFreshData: _onFreshDataReceived,
      );
      
      if (mounted) {
        if (cacheResult.hasCachedData) {
          // Show cached data immediately
          setState(() {
            _result = cacheResult.result;
            _isFromCache = true;
            _cacheAge = cacheResult.cacheAge;
            _isLoading = false;
            _isRefreshing = true; // API fetch is running in background
          });
        } else {
          // No cache, show loading state
          _updateLoadingState('Fetching satellite data...', 25);
          setState(() {
            _isRefreshing = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }
  
  /// Called when fresh data arrives from background fetch
  void _onFreshDataReceived(TimeSeriesResult freshData) {
    if (mounted) {
      setState(() {
        _result = freshData;
        _isFromCache = false;
        _cacheAge = 'just now';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _updateLoadingState(String stage, int progress) {
    if (mounted) {
      setState(() {
        _loadingStage = stage;
        _loadingProgress = progress;
      });
    }
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with cache indicator
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
              // Refresh button
              if (_result != null)
                GestureDetector(
                  onTap: _isRefreshing ? null : () => _fetchData(forceRefresh: true),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: _isRefreshing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.historicalColor,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                  ),
                ),
              const SizedBox(width: 8),
              if (_result != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTrendColor(_result!.trend).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _result!.trendIcon,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _result!.trend.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getTrendColor(_result!.trend),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          // Cache status row
          if (_result != null && (_isFromCache || _isRefreshing)) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (_isFromCache) ...[
                  const Text(
                    '📦',
                    style: TextStyle(fontSize: 10),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Cached • $_cacheAge',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (_isRefreshing) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• Updating...',
                    style: TextStyle(
                      fontSize: 10,
                      color: widget.historicalColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 8),
          
          // Chart or Loading/Error
          SizedBox(
            height: widget.height,
            child: _buildContent(),
          ),
          
          // Legend
          if (_result != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Historical', widget.historicalColor, false),
                const SizedBox(width: 16),
                _buildLegendItem('Forecast', widget.forecastColor, true),
              ],
            ),
          ],
          
          // Selected point details
          if (_selectedIndex != null && _result != null) ...[
            const SizedBox(height: 12),
            _buildSelectedPointDetails(),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingBuffer();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300, size: 32),
            const SizedBox(height: 8),
            Text(
              'Unable to load time series data',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              _error!.replaceAll('Exception:', '').trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_result == null || _result!.historical.isEmpty) {
      return const Center(
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }

    return _buildChart();
  }

  /// Animated loading buffer with progress stages
  Widget _buildLoadingBuffer() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF167339).withValues(alpha: 0.05),
                const Color(0xFF2196F3).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated satellite icon
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF167339).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.satellite_alt,
                      size: 30,
                      color: Color(0xFF167339),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Progress indicator
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _loadingProgress / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF167339)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Loading stage text
                Text(
                  _loadingStage,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F3C33),
                  ),
                ),
                const SizedBox(height: 4),
                
                // Progress percentage
                Text(
                  '${_loadingProgress}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Info text
                Text(
                  'Fetching satellite data & running AI predictions\nPlease wait...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChart() {
    final allPoints = _result!.allPoints;
    final histLength = _result!.historical.length;
    
    // Convert to FlSpot
    final spots = <FlSpot>[];
    for (int i = 0; i < allPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), allPoints[i].value));
    }
    
    // Calculate min/max for y-axis
    final values = allPoints.map((p) => p.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b) - 1;
    final maxY = values.reduce((a, b) => a > b ? a : b) + 1;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: allPoints.length / 5,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= allPoints.length) return const SizedBox.shrink();
                final date = allPoints[idx].date;
                return Text(
                  '${date.month}/${date.day}',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
              setState(() {
                _selectedIndex = response.lineBarSpots!.first.spotIndex;
              });
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.spotIndex;
                final point = allPoints[idx];
                final isForecast = idx >= histLength;
                return LineTooltipItem(
                  '${point.date.toString().split(' ')[0]}\n${point.value.toStringAsFixed(2)}',
                  TextStyle(
                    color: isForecast ? widget.forecastColor : widget.historicalColor,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          // Historical line
          LineChartBarData(
            spots: spots.sublist(0, histLength),
            isCurved: true,
            color: widget.historicalColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: widget.historicalColor.withValues(alpha: 0.1),
            ),
          ),
          // Forecast line (dashed)
          if (histLength < spots.length)
            LineChartBarData(
              spots: spots.sublist(histLength - 1), // Overlap for continuity
              isCurved: true,
              color: widget.forecastColor,
              barWidth: 2,
              dashArray: [5, 5],
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: widget.forecastColor.withValues(alpha: 0.1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedPointDetails() {
    final allPoints = _result!.allPoints;
    final point = allPoints[_selectedIndex!];
    final isForecast = _selectedIndex! >= _result!.historical.length;
    
    ForecastPoint? forecastPoint;
    if (isForecast) {
      final fIdx = _selectedIndex! - _result!.historical.length;
      if (fIdx >= 0 && fIdx < _result!.forecast.length) {
        forecastPoint = _result!.forecast[fIdx];
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isForecast ? widget.forecastColor : widget.historicalColor).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isForecast ? widget.forecastColor : widget.historicalColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isForecast ? Icons.auto_graph : Icons.show_chart,
                size: 16,
                color: isForecast ? widget.forecastColor : widget.historicalColor,
              ),
              const SizedBox(width: 8),
              Text(
                isForecast ? 'FORECAST' : 'HISTORICAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isForecast ? widget.forecastColor : widget.historicalColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    point.date.toString().split(' ')[0],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Value', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    point.value.toStringAsFixed(4),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (forecastPoint != null && forecastPoint.confidenceLow != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Confidence', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      '${forecastPoint.confidenceLow!.toStringAsFixed(2)} - ${forecastPoint.confidenceHigh!.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDashed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDashed)
          Row(
            children: List.generate(3, (i) => Container(
              width: 4,
              height: 2,
              margin: const EdgeInsets.only(right: 2),
              color: color,
            )),
          )
        else
          Container(
            width: 16,
            height: 2,
            color: color,
          ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color),
        ),
      ],
    );
  }

  Color _getTrendColor(String trend) {
    switch (trend) {
      case 'improving': return Colors.green;
      case 'declining': return Colors.red;
      default: return Colors.orange;
    }
  }
}
