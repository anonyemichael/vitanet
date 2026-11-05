import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/data/services/clinical_articles_data.dart';
import 'package:vitanet/features/resources/models/health_article.dart';
import 'package:vitanet/features/resources/screens/emergency_protocols_screen.dart';
import 'package:vitanet/features/resources/screens/general_health_library_screen.dart';
import 'package:vitanet/features/resources/screens/health_article_detail_screen.dart';
import 'package:vitanet/features/resources/screens/medicine_search_screen.dart';
import 'package:vitanet/features/resources/screens/video_library_screen.dart';
import 'package:vitanet/features/resources/widgets/resource_media.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Resources hub: emergency entry point, four photo category cards and a
/// personalised reading pick.
class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static final List<_ResourceCategory> _categories = [
    const _ResourceCategory(
      title: 'First aid',
      subtitle: '10 step-by-step guides',
      imagePath: VnPhotos.firstAidKit,
      destination: EmergencyHubScreen(),
      route: '/resources/emergency',
      keywords: ['emergency', 'first aid', 'triage', 'cpr', 'burn', 'wound', 'bleeding', 'choking', 'guide'],
    ),
    const _ResourceCategory(
      title: 'Medicines',
      subtitle: 'FDA labels & dosage',
      imagePath: VnPhotos.pillsColorful,
      destination: MedicineSearchScreen(),
      route: '/resources/medicines',
      keywords: ['medicine', 'drugs', 'fda', 'dosage', 'prescription', 'pills', 'antibiotics'],
    ),
    const _ResourceCategory(
      title: 'Videos',
      subtitle: 'Shorts & masterclasses',
      imagePath: VnPhotos.doctorOnPhone,
      destination: VideoLibraryScreen(),
      route: '/resources/videos',
      keywords: ['video', 'tutorials', 'masterclass', 'clinical', 'shorts', 'doctor', 'learn'],
      isVideo: true,
    ),
    const _ResourceCategory(
      title: 'Health library',
      subtitle: 'PubMed-verified reading',
      imagePath: VnPhotos.laptopStethoscope,
      destination: GeneralHealthLibraryScreen(),
      route: '/resources/health-library',
      keywords: ['articles', 'pubmed', 'research', 'library', 'studies', 'reading', 'guides'],
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
    if (query.isEmpty) return _categories;
    return _categories.where((cat) {
      return cat.title.toLowerCase().contains(query) ||
          cat.subtitle.toLowerCase().contains(query) ||
          cat.keywords.any((k) => k.contains(query));
    }).toList();
  }

  bool get _emergencyMatches {
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
      'arthritis': 'Fitness',
    };
    for (final condition in conditions) {
      final lower = condition.toLowerCase();
      for (final entry in map.entries) {
        if (lower.contains(entry.key)) {
          final match = articles.where((a) => a.category == entry.value);
          if (match.isNotEmpty) {
            return (article: match.first, reason: 'Because you have ${condition.toLowerCase()}');
          }
        }
      }
    }
    return (article: articles.first, reason: 'Recommended reading');
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final filtered = _filteredCategories;
    final picked = _pickedArticle();

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => handleScrollNotification(n, ref),
              child: ListView(
                physics: const VnAlwaysScrollablePhysics(),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
                children: [
              Semantics(
                header: true,
                child: Text('Resources', style: VnText.heading(28, color: p.ink)),
              ),
              const SizedBox(height: 4),
              Text(
                'Trusted guides, medicines and videos, reviewed by clinicians.',
                style: VnText.body(15, color: p.muted),
              ),
              const SizedBox(height: 20),
              _buildSearch(p),
              const SizedBox(height: 20),
              if (_emergencyMatches) ...[
                _EmergencyBanner(
                  onTap: () => _open('/resources/emergency', const EmergencyHubScreen()),
                ),
                const SizedBox(height: 20),
              ],
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 40, color: p.faint),
                      const SizedBox(height: 10),
                      Text(
                        'No resources found for "$_searchQuery"',
                        textAlign: TextAlign.center,
                        style: VnText.body(15, weight: FontWeight.w500, color: p.muted),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 700 ? 4 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 200,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final cat = filtered[index];
                        return _PhotoCategoryCard(
                          category: cat,
                          onTap: () => _open(cat.route, cat.destination),
                        );
                      },
                    );
                  },
                ),
              if (picked != null && _searchQuery.trim().isEmpty) ...[
                const SizedBox(height: 20),
                VnSectionHeader(
                  title: 'Picked for you',
                  action: 'More',
                  onAction: () => _open('/resources/health-library', const GeneralHealthLibraryScreen()),
                ),
                const SizedBox(height: 4),
                _PickedArticleTile(
                  article: picked.article,
                  reason: picked.reason,
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => HealthArticleDetailScreen(article: picked.article),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildSearch(VnPalette p) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 4),
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
              onChanged: (val) => setState(() => _searchQuery = val),
              style: VnText.body(15, color: p.ink),
              decoration: InputDecoration(
                hintText: 'Search first aid, medicines, guides…',
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
                setState(() => _searchQuery = '');
              },
            ),
        ],
      ),
    );
  }
}

class _ResourceCategory {
  final String title;
  final String subtitle;
  final String imagePath;
  final Widget destination;
  final String route;
  final List<String> keywords;
  final bool isVideo;

  const _ResourceCategory({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.destination,
    required this.route,
    required this.keywords,
    this.isVideo = false,
  });
}

class _EmergencyBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _EmergencyBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final bg = p.isDark ? const Color(0xFF2A1212) : const Color(0xFFFEF2F2);
    final border = p.isDark ? const Color(0xFF5B1D1D) : const Color(0xFFFECACA);
    return VnCard(
      onTap: onTap,
      color: bg,
      borderColor: border,
      padding: const EdgeInsets.all(16),
      semanticLabel: 'Emergency? Start here. CPR, choking, bleeding, burns, seizures',
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFB91C1C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency? Start here',
                  style: VnText.body(16,
                      weight: FontWeight.w800,
                      color: p.isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B)),
                ),
                const SizedBox(height: 2),
                Text(
                  'CPR, choking, bleeding, burns, seizures',
                  style: VnText.body(13,
                      color: p.isDark ? const Color(0xFFFECACA) : const Color(0xFF7F1D1D)),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.danger),
        ],
      ),
    );
  }
}

class _PhotoCategoryCard extends StatelessWidget {
  final _ResourceCategory category;
  final VoidCallback onTap;

  const _PhotoCategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${category.title}. ${category.subtitle}',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                      stops: [0.3, 1.0],
                      colors: [Color(0x000F172A), Color(0xD90F172A)],
                    ),
                  ),
                ),
                if (category.isVideo)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xE6FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 20, color: Color(0xFF0F172A)),
                    ),
                  ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VnText.body(16, weight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(category.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VnText.body(12, color: const Color(0xFFE2E8F0))),
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

class _PickedArticleTile extends StatelessWidget {
  final HealthArticle article;
  final String reason;
  final VoidCallback onTap;

  const _PickedArticleTile({required this.article, required this.reason, required this.onTap});

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
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          VnIconTile(
            icon: _icon,
            bg: const Color(0xFFE0F2FE),
            fg: const Color(0xFF0369A1),
            size: 52,
            radius: 14,
            iconSize: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VnText.body(15, weight: FontWeight.w600, color: p.ink)),
                const SizedBox(height: 3),
                Text('$reason · $minutes', style: VnText.body(13, color: p.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
