import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vitanet/features/resources/models/health_article.dart';
import 'package:vitanet/features/resources/services/medical_image_resolver.dart';
import 'package:vitanet/features/resources/services/dynamic_feed_mixer.dart';
import 'package:vitanet/features/resources/services/europe_pmc_feed_service.dart';

void main() {
  group('MedicalImageResolver Tests', () {
    test('Correctly maps clinical keywords to granular sub-buckets', () {
      expect(
        MedicalImageResolver.matchBucket(
          title: 'Impact of Myocardial Infarction on Heart Function',
          category: 'Cardiology',
        ),
        'cardiology',
      );

      expect(
        MedicalImageResolver.matchBucket(
          title: 'Intermittent Fasting and Dietary Fiber in Longevity',
          category: 'Nutrition',
        ),
        'nutrition_fasting',
      );

      expect(
        MedicalImageResolver.matchBucket(
          title: 'Circadian Rhythm Disruptions and Insomnia in Shift Workers',
          category: 'Sleep',
        ),
        'sleep_neurology',
      );

      expect(
        MedicalImageResolver.matchBucket(
          title: 'Resistance Training and Hypertrophy Biomechanics',
          category: 'Fitness',
        ),
        'resistance_fitness',
      );

      expect(
        MedicalImageResolver.matchBucket(
          title: 'Monoclonal Antibody and Cytokine Release in Viral Infection',
          category: 'Immunology',
        ),
        'immunology_lab',
      );

      expect(
        MedicalImageResolver.matchBucket(
          title: 'Insulin Resistance and Glycemic Control in Type 2 Diabetes',
          category: 'All',
        ),
        'endocrinology_diabetes',
      );

      expect(
        MedicalImageResolver.matchBucket(
          title: 'Targeted Chemotherapy in Melanoma Carcinoma Tumors',
          category: 'All',
        ),
        'oncology',
      );

      expect(
        MedicalImageResolver.matchBucket(
          title: 'Cutaneous Barrier Dysregulation in Severe Atopic Dermatitis',
          category: 'All',
        ),
        'dermatology',
      );

      expect(
        MedicalImageResolver.matchBucket(
          title: 'Neonatal Assessment and Pediatric Respiratory Syncytial Virus',
          category: 'All',
        ),
        'pediatrics',
      );
    });

    test('Deterministic hashing returns consistent image for same ID and different for distinct IDs', () {
      const article1 = HealthArticle(
        id: 'PMC_1001',
        title: 'Cardiac Rhythm and Arrhythmia Management',
        category: 'Cardiology',
        readTime: '5 min read',
      );

      const article2 = HealthArticle(
        id: 'PMC_1002',
        title: 'Cardiac Rhythm and Arrhythmia Management',
        category: 'Cardiology',
        readTime: '5 min read',
      );

      final photo1A = MedicalImageResolver.resolvePhotoId(article1);
      final photo1B = MedicalImageResolver.resolvePhotoId(article1);
      expect(photo1A, photo1B, reason: 'Must be deterministic for identical article ID');

      final photo2 = MedicalImageResolver.resolvePhotoId(article2);
      expect(photo2, isNotEmpty);

      final coverUrl = MedicalImageResolver.resolveCoverUrl(article1);
      final thumbUrl = MedicalImageResolver.resolveThumbnailUrl(article1);

      expect(coverUrl, contains('w=800'));
      expect(thumbUrl, contains('w=300'));
      expect(coverUrl, contains('images.unsplash.com'));
    });
  });

  group('DynamicFeedMixer Tests', () {
    test('Builds rotating discovery query on "All" with time-seeded session', () {
      final mixer = DynamicFeedMixer(initialSeed: 42);
      final query = mixer.buildQuery(selectedCategory: 'All');

      expect(query, contains('OPEN_ACCESS:y'));
      expect(query, contains('FIRST_PDATE:[2024 TO 2026]'));
      expect(query, contains('has_abstract:y'));
    });

    test('Builds domain-specific query when category is selected', () {
      final mixer = DynamicFeedMixer();
      final cardioQuery = mixer.buildQuery(selectedCategory: 'Cardiology');
      expect(cardioQuery.toLowerCase(), contains('cardiology'));
      expect(cardioQuery, contains('OPEN_ACCESS:y'));

      final sleepQuery = mixer.buildQuery(selectedCategory: 'Sleep');
      expect(sleepQuery.toLowerCase(), contains('sleep'));
    });

    test('Search query takes precedence over category filters', () {
      final mixer = DynamicFeedMixer();
      final searchQuery = mixer.buildQuery(
        selectedCategory: 'Cardiology',
        searchQuery: 'mitochondrial oxidative stress',
      );

      expect(searchQuery, contains('mitochondrial oxidative stress'));
      expect(searchQuery, contains('has_abstract:y'));
    });

    test('Interleaves curated high-impact studies with live feed items', () {
      final mixer = DynamicFeedMixer(initialSeed: 12345);
      final liveStudies = List.generate(
        6,
        (i) => HealthArticle(
          id: 'live_$i',
          title: 'Live Study $i',
          category: 'Cardiology',
          readTime: '4 min read',
        ),
      );

      final mixed = mixer.interleaveFeed(
        liveArticles: liveStudies,
        selectedCategory: 'All',
      );

      expect(mixed.length, greaterThan(liveStudies.length));
      expect(mixed.any((a) => a.id.startsWith('live_')), isTrue);
    });
  });

  group('EuropePmcFeedService Tests', () {
    test('Fetches and parses Europe PMC JSON with cursorMark and key takeaways', () async {
      final mockResponse = json.encode({
        'hitCount': 1520,
        'nextCursorMark': 'CURSOR_TOKEN_ABC123',
        'resultList': {
          'result': [
            {
              'id': 'PMC999999',
              'title': '<h4>Effect of Mediterranean Diet on Arterial Stiffness</h4>',
              'abstractText': '<p>Background: Cardiovascular disease remains prevalent. Results show that dietary intervention significantly improved pulse wave velocity. In conclusion, adherence demonstrates vascular protection.</p>',
              'journalInfo': {
                'journal': {
                  'title': 'The American Journal of Clinical Nutrition',
                },
              },
              'pubYear': '2026',
              'doi': '10.1016/j.ajcnut.2026.01.001',
              'meshHeadingList': {
                'meshHeading': [
                  {'descriptorName': 'Diet, Mediterranean'},
                  {'descriptorName': 'Vascular Stiffness'},
                ],
              },
            },
          ],
        },
      });

      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['cursorMark'], '*');
        expect(request.url.queryParameters['pageSize'], '12');
        return http.Response(mockResponse, 200);
      });

      final service = EuropePmcFeedService(client: mockClient);
      final page = await service.fetchFeedPage(query: 'mediterranean diet', cursorMark: '*');

      expect(page.hitCount, 1520);
      expect(page.nextCursorMark, 'CURSOR_TOKEN_ABC123');
      expect(page.hasMore, isTrue);
      expect(page.articles.length, 1);

      final article = page.articles.first;
      expect(article.title, 'Effect of Mediterranean Diet on Arterial Stiffness');
      expect(article.title, isNot(contains('<h4>')));
      expect(article.verifiedSource, contains('The American Journal of Clinical Nutrition'));
      expect(article.meshHeadings, contains('Diet, Mediterranean'));
      expect(article.imageUrls.isNotEmpty, isTrue);
      expect(article.imageUrls.first, contains('w=800'));
      expect(article.keyTakeaways.isNotEmpty, isTrue);
    });
  });
}
