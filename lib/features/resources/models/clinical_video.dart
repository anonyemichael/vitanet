import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:vitanet/core/network/backend.dart';
import 'package:http/http.dart' as http;
import 'health_video.dart';

/// Clinical video model representing verified medical tutorials, masterclasses, and shorts.
class ClinicalVideo {
  final String youtubeId;
  final String title;
  final String channelName;
  final String channelAvatarUrl;
  final bool isVerifiedChannel;
  final String
  category; // 'Physical Therapy', 'Cardio & Vitals', 'First Aid & CPR', 'Trauma', 'Guided Breathing', 'Nutrition & Sleep'
  final int durationSeconds;
  final String formattedDuration;
  final String viewsCount;
  final String publishedAgo;
  final bool isShort; // true when <= 60s
  final List<String> keyTakeaways;

  const ClinicalVideo({
    required this.youtubeId,
    String? id,
    required this.title,
    required this.channelName,
    required this.channelAvatarUrl,
    this.isVerifiedChannel = true,
    required this.category,
    required this.durationSeconds,
    required this.formattedDuration,
    required this.viewsCount,
    required this.publishedAgo,
    required this.isShort,
    required this.keyTakeaways,
  }) : _legacyId = id;

  final String? _legacyId;

  /// Backward compatibility getter
  String get id => _legacyId ?? youtubeId;

  /// Standard 16:9 thumbnail deterministically computed
  String get thumbnailUrl => 'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg';

  /// 9:16 Shorts thumbnail deterministically computed (falls back to hqdefault.jpg with BoxFit.cover)
  String get shortsThumbnailUrl => 'https://i.ytimg.com/vi/$youtubeId/oar2.jpg';

  /// High-resolution thumbnail when available
  String get highResThumbnailUrl =>
      'https://i.ytimg.com/vi/$youtubeId/maxresdefault.jpg';

  /// Fallback to HealthVideo model for legacy compatibility
  HealthVideo toHealthVideo() {
    return HealthVideo(
      videoId: youtubeId,
      title: title,
      category: category,
      organization: channelName,
      duration: formattedDuration,
      thumbnailUrl: thumbnailUrl,
      summary: keyTakeaways.isNotEmpty ? keyTakeaways.join('. ') : title,
      keySteps: keyTakeaways.asMap().entries.map((e) {
        final minutes = e.key + 1;
        return VideoKeyStep(time: '0$minutes:00', action: e.value);
      }).toList(),
      verificationStatus: isVerifiedChannel
          ? 'Verified Clinical Source'
          : 'Community Guide',
    );
  }
}

/// Paginated result response wrapper for infinite scrolling
class PaginatedVideosResponse {
  final List<ClinicalVideo> videos;
  final String? nextPageToken;
  final bool hasMore;

  const PaginatedVideosResponse({
    required this.videos,
    this.nextPageToken,
    this.hasMore = true,
  });
}

/// Production hybrid video repository uniting verified curated clinical videos
/// with live YouTube Data API v3 search & pagination and in-memory quota caching.
class ClinicalVideoRepository {
  // In-memory LRU-style cache for search queries to ensure 0 duplicate API quota cost
  static final Map<String, List<ClinicalVideo>> _searchCache = {};
  static final Map<String, String?> _searchNextPageTokens = {};

  // Catalog audit (Nov 2026): every title, channel and duration below was
  // checked against YouTube oEmbed / the watch page for its ID. View counts
  // and "published ago" values are not stored because they change over time
  // and could not be verified; the UI hides them when empty.

