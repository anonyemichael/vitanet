import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/data/providers/health_providers.dart';
import 'package:vitanet/data/providers/providers.dart' show aiServiceProvider;
import 'package:vitanet/features/devices/screens/device_connection_screen.dart';
import 'package:vitanet/features/resources/widgets/resource_media.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Metric metadata for the trends screen.
class _Metric {
  final String id;
  final String label;
  final String title;
  final String unit;
  final IconData icon;
  final Color color;
  final double low;
  final double high;
  final int decimals;

  const _Metric({
    required this.id,
    required this.label,
    required this.title,
    required this.unit,
    required this.icon,
    required this.color,
    required this.low,
    required this.high,
    this.decimals = 0,
  });
}

const _metrics = <_Metric>[
  _Metric(
    id: 'heart_rate',
    label: 'Heart rate',
    title: 'Heart Rate',
    unit: 'bpm',
    icon: Icons.favorite_border_rounded,
    color: Color(0xFFBE123C),
    low: 60,
    high: 100,
  ),
  _Metric(
    id: 'blood_oxygen',
    label: 'SpO2',
    title: 'Blood Oxygen',
    unit: '%',
    icon: Icons.water_drop_outlined,
    color: Color(0xFF0369A1),
    low: 95,
    high: 100,
  ),
  _Metric(
    id: 'temperature',
    label: 'Temperature',
    title: 'Body Temp',
    unit: '°C',
    icon: Icons.thermostat_rounded,
    color: Color(0xFFC2410C),
    low: 36.1,
    high: 37.2,
    decimals: 1,
  ),
  _Metric(
    id: 'respiratory_rate',
    label: 'Breathing rate',
    title: 'Respiratory Rate',
    unit: 'breaths/min',
    icon: Icons.air_rounded,
    color: Color(0xFF6D28D9),
    low: 12,
    high: 20,
  ),
];

class _Reading {
  final DateTime time;
  final double value;
  const _Reading(this.time, this.value);
}

class HealthTrendsScreen extends ConsumerStatefulWidget {
  final String metricId;

  const HealthTrendsScreen({super.key, required this.metricId});

  @override
  ConsumerState<HealthTrendsScreen> createState() => _HealthTrendsScreenState();
}

class _HealthTrendsScreenState extends ConsumerState<HealthTrendsScreen> {
  static const _ranges = ['Day', 'Week', 'Month', 'Year'];
  static const _rangeDays = [1, 7, 30, 365];
  static const _previousLabel = ['yesterday', 'last week', 'last month', 'last year'];

  int _rangeIndex = 1;
  late String _metricId;

  @override
  void initState() {
    super.initState();
    _metricId = _metrics.any((m) => m.id == widget.metricId) ? widget.metricId : 'heart_rate';
  }

  _Metric get _metric => _metrics.firstWhere((m) => m.id == _metricId);

  static double? _valueOf(HealthDataPoint p) {
    final v = p.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return double.tryParse(v.toString());
  }

  String _fmt(double v) => v.toStringAsFixed(_metric.decimals);

