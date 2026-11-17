import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';
import '../models/health_article.dart';
import '../services/health_library_service.dart';
import '../widgets/resource_media.dart';
import 'health_article_detail_screen.dart';

/// Clean alias for backward compatibility across navigation routes
typedef GeneralHealthLibraryScreen = HealthLibraryScreen;

/// Photo for an article: its own picture (from the source, or a Pexels photo the backend chose for it) when it
/// has one. Otherwise a bundled photo: a specific one when the title matches (e.g. ECG), else one picked from
/// a small set for the article's topic by its title, so articles in the same topic do not all look the same.
({String asset, String url}) articlePhoto(HealthArticle a) {
  final directUrl = a.imageUrls.isNotEmpty ? a.imageUrls.first : '';
  // Bucketed Unsplash IDs from MedicalImageResolver are guesses (a beach for a Tai Chi study; some 404 and
  // render blank), so they are not used. Real article images from other hosts are.
  final useDirect = directUrl.isNotEmpty && !directUrl.contains('images.unsplash.com');
  return (asset: fallbackPhotoFor(a.title, a.category), url: useDirect ? directUrl : '');
}

/// Bundled photos per library topic (the backend's topic names).
const Map<String, List<String>> _topicPhotos = {
  'Infections': [VnPhotos.vaccination, VnPhotos.doctorWithPatient, VnPhotos.clinicalExamination,
      VnPhotos.stethoscopeDiagnostics, VnPhotos.pillsColorful, VnPhotos.doctorOnPhone],
  'Heart': [VnPhotos.bloodPressureCheck, VnPhotos.bpCuff, VnPhotos.cardiologyEcg, VnPhotos.smartwatchWrist,
      VnPhotos.stethoscopeDiagnostics],
  'Breathing': [VnPhotos.respiratoryHealth, VnPhotos.stethoscopeDiagnostics, VnPhotos.xray, VnPhotos.doctorWithPatient],
  'Mental health': [VnPhotos.meditation, VnPhotos.holdingHands, VnPhotos.mindfulnessWellness, VnPhotos.sleep,
      VnPhotos.doctorOnPhone],
  'Nutrition': [VnPhotos.healthyPlate, VnPhotos.saladBowl, VnPhotos.metabolicNutrition, VnPhotos.glucoseMonitoring],
  'Women & children': [VnPhotos.doctorsWithChild, VnPhotos.clinicianFemale, VnPhotos.vaccination, VnPhotos.holdingHands],
  'Fitness': [VnPhotos.workout, VnPhotos.fitnessVitality, VnPhotos.smartwatchWrist],
  'Chronic conditions': [VnPhotos.glucoseMonitoring, VnPhotos.bloodPressureCheck, VnPhotos.pillsOrange,
      VnPhotos.blisterPacks, VnPhotos.doctorWithPatient, VnPhotos.clinicalExamination],
  'First aid & safety': [VnPhotos.firstAidKit, VnPhotos.bandageTherapy, VnPhotos.cprResuscitation, VnPhotos.medicalTeam],
  'General health': [VnPhotos.laptopStethoscope, VnPhotos.doctorPortrait, VnPhotos.medicalTeam, VnPhotos.digitalHealth,
      VnPhotos.physicianMale, VnPhotos.clinicianFemale],
};

