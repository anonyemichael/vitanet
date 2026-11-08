import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/data/services/daily_med_service.dart';
import 'package:vitanet/data/services/drug_synonyms.dart';
import 'package:vitanet/features/pharmacy/screens/pharmacy_screen.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

import '../models/health_video.dart';
import '../models/medicine.dart';
import '../widgets/resource_media.dart';
import 'video_player_screen.dart';

/// Medicine monograph (FDA label / verified catalog) in the redesigned layout.
class MedicineDetailScreen extends ConsumerStatefulWidget {
  final Medicine medicine;

  const MedicineDetailScreen({super.key, required this.medicine});

  @override
  ConsumerState<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends ConsumerState<MedicineDetailScreen> {
  int _tab = 0;
  String? _heroImageUrl;

  Medicine get m => widget.medicine;

  @override
  void initState() {
    super.initState();
    _resolveHeroImage();
  }

  @override
  void didUpdateWidget(MedicineDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.medicine.id != widget.medicine.id ||
        oldWidget.medicine.heroImageUrl != widget.medicine.heroImageUrl) {
      _resolveHeroImage();
    }
  }

  void _resolveHeroImage() {
    final direct = widget.medicine.heroImageUrl;
    if (direct != null && direct.isNotEmpty) {
      _heroImageUrl = DailyMedService.safeImageUrl(direct);
      return;
    }

    final cached = DailyMedService.instance.getCachedImageUrl(
      splSetId: widget.medicine.splSetId,
      drugName: widget.medicine.genericName ?? widget.medicine.name,
    );
    if (cached != null) {
      _heroImageUrl = DailyMedService.safeImageUrl(cached);
      return;
    }

    DailyMedService.instance.resolveMedicineImageUrl(
      splSetId: widget.medicine.splSetId,
      drugName: widget.medicine.genericName ?? widget.medicine.name,
    ).then((url) {
      if (mounted) {
        setState(() => _heroImageUrl = url != null ? DailyMedService.safeImageUrl(url) : null);
      }
    }).catchError((_) {});
  }

  // ── Label parsing (real monograph text) ──────────────────────────────────

  String get _allDosageText => m.details
      .where((d) => d.title.toLowerCase().contains('dos'))
      .map((d) => d.content)
      .join(' ');

  static String _dash(String s) => s.replaceAll(RegExp(r'\s*(?:to|-)\s*'), '–');

  String? get _adultDose {
    final match = RegExp(r'(\d[\d,.]*\s*(?:mg|mcg|g|ml|mL)?\s*(?:to|-|–)\s*)?\d[\d,.]*\s*(?:mg|mcg|ml|mL|g)\b',
            caseSensitive: false)
        .firstMatch(_allDosageText);
    if (match == null) return null;
    var text = match.group(0)!.trim();
    // "500 mg to 1,000 mg" -> "500–1,000 mg"
    text = text.replaceAllMapped(
      RegExp(r'^(\d[\d,.]*)\s*(mg|mcg|ml|g)\s*(?:to|-|–)\s*(\d[\d,.]*)\s*(mg|mcg|ml|g)$', caseSensitive: false),
      (mm) => mm.group(2)!.toLowerCase() == mm.group(4)!.toLowerCase()
          ? '${mm.group(1)}–${mm.group(3)} ${mm.group(4)}'
          : mm.group(0)!,
    );
    return _dash(text);
  }

  String? get _frequency {
    final t = _allDosageText.toLowerCase();
    final every = RegExp(r'every\s+(\d+(?:\s*(?:to|-|–)\s*\d+)?)\s*hours?').firstMatch(t);
    if (every != null) return 'Every ${_dash(every.group(1)!)} h';
    if (t.contains('once daily') || t.contains('once a day')) return 'Once a day';
    if (t.contains('twice daily') || t.contains('twice a day')) return 'Twice a day';
    if (t.contains('three times')) return '3 times a day';
    return null;
  }

  String? get _maxDaily {
    final match = RegExp(
      r'(?:not exceed|maximum(?: daily)?(?: dose)?(?: of)?|max(?:imum)? of|up to)\s+(\d[\d,.]*\s*(?:mg|mcg|g))',
      caseSensitive: false,
    ).firstMatch(_allDosageText);
    return match?.group(1)?.trim();
  }

