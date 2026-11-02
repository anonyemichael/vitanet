import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/resources/models/clinical_video.dart';
import 'package:vitanet/features/resources/screens/video_library_screen.dart';
import 'package:vitanet/shared/widgets/liquid_glass.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class FakeYoutubePlayerController extends Fake implements YoutubePlayerController {
  bool closed = false;
  bool isPlaying = false;
  double seekSeconds = 0;

  @override
  Future<void> playVideo() async {
    isPlaying = true;
  }

  @override
  Future<void> pauseVideo() async {
    isPlaying = false;
  }

  @override
  Future<void> seekTo({required double seconds, bool allowSeekAhead = false}) async {
    seekSeconds = seconds;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'GOOGLE_API_KEY=\n');
  });

  group('ClinicalVideo Model & Deterministic Thumbnail Tests', () {
    test('Computes deterministic 16:9 and 9:16 thumbnail URLs from youtubeId', () {
      const video = ClinicalVideo(
        youtubeId: 'hizBdM1Ob68',
        title: 'How to Do CPR on an Adult',
        channelName: 'St John Ambulance',
        channelAvatarUrl: 'SJ',
        isVerifiedChannel: true,
        category: 'First Aid & CPR',
        durationSeconds: 248,
        formattedDuration: '4:08',
        viewsCount: '7.2M',
        publishedAgo: '1 yr ago',
        isShort: false,
        keyTakeaways: ['Check safety', 'Call 999/112', 'Compress 5-6cm at 100-120 bpm'],
      );

      expect(video.youtubeId, equals('hizBdM1Ob68'));
      expect(video.id, equals('hizBdM1Ob68'));
      expect(video.thumbnailUrl, equals('https://i.ytimg.com/vi/hizBdM1Ob68/hqdefault.jpg'));
      expect(video.shortsThumbnailUrl, equals('https://i.ytimg.com/vi/hizBdM1Ob68/oar2.jpg'));
      expect(video.highResThumbnailUrl, equals('https://i.ytimg.com/vi/hizBdM1Ob68/maxresdefault.jpg'));
    });

    test('Contains verified medical YouTube IDs from St John Ambulance, Mayo Clinic, Osmosis, Red Cross', () {
      final masterclasses = ClinicalVideoRepository.verifiedMasterclasses;
      final shorts = ClinicalVideoRepository.verifiedShorts;

      final allIds = {
        ...masterclasses.map((v) => v.youtubeId),
        ...shorts.map((v) => v.youtubeId),
      };

      // Check required YouTube IDs from prompt
      expect(allIds, contains('hizBdM1Ob68')); // Adult CPR
      expect(allIds, contains('GmqXqwSV3bo')); // Recovery Position
      expect(allIds, contains('PA9hpOnvtCk')); // Choking First Aid
      expect(allIds, contains('NxO5LvgqZe0')); // Severe Bleeding
      expect(allIds, contains('2v8vlXgGXwE')); // Fracture Care
      expect(allIds, contains('tEmt1Znux58')); // Box Breathing

      // Verify dataset sizes: initial page must have >= 10 Masterclasses and >= 8 Shorts
      expect(masterclasses.length, greaterThanOrEqualTo(10));
      expect(shorts.length, greaterThanOrEqualTo(8));
    });
  });

  group('ClinicalVideoRepository Hybrid & Caching Tests', () {
    test('Initial page loads 10 masterclasses immediately from verified dataset', () async {
      final res = await ClinicalVideoRepository.fetchMasterclasses(
        pageIndex: 0,
        pageSize: 10,
      );

      expect(res.videos.length, equals(10));
      expect(res.hasMore, isTrue);
      expect(res.nextPageToken, isNotNull);
    });

    test('In-memory caching prevents duplicate fetches for same search query', () async {
      final res1 = await ClinicalVideoRepository.fetchMasterclasses(
        pageIndex: 0,
        pageSize: 5,
        searchQuery: 'cpr',
      );

      final res2 = await ClinicalVideoRepository.fetchMasterclasses(
        pageIndex: 0,
        pageSize: 5,
        searchQuery: 'cpr',
      );

      // Verify identical list instances returned from in-memory cache (0 API quota cost)
      expect(identical(res1.videos, res2.videos), isTrue);
      expect(res1.videos.isNotEmpty, isTrue);
    });

    test('Filters videos by category correctly', () async {
      final res = await ClinicalVideoRepository.fetchMasterclasses(
        pageIndex: 0,
        pageSize: 10,
        category: 'First Aid & CPR',
      );

      expect(res.videos.isNotEmpty, isTrue);
      for (final v in res.videos) {
        expect(v.category, equals('First Aid & CPR'));
      }
    });
  });

  group('ShortsControllerPool Sliding-Window Tests', () {
    test('Maintains maximum of 3 controllers within sliding window [n-1, n, n+1]', () {
      final shorts = ClinicalVideoRepository.verifiedShorts;

      final pool = ShortsControllerPool(
        shorts: shorts,
        initialIndex: 0,
        controllerFactory: (videoId, autoPlay) {
          final fake = FakeYoutubePlayerController();
          return fake;
        },
      );

      // At index 0, controllers at 0 and 1 are in memory
      expect(pool.getController(0), isNotNull);
      expect(pool.getController(1), isNotNull);
      expect(pool.getController(2), isNull);

      // Swipe down to index 1 -> window becomes [0, 1, 2]
      pool.onPageChanged(1);
      expect(pool.getController(0), isNotNull);
      expect(pool.getController(1), isNotNull);
      expect(pool.getController(2), isNotNull);
      expect(pool.getController(3), isNull);

      // Swipe down to index 2 -> index 0 must be disposed because (0 - 2).abs() > 1
      pool.onPageChanged(2);
      expect(pool.getController(0), isNull);
      expect(pool.getController(1), isNotNull);
      expect(pool.getController(2), isNotNull);
      expect(pool.getController(3), isNotNull);

      // Swipe back up to index 1 -> index 3 must be disposed because (3 - 1).abs() > 1
      pool.onPageChanged(1);
      expect(pool.getController(0), isNotNull);
      expect(pool.getController(1), isNotNull);
      expect(pool.getController(2), isNotNull);
      expect(pool.getController(3), isNull);

      pool.dispose();
    });
  });

  group('LiquidGlassSurface Widget Tests', () {
    testWidgets('LiquidGlassSurface renders with static blur filter and architectural radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidGlassSurface(
                borderRadius: BorderRadius.circular(8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: const Text('Test Pill'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Pill'), findsOneWidget);
      expect(find.byType(LiquidGlassSurface), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
