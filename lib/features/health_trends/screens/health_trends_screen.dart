import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:health/health.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/health_providers.dart';

class HealthTrendsScreen extends ConsumerStatefulWidget {
  final String metricId;

  const HealthTrendsScreen({
    super.key,
    required this.metricId,
  });

  @override
  ConsumerState<HealthTrendsScreen> createState() => _HealthTrendsScreenState();
}

class _HealthTrendsScreenState extends ConsumerState<HealthTrendsScreen> {
  int _selectedTabIndex = 0; // 0: Day, 1: Week, 2: Month

  String _getMetricTitle() {
    switch (widget.metricId) {
      case 'heart_rate':
        return 'Heart Rate';
      case 'blood_oxygen':
        return 'Blood Oxygen';
      case 'temperature':
        return 'Body Temp';
      case 'respiratory_rate':
        return 'Respiratory Rate';
      default:
        return 'Health Metric';
    }
  }

  String _getMetricUnit() {
    switch (widget.metricId) {
      case 'heart_rate':
        return 'bpm';
      case 'blood_oxygen':
        return '%';
      case 'temperature':
        return '°C';
      case 'respiratory_rate':
        return 'breaths/min';
      default:
        return '';
    }
  }

  Color _getMetricColor() {
    switch (widget.metricId) {
      case 'heart_rate':
        return const Color(0xFFEC4899);
      case 'blood_oxygen':
        return const Color(0xFF8B5CF6);
      case 'temperature':
        return const Color(0xFF3B82F6);
      case 'respiratory_rate':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _getCurrentValue(List<HealthDataPoint> data) {
    if (data.isEmpty) return '--';
    return data.last.value.toString();
  }

  Map<String, String> _getStats(List<HealthDataPoint> data) {
    if (data.isEmpty) return {'avg': '--', 'high': '--', 'low': '--'};
    
    double sum = 0;
    double high = double.negativeInfinity;
    double low = double.infinity;
    
    for (var point in data) {
      double val = double.tryParse(point.value.toString()) ?? 0.0;
      sum += val;
      if (val > high) high = val;
      if (val < low) low = val;
    }
    
    return {
      'avg': (sum / data.length).toStringAsFixed(1),
      'high': high.toStringAsFixed(1),
      'low': low.toStringAsFixed(1),
    };
  }

  List<FlSpot> _getChartData(List<HealthDataPoint> data) {
    if (data.isEmpty) return const [];
    
    // For simplicity in the prototype, we just plot the index against the value
    // In a production app, we would normalize the x-axis to timestamps
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      double val = double.tryParse(data[i].value.toString()) ?? 0.0;
      spots.add(FlSpot(i.toDouble(), val));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    int daysBack = 1;
    if (_selectedTabIndex == 1) daysBack = 7;
    if (_selectedTabIndex == 2) daysBack = 30;

    final healthDataAsync = ref.watch(healthDataProvider(HealthMetricRequest(
      metricId: widget.metricId,
      daysBack: daysBack,
    )));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _getMetricTitle(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_rounded, color: isDark ? Colors.white : Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: healthDataAsync.when(
        data: (data) => LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 800) {
              return _buildMobileLayout(context, data);
            } else {
              return _buildDesktopLayout(context, data);
            }
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading health data', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, List<HealthDataPoint> data) {
    final isDark = context.isDark;
    final stats = _getStats(data);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentValueHeader(isDark, data),
          const SizedBox(height: AppSpacing.xxl),
          _buildTimePeriodTabs(isDark),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            height: 250,
            child: _buildChart(isDark, data),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(child: _buildStatCard('Average', stats['avg']!, isDark)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildStatCard('Highest', stats['high']!, isDark)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildStatCard('Lowest', stats['low']!, isDark)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildAiInsights(isDark),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, List<HealthDataPoint> data) {
    final isDark = context.isDark;
    final stats = _getStats(data);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column (Chart & Time Tabs)
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCurrentValueHeader(isDark, data),
                      SizedBox(
                        width: 300,
                        child: _buildTimePeriodTabs(isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Expanded(
                    child: _buildChart(isDark, data),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxl),
          // Right Column (Stats & Insights)
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Average', stats['avg']!, isDark)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _buildStatCard('Highest', stats['high']!, isDark)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Lowest', stats['low']!, isDark)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Container(
                        height: 90,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getMetricColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Normal Range\nMaintained',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _getMetricColor(),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Expanded(child: _buildAiInsights(isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentValueHeader(bool isDark, List<HealthDataPoint> data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              _getCurrentValue(data),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: -2,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, right: 12),
              child: Text(
                _getMetricUnit(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Normal',
            style: TextStyle(
              color: Color(0xFF10B981),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePeriodTabs(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTab('Day', 0, isDark),
          _buildTab('Week', 1, isDark),
          _buildTab('Month', 2, isDark),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? Colors.white : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? Colors.black87 : Colors.black87)
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart(bool isDark, List<HealthDataPoint> data) {
    final metricColor = _getMetricColor();
    final chartData = _getChartData(data);
    
    // Default values if empty
    double minY = 60;
    double maxY = 100;
    
    if (chartData.isNotEmpty) {
      minY = chartData.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 5;
      maxY = chartData.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 5;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark ? Colors.white10 : Colors.black12,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _getBottomTitle(value.toInt()),
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: chartData,
            isCurved: true,
            color: metricColor,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  metricColor.withValues(alpha: 0.3),
                  metricColor.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, bool isDark) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _getMetricUnit(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsights(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.1),
            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'AI Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Your ${_getMetricTitle().toLowerCase()} is extremely stable. You maintained a healthy range during sleep and light activities over the selected period.\n\nKeep up the good hydration and consistent sleep schedule to maintain this baseline.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                side: const BorderSide(color: Color(0xFF6366F1)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('View Detailed Report'),
            ),
          )
        ],
      ),
    );
  }

  String _getBottomTitle(int value) {
    switch (_selectedTabIndex) {
      case 0: // Day
        final times = ['12AM', '4AM', '8AM', '12PM', '4PM', '8PM', '11PM'];
        return value >= 0 && value < times.length ? times[value] : '';
      case 1: // Week
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return value >= 0 && value < days.length ? days[value] : '';
      case 2: // Month
        final weeks = ['1', '5', '10', '15', '20', '25', '30'];
        return value >= 0 && value < weeks.length ? weeks[value] : '';
      default:
        return '';
    }
  }
}
