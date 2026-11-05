import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Five-question guided symptom assessment. On completion the answers are
/// handed to VitaNet AI chat, which produces the triage result.
class AssessmentWizardScreen extends ConsumerStatefulWidget {
  const AssessmentWizardScreen({super.key});

  @override
  ConsumerState<AssessmentWizardScreen> createState() => _AssessmentWizardScreenState();
}

class _AssessmentWizardScreenState extends ConsumerState<AssessmentWizardScreen> {
  static const _areas = <(String, IconData)>[
    ('Head', Icons.psychology_outlined),
    ('Chest', Icons.favorite_border_rounded),
    ('Stomach', Icons.lunch_dining_outlined),
    ('Skin', Icons.water_drop_outlined),
    ('Muscles & joints', Icons.accessibility_new_rounded),
    ('Mind & mood', Icons.nightlight_outlined),
  ];
  static const _durations = [
    'Less than 24 hours',
    '1–3 days',
    '4–7 days',
    '1–4 weeks',
    'More than a month',
  ];
  static const _extras = [
    'Fever', 'Stiff neck', 'Light sensitivity', 'Nausea', 'Vomiting',
    'Rash', 'Confusion', 'Cough', 'Fatigue', 'Dizziness',
  ];
  static const _risks = [
    'Asthma or lung disease',
    'Pregnant',
    'Weakened immune system',
    'Recent travel abroad',
    'Over 65 years old',
  ];

  int _step = 0;
  String? _area;
  String? _duration;
  double _pain = 5;
  final Set<String> _symptoms = {};
  final Set<String> _riskFactors = {};

  @override
  void initState() {
    super.initState();
    // Pre-tick risk factors we already know from the profile.
    final profile = ref.read(userProfileProvider);
    final conditions = (profile?.preExistingConditions ?? const <String>[])
        .map((c) => c.toLowerCase())
        .toList();
    if (conditions.any((c) => c.contains('asthma') || c.contains('lung') || c.contains('copd'))) {
      _riskFactors.add('Asthma or lung disease');
    }
    if (conditions.any((c) => c.contains('pregnan'))) _riskFactors.add('Pregnant');
    if ((profile?.age ?? 0) >= 65) _riskFactors.add('Over 65 years old');
  }

  bool get _canContinue => switch (_step) {
        0 => _area != null,
        1 => _duration != null,
        _ => true,
      };

