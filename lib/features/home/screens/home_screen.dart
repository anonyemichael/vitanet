import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/home/screens/home_search_screen.dart';
import 'package:vitanet/features/home/widgets/filter_bottom_sheet.dart';
import 'package:vitanet/features/home/screens/add_contact_screen.dart';
import 'package:vitanet/features/notifications/screens/notifications_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vitanet/shared/widgets/premium_background.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/data/models/user_profile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: const _HeaderSection(),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 900;
                    
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isDesktop ? 1400 : 800),
                          child: isDesktop 
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Left Column
                                      const Expanded(
                                        flex: 7,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(height: AppSpacing.sm),
                                            _HealthOverviewSection(),
                                            SizedBox(height: 100),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xxxl),
                                      // Right Column
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: const [
                                            SizedBox(height: AppSpacing.sm),
                                            _AiHealthAlertsSection(),
                                            SizedBox(height: AppSpacing.xxl),
                                            _CareCircleSection(),
                                            SizedBox(height: 100),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    SizedBox(height: AppSpacing.sm),
                                    _HealthOverviewSection(),
                                    SizedBox(height: AppSpacing.xxl),
                                    _AiHealthAlertsSection(),
                                    SizedBox(height: AppSpacing.xxl),
                                    _CareCircleSection(),
                                    SizedBox(height: 100),
                                  ],
                                ),
                        ),
                      ),
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  const _HeaderSection();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final authState = ref.watch(authProvider);
    final greeting = _getGreeting();
    final name = profile?.name ?? 'Alex';

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        border: Border(
          bottom: BorderSide(
            color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        boxShadow: [
          if (!context.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        color: context.isDark ? Colors.white60 : Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: TextStyle(
                        color: context.isDark ? Colors.white : Colors.black87,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (!context.isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            color: context.isDark ? Colors.white : Colors.black87,
                            size: 24,
                          ),
                          Positioned(
                            top: 10,
                            right: 12,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  GestureDetector(
                    onTap: () => StatefulNavigationShell.of(context).goBranch(3),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                        image: authState.user?.photoURL != null
                            ? DecorationImage(
                                image: NetworkImage(authState.user!.photoURL!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: authState.user?.photoURL == null
                          ? Icon(
                              Icons.person_rounded,
                              color: context.isDark ? Colors.white : Colors.black54,
                              size: 22,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // Search Bar
          Hero(
            tag: 'home_search_bar',
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.search_rounded,
                      color: context.isDark ? Colors.white54 : Colors.black45,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        readOnly: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => const HomeSearchScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        style: TextStyle(
                          color: context.isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search health, insights...',
                          hintStyle: TextStyle(
                            color: context.isDark ? Colors.white38 : Colors.black38,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showFilter(context),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.tune_rounded,
                          color: context.isDark ? Colors.white54 : Colors.black45,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _HealthOverviewSection extends ConsumerWidget {
  const _HealthOverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(deviceConnectionProvider);
    final connections = connectionsAsync.valueOrNull ?? {
      'heart_rate': true,
    };
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
              _LiveHeartRateCard(
                isConnected: connections['heart_rate'] ?? false,
              ),
              _HealthCard(
                icon: Icons.air_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Respiratory Rate',
                value: '16',
                unit: 'breaths/min',
                status: 'Normal',
                statusColor: const Color(0xFF10B981),
                chartColor: const Color(0xFFF59E0B),
                chartData: const [5, 4, 4, 3, 4, 5, 6],
                isConnected: connections['respiratory_rate'] ?? false,
                onTap: () {
                  final connected = connections['respiratory_rate'] ?? false;
                  if (connected) {
                    context.push('/health-trends/respiratory_rate');
                  } else {
                    context.push('/device-connection/respiratory_rate');
                  }
                },
              ),
              _HealthCard(
                icon: Icons.thermostat_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Body Temp',
                value: '36.8',
                unit: '°C',
                status: 'Normal',
                statusColor: const Color(0xFF10B981),
                chartColor: const Color(0xFF3B82F6),
                chartData: const [4, 5, 4, 6, 5, 7, 8],
                isConnected: connections['temperature'] ?? false,
                onTap: () {
                  final connected = connections['temperature'] ?? false;
                  if (connected) {
                    context.push('/health-trends/temperature');
                  } else {
                    context.push('/device-connection/temperature');
                  }
                },
              ),
              _HealthCard(
                icon: Icons.water_drop_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Blood Oxygen',
                value: '98',
                unit: '%',
                status: 'Excellent',
                statusColor: const Color(0xFF10B981),
                chartColor: const Color(0xFF8B5CF6),
                chartData: const [7, 6, 8, 7, 9, 8, 9],
                isConnected: connections['blood_oxygen'] ?? false,
                onTap: () {
                  final connected = connections['blood_oxygen'] ?? false;
                  if (connected) {
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
              height: 195,
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

class _LiveHeartRateCard extends StatefulWidget {
  final bool isConnected;

  const _LiveHeartRateCard({required this.isConnected});

  @override
  State<_LiveHeartRateCard> createState() => _LiveHeartRateCardState();
}

class _LiveHeartRateCardState extends State<_LiveHeartRateCard> {
  Timer? _timer;
  int _currentRate = 72;
  List<double> _chartData = [72.0, 71.0, 73.0, 72.0, 74.0, 72.0, 75.0];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    if (widget.isConnected) {
      _startLiveUpdates();
    }
  }

  @override
  void didUpdateWidget(_LiveHeartRateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && !oldWidget.isConnected) {
      _startLiveUpdates();
    } else if (!widget.isConnected && oldWidget.isConnected) {
      _timer?.cancel();
    }
  }

  void _startLiveUpdates() async {
    if (!kIsWeb) {
      try {
        // Try fetching real heart rate via Health plugin on mobile devices
        final health = Health();
        final types = [HealthDataType.HEART_RATE];
        
        bool requested = await health.requestAuthorization(types);
        if (requested) {
          _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
            if (!mounted) return;
            try {
              final now = DateTime.now();
              final healthData = await health.getHealthDataFromTypes(
                startTime: now.subtract(const Duration(minutes: 5)),
                endTime: now,
                types: types,
              );
              if (healthData.isNotEmpty && mounted) {
                final latest = healthData.last;
                setState(() {
                  _currentRate = double.parse(latest.value.toString()).round();
                  _chartData.removeAt(0);
                  _chartData.add(_currentRate.toDouble());
                });
              }
            } catch (e) {
              // Ignore periodic errors, let it continue or fallback if empty
            }
          });
          return; // Early return if we successfully started real monitoring
        }
      } catch (e) {
        // Catch MissingPluginException or Unsupported operation
        // Will continue to fallback simulator
      }
    }

    // Fallback Simulator (for Web or if permissions denied)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Fluctuate heart rate slightly
          final change = _random.nextInt(5) - 2; // -2 to +2
          _currentRate = (_currentRate + change).clamp(60, 100);
          
          // Push new value to graph and remove oldest
          _chartData.removeAt(0);
          _chartData.add(_currentRate.toDouble());
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HealthCard(
      icon: Icons.favorite_rounded,
      iconColor: const Color(0xFFEC4899),
      title: 'Heart Rate',
      value: _currentRate.toString(),
      unit: 'bpm',
      status: _currentRate > 90 ? 'Elevated' : 'Normal',
      statusColor: _currentRate > 90 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
      chartColor: const Color(0xFFEC4899),
      chartData: _chartData,
      isConnected: widget.isConnected,
      onTap: () {
        if (widget.isConnected) {
          context.push('/health-trends/heart_rate');
        } else {
          context.push('/device-connection/heart_rate');
        }
      },
    );
  }
}

class _HealthCard extends StatelessWidget {
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

  const _HealthCard({
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
        width: 140,
        height: 170,
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
                fontSize: 12,
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
                        fontSize: 24,
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
              SizedBox(
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
              SizedBox(
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertData {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String actionText;
  final Color actionColor;
  final bool showDot;

  _AlertData({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.actionText,
    required this.actionColor,
    this.showDot = false,
  });
}

class _AiHealthAlertsSection extends StatefulWidget {
  const _AiHealthAlertsSection();

  @override
  State<_AiHealthAlertsSection> createState() => _AiHealthAlertsSectionState();
}

class _AiHealthAlertsSectionState extends State<_AiHealthAlertsSection> {
  final List<_AlertData> _activeAlerts = [
    _AlertData(
      id: 'alert_1',
      icon: Icons.trending_up_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: 'Blood Pressure Trend',
      description: 'Your blood pressure has been slightly higher than your usual range over the past 7 days.',
      actionText: 'View Insights',
      actionColor: const Color(0xFFF59E0B),
      showDot: true,
    ),
    _AlertData(
      id: 'alert_2',
      icon: Icons.medication_rounded,
      iconColor: const Color(0xFF6366F1),
      title: 'Medication Reminder',
      description: 'You missed your morning Lisinopril dose. Would you like to log it now or reschedule?',
      actionText: 'Log Medication',
      actionColor: const Color(0xFF6366F1),
    ),
  ];

  final List<_AlertData> _hiddenQueue = [
    _AlertData(
      id: 'alert_3',
      icon: Icons.water_drop_rounded,
      iconColor: const Color(0xFF06B6D4),
      title: 'Hydration Goal',
      description: 'You\'ve only logged 2 glasses of water today. Stay hydrated to maintain your energy levels!',
      actionText: 'Log Water',
      actionColor: const Color(0xFF06B6D4),
    ),
    _AlertData(
      id: 'alert_4',
      icon: Icons.bed_rounded,
      iconColor: const Color(0xFF8B5CF6),
      title: 'Sleep Analysis',
      description: 'Your sleep quality was 85% last night. Your deep sleep increased by 15 minutes.',
      actionText: 'View Sleep Data',
      actionColor: const Color(0xFF8B5CF6),
    ),
    _AlertData(
      id: 'alert_5',
      icon: Icons.directions_run_rounded,
      iconColor: const Color(0xFF10B981),
      title: 'Activity Goal Met',
      description: 'Great job! You have reached your daily step goal of 10,000 steps.',
      actionText: 'View Summary',
      actionColor: const Color(0xFF10B981),
      showDot: true,
    ),
    _AlertData(
      id: 'alert_6',
      icon: Icons.restaurant_rounded,
      iconColor: const Color(0xFFF97316),
      title: 'Dietary Insight',
      description: 'You have consistently eaten your dinner later than usual. Eating earlier can improve sleep quality.',
      actionText: 'Review Meals',
      actionColor: const Color(0xFFF97316),
    ),
    _AlertData(
      id: 'alert_7',
      icon: Icons.monitor_heart_rounded,
      iconColor: const Color(0xFFEF4444),
      title: 'Heart Rate Spike',
      description: 'Your heart rate briefly spiked to 120 bpm at 2:30 PM. Did you do a light workout?',
      actionText: 'Log Activity',
      actionColor: const Color(0xFFEF4444),
      showDot: true,
    ),
    _AlertData(
      id: 'alert_8',
      icon: Icons.self_improvement_rounded,
      iconColor: const Color(0xFFEC4899),
      title: 'Mental Wellbeing',
      description: 'It\'s been 3 days since you last logged a mindfulness session. Take 5 minutes to breathe.',
      actionText: 'Start Session',
      actionColor: const Color(0xFFEC4899),
    ),
  ];

  void _onDismissed(int index) {
    setState(() {
      _activeAlerts.removeAt(index);
      
      // Infinitely generate a new alert when one is dismissed
      final random = Random();
      final newAlert = _hiddenQueue[random.nextInt(_hiddenQueue.length)];
      
      // Ensure it has a unique ID by appending a timestamp
      _activeAlerts.add(
        _AlertData(
          id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          icon: newAlert.icon,
          iconColor: newAlert.iconColor,
          title: newAlert.title,
          description: newAlert.description,
          actionText: newAlert.actionText,
          actionColor: newAlert.actionColor,
          showDot: random.nextBool(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeAlerts.isEmpty) {
      return const SizedBox.shrink(); // Hide section if no alerts
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Health Alerts',
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
                child: const Text(
                  'See All',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: List.generate(_activeAlerts.length, (index) {
                final alert = _activeAlerts[index];
                return _AnimatedSection(
                  key: ValueKey(alert.id),
                  delay: index,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: index == _activeAlerts.length - 1 ? 0 : AppSpacing.md),
                    child: Dismissible(
                      key: ValueKey('dismiss_${alert.id}'),
                      direction: DismissDirection.horizontal,
                      dismissThresholds: const {
                        DismissDirection.horizontal: 0.4,
                      },
                      movementDuration: const Duration(milliseconds: 300),
                      onDismissed: (direction) => _onDismissed(index),
                      background: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: AppSpacing.xl),
                        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                      ),
                      secondaryBackground: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: AppSpacing.xl),
                        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                      ),
                      child: _AlertTile(
                        icon: alert.icon,
                        iconColor: alert.iconColor,
                        title: alert.title,
                        description: alert.description,
                        actionText: alert.actionText,
                        actionColor: alert.actionColor,
                        showDot: alert.showDot,
                        dotColor: alert.showDot ? alert.iconColor : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _CareCircleSection extends ConsumerStatefulWidget {
  const _CareCircleSection();

  @override
  ConsumerState<_CareCircleSection> createState() => _CareCircleSectionState();
}

class _CareCircleSectionState extends ConsumerState<_CareCircleSection> {
  bool _showAlert = true;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _navigateToAddContact() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddContactScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final contacts = profile?.emergencyContacts ?? [];
    
    // Get the primary contact for the urgent alert if available
    final primaryContact = contacts.isNotEmpty ? contacts.first : null;
    final primaryName = primaryContact?.name ?? 'Mary';
    final primaryPhone = primaryContact?.phone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Care Circle',
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
                child: const Text(
                  'Manage',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        
        SizedBox(
          height: 90,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            children: [
              if (contacts.isEmpty) ...[
                _PulsatingAvatar(
                  name: 'Dr. Sarah',
                  icon: Icons.local_hospital_rounded,
                  color: const Color(0xFF6366F1),
                  isOnline: true,
                  onTap: () => _launchUrl('tel:1234567890'),
                ),
                const SizedBox(width: AppSpacing.lg),
                _PulsatingAvatar(
                  name: 'Mary S.',
                  icon: Icons.person_rounded,
                  color: const Color(0xFF10B981),
                  isOnline: true,
                  onTap: () => _launchUrl('tel:0987654321'),
                ),
              ] else ...[
                for (var contact in contacts) ...[
                  _PulsatingAvatar(
                    name: contact.name.split(' ').first,
                    icon: Icons.person_rounded,
                    color: const Color(0xFF10B981),
                    isOnline: true, // Mock online status
                    onTap: () {
                      if (contact.phone.isNotEmpty) {
                        _launchUrl('tel:${contact.phone}');
                      }
                    },
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
              ],
              _PulsatingAvatar(
                name: 'Add Member',
                icon: Icons.add_rounded,
                color: Colors.grey,
                isOnline: false,
                isDashed: true,
                onTap: _navigateToAddContact,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        
        if (_showAlert)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Dismissible(
              key: const ValueKey('care_circle_alert'),
              direction: DismissDirection.horizontal,
              onDismissed: (direction) {
                setState(() {
                  _showAlert = false;
                });
              },
              background: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: AppSpacing.xl),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
              ),
              secondaryBackground: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.xl),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
              ),
              child: _AlertTile(
                icon: Icons.warning_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'Urgent Update: $primaryName',
                description: '$primaryName\'s blood pressure is unusually high. Consider calling to check on them.',
                actionText: 'Call $primaryName Now',
                actionColor: const Color(0xFFEF4444),
                showDot: true,
                dotColor: const Color(0xFFEF4444),
                onActionTap: () {
                  if (primaryPhone != null) {
                    _launchUrl('tel:$primaryPhone');
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String actionText;
  final Color actionColor;
  final bool showDot;
  final Color? dotColor;
  final VoidCallback? onActionTap;

  const _AlertTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.actionText,
    required this.actionColor,
    this.showDot = false,
    this.dotColor,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: iconColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.03) 
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.05) 
                    : Colors.white,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Glowing Left Accent Bar
                Container(
                  width: 4,
                  height: 120, // Forces height slightly, but column shrinks
                  decoration: BoxDecoration(
                    color: iconColor,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: iconColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (showDot) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: dotColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: dotColor!.withValues(alpha: 0.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87.withValues(alpha: 0.7),
                            fontSize: 14,
                            height: 1.4,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: onActionTap,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: actionColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: actionColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              actionText,
                              style: TextStyle(
                                color: actionColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedSection extends StatefulWidget {
  final Widget child;
  final int delay; // Delay multiplier

  const _AnimatedSection({super.key, required this.child, required this.delay});

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Staggered start
    Future.delayed(Duration(milliseconds: 100 * widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class _PulsatingAvatar extends StatefulWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool isOnline;
  final bool isDashed;
  final VoidCallback? onTap;

  const _PulsatingAvatar({
    required this.name,
    required this.icon,
    required this.color,
    this.isOnline = false,
    this.isDashed = false,
    this.onTap,
  });

  @override
  State<_PulsatingAvatar> createState() => _PulsatingAvatarState();
}

class _PulsatingAvatarState extends State<_PulsatingAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isOnline) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isOnline)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color.withValues(alpha: 1.0 - (_pulseAnimation.value - 1.0) * 5),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isDashed 
                    ? Colors.transparent 
                    : (isDark ? Colors.white.withValues(alpha: 0.1) : widget.color.withValues(alpha: 0.1)),
                border: widget.isDashed
                    ? Border.all(color: isDark ? Colors.white24 : Colors.black26, width: 2)
                    : null,
              ),
              child: Icon(
                widget.icon,
                color: widget.isDashed 
                    ? (isDark ? Colors.white54 : Colors.black54)
                    : widget.color,
                size: 28,
              ),
            ),
            if (widget.isOnline)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981), // Online green
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.name,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
}