  bool _isSideEffect(MedicineAccordionItem d) {
    final t = d.title.toLowerCase();
    return t.contains('side') || t.contains('adverse') || t.contains('reaction');
  }

  bool _isInteraction(MedicineAccordionItem d) {
    final t = d.title.toLowerCase();
    return t.contains('interact') || t.contains('warning') || t.contains('contraindic') || t.contains('precaution');
  }

  List<MedicineAccordionItem> get _sectionsForTab {
    switch (_tab) {
      case 1:
        return m.details.where(_isSideEffect).toList();
      case 2:
        return m.details.where(_isInteraction).toList();
      default:
        return m.details.where((d) => !_isSideEffect(d) && !_isInteraction(d)).toList();
    }
  }

  static const _interactionNames = [
    'Aspirin',
    'Warfarin',
    'Alcohol',
    'Lisinopril',
    'Other NSAIDs',
    'Methotrexate',
    'Lithium',
    'Digoxin',
    'Antacids',
    'Clopidogrel',
    'Grapefruit',
    'MAO inhibitors',
    'Acetaminophen',
    'Diuretics',
  ];

  List<String> get _dontTakeWith {
    final text = m.details.where(_isInteraction).map((d) => d.content).join(' ').toLowerCase();
    if (text.isEmpty) return const [];
    final out = <String>[];
    for (final name in _interactionNames) {
      final key = name == 'Other NSAIDs'
          ? 'nsaid'
          : name == 'MAO inhibitors'
              ? 'mao'
              : name.toLowerCase();
      if (text.contains(key) && !m.name.toLowerCase().contains(key)) out.add(name);
    }
    return out;
  }

  /// Profile-aware caution (asthma + NSAIDs, or a recorded allergy).
  ({String title, String body})? _caution(List<String> conditions, List<String> allergies) {
    final name = '${m.name} ${m.genericName ?? ''} ${m.brandName ?? ''}'.toLowerCase();
    for (final allergy in allergies) {
      final a = allergy.toLowerCase().trim();
      if (a.length > 2 && (name.contains(a) || m.type.toLowerCase().contains(a))) {
        return (
          title: 'Caution: you listed an allergy to $allergy',
          body: 'Do not take this medicine without speaking to a doctor or pharmacist first.',
        );
      }
    }
    final isNsaid = '${m.type} $name'.toLowerCase().contains('nsaid') ||
        ['ibuprofen', 'naproxen', 'aspirin', 'diclofenac'].any(name.contains);
    if (isNsaid && conditions.any((c) => c.toLowerCase().contains('asthma'))) {
      return (
        title: 'Caution: you have asthma',
        body: 'NSAIDs can trigger wheezing in some people with asthma. Paracetamol is usually a safer first choice.',
      );
    }
    if (isNsaid &&
        conditions.any((c) => c.toLowerCase().contains('ulcer') || c.toLowerCase().contains('kidney'))) {
      return (
        title: 'Caution: check with a pharmacist',
        body: 'NSAIDs can worsen stomach ulcers and kidney problems. Ask before taking this medicine.',
      );
    }
    return null;
  }

  String get _shortClass {
    final t = m.type;
    final paren = RegExp(r'\(([^)]+)\)').firstMatch(t);
    if (paren != null && paren.group(1)!.length <= 14) return paren.group(1)!;
    final first = t.split(RegExp(r'[&,(]')).first.trim();
    return first.length > 28 ? '${first.substring(0, 26)}…' : first;
  }

  void _askAi() {
    askVitaNetAi(
      context,
      'Is ${m.name} (${m.type}) safe for me to take? Please consider my health profile, '
      'my current medicines and any allergies, and tell me the usual adult dose.',
    );
  }

  Future<void> _share() async {
    final dose = _adultDose;
    try {
      await Share.share(
        '${m.name} (${m.type})\n${m.description}${dose != null ? '\nTypical adult dose: $dose' : ''}\n'
        'Source: ${m.isFdaApproved ? 'FDA label' : 'VitaNet catalog'} via VitaNet',
        subject: m.name,
      );
    } catch (_) {}
  }

