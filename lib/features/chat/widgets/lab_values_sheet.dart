import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class _LabTest {
  final String name;
  final String unit;
  final double? low;
  final double? high;
  const _LabTest(this.name, this.unit, this.low, this.high);

  String get range {
    if (low == null && high != null) return '< ${_fmt(high!)}';
    if (high == null && low != null) return '> ${_fmt(low!)}';
    return '${_fmt(low!)}–${_fmt(high!)}';
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

const _panels = <String, List<_LabTest>>{
  'Full blood count': [
    _LabTest('White blood cells', '×10⁹/L', 4.0, 11.0),
    _LabTest('Haemoglobin', 'g/dL', 12.0, 15.5),
    _LabTest('Platelets', '×10⁹/L', 150, 400),
    _LabTest('Neutrophils', '×10⁹/L', 2.0, 7.5),
    _LabTest('CRP', 'mg/L', null, 5),
  ],
  'Kidney': [
    _LabTest('Creatinine', 'µmol/L', 45, 90),
    _LabTest('Urea', 'mmol/L', 2.5, 7.8),
    _LabTest('eGFR', 'mL/min', 90, null),
    _LabTest('Sodium', 'mmol/L', 135, 145),
    _LabTest('Potassium', 'mmol/L', 3.5, 5.3),
  ],
  'Lipids': [
    _LabTest('Total cholesterol', 'mmol/L', null, 5.0),
    _LabTest('LDL', 'mmol/L', null, 3.0),
    _LabTest('HDL', 'mmol/L', 1.2, null),
    _LabTest('Triglycerides', 'mmol/L', null, 1.7),
  ],
};

/// "Enter lab values" sheet. Resolves with a prompt describing the entered
/// values (to send to VitaNet AI), or null when closed.
Future<String?> showLabValuesSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C0F172A),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        top: 96,
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: const _LabValuesSheet(),
    ),
  );
}

class _LabValuesSheet extends StatefulWidget {
  const _LabValuesSheet();

  @override
  State<_LabValuesSheet> createState() => _LabValuesSheetState();
}

class _LabValuesSheetState extends State<_LabValuesSheet> {
  String _panel = _panels.keys.first;
  final Map<String, TextEditingController> _values = {};
  final List<(TextEditingController, TextEditingController, TextEditingController)> _custom = [];

  TextEditingController _ctrl(String key) =>
      _values.putIfAbsent(key, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _values.values) {
      c.dispose();
    }
    for (final (a, b, c) in _custom) {
      a.dispose();
      b.dispose();
      c.dispose();
    }
    super.dispose();
  }

  String? _flag(_LabTest t, String raw) {
    final v = double.tryParse(raw.trim());
    if (v == null) return null;
    if (t.low != null && v < t.low!) return 'LOW';
    if (t.high != null && v > t.high!) return 'HIGH';
    return 'OK';
  }

  void _submit() {
    final lines = <String>[];
    for (final entry in _panels.entries) {
      for (final t in entry.value) {
        final raw = _values['${entry.key}|${t.name}']?.text.trim() ?? '';
        if (raw.isEmpty) continue;
        lines.add('- ${t.name}: $raw ${t.unit} (normal ${t.range}) ${_flag(t, raw) ?? ''}'.trim());
      }
    }
    for (final (n, v, u) in _custom) {
      if (n.text.trim().isEmpty || v.text.trim().isEmpty) continue;
      lines.add('- ${n.text.trim()}: ${v.text.trim()} ${u.text.trim()}'.trim());
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Enter at least one value')),
      );
      return;
    }
    Navigator.of(context).pop(
      'Please interpret my lab results in plain language and tell me what to do next:\n${lines.join('\n')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final tests = _panels[_panel]!;

    Widget flagPill(String? f) {
      if (f == null) return const SizedBox(width: 40);
      final (bg, fg) = switch (f) {
        'OK' => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
        'HIGH' => (const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
        _ => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      };
      return Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.tintBg(bg, fg), borderRadius: BorderRadius.circular(8)),
        child: Text(f, style: VnText.body(11, weight: FontWeight.w800, color: p.tintFg(fg))),
      );
    }

    InputDecoration valueDec(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: VnText.body(14, color: p.faint),
          isDense: true,
          filled: true,
          fillColor: p.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: p.isDark ? const Color(0xFF404040) : const Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: p.brand, width: 2),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: p.isDark ? const Color(0xFF404040) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Text('Enter lab values', style: VnText.heading(20, color: p.ink))),
                  VnIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    size: 44,
                    radius: 12,
                    background: p.surfaceAlt,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in _panels.keys)
                    VnChip(
                      label: k,
                      height: 36,
                      fontSize: 13,
                      selected: _panel == k,
                      onTap: () => setState(() => _panel = k),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    for (final t in tests) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.name,
                                      style: VnText.body(14, weight: FontWeight.w600, color: p.ink)),
                                  const SizedBox(height: 2),
                                  Text('Normal ${t.range}', style: VnText.body(12, color: p.muted)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 76,
                              child: TextField(
                                controller: _ctrl('$_panel|${t.name}'),
                                onChanged: (_) => setState(() {}),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                textAlign: TextAlign.right,
                                style: VnText.body(15, weight: FontWeight.w600, color: p.ink),
                                decoration: valueDec('--'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 58,
                              child: Text(t.unit, style: VnText.body(12, color: p.muted)),
                            ),
                            flagPill(_flag(t, _ctrl('$_panel|${t.name}').text)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    for (final (n, v, u) in _custom) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: n,
                              style: VnText.body(14, color: p.ink),
                              decoration: valueDec('Test name'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: v,
                              style: VnText.body(14, color: p.ink),
                              decoration: valueDec('Value'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: u,
                              style: VnText.body(14, color: p.ink),
                              decoration: valueDec('Unit'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: p.brand,
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: () => setState(() => _custom.add((
                              TextEditingController(),
                              TextEditingController(),
                              TextEditingController(),
                            ))),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text('Add another value',
                            style: VnText.body(14, weight: FontWeight.w700, color: p.brand)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VnButton(
                label: 'Interpret my results',
                icon: Icons.auto_awesome_rounded,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