  /// Verified YouTube Shorts (duration <= 60 seconds, or just over for the
  /// short-form clips published as Shorts by the channel).
  static final List<ClinicalVideo> verifiedShorts = [
    const ClinicalVideo(
      youtubeId: 'IRP5dgOB42U',
      title: 'What is an abnormal heart rate and is it dangerous?',
      channelName: 'British Heart Foundation',
      channelAvatarUrl: 'BHF',
      isVerifiedChannel: true,
      category: 'Cardio & Vitals',
      durationSeconds: 37,
      formattedDuration: '0:37',
      viewsCount: '',
      publishedAgo: '',
      isShort: true,
      keyTakeaways: [],
    ),
    const ClinicalVideo(
      youtubeId: 'P18Id5CLzBE',
      title: '3 best exercises for a healthy heart',
      channelName: 'British Heart Foundation',
      channelAvatarUrl: 'BHF',
      isVerifiedChannel: true,
      category: 'Cardio & Vitals',
      durationSeconds: 53,
      formattedDuration: '0:53',
      viewsCount: '',
      publishedAgo: '',
      isShort: true,
      keyTakeaways: [],
    ),
    const ClinicalVideo(
      youtubeId: 'kFY--rPwMFY',
      title: "Anthony's experience of panic disorder | NHS Talking Therapies",
      channelName: 'NHS',
      channelAvatarUrl: 'NHS',
      isVerifiedChannel: true,
      category: 'Guided Breathing',
      durationSeconds: 53,
      formattedDuration: '0:53',
      viewsCount: '',
      publishedAgo: '',
      isShort: true,
      keyTakeaways: [],
    ),
    const ClinicalVideo(
      youtubeId: 'djNFiWcxofM',
      title: 'Heat exhaustion in sports.',
      channelName: 'Cleveland Clinic',
      channelAvatarUrl: 'CC',
      isVerifiedChannel: true,
      category: 'First Aid & CPR',
      durationSeconds: 55,
      formattedDuration: '0:55',
      viewsCount: '',
      publishedAgo: '',
      isShort: true,
      keyTakeaways: [],
    ),
    const ClinicalVideo(
      youtubeId: 'DrCIrl9WBls',
      title: 'Are eggs good or bad for cholesterol?',
      channelName: 'British Heart Foundation',
      channelAvatarUrl: 'BHF',
      isVerifiedChannel: true,
      category: 'Nutrition & Sleep',
      durationSeconds: 52,
      formattedDuration: '0:52',
      viewsCount: '',
      publishedAgo: '',
      isShort: true,
      keyTakeaways: [],
    ),
    const ClinicalVideo(
      youtubeId: 'YO_RJLyu9to',
      title: 'If your joints hurt, you should avoid exercise?',
      channelName: 'Cleveland Clinic',
      channelAvatarUrl: 'CC',
      isVerifiedChannel: true,
      category: 'Physical Therapy',
      durationSeconds: 31,
      formattedDuration: '0:31',
      viewsCount: '',
      publishedAgo: '',
      isShort: true,
      keyTakeaways: [],
    ),
    const ClinicalVideo(
      youtubeId: 'dtJErRKjtG8',
      title: 'IBS diet tips | NHS',
      channelName: 'NHS',
      channelAvatarUrl: 'NHS',
      isVerifiedChannel: true,
      category: 'Nutrition & Sleep',
      durationSeconds: 51,
      formattedDuration: '0:51',
      viewsCount: '',
      publishedAgo: '',
      isShort: true,
      keyTakeaways: [],
    ),
    const ClinicalVideo(
      youtubeId: '1QElp8toGcg',
      title: 'How to measure your waist',
      channelName: 'British Heart Foundation',
      channelAvatarUrl: 'BHF',
      isVerifiedChannel: true,
      category: 'Cardio & Vitals',
      durationSeconds: 40,
      formattedDuration: '0:40',
      viewsCount: '',
      publishedAgo: '',
      isShort: true,
      keyTakeaways: [],
    ),
    const ClinicalVideo(
      youtubeId: 'FCpVck1RSvI',
      title: 'How to start exercising: 3 tips for beginners',
      channelName: 'British Heart Foundation',
      channelAvatarUrl: 'BHF',
      isVerifiedChannel: true,
      category: 'Physical Therapy',
      durationSeconds: 63,
      formattedDuration: '1:03',
      viewsCount: '',
      publishedAgo: '',
      isShort: true,
      keyTakeaways: [],
    ),
    const ClinicalVideo(
      youtubeId: 'y-y4O5yNAGo',
      title: 'How much exercise do you need?',
      channelName: 'British Heart Foundation',
      channelAvatarUrl: 'BHF',
      isVerifiedChannel: true,
      category: 'Physical Therapy',
      durationSeconds: 78,
      formattedDuration: '1:18',
      viewsCount: '',
      publishedAgo: '',
      isShort: true,
      keyTakeaways: [],
    ),
  ];