  void _openVideo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          video: HealthVideo(
            videoId: m.relatedVideoId!,
            title: 'How to safely take ${m.name}',
            summary: 'Clinical guidance on dosage, administration, and adverse event warnings.',
            duration: '',
            category: 'Medication Guide',
            organization: 'VitaNet Clinical Pharmacology',
            thumbnailUrl: 'https://img.youtube.com/vi/${m.relatedVideoId}/hqdefault.jpg',
            keySteps: const [],
            verificationStatus: 'Verified Pharmacist Guide',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final profile = ref.watch(userProfileProvider);
    final caution = _caution(profile?.preExistingConditions ?? const [], profile?.allergies ?? const []);
    final displayName = DrugSynonymMapper.formatDisplayTitle(m.name, m.type);
    final brands = [
      if (m.brandName != null && m.brandName!.isNotEmpty && m.brandName!.toLowerCase() != m.name.toLowerCase())
        'Brands: ${m.brandName}',
      if (m.genericName != null && m.genericName!.isNotEmpty && m.genericName!.toLowerCase() != m.name.toLowerCase())
        'Generic: ${m.genericName}',
      'Source: ${m.isFdaApproved ? 'FDA label' : 'VitaNet verified catalog'}',
    ].join(' · ');
    final stats = <(String, String)>[
      if (_adultDose != null) ('Adult dose', _adultDose!),
      if (_frequency != null) ('How often', _frequency!),
      if (_maxDaily != null) ('Max a day', _maxDaily!),
    ];
    final sections = _sectionsForTab;
    final avoid = _dontTakeWith;

    return vnReadableWidth(Scaffold(
      backgroundColor: p.page,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) => handleScrollNotification(n, ref),
        child: CustomScrollView(
          physics: const VnAlwaysScrollablePhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  _buildHeroSection(context, p),
                  // The sheet's rounded top lip. Drawn here because the
                  // viewport paints earlier slivers above later ones, which
                  // hid a translated sheet behind the photo.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 24,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.page,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 16,
                    left: 16,
                    child: VnIconButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Back',
                      iconSize: 26,
                      background: p.isDark ? const Color(0xFF1E293B) : Colors.white,
                      foreground: p.ink,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 16,
                    right: 16,
                    child: VnIconButton(
                      icon: Icons.ios_share_rounded,
                      tooltip: 'Share medicine summary',
                      background: p.isDark ? const Color(0xFF1E293B) : Colors.white,
                      foreground: p.ink,
                      onPressed: _share,
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                  color: p.page,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (m.isHomeopathic)
                            const VnTag(label: 'Homeopathic / unverified', bg: Color(0xFFF1F5F9), fg: Color(0xFF475569))
                          else if (m.isRx)
                            const VnTag(label: 'Prescription', bg: Color(0xFFFEF3C7), fg: Color(0xFF92400E))
                          else
                            const VnTag(label: 'Over the counter', bg: Color(0xFFD1FAE5), fg: Color(0xFF065F46)),
                          if (_shortClass.isNotEmpty)
                            VnTag(label: _shortClass, bg: const Color(0xFFF1F5F9), fg: const Color(0xFF475569)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Semantics(header: true, child: Text(displayName, style: VnText.heading(28, color: p.ink))),
                      const SizedBox(height: 6),
                      Text(brands, style: VnText.body(14, color: p.muted)),
                      if (caution != null) ...[
                        const SizedBox(height: 16),
                        _CautionCard(title: caution.title, body: caution.body),
                      ],
                      if (stats.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < stats.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(child: _StatTile(label: stats[i].$1, value: stats[i].$2)),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      _Tabs(index: _tab, onChanged: (i) => setState(() => _tab = i)),
                      const SizedBox(height: 16),
                      if (_tab == 0) ...[
                        _Section(title: 'Used for', body: m.description),
                        const SizedBox(height: 16),
                      ],
                      if (sections.isEmpty && _tab != 0)
                        Text(
                          _tab == 1
                              ? 'No side effects are listed in this label. Read the leaflet in the pack and ask a pharmacist if you notice anything unusual.'
                              : 'No interaction warnings are listed in this label. Always tell your pharmacist about other medicines you take.',
                          style: VnText.body(14, color: p.inkSoft, height: 1.6),
                        ),
                      for (final s in sections) ...[
                        _Section(title: s.title, body: s.content),
                        const SizedBox(height: 16),
                      ],
                      if (_tab == 2 && avoid.isNotEmpty) ...[
                        Text("Don't take with", style: VnText.heading(16, weight: FontWeight.w700, color: p.ink)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final a in avoid)
                              VnTag(
                                label: a,
                                bg: const Color(0xFFFFF7ED),
                                fg: const Color(0xFF9A3412),
                                fontSize: 13,
                                weight: FontWeight.w600,
                                radius: 10,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (m.relatedVideoId != null) ...[
                        VnListGroup(
                          children: [
                            VnListRow(
                              leading: VnIconTile(
                                icon: Icons.play_arrow_rounded,
                                bg: const Color(0xFFCCFBF1),
                                fg: const Color(0xFF0F766E),
                              ),
                              title: 'Pharmacist video explainer',
                              subtitle: 'Safe use and dosage of ${m.name}',
                              onTap: _openVideo,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 6),
                      VnButton(
                        label: "Ask AI if it's safe for me",
                        icon: Icons.auto_awesome_rounded,
                        height: 54,
                        fontSize: 15,
                        onPressed: _askAi,
                      ),
                      const SizedBox(height: 12),
                      VnOutlineButton(
                        label: 'Find a pharmacy nearby',
                        icon: Icons.location_on_outlined,
                        borderColor: p.brand,
                        foreground: p.brand,
                        onPressed: () => Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (_) => const PharmacyScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
            ),
          ],
        ),
      ),
    ), maxWidth: 900, background: p.page);
  }

  /// Full-bleed photo hero as designed. The official DailyMed packaging scan
  /// is a flattened carton with die-lines, so it sits in a framed inset
  /// (tap to enlarge) rather than filling the hero.
  Widget _buildHeroSection(BuildContext context, VnPalette p) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final packaging = _heroImageUrl;
    return SizedBox(
      height: 240 + topPadding,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/photos/blister_packs.jpg',
            fit: BoxFit.cover,
            semanticLabel: 'Blister packs of tablets',
            errorBuilder: (_, _, _) => ColoredBox(color: p.surfaceAlt),
          ),
          if (packaging != null && packaging.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 40,
              child: _PackagingInset(url: packaging),
            ),
        ],
      ),
    );
  }
}

class _PackagingInset extends StatelessWidget {
  final String url;
  const _PackagingInset({required this.url});

