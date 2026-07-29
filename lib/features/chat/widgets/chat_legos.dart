import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:url_launcher/url_launcher.dart';

class HospitalRecommendationCard extends StatelessWidget {
  final Map<String, dynamic> payload;

  const HospitalRecommendationCard({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final hospitalName = payload['name'] ?? 'Cross Care Hospital';
    final distance = payload['distance'] ?? '2.1 km away from you';
    final estTime = payload['estTime'] ?? '7 min';
    final crowdLevel = payload['crowdLevel'] ?? 'Low';

    return GestureDetector(
      onTap: () async {
        final query = Uri.encodeComponent(hospitalName);
        final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.isDark ? context.colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0EFFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.local_hospital_rounded, color: Color(0xFF6B5BFF), size: 24),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended Hospital',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hospitalName,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF6B5BFF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF6B5BFF)),
                          const SizedBox(width: 4),
                          Text(
                            distance,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6B5BFF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F7ED),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              crowdLevel == 'Low' ? 'Less Crowded' : crowdLevel,
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 16, color: context.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Est. time',
                              style: context.textTheme.labelSmall?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              estTime,
                              style: context.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.people_alt_rounded, size: 16, color: context.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crowd Level',
                              style: context.textTheme.labelSmall?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              crowdLevel,
                              style: context.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.navigation_rounded, size: 16, color: context.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Get Directions',
                  style: context.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 20, color: context.colorScheme.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HeartRateCheckCard extends StatefulWidget {
  final Map<String, dynamic> payload;

  const HeartRateCheckCard({super.key, required this.payload});

  @override
  State<HeartRateCheckCard> createState() => _HeartRateCheckCardState();
}

class _HeartRateCheckCardState extends State<HeartRateCheckCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.isDark ? context.colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F3),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.favorite_border_rounded, color: Color(0xFFE11D48), size: 28),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checking your\nheart rate...',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This will take a few seconds',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _DottedCircularProgressPainter(
                        progress: 0.78, // Mock progress
                        color: const Color(0xFFE11D48),
                        rotation: _controller.value * 2 * math.pi,
                      ),
                      size: const Size(64, 64),
                    );
                  },
                ),
                Text(
                  '78%',
                  style: context.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFE11D48),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedCircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double rotation;

  _DottedCircularProgressPainter({required this.progress, required this.color, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    const int dotCount = 24;
    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * math.pi;
      final offset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final isFilled = i < dotCount * progress;
      canvas.drawCircle(offset, 2.5, isFilled ? activePaint : paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HeartRateResultCard extends StatelessWidget {
  final Map<String, dynamic> payload;

  const HeartRateResultCard({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final bpm = payload['bpm'] ?? 76;
    final min = payload['min'] ?? 68;
    final avg = payload['avg'] ?? 76;
    final max = payload['max'] ?? 88;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.isDark ? context.colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: Color(0xFFE11D48), size: 20),
              const SizedBox(width: 8),
              Text(
                'Heart Rate',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Normal',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          bpm.toString(),
                          style: context.textTheme.displayMedium?.copyWith(
                            color: const Color(0xFFE11D48),
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text(
                            'BPM',
                            style: context.textTheme.titleMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Measured just now',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 60,
                  child: CustomPaint(
                    painter: _SimpleSparklinePainter(color: const Color(0xFFE11D48)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, Icons.favorite_border_rounded, 'Min', '$min BPM'),
              _buildStatItem(context, Icons.analytics_outlined, 'Average', '$avg BPM'),
              _buildStatItem(context, Icons.favorite_border_rounded, 'Max', '$max BPM'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.isDark ? context.colorScheme.surfaceContainer : const Color(0xFFFFF0F3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: const Color(0xFFE11D48)),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SimpleSparklinePainter extends CustomPainter {
  final Color color;

  _SimpleSparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      0.4, 0.45, 0.35, 0.5, 0.8, 0.4, 0.5, 0.45, 0.5, 0.6, 0.55, 0.45, 0.4, 0.6, 0.9, 0.4, 0.45, 0.5
    ];
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    
    final dx = size.width / (points.length - 1);
    
    path.moveTo(0, size.height * (1 - points[0]));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, size.height * (1 - points[0]));

    for (int i = 1; i < points.length; i++) {
      final x = dx * i;
      final y = size.height * (1 - points[i]);
      
      // Use bezier curves for smooth lines
      final prevX = dx * (i - 1);
      final prevY = size.height * (1 - points[i - 1]);
      
      final cp1x = prevX + dx / 2;
      final cp1y = prevY;
      final cp2x = x - dx / 2;
      final cp2y = y;
      
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, x, y);
      fillPath.cubicTo(cp1x, cp1y, cp2x, cp2y, x, y);
    }
    
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
    
    // Draw horizontal axis lines
    final axisPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;
      
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), axisPaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), axisPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);
    
    // Draw y-axis labels
    _drawText(canvas, '120', Offset(size.width - 15, -6));
    _drawText(canvas, '80', Offset(size.width - 15, size.height / 2 - 6));
    _drawText(canvas, '40', Offset(size.width - 15, size.height - 6));
  }
  
  void _drawText(Canvas canvas, String text, Offset offset) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(color: Colors.grey, fontSize: 8),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
