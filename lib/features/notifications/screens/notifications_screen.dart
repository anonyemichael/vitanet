import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/shared/widgets/premium_background.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedTabIndex = 0;

  final List<Map<String, dynamic>> _allNotifications = [
    {
      'id': '1',
      'title': 'High Heart Rate Detected',
      'description': 'Your resting heart rate was above 100 bpm for 10 minutes.',
      'time': '2m ago',
      'isRead': false,
      'type': 'alert',
      'icon': Icons.favorite_rounded,
      'color': const Color(0xFFEF4444), // Red
    },
    {
      'id': '2',
      'title': 'Device Connected',
      'description': 'Withings Blood Pressure Monitor was successfully connected.',
      'time': '1h ago',
      'isRead': false,
      'type': 'system',
      'icon': Icons.bluetooth_connected_rounded,
      'color': const Color(0xFF3B82F6), // Blue
    },
    {
      'id': '3',
      'title': 'Medication Reminder',
      'description': 'Time to take Lisinopril (10mg).',
      'time': '3h ago',
      'isRead': true,
      'type': 'reminder',
      'icon': Icons.medication_rounded,
      'color': const Color(0xFF10B981), // Green
    },
    {
      'id': '4',
      'title': 'Weekly Health Report',
      'description': 'Your health insights for this week are ready.',
      'time': 'Yesterday',
      'isRead': true,
      'type': 'insight',
      'icon': Icons.insights_rounded,
      'color': const Color(0xFF8B5CF6), // Purple
    },
    {
      'id': '5',
      'title': 'Care Circle Update',
      'description': 'Dr. Sarah has reviewed your latest ECG results.',
      'time': '2 days ago',
      'isRead': true,
      'type': 'care',
      'icon': Icons.person_rounded,
      'color': const Color(0xFFF59E0B), // Orange
    },
  ];

  void _markAllAsRead() {
    setState(() {
      for (var notification in _allNotifications) {
        notification['isRead'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    final displayedNotifications = _selectedTabIndex == 0 
        ? _allNotifications 
        : _allNotifications.where((n) => !(n['isRead'] as bool)).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 800) {
                return _buildListContent(isDark, displayedNotifications, false);
              } else {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: _buildListContent(isDark, displayedNotifications, true),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildListContent(bool isDark, List<Map<String, dynamic>> displayedNotifications, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Custom App Bar
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 0 : AppSpacing.sm, 
            vertical: isDesktop ? AppSpacing.xl : AppSpacing.md,
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: isDesktop ? 28 : 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              TextButton(
                onPressed: _markAllAsRead,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                ),
                child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        
        // Tabs
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : AppSpacing.xl),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0 
                            ? (isDark ? Colors.white24 : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _selectedTabIndex == 0 && !isDark
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'All',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedTabIndex == 0 
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1 
                            ? (isDark ? Colors.white24 : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _selectedTabIndex == 1 && !isDark
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Unread',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedTabIndex == 1 
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: AppSpacing.lg),
        
        // Notifications List
        Expanded(
          child: displayedNotifications.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 0 : AppSpacing.xl, 
                    isDesktop ? AppSpacing.lg : 0, 
                    isDesktop ? 0 : AppSpacing.xl, 
                    AppSpacing.xxl,
                  ),
                  itemCount: displayedNotifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = displayedNotifications[index];
                    return _NotificationTile(
                      item: item,
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          item['isRead'] = true;
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRead = item['isRead'];
    final Color iconColor = item['color'];
    final IconData icon = item['icon'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            if (!isDark && !isRead)
              BoxShadow(
                color: iconColor.withValues(alpha: 0.1),
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
                    ? (isRead ? Colors.white.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.05))
                    : (isRead ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.9)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark 
                      ? (isRead ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.1))
                      : Colors.white,
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch, // to make accent bar fill height
                children: [
                  // Glowing Left Accent Bar for unread items
                  if (!isRead)
                    Container(
                      width: 4,
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
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: iconColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['title'],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                          color: isDark 
                                              ? (isRead ? Colors.white70 : Colors.white) 
                                              : (isRead ? Colors.black54 : Colors.black87),
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: BoxDecoration(
                                          color: iconColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: iconColor.withValues(alpha: 0.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['description'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    letterSpacing: -0.1,
                                    color: isDark ? Colors.white70 : Colors.black87.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item['time'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}