  void _enlarge(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: VnIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                size: 40,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      button: true,
      label: 'Official FDA packaging photo. Tap to enlarge',
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        elevation: 4,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _enlarge(context),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 64,
                  color: Colors.white,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.inventory_2_outlined, color: p.muted),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 12, color: p.brand),
                    const SizedBox(width: 3),
                    Text('FDA packaging',
                        style: VnText.body(10, weight: FontWeight.w700, color: p.inkSoft)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CautionCard extends StatelessWidget {
  final String title;
  final String body;
  const _CautionCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.isDark ? const Color(0xFF2A1212) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.isDark ? const Color(0xFF5B1D1D) : const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded, size: 20, color: p.danger),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: VnText.body(14,
                        weight: FontWeight.w700,
                        color: p.isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))),
                const SizedBox(height: 2),
                Text(body,
                    style: VnText.body(13,
                        color: p.isDark ? const Color(0xFFFECACA) : const Color(0xFF7F1D1D), height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: VnText.body(11, weight: FontWeight.w600, color: p.muted)),
          const SizedBox(height: 2),
          Text(value, style: VnText.body(16, weight: FontWeight.w800, color: p.ink)),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    const labels = ['Overview', 'Side effects', 'Interactions'];
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Semantics(
              selected: i == index,
              button: true,
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: i == index ? p.brand : Colors.transparent, width: 3),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: VnText.body(14,
                        weight: i == index ? FontWeight.w700 : FontWeight.w600,
                        color: i == index ? p.brand : p.muted),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: VnText.heading(16, weight: FontWeight.w700, color: p.ink))),
        const SizedBox(height: 8),
        Text(body,
            style: VnText.body(14, color: p.isDark ? p.inkSoft : const Color(0xFF334155), height: 1.6)),
      ],
    );
  }
}
