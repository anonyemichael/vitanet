import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/health_video.dart';
import '../widgets/resource_media.dart';
import '../widgets/video_engagement.dart';
import '../widgets/video_widgets.dart';
import 'video_search_screen.dart' show SubscribeButton;

/// YouTube-style watch page: real youtube_player_iframe playback, title and
/// meta, channel row, action pills, AI chapters, comments link and Up next.
/// Redesigned with clinical masterclass styling, verified badges, and
/// interactive protocol timeline stepper.
class VideoPlayerScreen extends StatefulWidget {
  final HealthVideo video;
  final String emergencyNumber;

  /// Catalog entry for [video] when opened from VitaNet Learn (adds views,
  /// age and channel data).
  final ClinicalVideo? source;

  /// Videos to offer under "Up next".
  final List<ClinicalVideo> related;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.emergencyNumber = '112',
    this.source,
    this.related = const [],
  });

  /// Opens the watch page for a catalog video.
  static Future<void> openClinical(
    BuildContext context,
    ClinicalVideo video, {
    List<ClinicalVideo> related = const [],
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          video: video.toHealthVideo(),
          source: video,
          related: related,
        ),
      ),
    );
  }

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final _store = VideoEngagementStore.instance;
  late HealthVideo _video;
  ClinicalVideo? _source;
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubeVideoState>? _stateSub;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  List<ClinicalVideo>? _cachedUpNext;
  bool _captions = false;
  bool _expanded = false;
  bool _hasPlaybackError = false;
  double _rate = 1;

  @override
  void initState() {
    super.initState();
    _video = widget.video;
    _source = widget.source;
    _startPlayback();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _controller?.close();
    _positionNotifier.dispose();
    super.dispose();
  }

  /// The catalog-shaped view of the current video (built from [HealthVideo]
  /// for callers outside the video library).
  ClinicalVideo get _clip =>
      _source ??
      ClinicalVideo(
        youtubeId: _video.videoId,
        title: _video.title,
        channelName: _video.organization,
        channelAvatarUrl: '',
        category: _video.category,
        durationSeconds: _parseDuration(_video.duration),
        formattedDuration: _video.duration,
        viewsCount: '',
        publishedAgo: '',
        isShort: false,
        keyTakeaways: _video.keySteps.map((s) => s.action).toList(),
      );

  static int _parseDuration(String text) {
    final parts = text.split(':');
    if (parts.length < 2) return 0;
    var total = 0;
    for (final part in parts) {
      final n = int.tryParse(part.trim());
      if (n == null) return 0;
      total = total * 60 + n;
    }
    return total;
  }

  bool get _isEmergencyTopic {
    final t = '${_video.category} ${_video.title}'.toLowerCase();
    return t.contains('first aid') || t.contains('cpr') || t.contains('trauma') || t.contains('bleed');
  }

  void _startPlayback({double startSeconds = 0}) {
    try {
      _stateSub?.cancel();
      _controller?.close();
      setState(() => _hasPlaybackError = false);
      final ctrl = YoutubePlayerController.fromVideoId(
        videoId: _video.videoId,
        autoPlay: true,
        startSeconds: startSeconds > 0 ? startSeconds : null,
        params: YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: _captions,
          mute: false,
          privacyEnhancedMode: true,
          strictRelatedVideos: true,
          origin: 'https://www.youtube-nocookie.com',
        ),
      );
      _stateSub = ctrl.videoStateStream.listen(_onState);
      ctrl.listen((value) {
        if (!mounted) return;
        if (value.hasError && !_hasPlaybackError) {
          setState(() => _hasPlaybackError = true);
        }
      });
      setState(() => _controller = ctrl);
    } catch (_) {
      _watchOnYouTube();
    }
  }

  void _onState(YoutubeVideoState state) {
    if (!mounted) return;
    _positionNotifier.value = state.position;
    final total = _clip.durationSeconds;
    if (total > 0) {
      _store.setProgress(_video.videoId, state.position.inSeconds / total);
    }
  }

  void _watchOnYouTube() {
    LaunchHelpers.openWeb(context, 'https://www.youtube.com/watch?v=${_video.videoId}');
  }

  void _changeVideo(ClinicalVideo next) {
    _stateSub?.cancel();
    _controller?.close();
    setState(() {
      _controller = null;
      _hasPlaybackError = false;
      _source = next;
      _video = next.toHealthVideo();
      _cachedUpNext = null;
      _expanded = false;
    });
    _positionNotifier.value = Duration.zero;
    _startPlayback();
  }

  void _toggleCaptions() {
    setState(() => _captions = !_captions);
    if (_controller != null) _startPlayback(startSeconds: _positionNotifier.value.inSeconds.toDouble());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_captions ? 'Captions enabled' : 'Captions disabled'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openSettings() {
    showVnSheet<void>(
      context,
      builder: (ctx) {
        final p = VnPalette.of(ctx);
        return VnSheet(
          gap: 8,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, color: p.brand, size: 22),
                const SizedBox(width: 10),
                Text('Playback Speed', style: VnText.heading(18, weight: FontWeight.w700, color: p.ink)),
              ],
            ),
            const SizedBox(height: 6),
            for (final r in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
              VnListRow(
                title: r == 1.0 ? 'Normal (1.0x)' : '${r}x',
                chevron: false,
                trailing: _rate == r ? Icon(Icons.check_circle_rounded, color: p.brand, size: 20) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _rate = r);
                  _controller?.setPlaybackRate(r);
                },
              ),
          ],
        );
      },
    );
  }

  List<ClinicalVideo> get _upNext {
    if (_cachedUpNext != null) return _cachedUpNext!;
    final id = _video.videoId;
    final pool = widget.related.isNotEmpty
        ? widget.related
        : ClinicalVideoRepository.verifiedMasterclasses;
    final seen = <String>{id};
    final list = <ClinicalVideo>[
      ..._store.queue.where((v) => seen.add(v.youtubeId)),
      ...pool.where((v) => !v.isShort && seen.add(v.youtubeId) && !_store.isHidden(v.youtubeId)),
    ];
    final cat = _video.category.toLowerCase();
    list.sort((a, b) {
      final aq = _store.queue.any((q) => q.youtubeId == a.youtubeId) ? 0 : 1;
      final bq = _store.queue.any((q) => q.youtubeId == b.youtubeId) ? 0 : 1;
      if (aq != bq) return aq - bq;
      final am = a.category.toLowerCase() == cat ? 0 : 1;
      final bm = b.category.toLowerCase() == cat ? 0 : 1;
      return am - bm;
    });
    _cachedUpNext = list.take(8).toList();
    return _cachedUpNext!;
  }

  int _activeChapter(Duration pos) {
    final steps = _video.keySteps;
    var active = -1;
    for (var i = 0; i < steps.length; i++) {
      final s = _parseDuration(steps[i].time);
      if (s <= pos.inSeconds && (steps[i].time.contains(':'))) active = i;
    }
    return _controller == null ? -1 : active;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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
          builder: (context, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                children: [
                  _buildPlayer(p),
                  Expanded(
                    child: ListView(
                      physics: const VnAlwaysScrollablePhysics(),
                      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
                      children: [
                        _buildTitle(p),
                        _buildChannelRow(p),
                        _buildActions(p),
                        _buildChapters(p),
                        _buildComments(p),
                        _buildUpNext(p),
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

  // ── Player Chrome ──────────────────────────────────────────────────────────

  Widget _buildPlayer(VnPalette p) {
    final clip = _clip;
    final total = Duration(seconds: clip.durationSeconds);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: const Color(0xFF090D14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null)
              YoutubePlayer(controller: _controller!, aspectRatio: 16 / 9),
            if (_hasPlaybackError)
              ColoredBox(
                color: const Color(0xEE090E17),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0x330D9488),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0x402DD4BF)),
                          ),
                          child: const Icon(Icons.play_circle_outline_rounded, color: Color(0xFF2DD4BF), size: 30),
                        ),
                        const SizedBox(height: 12),
                        Text('Playback Restricted in App',
                            style: VnText.heading(16, color: Colors.white, weight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('This clinical creator requires direct YouTube playback.',
                            textAlign: TextAlign.center,
                            style: VnText.body(13, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VnButton(
                              label: 'Watch on YouTube',
                              icon: Icons.open_in_new_rounded,
                              height: 40,
                              radius: 10,
                              onPressed: _watchOnYouTube,
                            ),
                            const SizedBox(width: 10),
                            VnOutlineButton(
                              label: 'Ask AI Protocol',
                              icon: Icons.auto_awesome_rounded,
                              height: 40,
                              radius: 10,
                              onPressed: () => askVitaNetAi(context, askAiPromptFor(clip)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_controller == null) ...[
              // Poster image
              Opacity(
                opacity: 0.88,
                child: isCprVideo(clip)
                    ? const CprDesignedThumbnail()
                    : VnNetworkPhoto(
                        url: _video.thumbnailUrl.isNotEmpty ? _video.thumbnailUrl : clip.thumbnailUrl,
                        fallbackAsset: videoFallbackPhoto(clip),
                        cacheWidth: 900,
                      ),
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.3, 0.7, 1],
                      colors: [Color(0x80000000), Color(0x20000000), Color(0x40000000), Color(0xB3000000)],
                    ),
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _RoundSkip(label: '-10'),
                    const SizedBox(width: 36),
                    Tooltip(
                      message: 'Play clinical video',
                      child: Semantics(
                        button: true,
                        label: 'Play',
                        child: Material(
                          color: const Color(0xCC0F172A),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _startPlayback(),
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0x802DD4BF), width: 1.5),
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF2DD4BF), size: 40),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                    const _RoundSkip(label: '+10'),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<Duration>(
                        valueListenable: _positionNotifier,
                        builder: (context, pos, _) => Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0x80000000),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_fmt(pos)} / ${clip.formattedDuration.isEmpty ? '--:--' : clip.formattedDuration}',
                                style: VnText.body(11, weight: FontWeight.w700, color: const Color(0xFF2DD4BF)),
                              ),
                            ),
                            if (_video.keySteps.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _video.keySteps.first.action,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: VnText.body(11, color: Colors.white70),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    VnIconButton(
                      icon: Icons.open_in_new_rounded,
                      tooltip: 'Watch on YouTube',
                      size: 36,
                      iconSize: 18,
                      foreground: Colors.white,
                      onPressed: _watchOnYouTube,
                    ),
                  ],
                ),
              ),
            ],
            // Top overlay bar
            Positioned(
              top: 6,
              left: 6,
              right: 6,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0x66000000),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x26FFFFFF)),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 26),
                          tooltip: 'Minimise player',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_controller == null) ...[
                    _TopControlButton(
                      icon: _captions ? Icons.closed_caption_rounded : Icons.closed_caption_off_outlined,
                      tooltip: _captions ? 'Captions on' : 'Captions off',
                      active: _captions,
                      onTap: _toggleCaptions,
                    ),
                    const SizedBox(width: 8),
                    _TopControlButton(
                      icon: Icons.speed_rounded,
                      label: _rate == 1.0 ? '1x' : '${_rate}x',
                      tooltip: 'Playback speed',
                      onTap: _openSettings,
                    ),
                  ],
                ],
              ),
            ),

            // Bottom Progress Scrubber
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: IgnorePointer(
                child: ValueListenableBuilder<Duration>(
                  valueListenable: _positionNotifier,
                  builder: (context, pos, _) {
                    final progress = clip.durationSeconds > 0
                        ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
                        : _store.progressOf(clip.youtubeId);
                    return ColoredBox(
                      color: const Color(0x33FFFFFF),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF0D9488), Color(0xFF2DD4BF)],
                            ),
                          ),
                          child: SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info & Metadata ───────────────────────────────────────────────────────

  Widget _buildTitle(VnPalette p) {
    final clip = _clip;
    final meta = clip.viewsCount.isNotEmpty
        ? '${videoMeta(clip)} · Peer-reviewed'
        : '${_video.category} · Verified Clinical Protocol';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Specialty category chip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.brandTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _video.category.toUpperCase(),
                  style: VnText.body(11, weight: FontWeight.w800, color: p.brandDeep, letterSpacing: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              if (_isEmergencyTopic)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emergency_rounded, size: 12, color: Color(0xFFDC2626)),
                      const SizedBox(width: 4),
                      Text('FIRST AID ESSENTIAL',
                          style: VnText.body(10, weight: FontWeight.w800, color: const Color(0xFF991B1B))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _video.title,
            style: VnText.heading(18, weight: FontWeight.w700, color: p.ink, height: 1.35),
          ),
          const SizedBox(height: 6),
          // Metadata + Expand description
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VnText.body(12, color: p.muted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _expanded ? 'Show less' : 'More…',
                    style: VnText.body(12, weight: FontWeight.w700, color: p.brand),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: p.brand,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CLINICAL OVERVIEW & OBJECTIVES',
                      style: VnText.body(11, weight: FontWeight.w800, color: p.muted, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  Text(_video.summary, style: VnText.body(13, color: p.inkSoft, height: 1.55)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _TopicPill(tag: '#${clip.category.replaceAll(RegExp(r'[^A-Za-z]'), '')}'),
                      const _TopicPill(tag: '#ClinicalGuideline'),
                      const _TopicPill(tag: '#VitaNetHealth'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChannelRow(VnPalette p) {
    final clip = _clip;
    final subscribed = _store.isSubscribed(clip.channelName);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            ChannelAvatar(channel: clip.channelName, code: clip.channelAvatarUrl, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          clip.channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VnText.body(14, weight: FontWeight.w700, color: p.ink),
                        ),
                      ),
                      if (clip.isVerifiedChannel) ...[
                        const SizedBox(width: 4),
                        Semantics(
                          label: 'Verified clinical source',
                          child: const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF0D9488)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Accredited Clinical Resource',
                    style: VnText.body(11, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SubscribeButton(
              subscribed: subscribed,
              onTap: () => _store.toggleSubscribe(clip.channelName),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(VnPalette p) {
    final clip = _clip;
    final id = clip.youtubeId;
    final liked = _store.isLiked(id);
    final disliked = _store.isDisliked(id);
    final saved = _store.isSaved(id);

    return SizedBox(
      height: 52,
      child: ListView(
        physics: const VnAlwaysScrollablePhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          // Like / Dislike joined pill
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                _PillButton(
                  icon: liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  label: liked ? 'Liked' : 'Like',
                  tooltip: liked ? 'Remove like' : 'Like',
                  selected: liked,
                  onTap: () => _store.toggleLike(id),
                ),
                Container(width: 1, height: 20, color: p.line),
                _PillButton(
                  icon: disliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                  tooltip: disliked ? 'Remove dislike' : 'Dislike',
                  selected: disliked,
                  onTap: () => _store.toggleDislike(id),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Emergency topic action
          if (_isEmergencyTopic) ...[
            _Pill(
              icon: Icons.phone_in_talk_rounded,
              label: 'Call ${widget.emergencyNumber}',
              bg: const Color(0xFFDC2626),
              fg: Colors.white,
              bold: true,
              onTap: () => LaunchHelpers.dialOrSnack(context, widget.emergencyNumber),
            ),
            const SizedBox(width: 8),
          ],

          // Ask VitaNet AI Assistant (Highlighted branded pill)
          _Pill(
            icon: Icons.auto_awesome_rounded,
            label: 'Ask AI Assistant',
            bg: p.brandTint,
            fg: p.brandDeep,
            bold: true,
            onTap: () => askVitaNetAi(context, askAiPromptFor(clip)),
          ),
          const SizedBox(width: 8),

          // Save / Bookmark
          _Pill(
            icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            label: saved ? 'Saved' : 'Save',
            fg: saved ? p.brand : null,
            bold: saved,
            onTap: () {
              final added = _store.toggleSaved(clip);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(added ? 'Saved to clinical bookmarks' : 'Removed from clinical bookmarks'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ));
            },
          ),
          const SizedBox(width: 8),

          // Share
          _Pill(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: () => shareVideo(context, clip),
          ),
          const SizedBox(width: 8),

          // Speed
          _Pill(
            icon: Icons.speed_rounded,
            label: _rate == 1.0 ? 'Speed' : '${_rate}x',
            onTap: _openSettings,
          ),
          const SizedBox(width: 8),

          // Offline
          _Pill(
            icon: Icons.download_rounded,
            label: 'Offline',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Opening YouTube, where this video can be saved offline'),
                behavior: SnackBarBehavior.floating,
              ));
              _watchOnYouTube();
            },
          ),
        ],
      ),
    );
  }

  // ── AI Protocol Stepper & Chapters ────────────────────────────────────────

  Widget _buildChapters(VnPalette p) {
    final steps = _video.keySteps;
    if (steps.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<Duration>(
      valueListenable: _positionNotifier,
      builder: (context, pos, _) {
        final active = _activeChapter(pos);
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: p.brandWash,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.brandBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: p.brandTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, size: 16, color: p.brandDeep),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI CLINICAL PROTOCOL TIMELINE',
                            style: VnText.body(11, weight: FontWeight.w800, color: p.brandDeep, letterSpacing: 0.6)),
                        Text('Tap any step to jump playback', style: VnText.body(11, color: p.muted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.brandTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${steps.length} Steps',
                      style: VnText.body(11, weight: FontWeight.w800, color: p.brandDeep),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < steps.length; i++) ...[
                _ChapterStepRow(
                  index: i + 1,
                  step: steps[i],
                  isActive: i == active,
                  palette: p,
                  onTap: _controller != null && steps[i].time.contains(':')
                      ? () => _controller!.seekTo(
                            seconds: _parseDuration(steps[i].time).toDouble(),
                            allowSeekAhead: true,
                          )
                      : null,
                ),
                if (i < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 38),
                    child: Container(
                      width: 1.5,
                      height: 10,
                      color: p.brandBorder,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildComments(VnPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Material(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _watchOnYouTube,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.line),
                  ),
                  child: Icon(Icons.forum_outlined, size: 20, color: p.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Clinical Discussion & Comments',
                          style: VnText.body(13, weight: FontWeight.w700, color: p.ink)),
                      const SizedBox(height: 2),
                      Text(
                        'Read community insights and peer questions on YouTube',
                        style: VnText.body(11, color: p.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded, size: 16, color: p.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpNext(VnPalette p) {
    final next = _upNext;
    if (next.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Up Next', style: VnText.heading(16, weight: FontWeight.w700, color: p.ink)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.line),
                ),
                child: Text(
                  '${next.length}',
                  style: VnText.body(11, weight: FontWeight.w700, color: p.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final v in next) ...[
            VideoListRow(
              video: v,
              thumbWidth: 150,
              thumbHeight: 88,
              onTap: () {
                _store.takeNextQueued(excludingId: null);
                _changeVideo(v);
              },
              onMore: () => showVideoOptionsSheet(context, v),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subcomponents
// ─────────────────────────────────────────────────────────────────────────────

class _TopControlButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _TopControlButton({
    required this.icon,
    this.label,
    required this.tooltip,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              height: 36,
              padding: EdgeInsets.symmetric(horizontal: label != null ? 10 : 8),
              decoration: BoxDecoration(
                color: active ? const Color(0x990D9488) : const Color(0x66000000),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: active ? const Color(0xFF2DD4BF) : const Color(0x26FFFFFF)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  if (label != null) ...[
                    const SizedBox(width: 4),
                    Text(label!, style: VnText.body(11, weight: FontWeight.w700, color: Colors.white)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicPill extends StatelessWidget {
  final String tag;
  const _TopicPill({required this.tag});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.line),
      ),
      child: Text(tag, style: VnText.body(11, weight: FontWeight.w600, color: p.muted)),
    );
  }
}

class _ChapterStepRow extends StatelessWidget {
  final int index;
  final VideoKeyStep step;
  final bool isActive;
  final VnPalette palette;
  final VoidCallback? onTap;

  const _ChapterStepRow({
    required this.index,
    required this.step,
    required this.isActive,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Material(
      color: isActive ? p.brandTint : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isActive ? p.brand : p.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: isActive ? p.brand : p.line),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: VnText.body(11, weight: FontWeight.w800, color: isActive ? Colors.white : p.muted),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? p.brand : p.brandTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  step.time,
                  style: VnText.body(11, weight: FontWeight.w800, color: isActive ? Colors.white : p.brandDeep),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.action,
                      style: VnText.body(
                        13,
                        weight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? p.brandDeep : p.ink,
                        height: 1.35,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: p.brand, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text('Playing now', style: VnText.body(10, weight: FontWeight.w700, color: p.brand)),
                        ],
                      ),
                    ],
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

class _RoundSkip extends StatelessWidget {
  final String label;
  const _RoundSkip({required this.label});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0x66000000),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: VnText.body(11, weight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final color = selected ? p.brand : p.ink;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: selected,
        label: tooltip,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Container(
            height: 38,
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(label!, style: VnText.body(13, weight: FontWeight.w600, color: color)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? bg;
  final Color? fg;
  final bool bold;

  const _Pill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.bg,
    this.fg,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final color = fg ?? p.ink;
    return Material(
      color: bg ?? p.surfaceAlt,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: bg != null ? Colors.transparent : p.line),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: VnText.body(13, weight: bold ? FontWeight.w700 : FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