  void _next() {
    HapticFeedback.selectionClick();
    if (_step < 4) {
      setState(() => _step += 1);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step -= 1);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  String _painWord(int v) {
    if (v == 0) return 'None';
    if (v <= 3) return 'Mild';
    if (v <= 6) return 'Moderate';
    if (v <= 8) return 'Severe';
    return 'Unbearable';
  }

  void _openChat({String? prompt}) {
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    router.go('/chat');
    if (prompt != null) {
      Future.delayed(const Duration(milliseconds: 450), () {
        container.read(searchActionProvider.notifier).state = prompt;
      });
    }
  }

  Future<void> _finish() async {
    final pain = _pain.round();
    final buffer = StringBuffer()
      ..write('Guided symptom assessment. ')
      ..write('Main area: $_area. ')
      ..write('Duration: $_duration. ')
      ..write('Pain or discomfort: $pain/10 (${_painWord(pain)}). ');
    if (_symptoms.isNotEmpty) buffer.write('Other symptoms: ${_symptoms.join(", ")}. ');
    if (_riskFactors.isNotEmpty) buffer.write('Risk factors: ${_riskFactors.join(", ")}. ');
    buffer.write('Please triage me and tell me what to do next.');

    final allSymptoms = [
      ?_area,
      ..._symptoms,
    ];
    try {
      final ai = ref.read(aiServiceProvider);
      final triage = await ai.generateTriageResultFromML(
        symptoms: allSymptoms,
        primarySymptom: _symptoms.isNotEmpty ? _symptoms.first : (_area ?? 'General symptom'),
      );
      if (mounted) {
        ref.read(triageResultProvider.notifier).state = triage;
        ref.read(triageHistoryProvider.notifier).add(triage);
      }
    } catch (_) {
      // Graceful fallback
    }

    if (!mounted) return;
    _openChat(prompt: buffer.toString());
  }

  Future<void> _call112() async {
    final uri = Uri.parse('tel:112');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: p.page,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          VnIconButton(
                            icon: Icons.chevron_left_rounded,
                            tooltip: 'Back',
                            iconSize: 26,
                            onPressed: _back,
                          ),
                          Expanded(
                            child: Text('Symptom assessment',
                                textAlign: TextAlign.center,
                                style: VnText.heading(16, weight: FontWeight.w700, color: p.ink)),
                          ),
                          VnLink(label: 'Skip', onTap: () => _openChat()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        for (var k = 0; k < 5; k++) ...[
                          if (k > 0) const SizedBox(width: 6),
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 5,
                              decoration: BoxDecoration(
                                color: k <= _step
                                    ? p.brand
                                    : (p.isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Question ${_step + 1} of 5',
                        style: VnText.body(12, weight: FontWeight.w600, color: p.muted)),
                    const SizedBox(height: 22),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: KeyedSubtree(
                            key: ValueKey(_step),
                            child: switch (_step) {
                              0 => _stepArea(p),
                              1 => _stepDuration(p),
                              2 => _stepPain(p),
                              3 => _stepSymptoms(p),
                              _ => _stepRisks(p),
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    VnButton(
                      label: _step == 4 ? 'See my result' : 'Continue',
                      onPressed: _canContinue ? _next : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text('Severe chest pain or trouble breathing? ',
                              style: VnText.body(12, color: p.muted)),
                        ),
                        VnLink(
                          label: 'Call 112',
                          fontSize: 12,
                          weight: FontWeight.w700,
                          color: p.danger,
                          onTap: _call112,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _question(VnPalette p, String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: VnText.heading(24, color: p.ink))),
          const SizedBox(height: 6),
          Text(sub, style: VnText.body(15, color: p.muted)),
          const SizedBox(height: 18),
        ],
      );

  /// Spec option styling: selected = 2px brand border on brandWash.
  Widget _option({
    required VnPalette p,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
    double radius = 16,
    double? height,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    String? semanticLabel,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: Material(
        color: selected ? p.brandWash : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: selected ? p.brand : p.line, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(height: height, padding: padding, child: child),
        ),
      ),
    );
  }

  Widget _stepArea(VnPalette p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _question(p, 'Where is the problem?', 'Pick the main area. You can add more later.'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 96,
            children: [
              for (final (label, icon) in _areas)
                _option(
                  p: p,
                  radius: 18,
                  selected: _area == label,
                  onTap: () => setState(() => _area = label),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 24, color: _area == label ? p.brandDeep : p.ink),
                      const SizedBox(height: 8),
                      Text(label,
                          style: VnText.body(14,
                              weight: FontWeight.w600,
                              color: _area == label ? p.brandDeep : p.ink)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _stepDuration(VnPalette p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _question(p, 'How long have you had this?', 'The timeline helps us judge urgency.'),
          for (final d in _durations) ...[
            _option(
              p: p,
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              selected: _duration == d,
              onTap: () => setState(() => _duration = d),
              child: Row(
                children: [
                  Expanded(
                    child: Text(d,
                        style: VnText.body(15,
                            weight: FontWeight.w600,
                            color: _duration == d ? p.brandDeep : p.ink)),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _duration == d ? p.brand : p.switchOff,
                        width: _duration == d ? 6 : 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );

  Widget _stepPain(VnPalette p) {
    final v = _pain.round();
    final Color ring;
    final Color fill;
    final Color text;
    if (v <= 3) {
      ring = const Color(0xFF10B981);
      fill = const Color(0xFFECFDF5);
      text = const Color(0xFF047857);
    } else if (v <= 6) {
      ring = const Color(0xFFF59E0B);
      fill = const Color(0xFFFFFBEB);
      text = const Color(0xFFB45309);
    } else {
      ring = const Color(0xFFF97316);
      fill = const Color(0xFFFFF7ED);
      text = const Color(0xFFC2410C);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _question(p, 'How bad is the pain or discomfort?',
            '0 is none, 10 is the worst you can imagine.'),
        const SizedBox(height: 4),
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.isDark ? ring.withValues(alpha: 0.14) : fill,
              border: Border.all(color: ring, width: 10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$v',
                    style: VnText.heading(52, color: p.tintFg(text), height: 1)),
                Text(_painWord(v),
                    style: VnText.body(13, weight: FontWeight.w700, color: p.tintFg(text))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text('Pain level', style: VnText.body(13, weight: FontWeight.w600, color: p.ink)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFEA580C),
            thumbColor: const Color(0xFFEA580C),
            inactiveTrackColor: p.switchOff,
            overlayColor: const Color(0x33EA580C),
          ),
          child: Slider(
            value: _pain,
            min: 0,
            max: 10,
            divisions: 10,
            label: '$v',
            semanticFormatterCallback: (val) => '${val.round()} out of 10, ${_painWord(val.round())}',
            onChanged: (val) => setState(() => _pain = val),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 · None', style: VnText.body(12, color: p.muted)),
            Text('10 · Unbearable', style: VnText.body(12, color: p.muted)),
          ],
        ),
      ],
    );
  }

  Widget _stepSymptoms(VnPalette p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _question(p, 'Any other symptoms?', 'Select all that apply.'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final x in _extras)
                Semantics(
                  button: true,
                  selected: _symptoms.contains(x),
                  child: Material(
                    color: _symptoms.contains(x) ? p.brandWash : p.surface,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: _symptoms.contains(x) ? p.brand : p.line,
                        width: _symptoms.contains(x) ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => setState(() =>
                          _symptoms.contains(x) ? _symptoms.remove(x) : _symptoms.add(x)),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        child: Text(x,
                            style: VnText.body(14,
                                weight: FontWeight.w600,
                                color: _symptoms.contains(x) ? p.brandDeep : p.ink)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _stepRisks(VnPalette p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _question(p, 'Any special risk factors?', 'This helps us triage you safely.'),
          VnListGroup(
            children: [
              for (final r in _risks)
                InkWell(
                  onTap: () => setState(() =>
                      _riskFactors.contains(r) ? _riskFactors.remove(r) : _riskFactors.add(r)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _riskFactors.contains(r),
                          activeColor: p.brand,
                          checkColor: p.onBrand,
                          side: BorderSide(color: p.faint, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          onChanged: (v) => setState(() =>
                              v == true ? _riskFactors.add(r) : _riskFactors.remove(r)),
                        ),
                        const SizedBox(width: 2),
                        Expanded(child: Text(r, style: VnText.body(15, color: p.ink))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
}
