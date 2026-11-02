import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/data/services/drug_synonyms.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';
import '../models/medicine.dart';
import '../widgets/resource_media.dart';
import 'medicine_detail_screen.dart';

/// Medicine directory: search by brand or generic name across the local
/// verified catalog and live openFDA labels, filtered by therapeutic class.
class MedicineSearchScreen extends ConsumerStatefulWidget {
  const MedicineSearchScreen({super.key});

  @override
  ConsumerState<MedicineSearchScreen> createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends ConsumerState<MedicineSearchScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Medicine> _searchResults = [];
  bool _isLoading = true;
  bool _isSearchingLive = false;
  bool _showScrollToTop = false;
  Timer? _debounce;
  late AnimationController _shimmerController;

  /// Display label -> MedicineCategoryQueries key.
  static const _classes = <(String, String)>[
    ('All', 'All'),
    ('Pain & fever', 'Pain & Fever'),
    ('Antibiotics', 'Antibiotics'),
    ('Heart & BP', 'Cardiovascular'),
    ('Allergy & asthma', 'Respiratory'),
    ('Mental health', 'Mental Health'),
    ('Stomach', 'Gastrointestinal'),
  ];

  String _selectedClass = 'All';

  static const _iconPalette = <List<Color>>[
    [Color(0xFFE0F2FE), Color(0xFF0369A1)],
    [Color(0xFFFFE4E6), Color(0xFFBE123C)],
    [Color(0xFFFEF3C7), Color(0xFFB45309)],
    [Color(0xFFD1FAE5), Color(0xFF047857)],
    [Color(0xFFEDE9FE), Color(0xFF6D28D9)],
    [Color(0xFFE0E7FF), Color(0xFF4338CA)],
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _scrollController.addListener(_onScroll);
    _loadInitialMedicines();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 400;
    if (show != _showScrollToTop) setState(() => _showScrollToTop = show);
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  /// Loads the verified essential medicines instantly, then hydrates openFDA.
  Future<void> _loadInitialMedicines() async {
    final service = ref.read(dynamicResourcesServiceProvider);
    final defaultMeds = await service.getDefaultMedicines();
    if (mounted) {
      setState(() {
        _searchResults = defaultMeds;
        _isLoading = defaultMeds.isEmpty;
      });
    }
    _hydrateFdaLive();
  }

  Future<void> _hydrateFdaLive() async {
    if (!mounted) return;
    setState(() => _isSearchingLive = true);
    try {
      final service = ref.read(dynamicResourcesServiceProvider);
      final liveMeds = await service.fetchMedicinesForCategory('All');
      if (mounted && liveMeds.isNotEmpty && _searchQuery.isEmpty && _selectedClass == 'All') {
        setState(() => _searchResults = liveMeds);
      }
    } catch (e) {
      debugPrint('Background openFDA hydration exception: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingLive = false;
          _isLoading = false;
        });
      }
    }
  }

  void _onCategorySelected(String cls) {
    if (_selectedClass == cls) return;
    setState(() {
      _selectedClass = cls;
      _isLoading = true;
    });
    final service = ref.read(dynamicResourcesServiceProvider);
    if (_searchQuery.trim().isEmpty) {
      service.getDefaultMedicines().then((allMeds) {
        if (!mounted || _selectedClass != cls) return;
        final filtered =
            cls == 'All' ? allMeds : allMeds.where((m) => MedicineCategoryQueries.matchesCategory(m, cls)).toList();
        setState(() {
          _searchResults = filtered;
          _isLoading = filtered.isEmpty;
        });
      });
      _hydrateCategoryFromFda(cls);
    } else {
      _onSearchChanged(_searchQuery);
    }
  }

  Future<void> _hydrateCategoryFromFda(String category) async {
    if (!mounted) return;
    setState(() => _isSearchingLive = true);
    try {
      final service = ref.read(dynamicResourcesServiceProvider);
      final liveResults = await service.fetchMedicinesForCategory(category);
      if (mounted && _selectedClass == category && _searchQuery.isEmpty) {
        setState(() => _searchResults = liveResults);
      }
    } catch (e) {
      debugPrint('openFDA category hydration error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingLive = false;
          _isLoading = false;
        });
      }
    }
  }

  /// 400ms debounce on search input to avoid openFDA rate limiting.
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    setState(() {
      _searchQuery = query;
      _isLoading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      final service = ref.read(dynamicResourcesServiceProvider);
      final results = await service.searchMedicines(query, category: _selectedClass);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
          _isSearchingLive = false;
        });
      }
    });
  }

  void _askInteractions(List<String> myMeds) {
    final prompt = myMeds.isEmpty
        ? 'Can you help me check whether my medicines interact with each other? I will list them.'
        : 'I take ${myMeds.join(', ')}. Are there any interactions or clashes I should know about, '
            'and what should I avoid taking with them?';
    askVitaNetAi(context, prompt);
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final displayed = _searchResults;
    final showSkeleton = (_isLoading || _isSearchingLive) && displayed.isEmpty;
    final myMeds = ref.watch(userProfileProvider)?.medications ?? const <String>[];

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => handleScrollNotification(n, ref),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: VnTopBar(
                    title: 'Medicines',
                    actions: [_InteractionsPill(onTap: () => _askInteractions(myMeds))],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(child: _buildSearchField(p)),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: VnChipRow(
                    children: [
                      for (final c in _classes)
                        VnChip(
                          label: c.$1,
                          selected: _selectedClass == c.$2,
                          height: 36,
                          fontSize: 13,
                          onTap: () => _onCategorySelected(c.$2),
                        ),
                    ],
                  ),
                ),
              ),
              if (myMeds.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _YourMedicinesCard(meds: myMeds, onTap: () => _askInteractions(myMeds)),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                sliver: SliverToBoxAdapter(child: _buildStatusRow(p, displayed, showSkeleton)),
              ),
              if (showSkeleton)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: 6,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, _) => _buildSkeletonItem(p),
                  ),
                )
              else if (_searchQuery.trim().isNotEmpty && displayed.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState(p))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList.separated(
                    itemCount: displayed.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final med = displayed[index];
                      final colors = _iconPalette[index % _iconPalette.length];
                      return _MedicineRow(
                        medicine: med,
                        bg: colors[0],
                        fg: colors[1],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MedicineDetailScreen(medicine: med)),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              onPressed: _scrollToTop,
              backgroundColor: p.brand,
              foregroundColor: p.onBrand,
              tooltip: 'Scroll to top',
              child: const Icon(Icons.arrow_upward_rounded, size: 18),
            )
          : null,
    );
  }

  Widget _buildSearchField(VnPalette p) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: p.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: VnText.body(15, color: p.ink),
              decoration: InputDecoration(
                hintText: 'Search by brand or generic name',
                hintStyle: VnText.body(15, color: p.muted),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            VnIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Clear search',
              iconSize: 18,
              foreground: p.muted,
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(VnPalette p, List<Medicine> displayed, bool showSkeleton) {
    final label = _searchQuery.trim().isNotEmpty
        ? 'Results for "${_searchQuery.trim()}"'
        : (_selectedClass == 'All'
            ? 'Most searched'
            : _classes.firstWhere((c) => c.$2 == _selectedClass, orElse: () => ('All', 'All')).$1);
    return Row(
      children: [
        Expanded(child: VnSectionLabel(label, padding: EdgeInsets.zero)),
        if (_isSearchingLive)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: p.brand)),
              const SizedBox(width: 6),
              Text('Checking openFDA', style: VnText.body(12, weight: FontWeight.w600, color: p.brand)),
            ],
          )
        else if (!showSkeleton && displayed.isNotEmpty)
          Text('${displayed.length} found', style: VnText.body(12, color: p.muted)),
      ],
    );
  }

  Widget _buildSkeletonItem(VnPalette p) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final base = Color.lerp(p.surfaceAlt, p.line, _shimmerController.value)!;
        return Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 140, height: 14, color: base),
                    const SizedBox(height: 6),
                    Container(width: 190, height: 11, color: base),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(VnPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          Icon(Icons.medication_outlined, size: 44, color: p.faint),
          const SizedBox(height: 12),
          Text(
            'No medicines match "$_searchQuery"',
            textAlign: TextAlign.center,
            style: VnText.heading(16, weight: FontWeight.w700, color: p.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a brand name or the generic ingredient (for example Paracetamol or Ibuprofen), or pick a group above.',
            textAlign: TextAlign.center,
            style: VnText.body(13, color: p.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _InteractionsPill extends StatelessWidget {
  final VoidCallback onTap;
  const _InteractionsPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    const fg = Color(0xFF6D28D9);
    return Semantics(
      button: true,
      label: 'Check interactions with VitaNet AI',
      excludeSemantics: true,
      child: Material(
        color: p.tintBg(const Color(0xFFF5F3FF), fg),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: p.tintFg(fg)),
                const SizedBox(width: 6),
                Text('Interactions', style: VnText.body(13, weight: FontWeight.w700, color: p.tintFg(fg))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YourMedicinesCard extends StatelessWidget {
  final List<String> meds;
  final VoidCallback onTap;
  const _YourMedicinesCard({required this.meds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    const ai = Color(0xFF6D28D9);
    return VnCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.all(14),
      color: p.tintBg(const Color(0xFFF5F3FF), ai),
      borderColor: p.isDark ? ai.withValues(alpha: 0.4) : const Color(0xFFDDD6FE),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: ai, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.medication_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your medicines', style: VnText.body(14, weight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 2),
                Text(
                  '${meds.join(', ')} · tap to check for clashes',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VnText.body(13, color: p.isDark ? const Color(0xFFC4B5FD) : const Color(0xFF5B21B6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineRow extends StatelessWidget {
  final Medicine medicine;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _MedicineRow({required this.medicine, required this.bg, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final name = DrugSynonymMapper.formatDisplayTitle(medicine.name, medicine.type);
    final sub = [
      medicine.type,
      if (medicine.route.isNotEmpty && medicine.route != 'ORAL') medicine.route.toLowerCase(),
    ].where((s) => s.isNotEmpty).join(' · ');
    return VnCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      semanticLabel: '$name. $sub. ${medicine.isRx ? 'Prescription' : 'Over the counter'}',
      child: Row(
        children: [
          VnIconTile(icon: Icons.medication_rounded, bg: bg, fg: fg, size: 44, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VnText.body(15, weight: FontWeight.w700, color: p.ink)),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: VnText.body(13, color: p.muted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (medicine.isHomeopathic)
            const VnTag(label: 'Unverified', bg: Color(0xFFF1F5F9), fg: Color(0xFF64748B))
          else if (medicine.isRx)
            const VnTag(label: 'Prescription', bg: Color(0xFFFEF3C7), fg: Color(0xFF92400E))
          else
            const VnTag(label: 'Over the counter', bg: Color(0xFFD1FAE5), fg: Color(0xFF065F46)),
        ],
      ),
    );
  }
}
