import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/hospital_data.dart';

class InfrastructurePage extends StatefulWidget {
  const InfrastructurePage({super.key});

  @override
  State<InfrastructurePage> createState() => _InfrastructurePageState();
}

class _InfrastructurePageState extends State<InfrastructurePage> {
  final ApiService _apiService = ApiService();
  late Future<List<WardInfo>> _wardsFuture;
  late Future<List<StaffInfo>> _staffFuture;

  @override
  void initState() {
    super.initState();
    _wardsFuture = _apiService.getWards();
    _staffFuture = _apiService.getStaff();
  }

  void _handleSuiteTap(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Suite ${101 + index} is currently ready for allocation.'), behavior: SnackBarBehavior.floating),
    );
  }

  void _contactStaff(StaffInfo staff) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 30, child: const Icon(Icons.person, size: 30)),
            const SizedBox(height: 16),
            Text(staff.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(staff.role, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildContactBtn(Icons.phone, 'Call', Colors.green),
                _buildContactBtn(Icons.message, 'Page', Colors.blue),
                _buildContactBtn(Icons.video_call, 'Consult', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactBtn(IconData icon, String label, Color color) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: () => Navigator.pop(context),
          icon: Icon(icon),
          style: IconButton.styleFrom(backgroundColor: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF1F8FE),
        appBar: AppBar(
          title: const Text('Facility Resources'),
          bottom: TabBar(
            indicatorColor: colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Infrastructure'),
              Tab(text: 'Clinical Staff'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildInfrastructureTab(context),
            _buildStaffTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfrastructureTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<WardInfo>>(
      future: _wardsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final wards = snapshot.data ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            double horizontalPadding = constraints.maxWidth > 800 ? (constraints.maxWidth - 800) / 2 : 20;
            return ListView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
              children: [
                _buildSectionTitle(context, 'Ward Allocation'),
                const SizedBox(height: 16),
                ...wards.map((ward) => _buildResourceCard(
                  context, 
                  ward.name, 
                  '${ward.occupied}/${ward.total} Units Engaged', 
                  ward.occupancyRate, 
                  ward.type == 'Critical' ? colorScheme.error : colorScheme.primary
                )),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'Facility Readiness'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.start,
                  children: List.generate(
                    6,
                    (index) => InkWell(
                      onTap: () => _handleSuiteTap(index),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: (constraints.maxWidth - horizontalPadding * 2 - 32) / 3,
                        constraints: const BoxConstraints(minWidth: 100),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorScheme.primary.withAlpha(20)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.meeting_room_outlined, color: colorScheme.primary, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'Suite ${101 + index}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Text('Ready', style: TextStyle(fontSize: 11, color: Colors.green)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildStaffTab(BuildContext context) {
    return FutureBuilder<List<StaffInfo>>(
      future: _staffFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final staff = snapshot.data ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            double horizontalPadding = constraints.maxWidth > 800 ? (constraints.maxWidth - 800) / 2 : 20;
            return ListView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
              children: [
                _buildSectionTitle(context, 'Staff Roster'),
                const SizedBox(height: 16),
                ...staff.map((s) => _buildStaffTile(
                  context, s, s.status == 'On Duty' ? Colors.green : (s.status == 'Active' ? Colors.blue : Colors.teal)
                )),
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
      ),
    );
  }

  Widget _buildResourceCard(BuildContext context, String title, String status, double load, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: load,
              backgroundColor: color.withAlpha(20),
              color: color,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTile(BuildContext context, StaffInfo staff, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        onTap: () => _contactStaff(staff),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(20),
          child: Icon(Icons.person_outline, color: color),
        ),
        title: Text(staff.role, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(staff.name, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            staff.status,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
