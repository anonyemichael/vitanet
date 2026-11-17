import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/resources/models/clinical_video.dart';
import 'package:vitanet/features/resources/screens/video_library_screen.dart';
import 'package:vitanet/features/resources/widgets/shorts_controller_pool.dart';
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

  @override
  Future<void> mute() async {}

  @override
  Future<void> unMute() async {}
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

  group('ClinicalVideoRepository (backend feed + fallback)', () {
    Map<String, dynamic> vid(String id, {bool short = false, int views = 12345}) => {
          'id': id,
          'title': 'How to treat a burn &amp; scald',
          'channel': 'NHS',
          'category': 'Trauma',
          'duration_s': short ? 45 : 130,
          'is_short': short,
          'views': views,
          'published_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
          'takeaways': ['Cool the burn under running water for 20 minutes'],
          'verified': true,
        };

    test('Reads real videos from the backend, maps them and caches the page', () async {
      final asked = <Uri>[];
      final client = MockClient((req) async {
        asked.add(req.url);
        return http.Response(jsonEncode({'videos': [vid('a1'), vid('a2')], 'next_cursor': 2}), 200);
      });
      await http.runWithClient(() async {
        final r1 = await ClinicalVideoRepository.fetchMasterclasses(pageIndex: 0, pageSize: 2, category: 'Trauma');
        final r2 = await ClinicalVideoRepository.fetchMasterclasses(pageIndex: 0, pageSize: 2, category: 'Trauma');
        expect(identical(r1.videos, r2.videos), isTrue); // second call from memory
        expect(asked, hasLength(1));
        expect(asked.single.path, endsWith('videos/feed'));
        expect(asked.single.queryParameters, containsPair('topic', 'Trauma'));
        expect(asked.single.queryParameters, containsPair('kind', 'long'));
        final v = r1.videos.first;
        expect(v.title, 'How to treat a burn & scald');
        expect(v.formattedDuration, '2:10');
        expect(v.viewsCount, '12K views');
        expect(v.publishedAgo, '3d ago');
        expect(v.isVerifiedChannel, isTrue);
        expect(r1.nextPageToken, '2');
        expect(r1.hasMore, isTrue);
      }, () => client);
    });

    test('Search and shorts go to the right backend routes', () async {
      final asked = <Uri>[];
      final client = MockClient((req) async {
        asked.add(req.url);
        return http.Response(jsonEncode({'videos': [vid('s1', short: true)], 'next_cursor': null}), 200);
      });
      await http.runWithClient(() async {
        final r = await ClinicalVideoRepository.fetchShorts(searchQuery: 'burns');
        expect(r.videos.single.isShort, isTrue);
        expect(r.hasMore, isFalse);
      }, () => client);
      expect(asked.single.path, endsWith('videos/search'));
      expect(asked.single.queryParameters, containsPair('q', 'burns'));
      expect(asked.single.queryParameters, containsPair('kind', 'short'));
    });

    test('Backend down: the hand-checked videos, listed once (no endless repeats)', () async {
      final client = MockClient((req) async => http.Response('down', 503));
      await http.runWithClient(() async {
        final seen = <String>[];
        String? token;
        var page = 0;
        do {
          final r = await ClinicalVideoRepository.fetchMasterclasses(
              pageIndex: page++, pageSize: 5, pageToken: token, category: 'Offline test');
          seen.addAll(r.videos.map((v) => v.youtubeId));
          token = r.nextPageToken;
        } while (token != null && page < 20);
        expect(seen, isEmpty); // unknown topic: nothing, rather than unrelated videos
        final all = await ClinicalVideoRepository.fetchMasterclasses(pageIndex: 0, pageSize: 50, searchQuery: 'zzz-none');
        expect(all.videos, isEmpty);
        final firstAid = await ClinicalVideoRepository.fetchMasterclasses(pageIndex: 0, pageSize: 50, category: 'First Aid & CPR');
        expect(firstAid.videos, isNotEmpty);
        expect(firstAid.videos.map((v) => v.youtubeId).toSet().length, firstAid.videos.length);
        expect(firstAid.hasMore, isFalse);
      }, () => client);
    });
  });

  group('Shorts playback', () {
    test('Two players: the hidden one preloads the next clip and a swipe swaps them', () {
      final shorts = ClinicalVideoRepository.verifiedShorts;
      final created = <String>[];
      final fakes = <FakeYoutubePlayerController>[];
      final playback = ShortsPlayback(
        shorts: shorts,
        initialIndex: 0,
        controllerFactory: (videoId) {
          created.add(videoId);
          final f = FakeYoutubePlayerController();
          fakes.add(f);
          return f;
        },
      );

      // player 0 shows clip 0, player 1 starts loading clip 1 straight away
      expect(created, [shorts[0].youtubeId, shorts[1].youtubeId]);
      expect(playback.activePlayer, 0);

      // the hidden player started playing its clip: it is paused at the start (buffered, silent)
      playback.onPlayerState(1, PlayerState.playing);
      expect(fakes[1].isPlaying, isFalse);
      expect(fakes[1].seekSeconds, 0);
      // the visible player is left alone
      fakes[0].isPlaying = true;
      playback.onPlayerState(0, PlayerState.playing);
      expect(fakes[0].isPlaying, isTrue);

      // swipe to clip 1: no new load, just a swap; the freed player preloads clip 2
      playback.show(1);
      expect(playback.activePlayer, 1);
      expect(fakes[1].isPlaying, isTrue);
      expect(fakes[1].loaded, isEmpty);
      expect(fakes[0].loaded, [shorts[2].youtubeId]);
      expect(playback.controller, same(fakes[1]));

      // jump back to clip 0 (not preloaded): loaded into the visible player, clip 1 preloaded again
      playback.show(0);
      expect(fakes[1].loaded, [shorts[0].youtubeId]);
      expect(fakes[0].loaded.last, shorts[1].youtubeId);
      expect(created, hasLength(2)); // never more than two players

      playback.dispose();
      expect(fakes.every((f) => f.closed), isTrue);
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
