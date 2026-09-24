import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:health/health.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/providers.dart';

class HealthOverviewSection extends ConsumerStatefulWidget {
  const HealthOverviewSection({super.key});

  @override
  ConsumerState<HealthOverviewSection> createState() => _HealthOverviewSectionState();
}

class _HealthOverviewSectionState extends ConsumerState<HealthOverviewSection> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startLiveUpdates();
  }

  void _startLiveUpdates() {
    if (!kIsWeb) {
      // Poll all authorized metrics every 10 seconds
      _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
        if (!mounted) return;
        try {
          final biometrics = await ref.read(healthServiceProvider).fetchBiometrics();
          if (biometrics.isNotEmpty && mounted) {
            biometrics.forEach((key, value) {
              final doubleVal = double.tryParse(value.toString());
              if (doubleVal != null) {
                ref.read(liveVitalsProvider.notifier).setVital(key, doubleVal);
              }
            });
          }
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vitals = ref.watch(liveVitalsProvider);

    // A device is "connected" (showing real data) if it has a reading
    bool isConnected(String id) => vitals.containsKey(id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Health Overview',
                style: TextStyle(
                  color: context.isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  children: [
                    Text(
                      'Health Trends',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.show_chart_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              HealthCard(
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFEC4899),
                title: 'Heart Rate',
                value: vitals['heart_rate']?.round().toString() ?? '72',
                unit: 'bpm',
                status: (vitals['heart_rate'] ?? 72) > 90 ? 'Elevated' : 'Normal',
                statusColor: (vitals['heart_rate'] ?? 72) > 90 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                chartColor: const Color(0xFFEC4899),
                chartData: const [72.0, 71.0, 73.0, 72.0, 74.0, 72.0, 75.0],
                isConnected: isConnected('heart_rate'),
                onTap: () {
                  if (isConnected('heart_rate')) {
                    context.push('/health-trends/heart_rate');
                  } else {
                    context.push('/device-connection/heart_rate');
                  }
                },
              ),
              HealthCard(
                icon: Icons.air_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Respiratory Rate',
                value: vitals['respiratory_rate']?.round().toString() ?? '16',
                unit: 'breaths/min',
                status: 'Normal',
                statusColor: const Color(0xFF10B981),
                chartColor: const Color(0xFFF59E0B),
                chartData: const [5, 4, 4, 3, 4, 5, 6],
                isConnected: isConnected('respiratory_rate'),
                onTap: () {
                  if (isConnected('respiratory_rate')) {
                    context.push('/health-trends/respiratory_rate');
                  } else {
                    context.push('/device-connection/respiratory_rate');
                  }
                },
              ),
              HealthCard(
                icon: Icons.thermostat_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Body Temp',
                value: vitals['temperature']?.toStringAsFixed(1) ?? '36.8',
                unit: '°C',
                status: 'Normal',
                statusColor: const Color(0xFF10B981),
                chartColor: const Color(0xFF3B82F6),
                chartData: const [4, 5, 4, 6, 5, 7, 8],
                isConnected: isConnected('temperature'),
                onTap: () {
                  if (isConnected('temperature')) {
                    context.push('/health-trends/temperature');
                  } else {
                    context.push('/device-connection/temperature');
                  }
                },
              ),
              HealthCard(
                icon: Icons.water_drop_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Blood Oxygen',
                value: vitals['blood_oxygen']?.toStringAsFixed(0) ?? '98',
                unit: '%',
                status: 'Excellent',
                statusColor: const Color(0xFF10B981),
                chartColor: const Color(0xFF8B5CF6),
                chartData: const [7, 6, 8, 7, 9, 8, 9],
                isConnected: isConnected('blood_oxygen'),
                onTap: () {
                  if (isConnected('blood_oxygen')) {
                    context.push('/health-trends/blood_oxygen');
                  } else {
                    context.push('/device-connection/blood_oxygen');
                  }
                },
              ),
            ];

            if (constraints.maxWidth > 600) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    runAlignment: WrapAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: cards,
                  ),
                ),
              );
            }

            return SizedBox(
              height: 220,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                itemCount: cards.length,
                separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) => cards[index],
              ),
            );
          },
        ),
      ],
    );
  }
}


class HealthCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String unit;
  final String status;
  final Color statusColor;
  final Color chartColor;
  final List<double> chartData;
  final bool isConnected;
  final VoidCallback? onTap;

  const HealthCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
    required this.chartColor,
    required this.chartData,
    this.isConnected = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayIconColor = isConnected ? iconColor : (context.isDark ? Colors.white38 : Colors.black38);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 135,
        height: 200,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          boxShadow: [
            if (!context.isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: displayIconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: displayIconColor, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: context.isDark ? Colors.white70 : Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (isConnected) ...[
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
                        color: context.isDark ? Colors.white : Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      unit,
                      style: TextStyle(
                        color: context.isDark ? Colors.white54 : Colors.black45,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RepaintBoundary(
                child: SizedBox(
                  height: 24,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: chartData.asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(), e.value);
                          }).toList(),
                          isCurved: true,
                          color: chartColor,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: chartColor.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      minX: 0,
                      maxX: (chartData.length - 1).toDouble(),
                      minY: chartData.reduce((a, b) => a < b ? a : b) - 1,
                      maxY: chartData.reduce((a, b) => a > b ? a : b) + 1,
                    ),
                    duration: const Duration(milliseconds: 150),
                  ),
                ),
              ),
            ] else ...[
              const Spacer(),
              Text(
                'Not Connected',
                style: TextStyle(
                  color: context.isDark ? Colors.white38 : Colors.black38,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: context.isDark ? Colors.white38 : Colors.black38,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Awaiting device',
                      style: TextStyle(
                        color: context.isDark ? Colors.white38 : Colors.black38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_link_rounded,
                      size: 14,
                      color: context.isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Connect',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
