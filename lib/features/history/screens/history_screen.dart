import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/triage_result/screens/triage_result_screen.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Visual style per triage level (History design palette).
class _LevelStyle {
  final String label;
  final String short;
  final Color accent;
  final Color tagBg;
  final Color tagFg;
  final Color count;
  const _LevelStyle(this.label, this.short, this.accent, this.tagBg, this.tagFg, this.count);

  static _LevelStyle of(TriageLevel level) {
    switch (level) {
      case TriageLevel.selfCare:
        return const _LevelStyle('Self-care', 'Self-care', Color(0xFF10B981), Color(0xFFD1FAE5), Color(0xFF065F46), Color(0xFF047857));
      case TriageLevel.pharmacist:
        return const _LevelStyle('Pharmacist', 'Pharmacist', Color(0xFFF59E0B), Color(0xFFFEF3C7), Color(0xFF92400E), Color(0xFFB45309));
      case TriageLevel.doctor:
        return const _LevelStyle('See a doctor', 'Doctor', Color(0xFFF97316), Color(0xFFFFEDD5), Color(0xFF9A3412), Color(0xFFC2410C));
      case TriageLevel.emergency:
        return const _LevelStyle('Urgent', 'Urgent', Color(0xFFDC2626), Color(0xFFFEE2E2), Color(0xFF991B1B), Color(0xFFB91C1C));
    }
  }
}

