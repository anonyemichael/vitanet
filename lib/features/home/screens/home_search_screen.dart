import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/home/widgets/filter_bottom_sheet.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class _SearchItem {
  final String title;
  final String subtitle;
  final SearchContentType type;
  final String? image;
  final IconData icon;
  final Color bg;
  final Color fg;
  final String route;
  final List<String> keywords;
  final String? area;
  final bool reviewed;
  final DateTime? date;

  const _SearchItem({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.route,
    this.image,
    this.icon = Icons.article_outlined,
    this.bg = const Color(0xFFCCFBF1),
    this.fg = const Color(0xFF0F766E),
    this.keywords = const [],
    this.area,
    this.reviewed = true,
    this.date,
  });
}

const _catalog = <_SearchItem>[
  _SearchItem(
    title: 'Tension headache vs migraine',
    subtitle: 'Article · 6 min read',
    type: SearchContentType.articles,
    image: 'assets/images/photos/meditation.jpg',
    route: '/resources/health-library',
    keywords: ['headache', 'migraine', 'pain', 'head'],
    area: 'Head',
  ),
  _SearchItem(
    title: 'Understanding blood pressure readings',
    subtitle: 'Article · 5 min read',
    type: SearchContentType.articles,
    image: 'assets/images/photos/blood_pressure_check.jpg',
    route: '/resources/health-library',
    keywords: ['blood pressure', 'hypertension', 'bp', 'heart'],
    area: 'Chest',
  ),
  _SearchItem(
    title: 'Sleep and your heart health',
    subtitle: 'Article · 4 min read',
    type: SearchContentType.articles,
    image: 'assets/images/photos/sleep.jpg',
    route: '/resources/health-library',
    keywords: ['sleep', 'insomnia', 'tired', 'fatigue'],
    area: 'Mental',
  ),
  _SearchItem(
    title: 'Eating for steady energy',
    subtitle: 'Article · 5 min read',
    type: SearchContentType.articles,
    image: 'assets/images/photos/healthy_plate.jpg',
    route: '/resources/health-library',
    keywords: ['diet', 'nutrition', 'food', 'stomach', 'diabetes'],
    area: 'Stomach',
  ),
  _SearchItem(
    title: 'Paracetamol 500 mg',
    subtitle: 'Medicine · Pain and fever relief',
    type: SearchContentType.medicines,
    icon: Icons.medication_outlined,
    bg: Color(0xFFEDE9FE),
    fg: Color(0xFF6D28D9),
    route: '/resources/medicines',
    keywords: ['paracetamol', 'acetaminophen', 'headache', 'fever', 'pain'],
    area: 'Head',
  ),
  _SearchItem(
    title: 'Ibuprofen 200 mg',
    subtitle: 'Medicine · Anti-inflammatory',
    type: SearchContentType.medicines,
    icon: Icons.medication_outlined,
    bg: Color(0xFFEDE9FE),
    fg: Color(0xFF6D28D9),
    route: '/resources/medicines',
    keywords: ['ibuprofen', 'pain', 'joint', 'inflammation', 'headache'],
    area: 'Joints',
  ),
  _SearchItem(
    title: 'Amoxicillin 500 mg',
    subtitle: 'Medicine · Antibiotic',
    type: SearchContentType.medicines,
    icon: Icons.medication_outlined,
    bg: Color(0xFFEDE9FE),
    fg: Color(0xFF6D28D9),
    route: '/resources/medicines',
    keywords: ['amoxicillin', 'antibiotic', 'infection', 'throat'],
  ),
  _SearchItem(
    title: '5-minute breathing to ease tension',
    subtitle: 'Video · 5:12',
    type: SearchContentType.videos,
    image: 'assets/images/photos/meditation.jpg',
    route: '/resources/videos',
    keywords: ['breathing', 'stress', 'anxiety', 'headache', 'mental'],
    area: 'Mental',
  ),
  _SearchItem(
    title: 'Measuring blood pressure at home',
    subtitle: 'Video · 3:40',
    type: SearchContentType.videos,
    image: 'assets/images/photos/bp_cuff.jpg',
    route: '/resources/videos',
    keywords: ['blood pressure', 'bp', 'cuff', 'hypertension'],
    area: 'Chest',
  ),
  _SearchItem(
    title: 'CPR steps for adults',
    subtitle: 'First aid · 6 steps',
    type: SearchContentType.firstAid,
    icon: Icons.warning_amber_rounded,
    bg: Color(0xFFFFEDD5),
    fg: Color(0xFFC2410C),
    route: '/first-aid',
    keywords: ['cpr', 'cardiac', 'heart attack', 'unconscious', 'chest'],
    area: 'Chest',
  ),
  _SearchItem(
    title: 'Burns and scalds',
    subtitle: 'First aid · 5 steps',
    type: SearchContentType.firstAid,
    icon: Icons.warning_amber_rounded,
    bg: Color(0xFFFFEDD5),
    fg: Color(0xFFC2410C),
    route: '/first-aid',
    keywords: ['burn', 'scald', 'skin'],
    area: 'Skin',
  ),
  _SearchItem(
    title: 'Choking',
    subtitle: 'First aid · back blows and thrusts',
    type: SearchContentType.firstAid,
    icon: Icons.warning_amber_rounded,
    bg: Color(0xFFFFEDD5),
    fg: Color(0xFFC2410C),
    route: '/first-aid',
    keywords: ['choking', 'airway', 'breathing'],
    area: 'Chest',
  ),
];

