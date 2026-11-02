import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

import '../models/clinical_video.dart';
import '../widgets/resource_media.dart';
import '../widgets/video_engagement.dart';
import '../widgets/video_widgets.dart';
import 'video_player_screen.dart';
import 'video_search_screen.dart';
import 'video_shorts_screen.dart';

export '../widgets/shorts_controller_pool.dart';
export 'video_shorts_screen.dart' show ShortsPlayerModal, VideoShortsScreen;

/// Legacy export alias for router & category compatibility.
typedef VideoLibraryScreen = VideoTutorialsScreen;

/// VitaNet Learn: a YouTube-style home feed for the verified clinical video
/// catalog, with topic chips, a Shorts shelf and its own tab bar.
class VideoTutorialsScreen extends ConsumerStatefulWidget {
  /// Optional topic chip to open on (e.g. 'First aid').
  final String initialTopic;

  const VideoTutorialsScreen({super.key, this.initialTopic = 'All'});

  @override
  ConsumerState<VideoTutorialsScreen> createState() => _VideoTutorialsScreenState();
}

class _VideoTutorialsScreenState extends ConsumerState<VideoTutorialsScreen> {
  final ScrollController _scrollController = ScrollController();
  final _store = VideoEngagementStore.instance;

  static const _topics = <String>[
    'All',
    'First aid',
    'Heart',
    'Mental health',
    'Nutrition',
    'Fitness',
    'Sleep',
    'Recently uploaded',
  ];

  /// Topic chip -> repository category.
  static const _topicCategory = <String, String>{
    'First aid': 'First Aid & CPR',
    'Heart': 'Cardio & Vitals',
    'Mental health': 'Guided Breathing',
    'Nutrition': 'Nutrition & Sleep',
    'Fitness': 'Physical Therapy',
    'Sleep': 'Nutrition & Sleep',
  };

  late String _topic;
  int _tab = 0; // 0 Home, 2 Channels, 3 Saved (Shorts opens full screen)

