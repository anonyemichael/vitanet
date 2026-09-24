import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/features/home/widgets/animated_section.dart';

class AiHealthAlertsSection extends StatefulWidget {
  const AiHealthAlertsSection({super.key});

  @override
  State<AiHealthAlertsSection> createState() => _AiHealthAlertsSectionState();
}

class _AiHealthAlertsSectionState extends State<AiHealthAlertsSection> {
  final List<AlertData> _activeAlerts = [
    AlertData(
      id: 'alert_1',
      icon: Icons.trending_up_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: 'Blood Pressure Trend',
      description: 'Your blood pressure has been slightly higher than your usual range over the past 7 days.',
      actionText: 'View Insights',
      actionColor: const Color(0xFFF59E0B),
      showDot: true,
    ),
    AlertData(
      id: 'alert_2',
      icon: Icons.medication_rounded,
      iconColor: const Color(0xFF6366F1),
      title: 'Medication Reminder',
      description: 'You missed your morning Lisinopril dose. Would you like to log it now or reschedule?',
      actionText: 'Log Medication',
      actionColor: const Color(0xFF6366F1),
    ),
  ];

  final List<AlertData> _hiddenQueue = [
    AlertData(
      id: 'alert_3',
      icon: Icons.water_drop_rounded,
      iconColor: const Color(0xFF06B6D4),
      title: 'Hydration Goal',
      description: 'You\'ve only logged 2 glasses of water today. Stay hydrated to maintain your energy levels!',
      actionText: 'Log Water',
      actionColor: const Color(0xFF06B6D4),
    ),
    AlertData(
      id: 'alert_4',
      icon: Icons.bed_rounded,
      iconColor: const Color(0xFF8B5CF6),
      title: 'Sleep Analysis',
      description: 'Your sleep quality was 85% last night. Your deep sleep increased by 15 minutes.',
      actionText: 'View Sleep Data',
      actionColor: const Color(0xFF8B5CF6),
    ),
    AlertData(
      id: 'alert_5',
      icon: Icons.directions_run_rounded,
      iconColor: const Color(0xFF10B981),
      title: 'Activity Goal Met',
      description: 'Great job! You have reached your daily step goal of 10,000 steps.',
      actionText: 'View Summary',
      actionColor: const Color(0xFF10B981),
      showDot: true,
    ),
    AlertData(
      id: 'alert_6',
      icon: Icons.restaurant_rounded,
      iconColor: const Color(0xFFF97316),
      title: 'Dietary Insight',
      description: 'You have consistently eaten your dinner later than usual. Eating earlier can improve sleep quality.',
      actionText: 'Review Meals',
      actionColor: const Color(0xFFF97316),
    ),
    AlertData(
      id: 'alert_7',
      icon: Icons.monitor_heart_rounded,
      iconColor: const Color(0xFFEF4444),
      title: 'Heart Rate Spike',
      description: 'Your heart rate briefly spiked to 120 bpm at 2:30 PM. Did you do a light workout?',
      actionText: 'Log Activity',
      actionColor: const Color(0xFFEF4444),
      showDot: true,
    ),
    AlertData(
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
        AlertData(
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
                return AnimatedSection(
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
                      child: AlertTile(
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

class AlertData {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String actionText;
  final Color actionColor;
  final bool showDot;

  AlertData({
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

class AlertTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String actionText;
  final Color actionColor;
  final bool showDot;
  final Color? dotColor;
  final String? timestamp;
  final VoidCallback? onActionTap;

  const AlertTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.actionText,
    required this.actionColor,
    this.showDot = false,
    this.dotColor,
    this.timestamp,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF1A2232)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.05) 
              : const Color(0xFFE8ECF0),
          width: 1.5,
        ),
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
        child: Row(
          children: [
            // Left Accent Bar
            Container(
              width: 4,
              height: 120,
              color: iconColor,
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
                            ),
                          ),
                        ],
                        if (timestamp != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            timestamp!,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
    );
  }
}