class HomeSearchScreen extends ConsumerStatefulWidget {
  const HomeSearchScreen({super.key});

  @override
  ConsumerState<HomeSearchScreen> createState() => _HomeSearchScreenState();
}

class _HomeSearchScreenState extends ConsumerState<HomeSearchScreen> {
  static const _recentKey = 'home_recent_searches';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  SearchFilters _filters = const SearchFilters();
  SearchContentType? _quickType;
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _recent = prefs.getStringList(_recentKey) ?? []);
    } catch (_) {}
  }

  Future<void> _saveRecent(String q) async {
    q = q.trim();
    if (q.isEmpty) return;
    final list = [q, ..._recent.where((r) => r.toLowerCase() != q.toLowerCase())]
        .take(6)
        .toList();
    setState(() => _recent = list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentKey, list);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<_SearchItem> _historyItems(List<TriageResult> history) {
    const levelLabel = {
      TriageLevel.selfCare: 'Self-care',
      TriageLevel.pharmacist: 'Pharmacist',
      TriageLevel.doctor: 'See a doctor',
      TriageLevel.emergency: 'Urgent',
    };
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return [
      for (final h in history)
        _SearchItem(
          title: 'Your check: "${h.primarySymptom.isNotEmpty ? h.primarySymptom : 'Symptom check'}"',
          subtitle:
              'Past check · ${h.timestamp.day} ${months[h.timestamp.month - 1]} · ${levelLabel[h.level]}',
          type: SearchContentType.myChecks,
          icon: Icons.chat_bubble_outline_rounded,
          bg: const Color(0xFFFFEDD5),
          fg: const Color(0xFFC2410C),
          route: '/history',
          keywords: [h.primarySymptom, h.summary],
          reviewed: false,
          date: h.timestamp,
        ),
    ];
  }

  List<_SearchItem> _results(List<_SearchItem> all, SearchFilters f, {SearchContentType? quick}) {
    final q = _query.trim().toLowerCase();
    var list = all.where((i) {
      if (q.isNotEmpty) {
        final hay = '${i.title} ${i.subtitle} ${i.keywords.join(' ')}'.toLowerCase();
        if (!q.split(RegExp(r'\s+')).every(hay.contains)) return false;
      }
      if (f.types.isNotEmpty && !f.types.contains(i.type)) return false;
      if (quick != null && i.type != quick) return false;
      if (f.bodyArea != null && i.area != f.bodyArea) return false;
      if (f.sort == SearchSort.reviewed && !i.reviewed) return false;
      return true;
    }).toList();
    if (f.sort == SearchSort.newest) {
      list.sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
    }
    return list;
  }

  void _askAi(String prompt) {
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/chat');
    Future.delayed(const Duration(milliseconds: 450), () {
      container.read(searchActionProvider.notifier).state = prompt;
    });
  }

  void _open(_SearchItem item) {
    _saveRecent(_query);
    context.push(item.route);
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final history = ref.watch(triageHistoryProvider);
    final all = [..._catalog, ..._historyItems(history)];
    final results = _results(all, _filters, quick: _quickType);
    final allCount = _results(all, _filters).length;
    final hasQuery = _query.trim().isNotEmpty;

    Widget quickChip(String label, SearchContentType? t) => VnChip(
          label: label,
          height: 36,
          fontSize: 13,
          selected: _quickType == t,
          onTap: () => setState(() => _quickType = t),
        );

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Row(
                  children: [
                    VnIconButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Back',
                      iconSize: 26,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Hero(
                        tag: 'home_search_bar',
                        child: Material(
                          color: p.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: p.brand, width: 2),
                          ),
                          child: SizedBox(
                            height: 50,
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                Icon(Icons.search_rounded, size: 20, color: p.muted),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _focusNode,
                                    textInputAction: TextInputAction.search,
                                    onChanged: (v) => setState(() => _query = v),
                                    onSubmitted: _saveRecent,
                                    style: VnText.body(15, color: p.ink),
                                    decoration: InputDecoration(
                                      hintText: 'Search health, vitals, medicines…',
                                      hintStyle: VnText.body(15, color: p.faint),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (hasQuery)
                                  IconButton(
                                    tooltip: 'Clear search',
                                    icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  )
                                else
                                  const SizedBox(width: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    VnIconButton(
                      icon: Icons.tune_rounded,
                      tooltip: 'Filters',
                      size: 50,
                      radius: 16,
                      bordered: true,
                      background: _filters.isDefault ? null : p.brandTint,
                      foreground: _filters.isDefault ? null : p.brand,
                      onPressed: () async {
                        final f = await showFilterBottomSheet(
                          context,
                          initial: _filters,
                          countFor: (f) => _results(all, f).length,
                        );
                        if (f != null && mounted) setState(() => _filters = f);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    quickChip('All · $allCount', null),
                    quickChip('Symptoms', SearchContentType.articles),
                    quickChip('Medicines', SearchContentType.medicines),
                    quickChip('Videos', SearchContentType.videos),
                  ],
                ),
                if (hasQuery) ...[
                  const SizedBox(height: 22),
                  Material(
                    color: p.isDark ? const Color(0xFF241A3B) : const Color(0xFFF5F3FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                          color: p.isDark ? const Color(0xFF3B2A63) : const Color(0xFFDDD6FE)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        _saveRecent(_query);
                        _askAi(_query.trim());
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6D28D9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Ask VitaNet AI about "${_query.trim()}"',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: VnText.body(15, weight: FontWeight.w700, color: p.ink)),
                                  const SizedBox(height: 2),
                                  Text('Get a personalised triage in a chat',
                                      style: VnText.body(13,
                                          color: p.isDark
                                              ? const Color(0xFFC4B5FD)
                                              : const Color(0xFF5B21B6))),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: p.isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                VnSectionLabel(hasQuery ? 'Top results' : 'Browse', padding: EdgeInsets.zero),
                const SizedBox(height: 6),
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No matches. Try another word, clear filters, or ask VitaNet AI.',
                      style: VnText.body(14, color: p.muted),
                    ),
                  )
                else
                  for (var i = 0; i < results.length; i++)
                    _ResultRow(
                      item: results[i],
                      last: i == results.length - 1,
                      onTap: () => _open(results[i]),
                    ),
                if (_recent.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const VnSectionLabel('Recent searches', padding: EdgeInsets.zero),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in _recent)
                        ActionChip(
                          avatar: Icon(Icons.schedule_rounded, size: 14, color: p.inkSoft),
                          label: Text(r, style: VnText.body(13, color: p.inkSoft)),
                          backgroundColor: p.surfaceAlt,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          onPressed: () {
                            _searchController.text = r;
                            setState(() => _query = r);
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final _SearchItem item;
  final bool last;
  final VoidCallback onTap;
  const _ResultRow({required this.item, required this.last, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    Widget thumb;
    if (item.image != null) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.asset(item.image!, width: 56, height: 56, fit: BoxFit.cover),
            if (item.type == SearchContentType.videos)
              const Positioned.fill(
                child: Center(
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ),
          ],
        ),
      );
    } else {
      thumb = VnIconTile(icon: item.icon, bg: item.bg, fg: item.fg, size: 56, radius: 14, iconSize: 24);
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: p.line)),
        ),
        child: Row(
          children: [
            thumb,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: VnText.body(15, weight: FontWeight.w600, color: p.ink)),
                  const SizedBox(height: 3),
                  Text(item.subtitle, style: VnText.body(13, color: p.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