  /// Verified long-form videos (titles/channels as published on YouTube).
  static final List<ClinicalVideo> verifiedMasterclasses = [
    const ClinicalVideo(
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
      keyTakeaways: [
        'Check the scene is safe and whether the person responds and is breathing normally',
        'Call emergency services straight away, ideally on speakerphone',
        'Push hard and fast in the centre of the chest, about 100-120 compressions a minute',
        'Use an AED as soon as one arrives and follow its voice prompts',
      ],
    ),
    const ClinicalVideo(
      youtubeId: 'GmqXqwSV3bo',
      title: 'The Recovery Position - First Aid Training - St John Ambulance',
      channelName: 'St John Ambulance',
      channelAvatarUrl: 'SJ',
      isVerifiedChannel: true,
      category: 'First Aid & CPR',
      durationSeconds: 152,
      formattedDuration: '2:32',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'Use the recovery position for someone unresponsive who is breathing normally',
        'Roll them onto their side and tilt the head back to keep the airway open',
        'Call for emergency help and keep checking their breathing',
      ],
    ),
    const ClinicalVideo(
      youtubeId: 'PA9hpOnvtCk',
      title:
          'What To Do When Someone Is Choking - First Aid Training - St John Ambulance',
      channelName: 'St John Ambulance',
      channelAvatarUrl: 'SJ',
      isVerifiedChannel: true,
      category: 'First Aid & CPR',
      durationSeconds: 145,
      formattedDuration: '2:25',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'Encourage them to cough if they can',
        'Give up to 5 back blows between the shoulder blades, then up to 5 abdominal thrusts',
        'Call emergency services if the blockage does not clear',
      ],
    ),
    const ClinicalVideo(
      youtubeId: 'NxO5LvgqZe0',
      title:
          'How to Treat Severe Bleeding - First Aid Training - St John Ambulance',
      channelName: 'St John Ambulance',
      channelAvatarUrl: 'SJ',
      isVerifiedChannel: true,
      category: 'Trauma',
      durationSeconds: 268,
      formattedDuration: '4:28',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'Apply firm, direct pressure to the wound',
        'Call emergency services for severe bleeding',
        'Secure a dressing and watch for signs of shock',
      ],
    ),
    const ClinicalVideo(
      youtubeId: '2v8vlXgGXwE',
      title:
          'How To Treat A Fracture & Fracture Types - First Aid Training - St John Ambulance',
      channelName: 'St John Ambulance',
      channelAvatarUrl: 'SJ',
      isVerifiedChannel: true,
      category: 'Trauma',
      durationSeconds: 172,
      formattedDuration: '2:52',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'Keep the injured part still and supported in the position found',
        'Do not try to straighten a suspected fracture',
        'Get medical help; call emergency services for open or serious fractures',
      ],
    ),
    const ClinicalVideo(
      youtubeId: 'tEmt1Znux58',
      title:
          'Box breathing relaxation technique: how to calm feelings of stress or anxiety',
      channelName: 'Sunnybrook Hospital',
      channelAvatarUrl: 'SH',
      isVerifiedChannel: true,
      category: 'Guided Breathing',
      durationSeconds: 167,
      formattedDuration: '2:47',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'Breathe in for 4, hold for 4, breathe out for 4, hold for 4',
        'Repeat the cycle slowly to help calm feelings of stress or anxiety',
      ],
    ),
    const ClinicalVideo(
      youtubeId: 'wWGulLAa0O0',
      title: 'What happens inside your body when you exercise?',
      channelName: 'British Heart Foundation',
      channelAvatarUrl: 'BHF',
      isVerifiedChannel: true,
      category: 'Cardio & Vitals',
      durationSeconds: 153,
      formattedDuration: '2:33',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [],
    ),
    const ClinicalVideo(
      youtubeId: 'BHY0FxzoKZE',
      title: 'The Brain-Changing Benefits of Exercise | Wendy Suzuki | TED',
      channelName: 'TED',
      channelAvatarUrl: 'TED',
      isVerifiedChannel: true,
      category: 'Physical Therapy',
      durationSeconds: 783,
      formattedDuration: '13:03',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'A single workout can lift mood and improve focus',
        'Regular exercise supports the hippocampus, a brain area important for memory',
      ],
    ),
    const ClinicalVideo(
      youtubeId: 'aUaInS6HIGo',
      title:
          '23 and 1/2 hours: What is the single best thing we can do for our health?',
      channelName: 'DocMikeEvans',
      channelAvatarUrl: 'DM',
      isVerifiedChannel: false,
      category: 'Physical Therapy',
      durationSeconds: 558,
      formattedDuration: '9:18',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'Limiting sitting and moving for about 30 minutes a day, such as walking, has wide health benefits',
      ],
    ),
    const ClinicalVideo(
      youtubeId: 'WuyPuH9ojCE',
      title: 'How stress affects your brain - Madhumita Murgia',
      channelName: 'TED-Ed',
      channelAvatarUrl: 'TE',
      isVerifiedChannel: true,
      category: 'Guided Breathing',
      durationSeconds: 256,
      formattedDuration: '4:16',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'Long-term stress keeps cortisol levels high, which can affect memory and mood',
        'Exercise and meditation can help reduce the effects of stress',
      ],
    ),
    const ClinicalVideo(
      youtubeId: 'inpok4MKVLM',
      title: '5-Minute Meditation You Can Do Anywhere | Goodful',
      channelName: 'Goodful',
      channelAvatarUrl: 'GF',
      isVerifiedChannel: false,
      category: 'Guided Breathing',
      durationSeconds: 317,
      formattedDuration: '5:17',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'A short guided meditation focused on slow, steady breathing',
      ],
    ),
    const ClinicalVideo(
      youtubeId: 'DxIDKZHW3-E',
      title: 'We All Have Mental Health',
      channelName: 'Anna Freud',
      channelAvatarUrl: 'AF',
      isVerifiedChannel: true,
      category: 'Guided Breathing',
      durationSeconds: 339,
      formattedDuration: '5:39',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'Everyone has mental health, and it can change over time',
        'Talking to someone you trust is a good first step when things feel hard',
      ],
    ),
    const ClinicalVideo(
      youtubeId: 'gedoSfZvBgE',
      title: "The benefits of a good night's sleep - Shai Marcu",
      channelName: 'TED-Ed',
      channelAvatarUrl: 'TE',
      isVerifiedChannel: true,
      category: 'Nutrition & Sleep',
      durationSeconds: 345,
      formattedDuration: '5:45',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'Sleep moves through several stages each night',
        'Good sleep supports memory, and missing sleep affects how we think and feel',
      ],
    ),
    const ClinicalVideo(
      youtubeId: '5MuIMqhT8DM',
      title: 'Sleep Is Your Superpower | Matt Walker | TED',
      channelName: 'TED',
      channelAvatarUrl: 'TED',
      isVerifiedChannel: true,
      category: 'Nutrition & Sleep',
      durationSeconds: 1158,
      formattedDuration: '19:18',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        'Lack of sleep harms learning, memory and the immune system',
        'Keep a regular sleep schedule and a cool bedroom',
      ],
    ),
    const ClinicalVideo(
      youtubeId: '3dqXHHCc5lA',
      title:
          'The surprisingly dramatic role of nutrition in mental health | Julia Rucklidge | TEDxChristchurch',
      channelName: 'TEDx Talks',
      channelAvatarUrl: 'TX',
      isVerifiedChannel: false,
      category: 'Nutrition & Sleep',
      durationSeconds: 1063,
      formattedDuration: '17:43',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: ['Diet quality and nutrients play a role in mental health'],
    ),
    const ClinicalVideo(
      youtubeId: 'lEXBxijQREo',
      title: 'How sugar affects the brain - Nicole Avena',
      channelName: 'TED-Ed',
      channelAvatarUrl: 'TE',
      isVerifiedChannel: true,
      category: 'Nutrition & Sleep',
      durationSeconds: 303,
      formattedDuration: '5:03',
      viewsCount: '',
      publishedAgo: '',
      isShort: false,
      keyTakeaways: [
        "Sugar activates the brain's reward system",
        'Eating a lot of added sugar regularly can make cravings stronger',
      ],
    ),
  ];

  /// Health videos from the VitaNet backend (`GET /videos/feed`, `GET /videos/search`): the newest uploads of
  /// trusted health channels, read from YouTube on the server and kept there, so a page answers fast and no
  /// YouTube key is ever inside the app. [pageToken] is the backend's cursor. When the backend cannot be
  /// reached, the hand-checked videos above are shown instead (no repeats: they are listed once).
  static Future<PaginatedVideosResponse> fetchMasterclasses({
    required int pageIndex,
    required int pageSize,
    String? category,
    String? searchQuery,
    String? pageToken,
    bool shorts = false,
  }) async {
    final query = searchQuery?.trim() ?? '';
    final topic = (category != null && category != 'All') ? category : null;
    final cursor = int.tryParse(pageToken ?? '') ?? (pageIndex * pageSize);
    final cacheKey = '${shorts ? 's' : 'l'}|${query.toLowerCase()}|${topic ?? 'all'}|$cursor|$pageSize';
    final cached = _searchCache[cacheKey];
    if (cached != null) {
      final next = _searchNextPageTokens[cacheKey];
      return PaginatedVideosResponse(videos: cached, nextPageToken: next, hasMore: next != null);
    }
    try {
      final params = {
        if (query.isNotEmpty) 'q': query,
        if (query.isEmpty && topic != null) 'topic': topic,
        'kind': shorts ? 'short' : 'long',
        'cursor': '$cursor',
        'limit': '$pageSize',
      };
      final uri = BackendConfig.uri(query.isNotEmpty ? 'videos/search' : 'videos/feed').replace(queryParameters: params);
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('videos ${res.statusCode}');
      final data = json.decode(res.body) as Map<String, dynamic>;
      final videos = [
        for (final j in (data['videos'] as List? ?? const []))
          if (j is Map) fromBackend(Map<String, dynamic>.from(j)),
      ];
      final next = data['next_cursor'] == null ? null : '${data['next_cursor']}';
      _searchCache[cacheKey] = videos;
      _searchNextPageTokens[cacheKey] = next;
      return PaginatedVideosResponse(videos: videos, nextPageToken: next, hasMore: next != null);
    } catch (e) {
      debugPrint('Videos: backend unavailable, showing the hand-checked list ($e)');
      return _curatedPage(shorts ? verifiedShorts : verifiedMasterclasses, topic, query, cursor, pageSize);
    }
  }

  /// Shorts (60 s or less) for the Shorts shelf and the swipe feed.
  static Future<PaginatedVideosResponse> fetchShorts({String? category, String? searchQuery, String? pageToken,
          int pageSize = 20}) =>
      fetchMasterclasses(pageIndex: 0, pageSize: pageSize, category: category, searchQuery: searchQuery,
          pageToken: pageToken, shorts: true);

  static PaginatedVideosResponse _curatedPage(
      List<ClinicalVideo> source, String? topic, String query, int cursor, int pageSize) {
    var pool = source.toList();
    if (topic != null) {
      final t = topic.toLowerCase();
      pool = pool.where((v) {
        final c = v.category.toLowerCase();
        if (t == 'trauma') return c.contains('trauma') || c.contains('first aid');
        return c.contains(t) || t.contains(c);
      }).toList();
    }
    if (query.isNotEmpty) {
      final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1);
      pool = pool.where((v) {
        final text = '${v.title} ${v.channelName} ${v.category} ${v.keyTakeaways.join(' ')}'.toLowerCase();
        return words.every(text.contains);
      }).toList();
    }
    final page = pool.skip(cursor).take(pageSize).toList();
    final more = cursor + pageSize < pool.length;
    return PaginatedVideosResponse(videos: page, nextPageToken: more ? '${cursor + pageSize}' : null, hasMore: more);
  }

  /// One video from the backend's JSON.
  static ClinicalVideo fromBackend(Map<String, dynamic> j) {
    final seconds = (j['duration_s'] as num?)?.toInt() ?? 0;
    final channel = '${j['channel'] ?? ''}';
    final views = (j['views'] as num?)?.toInt();
    final takeaways = [for (final t in (j['takeaways'] as List? ?? const [])) '$t'];
    return ClinicalVideo(
      youtubeId: '${j['id']}',
      title: _unescapeHtml('${j['title'] ?? ''}'),
      channelName: channel,
      channelAvatarUrl: _extractInitials(channel),
      isVerifiedChannel: j['verified'] == true,
      category: '${j['category'] ?? 'General health'}',
      durationSeconds: seconds,
      formattedDuration: formatDuration(seconds),
      viewsCount: views == null ? '' : '${formatCount(views)} views',
      publishedAgo: j['published_at'] == null ? '' : _formatRelativeTime('${j['published_at']}'),
      isShort: j['is_short'] == true,
      keyTakeaways: takeaways,
    );
  }

  static String formatDuration(int s) {
    if (s <= 0) return '';
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
    return '${h > 0 ? '$h:' : ''}$mm:${sec.toString().padLeft(2, '0')}';
  }

  static String formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }

  static String _unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  static String _extractInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'VN';
  }

  static String _formatRelativeTime(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return 'Just now';
    } catch (_) {
      return 'Recently';
    }
  }
}
