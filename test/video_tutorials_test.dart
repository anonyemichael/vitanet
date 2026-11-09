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
  final List<String> loaded = [];

  @override
  Future<void> loadVideoById({required String videoId, double? startSeconds, double? endSeconds}) async {
    loaded.add(videoId);
  }

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
        title: 'Learn How To Do CPR',
        channelName: 'HealthSketch',
        channelAvatarUrl: 'HS',
        isVerifiedChannel: false,
        category: 'First Aid & CPR',
        durationSeconds: 243,
        formattedDuration: '4:03',
        viewsCount: '',
        publishedAgo: '',
        isShort: false,
        keyTakeaways: ['Check safety', 'Call 999/112', 'Compress 5-6cm at 100-120 bpm'],
      );

      expect(video.youtubeId, equals('hizBdM1Ob68'));
      expect(video.id, equals('hizBdM1Ob68'));
      expect(video.thumbnailUrl, equals('https://i.ytimg.com/vi/hizBdM1Ob68/hqdefault.jpg'));
      expect(video.shortsThumbnailUrl, equals('https://i.ytimg.com/vi/hizBdM1Ob68/oar2.jpg'));
      expect(video.highResThumbnailUrl, equals('https://i.ytimg.com/vi/hizBdM1Ob68/maxresdefault.jpg'));
    });

    test('Contains the audited first-aid and health YouTube IDs', () {
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

      // Audited metadata must match what YouTube reports for the ID.
      final cpr = masterclasses.firstWhere((v) => v.youtubeId == 'hizBdM1Ob68');
      expect(cpr.title, equals('Learn How To Do CPR'));
      expect(cpr.channelName, equals('HealthSketch'));
      // No unverifiable view counts are shipped in the curated catalog.
      expect([...masterclasses, ...shorts].every((v) => v.viewsCount.isEmpty), isTrue);
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

  group('Shorts playback', () {
    test('Uses one player for the whole feed and loads each clip into it', () {
      final shorts = ClinicalVideoRepository.verifiedShorts;
      var created = 0;
      late FakeYoutubePlayerController fake;
      final playback = ShortsPlayback(
        shorts: shorts,
        initialIndex: 0,
        controllerFactory: (videoId) {
          created++;
          expect(videoId, shorts[0].youtubeId);
          return fake = FakeYoutubePlayerController();
        },
      );

      expect(created, 1);
      expect(playback.loadedIndex, 0);

      playback.show(0); // already loaded: nothing to do
      expect(fake.loaded, isEmpty);

      playback.show(1);
      playback.show(2);
      playback.show(2);
      expect(fake.loaded, [shorts[1].youtubeId, shorts[2].youtubeId]);

      // The feed wraps around, so a large page index maps back into the list.
      playback.show(shorts.length + 1);
      expect(fake.loaded.last, shorts[1].youtubeId);
      expect(created, 1);

      playback.dispose();
      expect(fake.closed, isTrue);
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
