import 'package:vitanet/core/layout/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/data/services/clinical_articles_data.dart';
import 'package:vitanet/features/first_aid/screens/first_aid_screen.dart';
import 'package:vitanet/features/resources/models/clinical_video.dart';
import 'package:vitanet/features/resources/models/health_article.dart';
import 'package:vitanet/features/resources/screens/emergency_protocols_screen.dart';
import 'package:vitanet/features/resources/screens/general_health_library_screen.dart';
import 'package:vitanet/features/resources/screens/health_article_detail_screen.dart';
import 'package:vitanet/features/resources/screens/medicine_search_screen.dart';
import 'package:vitanet/features/resources/screens/video_library_screen.dart';
import 'package:vitanet/features/resources/screens/video_player_screen.dart';
import 'package:vitanet/features/resources/widgets/resource_media.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Redesigned Creative Clinical Resources Hub.
///
/// Features:
/// 1. Prominent header with clinical search & live category filters.
/// 2. High-impact Emergency Life Support Action Card (Direct 112 trigger).
/// 3. Asymmetrical Bento knowledge pillars (Medicines, Videos, PubMed Library, First Aid).
/// 4. Horizontal Essential Life-Saving Protocols Rail (CPR, Bleeding, Choking, etc.).
/// 5. Doctor-led Video Shorts Carousel with verified clinician tags.
/// 6. Personalised "Picked For You" Evidence-Based Article tailored to the user profile.
/// 7. Daily Clinical Pearl of Wisdom card.
class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

