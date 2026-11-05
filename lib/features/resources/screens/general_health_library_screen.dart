import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';
import '../models/health_article.dart';
import '../services/dynamic_feed_mixer.dart';
import '../services/europe_pmc_feed_service.dart';
import '../widgets/resource_media.dart';
import 'health_article_detail_screen.dart';

/// Clean alias for backward compatibility across navigation routes
typedef GeneralHealthLibraryScreen = HealthLibraryScreen;

/// Topic photo for an article. Uses curated/live image URL if available,
/// with the exact matching local clinical topic photo as instant 0ms fallback.
({String asset, String url}) articlePhoto(HealthArticle a) {
  final fallbackAsset = VnTopics.photoForArticle(a.title, a.category);
  final directUrl = a.imageUrls.isNotEmpty ? a.imageUrls.first : '';
  return (asset: fallbackAsset, url: directUrl);
}

/// Health library: Europe PMC live literature interleaved with curated
/// clinician-reviewed articles, with topic chips, search and bookmarks.
class HealthLibraryScreen extends ConsumerStatefulWidget {
  const HealthLibraryScreen({super.key});

  @override
  ConsumerState<HealthLibraryScreen> createState() => _HealthLibraryScreenState();
}

class _HealthLibraryScreenState extends ConsumerState<HealthLibraryScreen> {
  /// Chip label -> feed category / query understood by [DynamicFeedMixer].
  static const List<(String, String)> _categories = [
    ('For you', 'All'),
    ('Heart', 'Cardiology'),
    ('Breathing', 'TITLE:(asthma OR "lung function" OR respiratory OR breathing)'),
    ('Mental health', 'TITLE:("mental health" OR anxiety OR depression OR stress)'),
    ('Nutrition', 'Nutrition'),
    ('Sleep', 'Sleep'),
    ("Women's health", 'TITLE:("women\'s health" OR pregnancy OR menopause OR maternal)'),
    ('Fitness', 'Fitness'),
    ('Immunity', 'Immunology'),
  ];

  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _searchOpen = false;

  List<HealthArticle> _articles = [];
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _nextCursorMark = '*';
  String _activeSearchQuery = '';

  final Set<String> _bookmarkedIds = {};

  late final DynamicFeedMixer _feedMixer;
  http.Client? _activeClient;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _feedMixer = DynamicFeedMixer();
    _scrollController.addListener(_onScroll);
    _loadInitialFeed();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _activeClient?.close();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Feed fetching & cursor pagination ─────────────────────────────────────

  Future<void> _loadInitialFeed({bool isRefresh = false}) async {
    if (!mounted) return;
    if (!isRefresh) {
      setState(() {
        _isLoadingInitial = true;
        _nextCursorMark = '*';
        _hasMore = true;
      });
    }

    _activeClient?.close();
    final client = http.Client();
    _activeClient = client;

    final query = _feedMixer.buildQuery(selectedCategory: _selectedCategory, searchQuery: _activeSearchQuery);
    final service = EuropePmcFeedService(client: client);
    final page = await service.fetchFeedPage(query: query, cursorMark: '*', pageSize: 12);

    if (!mounted || client != _activeClient) return;

    final mixed = _feedMixer.interleaveFeed(liveArticles: page.articles, selectedCategory: _selectedCategory);
    setState(() {
      _articles = mixed;
      _nextCursorMark = page.nextCursorMark;
      _hasMore = page.hasMore && (page.nextCursorMark != null);
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
    if (_nextCursorMark == null || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final query = _feedMixer.buildQuery(selectedCategory: _selectedCategory, searchQuery: _activeSearchQuery);
    final service = EuropePmcFeedService(client: _activeClient ?? http.Client());
    final page = await service.fetchFeedPage(query: query, cursorMark: _nextCursorMark!, pageSize: 12);

    if (!mounted) return;
    if (page.articles.isEmpty) {
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
      return;
    }

    final currentIds = _articles.map((a) => a.id).toSet();
    final newUnique = page.articles.where((a) => !currentIds.contains(a.id)).toList();
    setState(() {
      _articles.addAll(newUnique);
      _hasMore = page.hasMore && (page.nextCursorMark != null && page.nextCursorMark != _nextCursorMark);
      _nextCursorMark = page.nextCursorMark;
      _isLoadingMore = false;
    });
  }

  Future<void> _onPullToRefresh() async {
    _feedMixer.reseed();
    await _loadInitialFeed(isRefresh: true);
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _activeSearchQuery = value.trim();
        _nextCursorMark = '*';
        _hasMore = true;
      });
      _loadInitialFeed();
    });
  }

  void _onCategorySelected(String category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
      _nextCursorMark = '*';
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
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
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
                        for (final c in _categories)
                          VnInkChip(
                            label: c.$1,
                            selected: _selectedCategory == c.$2,
                            onTap: () => _onCategorySelected(c.$2),
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
  if (s.contains('pubmed')) return 'PubMed';
  if (s.contains('europe pmc') || s.contains('peer')) return 'Peer reviewed';
  return 'Verified';
}

/// "The Lancet • 2026" -> "The Lancet 2026"; drops the generic "Peer Reviewed" suffix.
String cleanArticleSource(HealthArticle a) => a.verifiedSource
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
