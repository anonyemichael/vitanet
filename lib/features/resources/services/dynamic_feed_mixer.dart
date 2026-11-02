import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:vitanet/data/services/clinical_articles_data.dart';
import '../models/health_article.dart';
import 'medical_image_resolver.dart';

/// Dynamic Feed Mixer for VitaNet Health Library.
///
/// Features:
/// - Eliminates static feeds: rotates across time-seeded medical queries on "All".
/// - Rotates 8 clinical domains: Cardiology, Nutrition, Sleep Science, Metabolic Health,
///   Sports Medicine, Immunology, Mental Health, and Longevity.
/// - Interleaves verified curated clinical studies with live Europe PMC API results using a session seed.
/// - Deterministically constructs Europe PMC queries for search, category filtering, and discovery.
class DynamicFeedMixer {
  int _sessionSeed;
  int _rotationOffset = 0;

  DynamicFeedMixer({int? initialSeed})
      : _sessionSeed = initialSeed ?? DateTime.now().millisecondsSinceEpoch;

  int get sessionSeed => _sessionSeed;

  /// Clinical topic domains used for rotating discovery feed queries
  static const List<String> discoveryDomains = [
    'Cardiology',
    'Nutrition',
    'Sleep Science',
    'Metabolic Health',
    'Sports Medicine',
    'Immunology',
    'Mental Health',
    'Longevity',
  ];

  /// Re-seeds the mixer session (called on Pull-to-Refresh or screen mount).
  void reseed() {
    _sessionSeed = DateTime.now().millisecondsSinceEpoch;
    _rotationOffset = (_rotationOffset + 1) % discoveryDomains.length;
    debugPrint('DynamicFeedMixer re-seeded with seed $_sessionSeed, offset $_rotationOffset');
  }

  /// Builds the Europe PMC query for a given category and optional search term.
  String buildQuery({
    required String selectedCategory,
    String searchQuery = '',
  }) {
    final cleanSearch = searchQuery.trim();

    // 1. Explicit search has highest priority
    if (cleanSearch.isNotEmpty) {
      // Query across titles, abstracts, and MeSH terms
      return '$cleanSearch AND (has_abstract:y)';
    }

    // 2. Specific category selected
    if (selectedCategory.isNotEmpty && selectedCategory.toLowerCase() != 'all') {
      final categoryQuery = _getCategorySpecificQuery(selectedCategory);
      return '$categoryQuery AND (OPEN_ACCESS:y) AND (has_abstract:y) AND (FIRST_PDATE:[2024 TO 2026])';
    }

    // 3. "All" mode: rotate clinical domains with session seed
    final random = Random(_sessionSeed + _rotationOffset);
    final shuffled = List<String>.from(discoveryDomains)..shuffle(random);
    final topThree = shuffled.take(3).toList();

    // Bias "For you" towards patient-friendly, everyday-health subjects by
    // matching on titles rather than anywhere in the full record.
    final domainsSubquery = topThree.map((d) => _forYouTitleQuery[d] ?? 'TITLE:"$d"').join(' OR ');
    return '(OPEN_ACCESS:y) AND (has_abstract:y) AND (FIRST_PDATE:[2024 TO 2026]) AND ($domainsSubquery)';
  }

  /// Interleaves live Europe PMC studies with curated gold-standard articles.
  List<HealthArticle> interleaveFeed({
    required List<HealthArticle> liveArticles,
    List<HealthArticle>? curatedArticles,
    String selectedCategory = 'All',
  }) {
    final curatedPool = List<HealthArticle>.from(
      curatedArticles ?? ClinicalArticlesRepository.verifiedArticles,
    );

    // Filter curated articles if category is specific
    List<HealthArticle> eligibleCurated;
    if (selectedCategory.toLowerCase() != 'all') {
      eligibleCurated = curatedPool
          .where((a) => a.category.toLowerCase() == selectedCategory.toLowerCase())
          .toList();
    } else {
      eligibleCurated = curatedPool;
    }

    // Seed-shuffle the curated pool
    final random = Random(_sessionSeed);
    eligibleCurated.shuffle(random);

    // Ensure all curated articles have valid Unsplash images resolved
    final resolvedCurated = eligibleCurated.map((article) {
      if (article.imageUrls.isEmpty || !article.imageUrls.first.startsWith('http')) {
        final cover = MedicalImageResolver.resolveCoverUrl(article);
        final thumb = MedicalImageResolver.resolveThumbnailUrl(article);
        return article.copyWith(imageUrls: [cover, thumb]);
      }
      return article;
    }).toList();

    // If no live articles returned yet, return resolved curated
    if (liveArticles.isEmpty) {
      return resolvedCurated;
    }

    final result = <HealthArticle>[];
    final seenIds = <String>{};

    int curatedIndex = 0;
    for (int i = 0; i < liveArticles.length; i++) {
      final liveItem = liveArticles[i];
      if (!seenIds.contains(liveItem.id)) {
        seenIds.add(liveItem.id);
        result.add(liveItem);
      }

      // Interleave 1 curated high-impact study every 3 live items
      if ((i + 1) % 3 == 0 && curatedIndex < resolvedCurated.length) {
        final curatedItem = resolvedCurated[curatedIndex];
        curatedIndex++;
        if (!seenIds.contains(curatedItem.id)) {
          seenIds.add(curatedItem.id);
          result.add(curatedItem);
        }
      }
    }

    // Append remaining curated items if feed is small
    while (result.length < 6 && curatedIndex < resolvedCurated.length) {
      final curatedItem = resolvedCurated[curatedIndex];
      curatedIndex++;
      if (!seenIds.contains(curatedItem.id)) {
        seenIds.add(curatedItem.id);
        result.add(curatedItem);
      }
    }

    return result;
  }

  /// Patient-friendly title queries for each "For you" discovery domain.
  static const Map<String, String> _forYouTitleQuery = {
    'Cardiology': 'TITLE:("heart health" OR "blood pressure" OR hypertension OR "heart disease")',
    'Nutrition': 'TITLE:(diet OR nutrition OR "healthy eating" OR "dietary")',
    'Sleep Science': 'TITLE:(sleep OR insomnia)',
    'Metabolic Health': 'TITLE:(diabetes OR "blood sugar" OR obesity OR "weight loss")',
    'Sports Medicine': 'TITLE:("physical activity" OR exercise OR walking)',
    'Immunology': 'TITLE:(vaccination OR vaccine OR influenza OR "infection prevention")',
    'Mental Health': 'TITLE:("mental health" OR anxiety OR depression OR stress OR loneliness)',
    'Longevity': 'TITLE:("healthy ageing" OR "healthy aging" OR "older adults")',
  };

  String _getCategorySpecificQuery(String category) {
    switch (category.toLowerCase()) {
      case 'cardiology':
        return 'TITLE:(cardiology OR "heart health" OR cardiovascular OR "blood pressure" OR hypertension OR "heart disease")';
      case 'nutrition':
        return 'TITLE:(nutrition OR diet OR dietary OR fasting OR "healthy eating" OR micronutrients)';
      case 'sleep':
        return 'TITLE:(sleep OR "circadian rhythm" OR insomnia OR melatonin)';
      case 'fitness':
        return 'TITLE:(exercise OR "physical activity" OR "strength training" OR fitness)';
      case 'immunology':
        return 'TITLE:(immunology OR vaccine OR vaccination OR antibodies OR infection)';
      case 'neurology':
        return '(neurology OR neuroscience OR cognition OR "brain function")';
      case 'longevity':
        return '(longevity OR aging OR "cellular health" OR "metabolic biomarkers")';
      default:
        return category;
    }
  }
}
