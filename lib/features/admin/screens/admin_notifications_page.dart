import 'package:flutter/material.dart';
import '../services/hospital_api_service.dart';
import '../models/alert.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final ApiService _apiService = ApiService();
  List<ClinicalAlert>? _alerts;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await _apiService.getAlerts();
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _clearAll() {
    if (_alerts == null || _alerts!.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Alerts'),
        content: const Text('Are you sure you want to dismiss all current clinical alerts?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _alerts = []);
              Navigator.pop(context);
            },
            child: const Text('Dismiss All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _attendAlert(ClinicalAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attend to ${alert.title}'),
        content: Text('Marking this as attended will notify the clinical team. \n\nDetails: ${alert.description}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _alerts?.removeWhere((a) => a.id == alert.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Attending to ${alert.title}...'), behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF1F8FE),
      appBar: AppBar(
        title: const Text('Priority Alerts'),
        actions: [
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Clear All'),
            style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        color: colorScheme.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_alerts == null || _alerts!.isEmpty)
                ? Stack(
                    children: [
                      ListView(), // Empty listview to enable pull-to-refresh
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 64, color: colorScheme.primary.withAlpha(100)),
                            const SizedBox(height: 16),
                            const Text('No active clinical alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    double horizontalPadding = constraints.maxWidth > 600 ? constraints.maxWidth * 0.15 : 16;
                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                      itemCount: _alerts!.length,
                      itemBuilder: (context, index) {
                        final alert = _alerts![index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark ? colorScheme.surfaceContainerHighest.withAlpha(50) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: isDark ? [] : [
                              BoxShadow(
                                color: Colors.black.withAlpha(5),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: isDark ? colorScheme.outlineVariant : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: alert.isCritical ? colorScheme.error : colorScheme.primary,
                                    width: 6,
                                  ),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(20),
                                title: Row(
                                  children: [
                                    Icon(
                                      alert.isCritical ? Icons.emergency_share_outlined : Icons.info_outline,
                                      size: 18,
                                      color: alert.isCritical ? colorScheme.error : colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      alert.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: alert.isCritical ? colorScheme.error : colorScheme.primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    Text(
                                      alert.description,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.onSurface,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${DateTime.now().difference(alert.timestamp).inMinutes} minutes ago',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: alert.isCritical
                                    ? TextButton(
                                        onPressed: () => _attendAlert(alert),
                                        style: TextButton.styleFrom(
                                          backgroundColor: colorScheme.error.withAlpha(20),
                                          foregroundColor: colorScheme.error,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('Attend'),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
      ),
    );
  }
}


