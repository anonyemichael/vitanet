import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/settings/settings_providers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme sheet
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showThemeSheet(BuildContext context) =>
    showVnSheet<void>(context, builder: (_) => const _ThemeSheet());

class _ThemeSheet extends ConsumerWidget {
  const _ThemeSheet();

  static const _descs = {
    ThemeMode.system: 'Matches your phone. Switches to dark automatically at night.',
    ThemeMode.light: 'Clean, high-contrast interface for daytime use.',
    ThemeMode.dark: 'Reduces eye strain and glare in low light.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VnPalette.of(context);
    final mode = ref.watch(themeModeProvider);

    Widget option(ThemeMode m, String label, Widget preview) {
      final on = mode == m;
      return Semantics(
        button: true,
        selected: on,
        label: '$label theme',
        excludeSemantics: true,
        child: Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: on ? p.brand : p.line, width: on ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => ref.read(themeModeProvider.notifier).setTheme(m),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  preview,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: on ? p.brand : p.switchOff,
                            width: on ? 5 : 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(label,
                            overflow: TextOverflow.ellipsis,
                            style: VnText.body(14, weight: FontWeight.w700, color: p.ink)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return VnSheet(
      children: [
        Semantics(
          header: true,
          child: Text('Appearance', style: VnText.heading(20, color: p.ink)),
        ),
        Row(
          children: [
            Expanded(
              child: option(
                ThemeMode.system,
                'System',
                const _ThemePreview(split: true, bg: Color(0xFFF8FAFC), fg: Color(0xFF64748B), line: Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: option(
                ThemeMode.light,
                'Light',
                const _ThemePreview(bg: Color(0xFFF8FAFC), fg: Color(0xFF0F172A), line: Color(0xFFE2E8F0)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: option(
                ThemeMode.dark,
                'Dark',
                const _ThemePreview(bg: Color(0xFF121212), fg: Color(0xFFF5F5F5), line: Color(0xFF2A2A2A)),
              ),
            ),
          ],
        ),
        Text(_descs[mode]!, style: VnText.body(13, color: p.muted, height: 1.5)),
        VnButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final Color bg;
  final Color fg;
  final Color line;
  final bool split;
  const _ThemePreview({required this.bg, required this.fg, required this.line, this.split = false});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h, Color c) => FractionallySizedBox(
          widthFactor: w,
          child: Container(
            height: h,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
          ),
        );
    return Container(
      height: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: split ? null : bg,
        gradient: split
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.5, 0.5],
                colors: [Color(0xFFF8FAFC), Color(0xFF121212)],
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E9EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(0.5, 10, fg),
          const SizedBox(height: 7),
          bar(1, 8, line),
          const SizedBox(height: 7),
          bar(0.8, 8, line),
          const SizedBox(height: 7),
          bar(0.6, 14, const Color(0xFF0F766E)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text size sheet
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showTextSizeSheet(BuildContext context) =>
    showVnSheet<void>(context, builder: (_) => const _TextSizeSheet());

class _TextSizeSheet extends ConsumerWidget {
  const _TextSizeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VnPalette.of(context);
    final scale = ref.watch(textScaleProvider);
    return VnSheet(
      children: [
        Text('Text size', style: VnText.heading(20, color: p.ink)),
        VnListGroup(
          children: [
            for (final (label, value) in TextScaleNotifier.options)
              VnListRow(
                title: label,
                chevron: false,
                onTap: () => ref.read(textScaleProvider.notifier).set(value),
                leading: Text('Aa',
                    style: VnText.body(14 * value, weight: FontWeight.w800, color: p.inkSoft)),
                trailing: scale == value
                    ? Icon(Icons.check_rounded, color: p.brand)
                    : const SizedBox(width: 24),
              ),
          ],
        ),
        Text('Changes text across VitaNet. Your phone\'s own text size setting still applies.',
            style: VnText.body(13, color: p.muted, height: 1.5)),
        VnButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Clear triage history dialog
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showClearHistoryDialog(BuildContext context) => showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: const Color(0x8C0F172A),
      builder: (_) => const _ClearHistoryDialog(),
    );

class _ClearHistoryDialog extends ConsumerStatefulWidget {
  const _ClearHistoryDialog();

  @override
  ConsumerState<_ClearHistoryDialog> createState() => _ClearHistoryDialogState();
}

class _ClearHistoryDialogState extends ConsumerState<_ClearHistoryDialog> {
  final _confirm = TextEditingController();
  bool _shareFirst = true;
  bool _busy = false;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    final history = ref.read(triageHistoryProvider);
    if (_shareFirst && history.isNotEmpty) {
      final b = StringBuffer('VitaNet triage history\n\n');
      for (final h in history) {
        final d = h.timestamp;
        b.writeln('${d.day}/${d.month}/${d.year} - ${h.primarySymptom} (${h.level.name})');
        if (h.summary.isNotEmpty) b.writeln('  ${h.summary}');
      }
      try {
        await Share.share(b.toString(), subject: 'VitaNet triage history');
      } catch (_) {}
    }
    await ref.read(triageHistoryProvider.notifier).clearAll();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Triage history cleared.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final count = ref.watch(triageHistoryProvider).length;
    final ok = _confirm.text.trim() == 'DELETE';

    return VnDialog(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: p.dangerTint, borderRadius: BorderRadius.circular(18)),
          child: Icon(Icons.warning_amber_rounded, size: 26, color: p.danger),
        ),
        Semantics(
          header: true,
          child: Text('Clear all triage history?', style: VnText.heading(21, color: p.ink)),
        ),
        Text.rich(
          TextSpan(
            style: VnText.body(14, color: p.inkSoft, height: 1.55),
            children: [
              const TextSpan(text: 'This permanently deletes '),
              TextSpan(
                text: '$count ${count == 1 ? 'check' : 'checks'}',
                style: VnText.body(14, weight: FontWeight.w700, color: p.ink),
              ),
              const TextSpan(text: ' from this phone. Your medical profile and vitals stay.'),
            ],
          ),
        ),
        Material(
          color: p.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _shareFirst = !_shareFirst),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                children: [
                  Checkbox(
                    value: _shareFirst,
                    activeColor: p.brand,
                    checkColor: p.onBrand,
                    onChanged: (v) => setState(() => _shareFirst = v ?? false),
                  ),
                  Expanded(
                    child: Text('Save or send a copy first',
                        style: VnText.body(13, color: p.inkSoft, height: 1.45)),
                  ),
                ],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type DELETE to confirm',
                style: VnText.body(13, weight: FontWeight.w600, color: p.ink)),
            const SizedBox(height: 6),
            TextField(
              controller: _confirm,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.characters,
              style: VnText.body(15, weight: FontWeight.w700, letterSpacing: 1, color: p.ink),
              decoration: InputDecoration(
                filled: true,
                fillColor: p.surface,
                hintText: 'DELETE',
                hintStyle: VnText.body(15, color: p.faint, letterSpacing: 1),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ok ? p.danger : p.line, width: ok ? 2 : 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.danger, width: 2),
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
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: VnButton(
                label: 'Clear history',
                height: 52,
                fontSize: 15,
                loading: _busy,
                background: const Color(0xFFB91C1C),
                foreground: Colors.white,
                onPressed: ok && !_busy ? _clear : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