enum _ResourceFilter { all, emergency, medicines, videos, research }

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ResourceFilter _activeFilter = _ResourceFilter.all;

  static final List<_ResourceCategory> _categories = [
    const _ResourceCategory(
      title: 'Medicines',
      subtitle: 'FDA monographs & dosages',
      badge: 'FDA APPROVED',
      imagePath: VnPhotos.pillsColorful,
      destination: MedicineSearchScreen(),
      route: '/resources/medicines',
      filter: _ResourceFilter.medicines,
      keywords: ['medicine', 'drugs', 'fda', 'dosage', 'prescription', 'pills', 'antibiotics'],
    ),
    const _ResourceCategory(
      title: 'Physician Videos',
      subtitle: 'Clinical shorts & masterclasses',
      badge: 'CLINICAL REELS',
      imagePath: VnPhotos.doctorOnPhone,
      destination: VideoLibraryScreen(),
      route: '/resources/videos',
      filter: _ResourceFilter.videos,
      isVideo: true,
      keywords: ['video', 'tutorials', 'masterclass', 'clinical', 'shorts', 'doctor', 'learn'],
    ),
    const _ResourceCategory(
      title: 'Clinical Library',
      subtitle: 'PubMed-verified research',
      badge: 'PUBMED VERIFIED',
      imagePath: VnPhotos.stethoscopeDiagnostics,
      destination: GeneralHealthLibraryScreen(),
      route: '/resources/health-library',
      filter: _ResourceFilter.research,
      keywords: ['articles', 'pubmed', 'research', 'library', 'studies', 'reading', 'guides'],
    ),
    const _ResourceCategory(
      title: 'First Aid Hub',
      subtitle: '10 step-by-step guides',
      badge: 'STEP-BY-STEP',
      imagePath: VnPhotos.firstAidKit,
      destination: EmergencyHubScreen(),
      route: '/resources/emergency',
      filter: _ResourceFilter.emergency,
      keywords: ['emergency', 'first aid', 'triage', 'cpr', 'burn', 'wound', 'bleeding', 'choking', 'guide'],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _open(String route, Widget destination) {
    try {
      context.push(route);
    } catch (_) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => destination),
      );
    }
  }

  List<_ResourceCategory> get _filteredCategories {
    final query = _searchQuery.trim().toLowerCase();
    return _categories.where((cat) {
      if (_activeFilter != _ResourceFilter.all && cat.filter != _activeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return cat.title.toLowerCase().contains(query) ||
          cat.subtitle.toLowerCase().contains(query) ||
          cat.keywords.any((k) => k.contains(query));
    }).toList();
  }

  bool get _showEmergencyHero {
    if (_activeFilter != _ResourceFilter.all && _activeFilter != _ResourceFilter.emergency) {
      return false;
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return const ['emergency', 'cpr', 'choking', 'bleeding', 'burn', 'seizure', 'first aid', '112']
        .any((k) => k.contains(q) || q.contains(k));
  }

  /// Picks a curated article that matches the user's profile when possible.
  ({HealthArticle article, String reason})? _pickedArticle() {
    final articles = ClinicalArticlesRepository.verifiedArticles;
    if (articles.isEmpty) return null;
    final profile = ref.watch(userProfileProvider);
    final conditions = profile?.preExistingConditions ?? const <String>[];
    const map = <String, String>{
      'hypertension': 'Cardiology',
      'blood pressure': 'Cardiology',
      'heart': 'Cardiology',
      'cholesterol': 'Cardiology',
      'diabetes': 'Nutrition',
      'obesity': 'Nutrition',
      'insomnia': 'Sleep',
      'sleep': 'Sleep',
      'asthma': 'Immunology',
      'allerg': 'Immunology',
      'anxiety': 'Cardiology',
      'arthritis': 'Fitness',
    };
    for (final condition in conditions) {
      final lower = condition.toLowerCase();
      for (final entry in map.entries) {
        if (lower.contains(entry.key)) {
          final match = articles.where((a) => a.category == entry.value);
          if (match.isNotEmpty) {
            return (article: match.first, reason: 'Tailored for your $condition profile');
          }
        }
      }
    }
    return (article: articles.first, reason: 'Recommended clinical reading');
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final filtered = _filteredCategories;
    final picked = _pickedArticle();
    final firstAidTips = FirstAidScreen.tips.take(5).toList();
    final shorts = ClinicalVideoRepository.verifiedShorts.take(4).toList();

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => handleScrollNotification(n, ref),
              child: ListView(
                physics: const VnAlwaysScrollablePhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                children: [
                  // Header Bar
                  _buildHeader(p),
                  const SizedBox(height: 16),

                  // Search Bar
                  _buildSearchBar(p),
                  const SizedBox(height: 14),

                  // Category Filters Rail
                  _buildFilterRail(p),
                  const SizedBox(height: 20),

                  // Emergency Spotlight Action Card
                  if (_showEmergencyHero) ...[
                    _CreativeEmergencyHero(
                      onOpenHub: () => _open('/resources/emergency', const EmergencyHubScreen()),
                      onCall112: () => LaunchHelpers.dialOrSnack(context, '112'),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Bento Knowledge Pillars
                  if (filtered.isNotEmpty) ...[
                    VnSectionHeader(
                      title: 'Knowledge pillars',
                      action: _searchQuery.isNotEmpty ? null : 'Explore all',
                      onAction: () => _open('/resources/health-library', const GeneralHealthLibraryScreen()),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= VnBreakpoints.medium ? 4 : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisExtent: 185,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final cat = filtered[index];
                            return _CreativeCategoryTile(
                              category: cat,
                              onTap: () => _open(cat.route, cat.destination),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 26),
                  ],

                  // Essential First Aid Rail (When not filtered out)
                  if ((_activeFilter == _ResourceFilter.all || _activeFilter == _ResourceFilter.emergency) &&
                      _searchQuery.isEmpty) ...[
                    VnSectionHeader(
                      title: 'Life-saving protocols',
                      action: 'All 10 guides',
                      onAction: () => _open('/resources/emergency', const EmergencyHubScreen()),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 148,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const VnAlwaysScrollablePhysics(),
                        itemCount: firstAidTips.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final tip = firstAidTips[i];
                          return SizedBox(
                            width: 230,
                            child: _ProtocolRailCard(
                              tip: tip,
                              onTap: () => Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                  builder: (_) => EmergencyProtocolDetailScreen(tip: tip),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],

                  // Physician Video Shorts Showcase
                  if ((_activeFilter == _ResourceFilter.all || _activeFilter == _ResourceFilter.videos) &&
                      _searchQuery.isEmpty &&
                      shorts.isNotEmpty) ...[
                    VnSectionHeader(
                      title: 'Doctor-led video reels',
                      action: 'Video library',
                      onAction: () => _open('/resources/videos', const VideoLibraryScreen()),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 205,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const VnAlwaysScrollablePhysics(),
                        itemCount: shorts.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final video = shorts[i];
                          return SizedBox(
                            width: 145,
                            child: _VideoShortRailCard(
                              video: video,
                              onTap: () => VideoPlayerScreen.openClinical(context, video),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],

                  // Picked for You Clinical Research Card
                  if (picked != null &&
                      (_activeFilter == _ResourceFilter.all || _activeFilter == _ResourceFilter.research) &&
                      _searchQuery.isEmpty) ...[
                    VnSectionHeader(
                      title: 'Picked for you',
                      action: '50+ articles',
                      onAction: () => _open('/resources/health-library', const GeneralHealthLibraryScreen()),
                    ),
                    const SizedBox(height: 12),
                    _CreativePickedArticleCard(
                      article: picked.article,
                      reason: picked.reason,
                      onTap: () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => HealthArticleDetailScreen(article: picked.article),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Daily Clinical Pearl Card
                  if (_searchQuery.isEmpty) ...[
                    const _ClinicalPearlCard(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(VnPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: p.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_outlined, size: 14, color: p.brand),
                  const SizedBox(width: 5),
                  Text(
                    'CLINICAL KNOWLEDGE BASE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: p.brand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Medical Resources',
          style: VnText.heading(28, color: p.ink, weight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Peer-reviewed medical guides, FDA drug directories & clinician masterclasses.',
          style: VnText.body(14, color: p.muted, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildSearchBar(VnPalette p) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 21, color: p.muted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: VnText.body(14.5, color: p.ink),
              decoration: InputDecoration(
                hintText: 'Search first aid, drugs, dosage, videos…',
                hintStyle: VnText.body(14, color: p.muted),
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
              size: 38,
              foreground: p.muted,
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            )
          else
            Icon(Icons.mic_none_rounded, size: 20, color: p.brand),
        ],
      ),
    );
  }

  Widget _buildFilterRail(VnPalette p) {
    final filters = [
      (_ResourceFilter.all, 'All', Icons.auto_awesome_rounded),
      (_ResourceFilter.emergency, 'First Aid', Icons.emergency_rounded),
      (_ResourceFilter.medicines, 'Medicines', Icons.medication_rounded),
      (_ResourceFilter.videos, 'Videos', Icons.play_circle_outline_rounded),
      (_ResourceFilter.research, 'Research', Icons.menu_book_rounded),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const VnAlwaysScrollablePhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (filter, label, icon) = filters[i];
          final isSelected = _activeFilter == filter;
          final bg = isSelected ? p.brand : p.surface;
          final fg = isSelected ? Colors.white : p.ink;
          final border = isSelected ? p.brand : p.line;

          return Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _activeFilter = filter),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: VnText.body(13, weight: isSelected ? FontWeight.w700 : FontWeight.w600, color: fg),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Creative High-Impact Emergency Hero Spotlight
class _CreativeEmergencyHero extends StatelessWidget {
  final VoidCallback onOpenHub;
  final VoidCallback onCall112;

  const _CreativeEmergencyHero({
    required this.onOpenHub,
    required this.onCall112,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF991B1B), // Dark crimson
            Color(0xFFDC2626), // Vivid medical red
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 24,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.warning_amber_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'CRITICAL LIFE SUPPORT · 24/7 ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Emergency Protocols & First Aid',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Instant step-by-step CPR, choking, bleeding, and burn management.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.90),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                // Quick protocol tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _heroChip('CPR (Hands-only)'),
                    _heroChip('Choking (Heimlich)'),
                    _heroChip('Severe Bleeding'),
                    _heroChip('Burns'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 10,
                      child: VnButton(
                        label: 'Call 112',
                        icon: Icons.phone_in_talk_rounded,
                        height: 44,
                        radius: 12,
                        fontSize: 13.5,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        background: Colors.white,
                        foreground: const Color(0xFF991B1B),
                        onPressed: onCall112,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 12,
                      child: VnOutlineButton(
                        label: '10 Guides',
                        icon: Icons.arrow_forward_rounded,
                        height: 44,
                        radius: 12,
                        fontSize: 13.5,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        background: Colors.white.withValues(alpha: 0.16),
                        borderColor: Colors.transparent,
                        foreground: Colors.white,
                        onPressed: onOpenHub,
                      ),
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

  static Widget _heroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}

/// Category Bento Tile with authentic photography & micro-badges
class _CreativeCategoryTile extends StatelessWidget {
  final _ResourceCategory category;
  final VoidCallback onTap;

  const _CreativeCategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${category.title}. ${category.subtitle}',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.black,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VnPhoto(category.imagePath),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.2, 0.65, 1.0],
                      colors: [
                        Color(0x33000000),
                        Color(0x800F172A),
                        Color(0xF20F172A),
                      ],
                    ),
                  ),
                ),
                // Badge at top
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      category.badge,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (category.isVideo)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xE6FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 18, color: Color(0xFF0F172A)),
                    ),
                  ),
                // Bottom content
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VnText.body(15, weight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: VnText.body(11, color: const Color(0xFFCBD5E1), height: 1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal protocol rail card
class _ProtocolRailCard extends StatelessWidget {
  final FirstAidTip tip;
  final VoidCallback onTap;

  const _ProtocolRailCard({required this.tip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final isCritical = tip.isCritical;
    final accentBg = isCritical ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE);
    final accentFg = isCritical ? const Color(0xFFB91C1C) : const Color(0xFF0369A1);

    return VnCard(
      onTap: onTap,
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: p.isDark ? accentFg.withValues(alpha: 0.20) : accentBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tip.icon, size: 18, color: p.tintFg(accentFg)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCritical
                      ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                      : p.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  isCritical ? 'URGENT' : '${tip.steps.length} STEPS',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: isCritical ? const Color(0xFFDC2626) : p.brand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tip.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VnText.body(14, weight: FontWeight.w700, color: p.ink),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              tip.cue ?? tip.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: VnText.body(11.5, color: p.muted, height: 1.3),
            ),
          ),
          Row(
            children: [
              Text(
                'Follow guide',
                style: VnText.body(11.5, weight: FontWeight.w700, color: p.brand),
              ),
              const SizedBox(width: 3),
              Icon(Icons.arrow_forward_rounded, size: 12, color: p.brand),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal video short card
class _VideoShortRailCard extends StatelessWidget {
  final ClinicalVideo video;
  final VoidCallback onTap;

  const _VideoShortRailCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Colors.black,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                video.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF1E293B),
                  child: const Center(
                    child: Icon(Icons.video_library_rounded, color: Colors.white54, size: 28),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 0.7, 1.0],
                    colors: [
                      Color(0x20000000),
                      Color(0x80000000),
                      Color(0xEE0F172A),
                    ],
                  ),
                ),
              ),
              // Play button
              Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 22, color: Color(0xFF0F172A)),
                ),
              ),
              // Duration Pill at top right
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    video.formattedDuration,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
              // Channel & Title at bottom
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_rounded, size: 11, color: AppColors.mintLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            video.channelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mintLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.25,
                      ),
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

/// Creative Picked Article Card
class _CreativePickedArticleCard extends StatelessWidget {
  final HealthArticle article;
  final String reason;
  final VoidCallback onTap;

  const _CreativePickedArticleCard({
    required this.article,
    required this.reason,
    required this.onTap,
  });

  IconData get _icon {
    switch (article.category.toLowerCase()) {
      case 'cardiology':
        return Icons.favorite_border_rounded;
      case 'sleep':
        return Icons.bedtime_outlined;
      case 'nutrition':
        return Icons.restaurant_rounded;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'immunology':
        return Icons.air_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final minutes = article.readTime.replaceAll(' read', '');

    return VnCard(
      onTap: onTap,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    reason.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: p.brand,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$minutes read · Verified',
                style: VnText.body(11, color: p.muted, weight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VnIconTile(
                icon: _icon,
                bg: const Color(0xFFE0F2FE),
                fg: const Color(0xFF0369A1),
                size: 44,
                radius: 12,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: VnText.heading(15, color: p.ink, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: VnText.body(12.5, color: p.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  article.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VnText.body(11.5, color: p.faint, weight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Read full paper',
                    style: VnText.body(12, weight: FontWeight.w700, color: p.brand),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 13, color: p.brand),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Clinical Pearl of the Day Card
class _ClinicalPearlCard extends StatelessWidget {
  const _ClinicalPearlCard();

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final bg = p.isDark ? const Color(0xFF0D2924) : const Color(0xFFF0FDF4);
    final border = p.isDark ? const Color(0xFF134E48) : const Color(0xFFBBF7D0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: p.brand.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lightbulb_outline_rounded, size: 20, color: p.brand),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'CLINICAL PEARL',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: p.brand,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(color: p.brand, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cardiology & Sleep',
                      style: VnText.body(11, color: p.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'During deep slow-wave sleep (N3), the brain’s glymphatic space expands by up to 60%, accelerating metabolic neurotoxin clearance. Consistent sleep schedules preserve this vital cellular recovery architecture.',
                  style: VnText.body(13, color: p.ink, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  'Source: Mayo Clinic Proceedings & JACC 2024',
                  style: VnText.body(11, color: p.muted, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceCategory {
  final String title;
  final String subtitle;
  final String badge;
  final String imagePath;
  final Widget destination;
  final String route;
  final _ResourceFilter filter;
  final List<String> keywords;
  final bool isVideo;

  const _ResourceCategory({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.imagePath,
    required this.destination,
    required this.route,
    required this.filter,
    required this.keywords,
    this.isVideo = false,
  });
}