/// A stable pick from the topic's set (same article -> same photo every time).
String fallbackPhotoFor(String title, String category) {
  final pool = _topicPhotos[category];
  if (pool == null) return VnTopics.photoForArticle(title, category); // older built-in articles
  final specific = VnTopics.classify(title);
  if (specific != null && specific.refinements.isNotEmpty) {
    final refined = specific.photoFor(title);
    if (refined != specific.photo) return refined; // a title-specific photo (ECG, smartwatch, salad, ...)
  }
  var h = 0;
  for (final c in title.toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return pool[h % pool.length];
}

/// Health library: plain-language articles from MedlinePlus and MyHealthfinder (collected by the VitaNet
/// backend), with topic chips, search (any condition, via MedlinePlus) and bookmarks.
class HealthLibraryScreen extends ConsumerStatefulWidget {
  const HealthLibraryScreen({super.key});

  @override
  ConsumerState<HealthLibraryScreen> createState() => _HealthLibraryScreenState();
}

class _HealthLibraryScreenState extends ConsumerState<HealthLibraryScreen> {
  String _selectedCategory = 'For you';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _searchOpen = false;

  List<HealthArticle> _articles = [];
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int? _nextCursor = 0;
  String _activeSearchQuery = '';

  final Set<String> _bookmarkedIds = {};

  final _library = HealthLibraryService();
  int _loadToken = 0; // a newer load (topic / search change) makes older answers stale
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialFeed();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Feed fetching & cursor pagination ─────────────────────────────────────

  Future<LibraryPage> _fetch(int cursor) => _activeSearchQuery.isNotEmpty
      ? _library.search(_activeSearchQuery, cursor: cursor)
      : _library.feed(topic: _selectedCategory, cursor: cursor);

  Future<void> _loadInitialFeed({bool isRefresh = false}) async {
    if (!mounted) return;
    if (!isRefresh) {
      setState(() {
        _isLoadingInitial = true;
        _nextCursor = 0;
        _hasMore = true;
      });
    }
    final token = ++_loadToken;
    final page = await _fetch(0);
    if (!mounted || token != _loadToken) return;
    setState(() {
      _articles = List.of(page.articles);
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      _isLoadingInitial = false;
      _isLoadingMore = false;
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 500 && !_isLoadingMore && !_isLoadingInitial && _hasMore) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    final cursor = _nextCursor;
    if (cursor == null || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final token = _loadToken;
    final page = await _fetch(cursor);
    if (!mounted || token != _loadToken) return;
    final known = _articles.map((a) => a.id).toSet();
    setState(() {
      _articles.addAll(page.articles.where((a) => known.add(a.id)));
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      _isLoadingMore = false;
    });
  }

  Future<void> _onPullToRefresh() async {
    await _loadInitialFeed(isRefresh: true);
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _activeSearchQuery = value.trim();
        _nextCursor = 0;
        _hasMore = true;
      });
      _loadInitialFeed();
    });
  }

  void _onCategorySelected(String category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
      _nextCursor = 0;
      _hasMore = true;
    });
    _loadInitialFeed();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen && _searchController.text.isNotEmpty) {
      _searchController.clear();
      _onSearchChanged('');
    }
  }

  void _toggleBookmark(HealthArticle article) {
    final added = !_bookmarkedIds.contains(article.id);
    setState(() => added ? _bookmarkedIds.add(article.id) : _bookmarkedIds.remove(article.id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(added ? 'Saved to bookmarks' : 'Removed from bookmarks'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _openArticle(HealthArticle article) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HealthArticleDetailScreen(article: article)));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return vnReadableWidth(Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => handleScrollNotification(n, ref),
          child: RefreshIndicator(
            color: p.brand,
            onRefresh: _onPullToRefresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const VnAlwaysScrollablePhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: VnTopBar(
                      title: 'Health library',
                      actions: [
                        VnIconButton(
                          icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                          tooltip: _searchOpen ? 'Close search' : 'Search',
                          bordered: true,
                          onPressed: _toggleSearch,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_searchOpen)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    sliver: SliverToBoxAdapter(child: _buildSearchField(p)),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: VnChipRow(
                      children: [
                        for (final c in HealthLibraryService.topics)
                          VnInkChip(
                            label: c,
                            selected: _selectedCategory == c,
                            onTap: () => _onCategorySelected(c),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_isLoadingInitial)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    sliver: SliverToBoxAdapter(child: _buildSkeleton(p)),
                  )
                else if (_articles.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState(p))
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _FeaturedCard(article: _articles.first, onTap: () => _openArticle(_articles.first)),
                    ),
                  ),
                  if (_articles.length > 1)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
                      sliver: SliverToBoxAdapter(child: VnSectionLabel('Latest', padding: EdgeInsets.zero)),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: _articles.length - 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final a = _articles[i + 1];
                        return RepaintBoundary(
                          child: _ArticleRow(
                            article: a,
                            bookmarked: _bookmarkedIds.contains(a.id),
                            onTap: () => _openArticle(a),
                            onBookmark: () => _toggleBookmark(a),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_hasMore) SliverToBoxAdapter(child: _buildBottomLoader(p)),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
        ),
      ),
    ), maxWidth: 1000, background: p.page);
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
              autofocus: true,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: VnText.body(15, color: p.ink),
              decoration: InputDecoration(
                hintText: 'Search studies and topics',
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
        ],
      ),
    );
  }

  Widget _buildBottomLoader(VnPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.brand)),
          const SizedBox(width: 10),
          Text('Loading more studies', style: VnText.body(12, weight: FontWeight.w500, color: p.muted)),
        ],
      ),
    );
  }

  Widget _buildSkeleton(VnPalette p) {
    Widget box(double h, {double? w, double r = 8}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(r)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        box(300, r: 22),
        const SizedBox(height: 18),
        for (var i = 0; i < 3; i++) ...[
          Row(
            children: [
              box(92, w: 92, r: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [box(12, w: 80), const SizedBox(height: 8), box(15), const SizedBox(height: 6), box(12, w: 140)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildEmptyState(VnPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 44, color: p.faint),
          const SizedBox(height: 12),
          Text('No articles found',
              textAlign: TextAlign.center, style: VnText.heading(16, weight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 6),
          Text('Try another topic or search term.',
              textAlign: TextAlign.center, style: VnText.body(13, color: p.muted)),
        ],
      ),
    );
  }
}

String _verifiedLabel(HealthArticle a) {
  final s = a.verifiedSource.toLowerCase();
  if (s.contains('medlineplus')) return 'MedlinePlus';
  if (s.contains('myhealthfinder')) return 'health.gov';
  if (s.contains('pubmed')) return 'PubMed';
  if (s.contains('europe pmc') || s.contains('peer')) return 'Peer reviewed';
  return 'Verified';
}

/// "The Lancet • 2026" -> "The Lancet 2026"; drops the generic "Peer Reviewed" suffix.
/// Library articles show the short source name ("MedlinePlus", "MyHealthfinder") in lists.
String cleanArticleSource(HealthArticle a) => a.verifiedSource.contains(' · ')
    ? a.verifiedSource.split(' · ').first
    : a.verifiedSource
    .replaceAll(RegExp(r'\s*[•·â€¢]+\s*Peer Reviewed', caseSensitive: false), '')
    .replaceAll(RegExp(r'\s*[•·â€¢]+\s*'), ' ')
    .trim();

String _cleanSource(HealthArticle a) => cleanArticleSource(a);

String _minutes(HealthArticle a) => a.readTime.replaceAll(' read', '');

class _FeaturedCard extends StatelessWidget {
  final HealthArticle article;
  final VoidCallback onTap;
  const _FeaturedCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final photo = articlePhoto(article);
    return VnCard(
      onTap: onTap,
      radius: 22,
      padding: EdgeInsets.zero,
      semanticLabel: 'Featured: ${article.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VnNetworkPhoto(
                  url: photo.url,
                  fallbackAsset: photo.asset,
                  alignment: const Alignment(0, -0.2),
                  cacheWidth: 900,
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Text('FEATURED',
                        style: VnText.body(11,
                            weight: FontWeight.w800, color: const Color(0xFF0F766E), letterSpacing: 0.4)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.category, style: VnText.body(12, weight: FontWeight.w700, color: p.brand)),
                const SizedBox(height: 8),
                Text(article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: VnText.heading(19, color: p.ink, height: 1.3)),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text('${_cleanSource(article)} · ${article.readTime} ·',
                        style: VnText.body(12, color: p.muted)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 14,
                            color: p.isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)),
                        const SizedBox(width: 4),
                        Text(_verifiedLabel(article),
                            style: VnText.body(12,
                                weight: FontWeight.w600,
                                color: p.isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))),
                      ],
                    ),
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

class _ArticleRow extends StatelessWidget {
  final HealthArticle article;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  const _ArticleRow({
    required this.article,
    required this.bookmarked,
    required this.onTap,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final photo = articlePhoto(article);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 92,
              height: 92,
              child: VnNetworkPhoto(url: photo.url, fallbackAsset: photo.asset, cacheWidth: 300),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.category, style: VnText.body(12, weight: FontWeight.w700, color: p.brand)),
                const SizedBox(height: 4),
                Text(article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: VnText.body(15, weight: FontWeight.w700, color: p.ink, height: 1.35)),
                const SizedBox(height: 4),
                Text('${_minutes(article)} · ${_cleanSource(article)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: VnText.body(12, color: p.muted)),
              ],
            ),
          ),
          VnIconButton(
            icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            tooltip: bookmarked ? 'Remove bookmark' : 'Save article',
            iconSize: 20,
            foreground: bookmarked ? p.brand : p.faint,
            onPressed: onBookmark,
          ),
        ],
      ),
    );
  }
}
