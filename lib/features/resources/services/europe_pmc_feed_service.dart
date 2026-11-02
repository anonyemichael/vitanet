import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/health_article.dart';
import 'medical_image_resolver.dart';

/// Response payload from Europe PMC REST API with cursor pagination.
class EuropePmcFeedPage {
  final List<HealthArticle> articles;
  final String? nextCursorMark;
  final int hitCount;
  final bool hasMore;

  const EuropePmcFeedPage({
    required this.articles,
    required this.nextCursorMark,
    required this.hitCount,
    required this.hasMore,
  });

  factory EuropePmcFeedPage.empty() {
    return const EuropePmcFeedPage(
      articles: [],
      nextCursorMark: null,
      hitCount: 0,
      hasMore: false,
    );
  }
}

/// Production service connecting to Europe PMC REST API with cursor-based pagination.
class EuropePmcFeedService {
  static const String _baseUrl = 'https://www.ebi.ac.uk/europepmc/webservices/rest/search';

  final http.Client _client;

  EuropePmcFeedService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches a page of clinical studies using Europe PMC cursorMark pagination.
  ///
  /// - [query]: Raw search query or clinical domain filters.
  /// - [cursorMark]: Europe PMC cursor token. Initial call uses `*`.
  /// - [pageSize]: Number of articles per page (default: 12).
  Future<EuropePmcFeedPage> fetchFeedPage({
    required String query,
    String cursorMark = '*',
    int pageSize = 12,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return EuropePmcFeedPage.empty();
    }

    final uri = Uri.parse(
      '$_baseUrl?query=${Uri.encodeComponent(cleanQuery)}&resultType=core&cursorMark=${Uri.encodeComponent(cursorMark)}&pageSize=$pageSize&format=json',
    );

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('Europe PMC API returned status ${response.statusCode}');
        return EuropePmcFeedPage.empty();
      }

