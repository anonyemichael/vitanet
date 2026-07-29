import 'package:flutter/material.dart';
import '../services/hospital_api_service.dart';
import '../models/hospital_data.dart';
import 'admin_profile_settings_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final ApiService _apiService = ApiService();
  late Future<HospitalStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _apiService.getDashboardStats();
  }

  void _handleWorkflow(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Initializing $action workflow...'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF1F8FE),
      body: FutureBuilder<HospitalStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stats = snapshot.data!;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 140.0,
                floating: false,
                pinned: true,
                backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF1F8FE),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
                  title: Text(
                    'Clinical Overview',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withAlpha(20),
                          colorScheme.secondary.withAlpha(10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminProfileSettingsPage()),
                      );
                    },
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, Medical Service Provider',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monitoring facility vitals and patient workflow.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildSectionTitle(context, 'Facility Metrics'),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.4,
                            children: [
                              _buildMetricCard(
                                context,
                                'Active Care',
                                '${stats.activePatients}',
                                'Patients',
                                Icons.personal_injury_outlined,
                                const Color(0xFFE3F2FD),
                                const Color(0xFF1976D2),
                              ),
                              _buildMetricCard(
                                context,
                                'Capacity',
                                '${stats.availableWards}',
                                'Wards Avail.',
                                Icons.door_sliding_outlined,
                                const Color(0xFFE0F2F1),
                                const Color(0xFF00897B),
                              ),
                              if (constraints.maxWidth > 600) ...[
                                _buildMetricCard(
                                  context,
                                  'Vitals',
                                  stats.systemHealth,
                                  'System Health',
                                  Icons.auto_graph_outlined,
                                  const Color(0xFFF3E5F5),
                                  const Color(0xFF8E24AA),
                                ),
                                _buildMetricCard(
                                  context,
                                  'Staffing',
                                  '${stats.staffOnDuty}',
                                  'Active Duty',
                                  Icons.badge_outlined,
                                  const Color(0xFFFFF3E0),
                                  const Color(0xFFF57C00),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle(context, 'Primary Workflow'),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.6,
                            children: [
                              _buildWorkflowItem(context, Icons.assignment_outlined, 'Consultation', const Color(0xFF0288D1)),
                              _buildWorkflowItem(context, Icons.history_edu_outlined, 'Case History', const Color(0xFF26C6DA)),
                              _buildWorkflowItem(context, Icons.science_outlined, 'Diagnostics', const Color(0xFF5E35B1)),
                              _buildWorkflowItem(context, Icons.vaccines_outlined, 'Therapeutics', const Color(0xFFD81B60)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
    Color bgColor,
    Color accentColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest.withAlpha(50) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withAlpha(isDark ? 80 : 30),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: accentColor, size: 20),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowItem(BuildContext context, IconData icon, String label, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _handleWorkflow(label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHighest.withAlpha(30) : color.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