  List<ClinicalVideo> _videos = [];
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _nextPageToken;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _topic = _topics.contains(widget.initialTopic) ? widget.initialTopic : 'All';
    _loadInitialVideos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String get _category => _topicCategory[_topic] ?? 'All';

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore || _tab != 0) return;
    if (_scrollController.position.extentAfter < 400) _fetchMoreVideos();
  }

  Future<void> _loadInitialVideos() async {
    setState(() {
      _isLoadingInitial = true;
      _currentPage = 0;
      _hasMore = true;
    });
    try {
      final res = await ClinicalVideoRepository.fetchMasterclasses(
        pageIndex: 0,
        pageSize: _pageSize,
        category: _category,
      );
      if (!mounted) return;
      final unique = <String>{};
      setState(() {
        _videos = res.videos.where((v) => unique.add(v.youtubeId)).toList();
        _nextPageToken = res.nextPageToken;
        _hasMore = res.hasMore;
        _isLoadingInitial = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videos = List.of(ClinicalVideoRepository.verifiedMasterclasses);
        _hasMore = false;
        _isLoadingInitial = false;
      });
    }
  }

  Future<void> _fetchMoreVideos() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final res = await ClinicalVideoRepository.fetchMasterclasses(
        pageIndex: _currentPage + 1,
        pageSize: _pageSize,
        category: _category,
        pageToken: _nextPageToken,
      );
      if (!mounted) return;
      final known = _videos.map((v) => v.youtubeId).toSet();
      final fresh = res.videos.where((v) => known.add(v.youtubeId)).toList();
      setState(() {
        _videos.addAll(fresh);
        _currentPage++;
        _nextPageToken = res.nextPageToken;
        // The curated pool cycles; stop once a page brings nothing new.
        _hasMore = res.hasMore && fresh.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onTopicSelected(String topic) {
    if (_topic == topic) return;
    setState(() => _topic = topic);
    _loadInitialVideos();
  }

  bool _matchesTopicKeywords(ClinicalVideo v) {
    final text = '${v.title} ${v.keyTakeaways.join(' ')}'.toLowerCase();
    switch (_topic) {
      case 'Sleep':
        return text.contains('sleep') || text.contains('circadian') || text.contains('melatonin');
      case 'Nutrition':
        return !(text.contains('sleep') || text.contains('circadian') || text.contains('melatonin'));
      default:
        return true;
    }
  }

  static int _ageInDays(String ago) {
    final m = RegExp(r'(\d+)\s*(\w+)').firstMatch(ago.toLowerCase());
    if (m == null) return 1 << 20;
    final n = int.tryParse(m.group(1)!) ?? 0;
    final unit = m.group(2)!;
    if (unit.startsWith('h')) return 0;
    if (unit.startsWith('d')) return n;
    if (unit.startsWith('w')) return n * 7;
    if (unit.startsWith('mo')) return n * 30;
    if (unit.startsWith('y')) return n * 365;
    return n;
  }

  List<ClinicalVideo> get _feed {
    var list = _videos.where((v) => !_store.isHidden(v.youtubeId) && _matchesTopicKeywords(v)).toList();
    if (_topic == 'Recently uploaded') {
      list.sort((a, b) => _ageInDays(a.publishedAgo).compareTo(_ageInDays(b.publishedAgo)));
    }
    return list;
  }

  List<ClinicalVideo> get _shorts {
    var list = ClinicalVideoRepository.verifiedShorts.where((v) => !_store.isHidden(v.youtubeId));
    final cat = _topicCategory[_topic];
    if (cat != null) {
      list = list.where((v) {
        final vCat = v.category.toLowerCase();
        if (cat == 'First Aid & CPR') return vCat.contains('first aid') || vCat.contains('trauma');
        return vCat == cat.toLowerCase() && _matchesTopicKeywords(v);
      });
    }
    return list.toList();
  }

  void _openVideo(ClinicalVideo v) => VideoPlayerScreen.openClinical(context, v, related: _videos);

  void _openShorts({int initialIndex = 0, List<ClinicalVideo>? list}) {
    final shorts = list ?? _shorts;
    final source = shorts.isEmpty ? ClinicalVideoRepository.verifiedShorts : shorts;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => VideoShortsScreen(shorts: source, initialIndex: initialIndex)),
    );
  }

  void _openSearch([String query = '']) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => VideoSearchScreen(initialQuery: query)),
    );
  }

  List<ClinicalVideo> get _notificationItems {
    final all = [...ClinicalVideoRepository.verifiedMasterclasses]
      ..sort((a, b) => _ageInDays(a.publishedAgo).compareTo(_ageInDays(b.publishedAgo)));
    return all.take(2).toList();
  }

  void _openNotifications() {
    _store.markNotificationsSeen();
    final items = _notificationItems;
    showVnSheet<void>(
      context,
      builder: (ctx) {
        final p = VnPalette.of(ctx);
        return VnSheet(
          gap: 12,
          children: [
            Text('Notifications', style: VnText.heading(18, weight: FontWeight.w700, color: p.ink)),
            for (final v in items)
              VideoListRow(
                video: v,
                thumbWidth: 120,
                thumbHeight: 68,
                onTap: () {
                  Navigator.pop(ctx);
                  _openVideo(v);
                },
              ),
          ],
        );
      },
    );
  }

  void _openTopicExplorer() {
    showVnSheet<void>(
      context,
      builder: (ctx) {
        final p = VnPalette.of(ctx);
        return VnSheet(
          children: [
            Text('Explore topics', style: VnText.heading(18, weight: FontWeight.w700, color: p.ink)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _topics)
                  VnInkChip(
                    label: t,
                    selected: t == _topic,
                    flat: true,
                    radius: 8,
                    onTap: () {
                      Navigator.pop(ctx);
                      _onTopicSelected(t);
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Scaffold(
      backgroundColor: p.surface,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            switch (_tab) {
              case 2:
                return _ChannelsTab(onOpenChannel: _openSearch);
              case 3:
                return _SavedTab(onOpen: _openVideo);
              default:
                return _buildHome(p);
            }
          },
        ),
      ),
      bottomNavigationBar: _LearnTabBar(
        index: _tab,
        onSelect: (i) {
          if (i == 1) {
            _openShorts();
            return;
          }
          setState(() => _tab = i);
        },
      ),
    );
  }

  Widget _buildHeader(VnPalette p) {
    final unseen = !_store.notificationsSeen;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 6),
        child: Row(
          children: [
            VnIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Back to resources',
              iconSize: 26,
              size: 44,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Semantics(
                header: true,
                label: 'VitaNet Learn',
                excludeSemantics: true,
                child: Row(
                  children: [
                    const VitaNetLogo(size: 26),
                    const SizedBox(width: 6),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'VitaNet '),
                        TextSpan(text: 'Learn', style: TextStyle(color: p.brand)),
                      ]),
                      style: VnText.heading(19, color: p.ink, letterSpacing: -0.4),
                    ),
                  ],
                ),
              ),
            ),
            VnIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              onPressed: _openNotifications,
              badge: unseen
                  ? Positioned(
                      top: 6,
                      right: 4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text('${_notificationItems.length}',
                            style: VnText.body(10, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    )
                  : null,
            ),
            VnIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Search videos',
              onPressed: () => _openSearch(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHome(VnPalette p) {
    final feed = _feed;
    final shorts = _shorts;
    final top = feed.take(2).toList();
    final more = feed.skip(2).toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) => handleScrollNotification(n, ref),
      child: RefreshIndicator(
        color: p.brand,
        onRefresh: _loadInitialVideos,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(p)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  children: [
                    Tooltip(
                      message: 'Explore topics',
                      child: Semantics(
                        button: true,
                        label: 'Explore topics',
                        child: Material(
                          color: p.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _openTopicExplorer,
                            child: SizedBox(
                              width: 44,
                              height: 34,
                              child: Icon(Icons.explore_outlined, size: 18, color: p.ink),
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final t in _topics) ...[
                      const SizedBox(width: 8),
                      VnInkChip(
                        label: t,
                        selected: t == _topic,
                        flat: true,
                        height: 34,
                        radius: 8,
                        onTap: () => _onTopicSelected(t),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isLoadingInitial)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: p.brand)),
                ),
              )
            else if (feed.isEmpty && shorts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  child: Column(
                    children: [
                      Icon(Icons.video_library_outlined, size: 40, color: p.faint),
                      const SizedBox(height: 10),
                      Text('No videos in "$_topic" yet',
                          style: VnText.body(15, weight: FontWeight.w600, color: p.muted)),
                    ],
                  ),
                ),
              )
            else ...[
              SliverList.list(
                children: [
                  for (final v in top)
                    VideoFeedCard(
                      video: v,
                      onTap: () => _openVideo(v),
                      onMore: () => showVideoOptionsSheet(context, v),
                    ),
                ],
              ),
              if (shorts.isNotEmpty) SliverToBoxAdapter(child: _buildShortsShelf(p, shorts)),
              SliverList.builder(
                itemCount: more.length,
                itemBuilder: (context, i) => VideoFeedCard(
                  video: more[i],
                  onTap: () => _openVideo(more[i]),
                  onMore: () => showVideoOptionsSheet(context, more[i]),
                ),
              ),
            ],
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: p.brand)),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildShortsShelf(VnPalette p, List<ClinicalVideo> shorts) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 18),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: p.surfaceAlt, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Semantics(header: true, child: Text('Shorts', style: VnText.heading(18, color: p.ink))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: shorts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _ShortCard(
                short: shorts[i],
                onTap: () => _openShorts(initialIndex: i, list: shorts),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortCard extends StatelessWidget {
  final ClinicalVideo short;
  final VoidCallback onTap;
  const _ShortCard({required this.short, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${short.title}, ${videoViews(short)}',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 172,
          child: Material(
            color: Colors.black,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VnNetworkPhoto(
                    url: short.shortsThumbnailUrl,
                    fallbackAsset: videoFallbackPhoto(short),
                    cacheWidth: 400,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.5, 1],
                        colors: [Color(0x00000000), Color(0xBF000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(short.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: VnText.body(14, weight: FontWeight.w700, color: Colors.white, height: 1.3)),
                        const SizedBox(height: 4),
                        Text(videoViews(short), style: VnText.body(12, color: const Color(0xFFE2E8F0))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LearnTabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _LearnTabBar({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'Home'),
      (Icons.bolt_outlined, Icons.bolt_rounded, 'Shorts'),
      (Icons.subscriptions_outlined, Icons.subscriptions_rounded, 'Channels'),
      (Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'Saved'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: items[i].$3,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(i == index ? items[i].$2 : items[i].$1, size: 22, color: p.ink),
                          const SizedBox(height: 3),
                          Text(items[i].$3,
                              style: VnText.body(10,
                                  weight: i == index ? FontWeight.w600 : FontWeight.w500, color: p.ink)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelsTab extends StatelessWidget {
  final ValueChanged<String> onOpenChannel;
  const _ChannelsTab({required this.onOpenChannel});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final store = VideoEngagementStore.instance;
    final counts = <String, int>{};
    final sample = <String, ClinicalVideo>{};
    for (final v in [...ClinicalVideoRepository.verifiedMasterclasses, ...ClinicalVideoRepository.verifiedShorts]) {
      counts[v.channelName] = (counts[v.channelName] ?? 0) + 1;
      sample.putIfAbsent(v.channelName, () => v);
    }
    final channels = counts.keys.toList()
      ..sort((a, b) {
        final sa = store.isSubscribed(a) ? 0 : 1;
        final sb = store.isSubscribed(b) ? 0 : 1;
        return sa != sb ? sa - sb : a.compareTo(b);
      });
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text('Channels', style: VnText.heading(22, color: p.ink)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
          child: Text('Verified clinical sources in VitaNet Learn',
              style: VnText.body(14, color: p.muted)),
        ),
        for (final c in channels)
          InkWell(
            onTap: () => onOpenChannel(c),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  ChannelAvatar(channel: c, code: sample[c]!.channelAvatarUrl, size: 48, fontSize: 15),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c, style: VnText.body(15, weight: FontWeight.w700, color: p.ink)),
                        Text('${counts[c]} ${counts[c] == 1 ? 'video' : 'videos'} · ${sample[c]!.category}',
                            style: VnText.body(12, color: p.muted)),
                      ],
                    ),
                  ),
                  SubscribeButton(
                    subscribed: store.isSubscribed(c),
                    onTap: () => store.toggleSubscribe(c),
                    fontSize: 13,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SavedTab extends StatelessWidget {
  final ValueChanged<ClinicalVideo> onOpen;
  const _SavedTab({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final store = VideoEngagementStore.instance;
    final watchLater = store.watchLater;
    final saved = store.saved;
    final all = [...ClinicalVideoRepository.verifiedMasterclasses, ...ClinicalVideoRepository.verifiedShorts];
    final seen = <String>{};
    final liked = all.where((v) => store.isLiked(v.youtubeId) && seen.add(v.youtubeId)).toList();

    Widget section(String title, List<ClinicalVideo> items, String empty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 10),
            child: Semantics(header: true, child: Text(title, style: VnText.heading(16, color: p.ink))),
          ),
          if (items.isEmpty)
            Text(empty, style: VnText.body(13, color: p.muted))
          else
            for (final v in items) ...[
              VideoListRow(
                video: v,
                thumbWidth: 140,
                thumbHeight: 79,
                onTap: () => onOpen(v),
                onMore: () => showVideoOptionsSheet(context, v),
              ),
              const SizedBox(height: 12),
            ],
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: Text('Saved', style: VnText.heading(22, color: p.ink)),
        ),
        section('Watch later', watchLater, 'Use "Save to Watch later" from any video\'s menu.'),
        section('Clinical bookmarks', saved, 'Videos you bookmark appear here.'),
        section('Liked videos', liked, 'Videos you like appear here.'),
      ],
    );
  }
}
