import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/triage_result.dart';

final adminCasesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return [
    {
      'id': 'case-1',
      'timestamp': DateTime.now()
          .subtract(const Duration(minutes: 10))
          .toIso8601String(),
      'primarySymptom': 'Severe Chest Pain',
      'level': 'emergency',
      'status': 'pending',
    },
    {
      'id': 'case-2',
      'timestamp': DateTime.now()
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
      'primarySymptom': 'Persistent Cough',
      'level': 'pharmacist',
      'status': 'reviewed',
    },
    {
      'id': 'case-3',
      'timestamp': DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String(),
      'primarySymptom': 'Mild Headache',
      'level': 'selfCare',
      'status': 'pending',
    },
  ];
});

class CaseManagementScreen extends ConsumerStatefulWidget {
  const CaseManagementScreen({super.key});

  @override
  ConsumerState<CaseManagementScreen> createState() =>
      _CaseManagementScreenState();
}

class _CaseManagementScreenState extends ConsumerState<CaseManagementScreen> {
  late List<Map<String, dynamic>> _cases;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _cases = List.of(ref.read(adminCasesProvider));
  }

  void _updateStatus(String id, String newStatus) {
    setState(() {
      final index = _cases.indexWhere((item) => item['id'] == id);
      if (index != -1) {
        _cases[index] = {..._cases[index], 'status': newStatus};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleCases = _filter == 'All'
        ? _cases
        : _cases
              .where((item) => item['status'] == _filter.toLowerCase())
              .toList();
    final pending = _cases.where((item) => item['status'] == 'pending').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Case queue')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxxl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.52,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: pending > 0
                        ? context.colorScheme.errorContainer
                        : context.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    pending > 0
                        ? Icons.priority_high_rounded
                        : Icons.task_alt_rounded,
                    color: pending > 0
                        ? context.colorScheme.error
                        : context.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$pending cases awaiting review',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Prioritize urgent assessments in the order they arrived.',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Pending', 'Reviewed'].map((label) {
                final selected = _filter == label;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = label),
                    selectedColor: context.colorScheme.primaryContainer,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: selected
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (visibleCases.isEmpty)
            const _EmptyQueue()
          else
            ...visibleCases.map(
              (caseData) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CaseCard(
                  caseData: caseData,
                  onStatusChanged: (value) =>
                      _updateStatus(caseData['id'], value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final Map<String, dynamic> caseData;
  final ValueChanged<String> onStatusChanged;

  const _CaseCard({required this.caseData, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    final level = TriageLevel.values.firstWhere(
      (item) => item.name == caseData['level'],
      orElse: () => TriageLevel.selfCare,
    );
    final levelStyle = _LevelStyle.from(level);
    final isPending = caseData['status'] == 'pending';
    final time = DateFormat.MMMd().add_jm().format(
      DateTime.parse(caseData['timestamp']),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: levelStyle.color.withValues(alpha: isPending ? 0.35 : 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: levelStyle.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  levelStyle.label,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: levelStyle.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                time,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            caseData['primarySymptom'],
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                isPending ? Icons.schedule_rounded : Icons.task_alt_rounded,
                size: 17,
                color: isPending
                    ? context.colorScheme.onSurfaceVariant
                    : context.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                isPending ? 'Awaiting review' : 'Reviewed',
                style: context.textTheme.bodySmall,
              ),
              const Spacer(),
              DropdownButton<String>(
                value: caseData['status'],
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'reviewed', child: Text('Reviewed')),
                  DropdownMenuItem(
                    value: 'contacted',
                    child: Text('Contacted'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onStatusChanged(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelStyle {
  final Color color;
  final String label;

  const _LevelStyle(this.color, this.label);

  factory _LevelStyle.from(TriageLevel level) {
    return switch (level) {
      TriageLevel.selfCare => const _LevelStyle(
        AppColors.triageSelfCare,
        'SELF CARE',
      ),
      TriageLevel.pharmacist => const _LevelStyle(
        AppColors.triagePharmacist,
        'PHARMACIST',
      ),
      TriageLevel.doctor => const _LevelStyle(
        AppColors.triageDoctor,
        'DOCTOR',
      ),
      TriageLevel.emergency => const _LevelStyle(
        AppColors.triageUrgent,
        'URGENT',
      ),
    };
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxxl),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No matching cases', style: context.textTheme.titleMedium),
        ],
      ),
    );
  }
}