  void _openDevices() {
    try {
      context.push('/device-connection/$_metricId');
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DeviceConnectionScreen(metricId: _metricId)),
      );
    }
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      try {
        context.go('/home');
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final days = _rangeDays[_rangeIndex];
    // Fetch two periods so the current one can be compared with the previous.
    final async = ref.watch(healthDataProvider(HealthMetricRequest(metricId: _metricId, daysBack: days * 2)));

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              physics: const VnAlwaysScrollablePhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                VnTopBar(
                  title: 'Health trends',
                  onBack: _back,
                  actions: [
                    VnIconButton(
                      icon: Icons.watch_outlined,
                      tooltip: 'Connected devices',
                      bordered: true,
                      onPressed: _openDevices,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    children: [
                      for (final m in _metrics) ...[
                        _MetricChip(
                          metric: m,
                          selected: m.id == _metricId,
                          onTap: () => setState(() => _metricId = m.id),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                async.when(
                  data: (points) => _buildContent(p, points, days),
                  loading: () => VnCard(
                    radius: 24,
                    child: SizedBox(
                      height: 320,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: p.brand)),
                    ),
                  ),
                  error: (_, _) => _emptyCard(p, 'We could not read your health data.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(VnPalette p, List<HealthDataPoint> points, int days) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final all = <_Reading>[];
    for (final pt in points) {
      final v = _valueOf(pt);
      if (v != null) all.add(_Reading(pt.dateFrom, v));
    }
    all.sort((a, b) => a.time.compareTo(b.time));
    final current = all.where((r) => !r.time.isBefore(start)).toList();
    final previous = all.where((r) => r.time.isBefore(start)).toList();

    if (current.isEmpty) {
      return _emptyCard(p, 'No ${_metric.label.toLowerCase()} readings in this period yet.');
    }

    double avg(List<_Reading> l) => l.map((r) => r.value).reduce((a, b) => a + b) / l.length;
    final average = avg(current);
    final prevAvg = previous.isEmpty ? null : avg(previous);
    final lowest = current.reduce((a, b) => a.value <= b.value ? a : b);
    final highest = current.reduce((a, b) => a.value >= b.value ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VnCard(
          radius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VnSegmented(
                options: _ranges,
                index: _rangeIndex,
                height: 40,
                onChanged: (i) => setState(() => _rangeIndex = i),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_metricId == 'heart_rate' ? 'Average heart rate' : 'Average',
                            style: VnText.body(13, weight: FontWeight.w500, color: p.muted)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(_fmt(average), style: VnText.heading(36, color: p.ink)),
                            const SizedBox(width: 4),
                            Text(_metric.unit, style: VnText.body(15, color: p.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (prevAvg != null) _DeltaBadge(delta: average - prevAvg, decimals: _metric.decimals,
                      suffix: 'vs ${_previousLabel[_rangeIndex]}'),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 190,
                child: _TrendChart(
                  readings: current,
                  start: start,
                  end: now,
                  metric: _metric,
                  rangeIndex: _rangeIndex,
                  highlight: highest,
                ),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: p.divider),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _Stat(label: 'Lowest', value: _fmt(lowest.value))),
                  Expanded(
                    child: _Stat(
                      label: 'Highest',
                      value: _fmt(highest.value),
                      color: p.isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C),
                    ),
                  ),
                  Expanded(child: _Stat(label: 'Readings', value: NumberFormat.decimalPattern().format(current.length))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _InsightCard(
          metric: _metric,
          highest: highest,
          lowest: lowest,
          average: average,
          fmt: _fmt,
          onAsk: () => askVitaNetAi(
            context,
            'My ${_metric.label.toLowerCase()} over the last ${_ranges[_rangeIndex].toLowerCase()} averaged '
            '${_fmt(average)} ${_metric.unit}, lowest ${_fmt(lowest.value)} and highest ${_fmt(highest.value)} '
            '(on ${DateFormat('EEE d MMM, HH:mm').format(highest.time)}). Is this anything to worry about?',
          ),
          onReport: () => _showDetailedReport(p, current, average, lowest.value, highest.value),
        ),
        const SizedBox(height: 18),
        _ZonesSection(metric: _metric, readings: current, title: _rangeIndex == 0 ? 'Time in zones today' : 'Readings by zone'),
      ],
    );
  }

  Widget _emptyCard(VnPalette p, String message) {
    return VnCard(
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          VnIconTile(icon: _metric.icon, bg: const Color(0xFFFFE4E6), fg: _metric.color, size: 52, radius: 16, iconSize: 26),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: VnText.body(15, weight: FontWeight.w600, color: p.ink)),
          const SizedBox(height: 6),
          Text('Connect a watch or tracker through Health Connect or Apple Health to see your trends.',
              textAlign: TextAlign.center, style: VnText.body(13, color: p.muted, height: 1.45)),
          const SizedBox(height: 14),
          VnButton(label: 'Connect a device', icon: Icons.watch_outlined, height: 48, fontSize: 15, onPressed: _openDevices),
        ],
      ),
    );
  }

  void _showDetailedReport(VnPalette p, List<_Reading> data, double avg, double low, double high) {
    final future = ref.read(aiServiceProvider).generateHealthReport(
          metricName: _metric.title,
          currentValue: _fmt(data.last.value),
          unit: _metric.unit,
          avg: _fmt(avg),
          high: _fmt(high),
          low: _fmt(low),
        );
    showVnSheet<void>(
      context,
      builder: (ctx) {
        final sp = VnPalette.of(ctx);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: VnSheet(
            children: [
              Row(
                children: [
                  const VnIconTile(icon: Icons.auto_awesome_rounded, bg: Color(0xFFF5F3FF), fg: Color(0xFF6D28D9)),
                  const SizedBox(width: 12),
                  Text('AI detailed report', style: VnText.heading(18, weight: FontWeight.w700, color: sp.ink)),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  physics: const VnAlwaysScrollablePhysics(),
                  child: FutureBuilder<String>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: sp.brand)),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Text('Could not generate the report. Please try again.',
                            style: VnText.body(14, color: sp.danger));
                      }
                      return Text(snapshot.data!, style: VnText.body(15, color: sp.inkSoft, height: 1.6));
                    },
                  ),
                ),
              ),
              VnButton(label: 'Close', height: 52, onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        );
      },
    );
  }
}

