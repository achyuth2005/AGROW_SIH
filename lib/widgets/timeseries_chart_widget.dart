/// ============================================================================
/// FILE: timeseries_chart_widget.dart
/// ============================================================================
/// PURPOSE: Interactive line chart showing historical data and AI predictions
///          for vegetation/soil indices over time.
/// 
/// FEATURES:
///   - Historical data (solid line) + Forecast (dashed line)
///   - Cache-first strategy: Show cached data instantly, refresh in background
///   - Touch interaction: Tap points to see details
///   - Timespan toggle: 30-day view vs full history
///   - Trend indicator: Rising, Falling, Stable
///   - Smart Y-axis scaling for vegetation indices (small value ranges)
///   - Animated loading state with progress indicator
/// 
/// CACHING FLOW:
///   1. Check TimeSeriesCacheService for cached data
///   2. If found: Display immediately, show "📦 Cached" indicator
///   3. If stale (>5 days): Fetch fresh in background
///   4. When fresh data arrives: Update display, hide refresh indicator
/// 
/// SUPPORTED METRICS:
///   Vegetation: NDVI, EVI, NDRE, PRI
///   Soil: SMI, SOMI, SFI, SASI
///   SAR: VV, VH
/// 
/// USAGE:
///   TimeSeriesChartWidget(
///     centerLat: 19.0760,
///     centerLon: 72.8777,
///     metric: 'NDVI',
///     title: 'Vegetation Health',
///     height: 200,
///   )
/// 
/// DEPENDENCIES:
///   - fl_chart: Charting library
///   - timeseries_service.dart: Fetch/compute indices
///   - timeseries_cache_service.dart: File-based caching
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/timeseries_service.dart';
import '../services/timeseries_cache_service.dart';

/// Interactive Time Series Chart Widget.
/// Shows cached data immediately while fetching fresh predictions in background.
class TimeSeriesChartWidget extends StatefulWidget {
  final double centerLat;
  final double centerLon;
  final double fieldSizeHectares;
  final String metric;
  final String title;
  final double height;
  final Color historicalColor;
  final Color forecastColor;
  final bool isCompact;  // Minimal layout for small spaces

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
    this.isCompact = false,  // Default to full layout
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
  
  // Timespan view mode: false = 30 days before/after, true = full history
  bool _showFullHistory = false;
  
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
    debugPrint('[TimeSeriesWidget] _fetchData called: metric=${widget.metric}, forceRefresh=$forceRefresh');
    
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
      
      debugPrint('[TimeSeriesWidget] Cache result: hasCachedData=${cacheResult.hasCachedData}, isFetching=${cacheResult.isFetching}, cacheAge=${cacheResult.cacheAge}');
      