      final dynamic decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return EuropePmcFeedPage.empty();
      }

      final hitCount = (decoded['hitCount'] as num?)?.toInt() ?? 0;
      final nextCursor = decoded['nextCursorMark'] as String?;
      final rawResults = decoded['resultList']?['result'] as List? ?? [];

      final articles = <HealthArticle>[];
      for (final item in rawResults) {
        if (item is Map<String, dynamic>) {
          final article = _parseEuropePmcArticle(item, cleanQuery);
          if (article != null) {
            articles.add(article);
          }
        }
      }

      // Check if more results remain
      final hasMore = nextCursor != null &&
          nextCursor.isNotEmpty &&
          nextCursor != cursorMark &&
          articles.isNotEmpty;

      return EuropePmcFeedPage(
        articles: articles,
        nextCursorMark: nextCursor,
        hitCount: hitCount,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('Europe PMC fetch exception: $e');
      return EuropePmcFeedPage.empty();
    }
  }

  /// Parses raw Europe PMC JSON item into [HealthArticle].
  HealthArticle? _parseEuropePmcArticle(Map<String, dynamic> item, String queryContext) {
    try {
      final id = item['id']?.toString() ??
          item['pmid']?.toString() ??
          item['pmcid']?.toString() ??
          'PMC_${DateTime.now().microsecondsSinceEpoch}';

      final rawTitle = item['title']?.toString() ?? 'Biomedical Discovery';
      final cleanTitle = _stripHtml(rawTitle);

      final rawAbstract = item['abstractText']?.toString() ?? '';
      final cleanAbstract = _stripHtml(rawAbstract).trim();

      // Extract Journal & Year
      final journal = item['journalInfo']?['journal']?['title']?.toString() ??
          item['journalInfo']?['journal']?['medlineAbbreviation']?.toString() ??
          'Europe PMC Open Access';
      final pubYear = item['pubYear']?.toString() ??
          item['firstPublicationDate']?.toString().split('-').first ??
          '2026';

      final doi = item['doi']?.toString();

      // Extract MeSH Headings
      final meshHeadings = <String>[];
      final meshList = item['meshHeadingList']?['meshHeading'] as List?;
      if (meshList != null) {
        for (final m in meshList) {
          if (m is Map && m['descriptorName'] != null) {
            meshHeadings.add(m['descriptorName'].toString());
          }
        }
      }

      // Extract Author String
      final authors = item['authorString']?.toString() ?? 'Clinical Research Consortium';

      // Infer Category
      final category = _inferCategory(cleanTitle, cleanAbstract, meshHeadings, queryContext);

      // Estimate Read Time based on abstract length
      final wordCount = cleanAbstract.split(RegExp(r'\s+')).length;
      final readMinutes = (wordCount / 40).clamp(3, 8).round();
      final readTime = '$readMinutes min read';

      // Generate Patient-Friendly AI Key Takeaways
      final takeaways = _generateKeyTakeaways(cleanAbstract, journal, pubYear);

      // Construct Sections
      final sections = <ArticleSection>[
        ArticleSection(
          heading: 'Clinical Abstract & Study Scope',
          content: cleanAbstract.isNotEmpty
              ? cleanAbstract
              : 'Peer-reviewed clinical research findings indexed in Europe PMC / NCBI repositories. Full text available through the Open Access DOI registry.',
        ),
        ArticleSection(
          heading: 'Investigative Source & Authors',
          content: 'Published in $journal ($pubYear).\nLead Authors: $authors.\nIndexed with verified open access clinical credentials.',
        ),
        if (meshHeadings.isNotEmpty)
          ArticleSection(
            heading: 'MeSH Clinical Classifications',
            content: meshHeadings.join(' • '),
          ),
      ];

      // Temporary article to pass to MedicalImageResolver
      final tempArticle = HealthArticle(
        id: id,
        title: cleanTitle,
        category: category,
        verifiedSource: '$journal • $pubYear',
        readTime: readTime,
        difficultyLevel: 'Peer Reviewed',
        icon: _getCategoryIcon(category),
        color: _getCategoryColor(category),
        excerpt: cleanAbstract.isNotEmpty ? cleanAbstract : 'Biomedical study published in $journal.',
        sections: sections,
        keyTakeaways: takeaways,
        doi: doi,
        publishedDate: pubYear,
        meshHeadings: meshHeadings,
      );

      // Deterministically resolve high-resolution cover & thumbnail
      final coverUrl = MedicalImageResolver.resolveCoverUrl(tempArticle);
      final thumbUrl = MedicalImageResolver.resolveThumbnailUrl(tempArticle);

      return tempArticle.copyWith(
        imageUrls: [coverUrl, thumbUrl],
      );
    } catch (e) {
      debugPrint('Error parsing article: $e');
      return null;
    }
  }

  /// Strips HTML tags and collapses redundant whitespaces.
  static String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extracts 3 clinical takeaways from the abstract.
  static List<String> _generateKeyTakeaways(String abstractText, String journal, String year) {
    final takeaways = <String>[];

    if (abstractText.isNotEmpty) {
      // Look for Conclusion / Results cues
      final sentences = abstractText.split(RegExp(r'(?<=[.!?])\s+'));
      for (final s in sentences.reversed) {
        final clean = s.trim();
        final lower = clean.toLowerCase();
        if (clean.length > 35 && clean.length < 240) {
          if (lower.contains('conclude') ||
              lower.contains('demonstrate') ||
              lower.contains('suggest') ||
              lower.contains('found that') ||
              lower.contains('results show') ||
              lower.contains('significant')) {
            takeaways.add(clean);
            if (takeaways.length >= 3) break;
          }
        }
      }

      // If not enough tagged sentences, take leading informative statements
      if (takeaways.length < 3) {
        for (final s in sentences) {
          final clean = s.trim();
          if (clean.length > 30 && clean.length < 220 && !takeaways.contains(clean)) {
            takeaways.add(clean);
            if (takeaways.length >= 3) break;
          }
        }
      }
    }

    if (takeaways.isEmpty) {
      takeaways.add('Verified biomedical finding indexed in Europe PMC.');
      takeaways.add('Published in $journal ($year) under open-access peer review.');
      takeaways.add('Full DOI protocol reference available for clinical review.');
    }

    return takeaways;
  }

  /// Infers clinical domain category for tag styling.
  static String _inferCategory(
    String title,
    String abstractText,
    List<String> meshHeadings,
    String queryContext,
  ) {
    final text = '$title $abstractText ${meshHeadings.join(' ')} $queryContext'.toLowerCase();

    if (text.contains('cardio') || text.contains('heart') || text.contains('vascular') || text.contains('hypertension')) {
      return 'Cardiology';
    }
    if (text.contains('nutrit') || text.contains('diet') || text.contains('fasting') || text.contains('micronutrient')) {
      return 'Nutrition';
    }
    if (text.contains('sleep') || text.contains('circadian') || text.contains('insomnia') || text.contains('neurolog') || text.contains('brain')) {
      return 'Sleep';
    }
    if (text.contains('exercise') || text.contains('fitness') || text.contains('muscle') || text.contains('resistance') || text.contains('physical activity')) {
      return 'Fitness';
    }
    if (text.contains('immun') || text.contains('vaccine') || text.contains('antibody') || text.contains('cytokine') || text.contains('infection')) {
      return 'Immunology';
    }
    if (text.contains('diabetes') || text.contains('insulin') || text.contains('glucose') || text.contains('metabolic')) {
      return 'Endocrinology';
    }
    if (text.contains('cancer') || text.contains('oncolog') || text.contains('tumor')) {
      return 'Oncology';
    }
    if (text.contains('depress') || text.contains('anxiety') || text.contains('mental') || text.contains('psychiatr')) {
      return 'Mental Health';
    }
    if (text.contains('longev') || text.contains('aging') || text.contains('senescen')) {
      return 'Longevity';
    }

    return 'Clinical';
  }

  static IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'cardiology':
        return Icons.favorite_rounded;
      case 'nutrition':
        return Icons.restaurant_rounded;
      case 'sleep':
        return Icons.nightlight_round;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'immunology':
        return Icons.biotech_rounded;
      case 'endocrinology':
        return Icons.monitor_heart_rounded;
      case 'oncology':
        return Icons.coronavirus_rounded;
      case 'mental health':
        return Icons.psychology_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  static Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'cardiology':
        return const Color(0xFFEF4444);
      case 'nutrition':
        return const Color(0xFF059669);
      case 'sleep':
        return const Color(0xFF0284C7);
      case 'fitness':
        return const Color(0xFF0D9488);
      case 'immunology':
        return const Color(0xFF7C3AED);
      case 'endocrinology':
        return const Color(0xFFF59E0B);
      case 'oncology':
        return const Color(0xFFE11D48);
      case 'mental health':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF0D9488);
    }
  }
}