class _MetricChip extends StatelessWidget {
  final _Metric metric;
  final bool selected;
  final VoidCallback onTap;
  const _MetricChip({required this.metric, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? metric.color : p.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? metric.color : p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(metric.icon, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Text(metric.label,
                    style: VnText.body(14,
                        weight: selected ? FontWeight.w700 : FontWeight.w600, color: selected ? Colors.white : p.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final double delta;
  final int decimals;
  final String suffix;
  const _DeltaBadge({required this.delta, required this.decimals, required this.suffix});

  @override
  Widget build(BuildContext context) {
    final rounded = double.parse(delta.toStringAsFixed(decimals));
    final sign = rounded > 0 ? '+' : (rounded < 0 ? '−' : '±');
    return VnTag(
      label: '$sign${rounded.abs().toStringAsFixed(decimals)} $suffix',
      bg: const Color(0xFFD1FAE5),
      fg: const Color(0xFF047857),
      fontSize: 13,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VnText.body(12, color: p.muted)),
        const SizedBox(height: 2),
        Text(value, style: VnText.body(17, weight: FontWeight.w800, color: color ?? p.ink)),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<_Reading> readings;
  final DateTime start;
  final DateTime end;
  final _Metric metric;
  final int rangeIndex;
  final _Reading highlight;

  const _TrendChart({
    required this.readings,
    required this.start,
    required this.end,
    required this.metric,
    required this.rangeIndex,
    required this.highlight,
  });

  double _x(DateTime t) => t.difference(start).inMinutes / 60.0;

  String _bottomLabel(double hours) {
    final t = start.add(Duration(minutes: (hours * 60).round()));
    switch (rangeIndex) {
      case 0:
        return DateFormat('HH:mm').format(t);
      case 1:
        return DateUtils.isSameDay(t, end) ? 'Today' : DateFormat('EEE').format(t);
      case 2:
        return DateFormat('d MMM').format(t);
      default:
        return DateFormat('MMM').format(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    // Average buckets so long ranges stay readable.
    final maxPoints = 120;
    final spots = <FlSpot>[];
    if (readings.length <= maxPoints) {
      for (final r in readings) {
        spots.add(FlSpot(_x(r.time), r.value));
      }
    } else {
      final size = (readings.length / maxPoints).ceil();
      for (var i = 0; i < readings.length; i += size) {
        final chunk = readings.sublist(i, math.min(i + size, readings.length));
        final v = chunk.map((r) => r.value).reduce((a, b) => a + b) / chunk.length;
        spots.add(FlSpot(_x(chunk[chunk.length ~/ 2].time), v));
      }
    }
    final values = readings.map((r) => r.value);
    final minV = math.min(values.reduce(math.min), metric.low);
    final maxV = math.max(values.reduce(math.max), metric.high);
    final pad = (maxV - minV) * 0.12 + (metric.decimals > 0 ? 0.2 : 2);
    final minY = minV - pad;
    final maxY = maxV + pad;
    final maxX = _x(end);
    final hl = FlSpot(_x(highlight.time), highlight.value);
    final interval = maxX / 6;
    final color = metric.color;

    return Semantics(
      label: '${metric.label} chart, ranging ${values.reduce(math.min).toStringAsFixed(metric.decimals)} '
          'to ${values.reduce(math.max).toStringAsFixed(metric.decimals)} ${metric.unit}',
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 3,
            getDrawingHorizontalLine: (_) => FlLine(color: p.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: p.line))),
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(
                y1: metric.low,
                y2: metric.high,
                color: const Color(0xFF10B981).withValues(alpha: 0.07),
              ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: (maxY - minY) / 3,
                getTitlesWidget: (v, meta) {
                  if (v == meta.min || v == meta.max) return const SizedBox.shrink();
                  return Text(v.toStringAsFixed(metric.decimals), style: VnText.body(10, color: p.muted));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: interval <= 0 ? 1 : interval,
                getTitlesWidget: (v, meta) {
                  final label = _bottomLabel(v);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: VnText.body(10,
                          weight: label == 'Today' ? FontWeight.w700 : FontWeight.w400,
                          color: label == 'Today' ? p.ink : p.muted),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0F172A),
              getTooltipItems: (items) => items
                  .map((i) => LineTooltipItem(
                        '${i.y.toStringAsFixed(metric.decimals)} · ${DateFormat('EEE HH:mm').format(start.add(Duration(minutes: (i.x * 60).round())))}',
                        VnText.body(10, weight: FontWeight.w700, color: Colors.white),
                      ))
                  .toList(),
            ),
          ),
          showingTooltipIndicators: [
            ShowingTooltipIndicators([
              LineBarSpot(
                LineChartBarData(spots: [hl]),
                1,
                hl,
              ),
            ]),
          ],
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
            ),
            LineChartBarData(
              spots: [hl],
              color: Colors.transparent,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 5,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final _Metric metric;
  final _Reading highest;
  final _Reading lowest;
  final double average;
  final String Function(double) fmt;
  final VoidCallback onAsk;
  final VoidCallback onReport;

  const _InsightCard({
    required this.metric,
    required this.highest,
    required this.lowest,
    required this.average,
    required this.fmt,
    required this.onAsk,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    const ai = Color(0xFF6D28D9);
    final when = DateFormat("EEEE 'at' HH:mm").format(highest.time);
    final String title;
    final String body;
    if (highest.value > metric.high) {
      title = 'One spike worth noting';
      body = 'Your highest reading was ${fmt(highest.value)} ${metric.unit} on $when. If it happens again with '
          'dizziness, chest pain or breathlessness, start a check.';
    } else if (lowest.value < metric.low) {
      title = 'A low reading worth noting';
      body = 'Your lowest reading was ${fmt(lowest.value)} ${metric.unit}. If you felt faint or unwell at the time, '
          'talk it through with VitaNet AI or a clinician.';
    } else {
      title = 'Steady and in range';
      body = 'All readings in this period stayed between ${fmt(metric.low)} and ${fmt(metric.high)} ${metric.unit}, '
          'averaging ${fmt(average)}.';
    }
    return VnCard(
      radius: 20,
      color: p.tintBg(const Color(0xFFF5F3FF), ai),
      borderColor: p.isDark ? ai.withValues(alpha: 0.4) : const Color(0xFFDDD6FE),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: ai, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: VnText.body(14, weight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 6),
                Text(body,
                    style: VnText.body(13, color: p.isDark ? const Color(0xFFDDD6FE) : const Color(0xFF4C1D95), height: 1.5)),
                Wrap(
                  spacing: 16,
                  children: [
                    VnLink(label: 'Talk it through with AI', fontSize: 13, weight: FontWeight.w700,
                        color: p.isDark ? const Color(0xFFC4B5FD) : ai, onTap: onAsk),
                    VnLink(label: 'Detailed report', fontSize: 13, weight: FontWeight.w700,
                        color: p.isDark ? const Color(0xFFC4B5FD) : ai, onTap: onReport),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZonesSection extends StatelessWidget {
  final _Metric metric;
  final List<_Reading> readings;
  final String title;
  const _ZonesSection({required this.metric, required this.readings, required this.title});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final List<(String, Color, bool Function(double))> zones = metric.id == 'heart_rate'
        ? [
            ('Resting', const Color(0xFF10B981), (v) => v < 90),
            ('Light', const Color(0xFFF59E0B), (v) => v >= 90 && v < 120),
            ('Cardio', const Color(0xFFF97316), (v) => v >= 120 && v < 150),
            ('Peak', const Color(0xFFDC2626), (v) => v >= 150),
          ]
        : [
            ('Below range', const Color(0xFFF59E0B), (v) => v < metric.low),
            ('In range', const Color(0xFF10B981), (v) => v >= metric.low && v <= metric.high),
            ('Above range', const Color(0xFFDC2626), (v) => v > metric.high),
          ];
    final total = readings.length;
    final shares = [for (final z in zones) readings.where((r) => z.$3(r.value)).length / total];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: VnText.heading(17, weight: FontWeight.w700, color: p.ink))),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (var i = 0; i < zones.length; i++)
                  if (shares[i] > 0)
                    Expanded(
                      flex: math.max(1, (shares[i] * 1000).round()),
                      child: ColoredBox(color: zones[i].$2),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          runSpacing: 8,
          children: [
            for (var i = 0; i < zones.length; i++)
              FractionallySizedBox(
                widthFactor: 0.5,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: zones[i].$2, borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: 8),
                    Text('${zones[i].$1} · ${(shares[i] * 100).round()}%',
                        style: VnText.body(13, color: p.isDark ? p.inkSoft : const Color(0xFF334155))),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