/// Check history: every saved triage with its outcome, deletable one by one
/// or all at once.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  void _open(TriageResult session, bool wide) {
    ref.read(triageResultProvider.notifier).state = session;
    if (!wide) {
      try {
        context.push('/triage-result');
      } catch (_) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TriageResultScreen()));
      }
    }
  }

  Future<void> _delete(TriageResult session) async {
    final ok = await confirmDeleteCheck(context, session);
    if (!ok || !mounted) return;
    await ref.read(triageHistoryProvider.notifier).remove(session.id);
    if (ref.read(triageResultProvider)?.id == session.id) {
      ref.read(triageResultProvider.notifier).state = null;
    }
  }

  Future<void> _clearAll(int count) async {
    final ok = await confirmClearHistory(context, count);
    if (!ok || !mounted) return;
    await ref.read(triageHistoryProvider.notifier).clearAll();
    ref.read(triageResultProvider.notifier).state = null;
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      try {
        context.go('/profile');
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final sessions = [...ref.watch(triageHistoryProvider)]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final selected = ref.watch(triageResultProvider);

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800;
            final list = _buildList(p, sessions, wide, selected);
            if (!wide) return list;
            return Row(
              children: [
                SizedBox(width: 420, child: list),
                VerticalDivider(width: 1, color: p.line),
                Expanded(
                  child: selected == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_rounded, size: 48, color: p.faint),
                              const SizedBox(height: 12),
                              Text('Select a check to see its result', style: VnText.body(15, color: p.muted)),
                            ],
                          ),
                        )
                      : const TriageResultScreen(isEmbedded: true),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(VnPalette p, List<TriageResult> sessions, bool wide, TriageResult? selected) {
    final counts = {for (final l in TriageLevel.values) l: sessions.where((s) => s.level == l).length};
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        VnTopBar(
          title: 'Check history',
          onBack: _back,
          actions: [
            if (sessions.isNotEmpty)
              VnLink(
                label: 'Clear all',
                fontSize: 13,
                weight: FontWeight.w700,
                color: p.danger,
                onTap: () => _clearAll(sessions.length),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (sessions.isEmpty)
          _EmptyHistory(onStart: () {
            try {
              context.push('/chat');
            } catch (_) {}
          })
        else ...[
          Row(
            children: [
              for (final l in TriageLevel.values) ...[
                if (l != TriageLevel.selfCare) const SizedBox(width: 8),
                Expanded(child: _CountTile(style: _LevelStyle.of(l), count: counts[l]!)),
              ],
            ],
          ),
          const SizedBox(height: 18),
          for (final s in sessions) ...[
            Dismissible(
              key: ValueKey(s.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => confirmDeleteCheck(context, s),
              onDismissed: (_) {
                ref.read(triageHistoryProvider.notifier).remove(s.id);
                if (selected?.id == s.id) ref.read(triageResultProvider.notifier).state = null;
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(color: p.dangerTint, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.delete_outline_rounded, color: p.danger),
              ),
              child: _HistoryRow(
                session: s,
                selected: wide && selected?.id == s.id,
                onTap: () => _open(s, wide),
                onDelete: () => _delete(s),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  final _LevelStyle style;
  final int count;
  const _CountTile({required this.style, required this.count});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      label: '$count ${style.short}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line),
        ),
        child: Column(
          children: [
            Text('$count', style: VnText.body(20, weight: FontWeight.w800, color: p.tintFg(style.count))),
            const SizedBox(height: 2),
            Text(style.short,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VnText.body(11, weight: FontWeight.w600, color: p.muted)),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final TriageResult session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _HistoryRow({required this.session, required this.selected, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final style = _LevelStyle.of(session.level);
    final t = session.timestamp;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                children: [
                  Text(DateFormat('MMM').format(t).toUpperCase(),
                      style: VnText.body(11, weight: FontWeight.w700, color: p.muted)),
                  Text('${t.day}', style: VnText.heading(20, color: p.ink)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: selected ? p.brandWash : p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: selected ? p.brandBorder : p.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(border: Border(left: BorderSide(color: style.accent, width: 4))),
                  padding: const EdgeInsets.fromLTRB(14, 6, 2, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(session.primarySymptom,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: VnText.body(14, weight: FontWeight.w700, color: p.ink)),
                            ),
                          ),
                          VnIconButton(
                            icon: Icons.delete_outline_rounded,
                            tooltip: 'Delete this check',
                            size: 40,
                            iconSize: 18,
                            foreground: p.faint,
                            onPressed: onDelete,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.tintBg(style.tagBg, style.tagFg),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(style.label,
                                style: VnText.body(12, weight: FontWeight.w700, color: p.tintFg(style.tagFg))),
                          ),
                          const SizedBox(width: 8),
                          Text(DateFormat('HH:mm').format(t), style: VnText.body(12, color: p.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyHistory({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          VnIconTile(icon: Icons.history_rounded, bg: const Color(0xFFCCFBF1), fg: const Color(0xFF0F766E), size: 64, radius: 20, iconSize: 30),
          const SizedBox(height: 16),
          Text('No checks yet', style: VnText.heading(20, color: p.ink)),
          const SizedBox(height: 6),
          Text('Start a symptom check and VitaNet will save the result here.',
              textAlign: TextAlign.center, style: VnText.body(14, color: p.muted, height: 1.5)),
          const SizedBox(height: 20),
          VnButton(label: 'Start a check', icon: Icons.chat_bubble_outline_rounded, expand: false, onPressed: onStart),
        ],
      ),
    );
  }
}

/// "Delete this check?" dialog (DeleteChat design). Returns true to delete.
Future<bool> confirmDeleteCheck(BuildContext context, TriageResult session) async {
  final date = DateFormat('d MMM').format(session.timestamp);
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x8C0F172A),
    builder: (ctx) {
      final p = VnPalette.of(ctx);
      return Dialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: 'Delete this check?',
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VnIconTile(
                  icon: Icons.delete_outline_rounded,
                  bg: Color(0xFFFEE2E2),
                  fg: Color(0xFFB91C1C),
                  size: 56,
                  radius: 18,
                  iconSize: 26,
                ),
                const SizedBox(height: 14),
                Text('Delete this check?', textAlign: TextAlign.center, style: VnText.heading(20, color: p.ink)),
                const SizedBox(height: 14),
                Text(
                  '"${session.primarySymptom}" from $date and its triage result will be removed from this device. This can\'t be undone.',
                  textAlign: TextAlign.center,
                  style: VnText.body(14, color: p.inkSoft, height: 1.55),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: VnOutlineButton(
                        label: 'Cancel',
                        background: p.surfaceAlt,
                        borderColor: Colors.transparent,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: VnButton(
                        label: 'Delete',
                        height: 52,
                        fontSize: 15,
                        background: const Color(0xFFB91C1C),
                        foreground: Colors.white,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// "Clear all triage history?" dialog (ClearHistory design) with a typed
/// DELETE confirmation. Returns true to clear.
Future<bool> confirmClearHistory(BuildContext context, int count) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x8C0F172A),
    builder: (ctx) => _ClearHistoryDialog(count: count),
  );
  return result ?? false;
}

class _ClearHistoryDialog extends StatefulWidget {
  final int count;
  const _ClearHistoryDialog({required this.count});

  @override
  State<_ClearHistoryDialog> createState() => _ClearHistoryDialogState();
}

class _ClearHistoryDialogState extends State<_ClearHistoryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmed => _controller.text.trim().toUpperCase() == 'DELETE';

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final n = widget.count;
    return VnDialog(
      children: [
        const VnIconTile(
          icon: Icons.warning_amber_rounded,
          bg: Color(0xFFFEE2E2),
          fg: Color(0xFFB91C1C),
          size: 56,
          radius: 18,
          iconSize: 26,
        ),
        Text('Clear all triage history?', style: VnText.heading(21, color: p.ink)),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'This permanently deletes '),
            TextSpan(
              text: '$n ${n == 1 ? 'check' : 'checks'}',
              style: VnText.body(14, weight: FontWeight.w700, color: p.ink),
            ),
            const TextSpan(text: ' from this phone. Your medical profile and vitals stay.'),
          ]),
          style: VnText.body(14, color: p.inkSoft, height: 1.55),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type DELETE to confirm', style: VnText.body(13, weight: FontWeight.w600, color: p.ink)),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              style: VnText.body(15, weight: FontWeight.w700, color: p.ink, letterSpacing: 1),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: VnText.body(15, color: p.faint, letterSpacing: 1),
                filled: true,
                fillColor: p.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _confirmed ? const Color(0xFFB91C1C) : p.line, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 2),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: VnOutlineButton(
                label: 'Cancel',
                background: p.surfaceAlt,
                borderColor: Colors.transparent,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: VnButton(
                label: 'Clear history',
                height: 52,
                fontSize: 15,
                background: const Color(0xFFB91C1C),
                foreground: Colors.white,
                onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
