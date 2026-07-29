import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/utils/triage_level_style.dart';
import 'package:vitanet/features/triage_result/screens/triage_result_screen.dart';

/// Agent-style inbox for completed VitaNet symptom conversations.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return _buildMobileLayout(context);
        } else {
          return _buildDesktopLayout(context);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final sessions = [...ref.watch(triageHistoryProvider)]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          if (sessions.isNotEmpty)
            IconButton(
              tooltip: 'Clear chats',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      body: sessions.isEmpty
          ? const _EmptyChats()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xxxl,
              ),
              children: [
                _InboxIntro(sessionCount: sessions.length),
                const SizedBox(height: AppSpacing.xxl),
                ..._buildSessionGroups(context, ref, sessions, isDesktop: false),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New chat'),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final sessions = [...ref.watch(triageHistoryProvider)]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
    final selectedResult = ref.watch(triageResultProvider);

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar Panel (History List)
          Container(
            width: 380,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: context.colorScheme.outlineVariant.withValues(alpha: 0.3))),
            ),
            child: Column(
              children: [
                AppBar(
                  title: const Text('Chats'),
                  actions: [
                    if (sessions.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear chats',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _confirmClearAll(context, ref),
                      ),
                  ],
                ),
                Expanded(
                  child: sessions.isEmpty
                      ? const _EmptyChats()
                      : ListView(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          children: [
                            _InboxIntro(sessionCount: sessions.length),
                            const SizedBox(height: AppSpacing.xl),
                            ..._buildSessionGroups(context, ref, sessions, isDesktop: true),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.push('/chat'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New chat'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Right Content Panel (Triage Result Detail)
          Expanded(
            child: selectedResult == null
                ? Container(
                    color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.forum_rounded, size: 64, color: context.colorScheme.primary.withValues(alpha: 0.3)),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Select a chat to view details',
                            style: context.textTheme.titleMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: context.colorScheme.surface,
                    ),
                    child: const TriageResultScreen(isEmbedded: true),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSessionGroups(
    BuildContext context,
    WidgetRef ref,
    List<TriageResult> sessions, {
    required bool isDesktop,
  }) {
    final groups = <String, List<TriageResult>>{};
    for (final session in sessions) {
      groups.putIfAbsent(_dateLabel(session.timestamp), () => []).add(session);
    }
    
    final selectedResult = ref.watch(triageResultProvider);

    return groups.entries.expand((entry) {
      return <Widget>[
        _DateDivider(label: entry.key),
        const SizedBox(height: AppSpacing.sm),
        ...entry.value.map(
          (session) {
            final isSelected = isDesktop && selectedResult?.id == session.id;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Dismissible(
                key: Key(session.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) {
                  ref.read(triageHistoryProvider.notifier).remove(session.id);
                  if (isSelected) {
                    ref.read(triageResultProvider.notifier).state = null;
                  }
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: context.colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: context.colorScheme.error,
                  ),
                ),
                child: _AgentSessionTile(
                  session: session,
                  isSelected: isSelected,
                  onTap: () {
                    ref.read(triageResultProvider.notifier).state = session;
                    if (!isDesktop) {
                      context.push('/triage-result');
                    }
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
      ];
    }).toList();
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return 'Today';
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, y').format(date);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete this chat?'),
            content: const Text(
              'The saved symptom assessment and care plan will be removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all chats?'),
        content: const Text(
          'This permanently removes every saved symptom assessment and care plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(triageHistoryProvider.notifier).clearAll();
              ref.read(triageResultProvider.notifier).state = null;
              Navigator.pop(dialogContext);
            },
            child: Text(
              'Clear chats',
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxIntro extends StatelessWidget {
  final int sessionCount;

  const _InboxIntro({required this.sessionCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.52,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: context.colorScheme.onPrimary,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sessionCount saved ${sessionCount == 1 ? 'chat' : 'chats'}',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Each chat keeps the assessment and recommended next step.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
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

class _DateDivider extends StatelessWidget {
  final String label;

  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.textTheme.labelLarge?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AgentSessionTile extends StatelessWidget {
  final TriageResult session;
  final VoidCallback onTap;
  final bool isSelected;

  const _AgentSessionTile({required this.session, required this.onTap, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final style = TriageLevelStyle.of(session.level);
    final time = DateFormat.jm().format(session.timestamp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected 
                ? context.colorScheme.primaryContainer.withValues(alpha: 0.4) 
                : context.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected 
                  ? context.colorScheme.primary.withValues(alpha: 0.5) 
                  : context.colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: context.colorScheme.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.primarySymptom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          time,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(style.icon, size: 15, color: style.color),
                        const SizedBox(width: 5),
                        Text(
                          style.shortLabel,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: style.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (!isSelected) ...[
                          Text(
                            'Open plan',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: context.colorScheme.primary,
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: context.colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No chats yet',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Start a symptom check and VitaNet will save the assessment here.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => context.push('/chat'),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Start a chat'),
            ),
          ],
        ),
      ),
    );
  }
}