      if (mounted) {
        if (cacheResult.hasCachedData) {
          // Show cached data immediately
          final result = cacheResult.result;
          debugPrint('[TimeSeriesWidget] Using cached data: result=${result != null}, historical=${result?.historical.length ?? 0} points');
          setState(() {
            _result = result;
            _isFromCache = true;
            _cacheAge = cacheResult.cacheAge;
            _isLoading = false;
            // Only show refreshing indicator if actually fetching from API
            _isRefreshing = cacheResult.isFetching;
          });
        } else {
          // No cache exists - fetch directly from API (await the result)
          debugPrint('[TimeSeriesWidget] No cache found, fetching from API directly...');
          _updateLoadingState('Fetching satellite data...', 25);
          
          try {
            final result = await TimeSeriesService.fetchTimeSeries(
              centerLat: widget.centerLat,
              centerLon: widget.centerLon,
              fieldSizeHectares: widget.fieldSizeHectares,
              metric: widget.metric,
            );
            
            // Save to cache for next time
            await TimeSeriesCacheService.saveToCache(
              widget.centerLat,
              widget.centerLon,
              widget.metric,
              result,
            );
            
            if (mounted) {
              setState(() {
                _result = result;
                _isFromCache = false;
                _cacheAge = 'just now';
                _isLoading = false;
                _isRefreshing = false;
              });
            }
          } catch (apiError) {
            debugPrint('[TimeSeriesWidget] API error: $apiError');
            if (mounted) {
              setState(() {
                _error = apiError.toString();
                _isLoading = false;
                _isRefreshing = false;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TimeSeriesWidget] Error: $e');
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
    // Auto-detect compact mode based on height
    final bool isCompact = widget.isCompact || widget.height < 150;
    
    // Compact mode: Just show the chart with minimal chrome
    if (isCompact) {
      return _buildCompactLayout();
    }
    
    // Full layout with all features
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
          
          // Timespan toggle and Legend row
          if (_result != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Expand/Collapse button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showFullHistory = !_showFullHistory;
                      _selectedIndex = null; // Reset selection on view change
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _showFullHistory 
                          ? widget.historicalColor.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showFullHistory 
                            ? widget.historicalColor 
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showFullHistory 
                              ? Icons.zoom_in_map 
                              : Icons.zoom_out_map,
                          size: 14,
                          color: _showFullHistory 
                              ? widget.historicalColor 
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showFullHistory ? '30 Days' : 'Full History',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _showFullHistory 
                                ? widget.historicalColor 
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Legend
                _buildLegendItem('Historical', widget.historicalColor, false),
                const SizedBox(width: 12),
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

  /// Compact layout for small spaces (analytics preview)
  Widget _buildCompactLayout() {
    return SizedBox(
      height: widget.height,
      child: _isLoading
          ? Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.historicalColor,
                ),
              ),
            )
          : _error != null
              ? Center(
                  child: Icon(Icons.error_outline, color: Colors.red.shade300, size: 20),
                )
              : _result == null || _result!.historical.isEmpty
                  ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey, fontSize: 11)))
                  : _buildChart(),
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
    final fullPoints = _result!.allPoints;
    final fullHistLength = _result!.historical.length;
    
    // Filter points based on timespan view mode
    List<DataPoint> displayPoints;
    int displayHistLength;
    
    if (_showFullHistory) {
      // Show all data
      displayPoints = fullPoints;
      displayHistLength = fullHistLength;
    } else {
      // Show 30 days before and 30 days after the current date
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final thirtyDaysAhead = now.add(const Duration(days: 30));
      
      // Filter historical points (last 30 days)
      final filteredHistorical = _result!.historical
          .where((p) => p.date.isAfter(thirtyDaysAgo) && p.date.isBefore(now.add(const Duration(days: 1))))
          .toList();
      
      // Filter forecast points (next 30 days)
      final filteredForecast = _result!.forecast
          .where((p) => p.date.isAfter(now.subtract(const Duration(days: 1))) && p.date.isBefore(thirtyDaysAhead))
          .toList();
      
      // Combine filtered points
      displayPoints = [
        ...filteredHistorical,
        ...filteredForecast.map((f) => DataPoint(date: f.date, value: f.value)),
      ];
      displayHistLength = filteredHistorical.length;
    }
    
    // Handle case where no points are in the filtered range
    if (displayPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, color: Colors.grey.shade400, size: 32),
            const SizedBox(height: 8),
            Text(
              'No data in the last 30 days',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _showFullHistory = true),
              child: const Text('View Full History'),
            ),
          ],
        ),
      );
    }
    
    // Convert to FlSpot
    final spots = <FlSpot>[];
    for (int i = 0; i < displayPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), displayPoints[i].value));
    }
    
    // Calculate min/max for y-axis with smart scaling
    final values = displayPoints.map((p) => p.value).toList();
    final dataMin = values.reduce((a, b) => a < b ? a : b);
    final dataMax = values.reduce((a, b) => a > b ? a : b);
    final dataRange = dataMax - dataMin;
    
    // Dynamic padding: 10% of range, but at least 0.01 for very flat data
    // This ensures vegetation indices (small variations) still show clear graphs
    final padding = dataRange > 0.001 ? dataRange * 0.1 : 0.02;
    final minY = dataMin - padding;
    final maxY = dataMax + padding;

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
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                // Use 2 decimal places for small ranges (vegetation indices)
                final decimals = dataRange < 0.5 ? 2 : 1;
                return Text(
                  value.toStringAsFixed(decimals),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: displayPoints.length > 5 ? displayPoints.length / 5 : 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= displayPoints.length) return const SizedBox.shrink();
                final date = displayPoints[idx].date;
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
            getTooltipColor: (touchedSpot) => const Color(0xFF1E1E1E), // Dark background
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.spotIndex;
                final point = displayPoints[idx];
                final isForecast = idx >= displayHistLength;
                return LineTooltipItem(
                  '${point.date.toString().split(' ')[0]}\n${point.value.toStringAsFixed(3)}',
                  const TextStyle(
                    color: Colors.white, // White text for contrast
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: isForecast ? '\n(Forecast)' : '\n(Historical)',
                      style: TextStyle(
                        color: isForecast ? const Color(0xFF64B5F6) : const Color(0xFF81C784), // Light blue/green
                        fontSize: 10,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          // Historical line
          if (displayHistLength > 0)
            LineChartBarData(
              spots: spots.sublist(0, displayHistLength.clamp(0, spots.length)),
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
          if (displayHistLength < spots.length)
            LineChartBarData(
              spots: spots.sublist((displayHistLength - 1).clamp(0, spots.length - 1)), // Overlap for continuity
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
