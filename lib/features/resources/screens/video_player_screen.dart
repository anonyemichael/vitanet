import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_colors.dart';
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
  Duration _position = Duration.zero;
  bool _captions = false;
  bool _expanded = false;
  double _rate = 1;

  @override
  void initState() {
    super.initState();
    _video = widget.video;
    _source = widget.source;
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _controller?.close();
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
      final ctrl = YoutubePlayerController.fromVideoId(
        videoId: _video.videoId,
        autoPlay: true,
        startSeconds: startSeconds > 0 ? startSeconds : null,
        params: YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: _captions,
          mute: false,
          strictRelatedVideos: true,
          origin: 'https://www.youtube.com',
        ),
      );
      _stateSub = ctrl.videoStateStream.listen(_onState);
      setState(() => _controller = ctrl);
    } catch (_) {
      _watchOnYouTube();
    }
  }

  void _onState(YoutubeVideoState state) {
    if (!mounted) return;
    setState(() => _position = state.position);
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
      _source = next;
      _video = next.toHealthVideo();
      _position = Duration.zero;
      _expanded = false;
    });
    _startPlayback();
  }


  void _toggleCaptions() {
    setState(() => _captions = !_captions);
    if (_controller != null) _startPlayback(startSeconds: _position.inSeconds.toDouble());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_captions ? 'Captions on' : 'Captions off'),
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
            Text('Playback speed', style: VnText.heading(18, weight: FontWeight.w700, color: p.ink)),
            for (final r in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
              VnListRow(
                title: r == 1.0 ? 'Normal' : '${r}x',
                chevron: false,
                trailing: _rate == r ? Icon(Icons.check_rounded, color: p.brand) : null,
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
    return list.take(8).toList();
  }

  int get _activeChapter {
    final steps = _video.keySteps;
    var active = -1;
    for (var i = 0; i < steps.length; i++) {
      final s = _parseDuration(steps[i].time);
      if (s <= _position.inSeconds && (steps[i].time.contains(':'))) active = i;
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
                      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 20),
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

  // ── Player ────────────────────────────────────────────────────────────────

  Widget _buildPlayer(VnPalette p) {
    final clip = _clip;
    final total = Duration(seconds: clip.durationSeconds);
    final progress = clip.durationSeconds > 0
        ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : _store.progressOf(clip.youtubeId);


    return AspectRatio(
      aspectRatio: 390 / 219,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null)
              YoutubePlayer(controller: _controller!, aspectRatio: 16 / 9)
            else ...[
              Opacity(
                opacity: 0.85,
                child: isCprVideo(clip)
                    ? const CprDesignedThumbnail()
                    : VnNetworkPhoto(
                        url: _video.thumbnailUrl.isNotEmpty ? _video.thumbnailUrl : clip.thumbnailUrl,
                        fallbackAsset: videoFallbackPhoto(clip),
                        cacheWidth: 900,
                      ),
              ),
              const ColoredBox(color: Color(0x40000000)),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _RoundSkip(label: '-10'),
                    const SizedBox(width: 44),
                    Tooltip(
                      message: 'Play',
                      child: Semantics(
                        button: true,
                        label: 'Play',
                        child: Material(
                          color: const Color(0x80000000),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _startPlayback(),
                            child: const SizedBox(
                              width: 64,
                              height: 64,
                              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                    const _RoundSkip(label: '+10'),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                right: 4,
                bottom: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_fmt(_position)} / ${clip.formattedDuration.isEmpty ? '--:--' : clip.formattedDuration}'
                        '${_video.keySteps.isNotEmpty ? ' · ${_video.keySteps.first.action}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VnText.body(12, weight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                    VnIconButton(
                      icon: Icons.open_in_new_rounded,
                      tooltip: 'Watch on YouTube',
                      size: 40,
                      iconSize: 20,
                      foreground: Colors.white,
                      onPressed: _watchOnYouTube,
                    ),
                  ],
                ),
              ),
            ],
            // Top controls
            Positioned(
              top: 4,
              left: 4,
              child: VnIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: 'Minimise player',
                iconSize: 28,
                foreground: Colors.white,
                background: _controller != null ? const Color(0x66000000) : null,
                radius: 22,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            if (_controller == null)
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  children: [
                    VnIconButton(
                      icon: _captions ? Icons.closed_caption_rounded : Icons.closed_caption_off_outlined,
                      tooltip: _captions ? 'Turn captions off' : 'Turn captions on',
                      foreground: Colors.white,
                      onPressed: _toggleCaptions,
                    ),
                    VnIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Playback settings',
                      foreground: Colors.white,
                      onPressed: _openSettings,
                    ),
                  ],
                ),
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: IgnorePointer(
                child: ColoredBox(
                  color: const Color(0x4DFFFFFF),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: const ColoredBox(color: Color(0xFF2DD4BF)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info ─────────────────────────────────────────────────────────────────

  Widget _buildTitle(VnPalette p) {
    final clip = _clip;
    final meta = clip.viewsCount.isNotEmpty
        ? '${videoMeta(clip)} · #${clip.category.replaceAll(RegExp(r'[^A-Za-z]'), '')}'
        : '${_video.category} · ${_video.verificationStatus}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_video.title, style: VnText.heading(18, weight: FontWeight.w700, color: p.ink, height: 1.35)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$meta '),
                  TextSpan(
                    text: _expanded ? 'less' : '…more',
                    style: VnText.body(12, weight: FontWeight.w700, color: p.ink),
                  ),
                ]),
                style: VnText.body(12, color: p.muted),
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(12)),
              child: Text(_video.summary, style: VnText.body(13, color: p.inkSoft, height: 1.5)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          ChannelAvatar(channel: clip.channelName, code: clip.channelAvatarUrl, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(clip.channelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VnText.body(15, weight: FontWeight.w700, color: p.ink)),
                ),
                if (clip.isVerifiedChannel) ...[
                  const SizedBox(width: 4),
                  Semantics(
                    label: 'Verified clinical source',
                    child: Icon(Icons.verified_rounded, size: 14, color: p.muted),
                  ),
                ],
              ],
            ),
          ),
          SubscribeButton(
            subscribed: subscribed,
            onTap: () => _store.toggleSubscribe(clip.channelName),
          ),
        ],
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
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          Container(
            height: 36,
            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                _PillButton(
                  icon: liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  label: liked ? 'Liked' : 'Like',
                  tooltip: liked ? 'Remove like' : 'Like',
                  selected: liked,
                  onTap: () => _store.toggleLike(id),
                ),
                Container(width: 1, height: 20, color: p.isDark ? const Color(0xFF404040) : const Color(0xFFCBD5E1)),
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
          if (_isEmergencyTopic) ...[
            _Pill(
              icon: Icons.phone_in_talk_rounded,
              label: 'Call ${widget.emergencyNumber}',
              bg: p.danger,
              fg: Colors.white,
              onTap: () => LaunchHelpers.dialOrSnack(context, widget.emergencyNumber),
            ),
            const SizedBox(width: 8),
          ],
          _Pill(
            icon: Icons.auto_awesome_rounded,
            label: 'Ask AI',
            bg: p.brandTint,
            fg: p.isDark ? AppColors.mintLight : const Color(0xFF115E59),
            bold: true,
            onTap: () => askVitaNetAi(context, askAiPromptFor(clip)),
          ),
          const SizedBox(width: 8),
          _Pill(icon: Icons.ios_share_rounded, label: 'Share', onTap: () => shareVideo(context, clip)),
          const SizedBox(width: 8),
          _Pill(
            icon: Icons.download_rounded,
            label: 'Download',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Opening YouTube, where this video can be saved offline'),
                behavior: SnackBarBehavior.floating,
              ));
              _watchOnYouTube();
            },
          ),
          const SizedBox(width: 8),
          _Pill(
            icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            label: saved ? 'Saved' : 'Save',
            onTap: () {
              final added = _store.toggleSaved(clip);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(added ? 'Saved to clinical bookmarks' : 'Removed from clinical bookmarks'),
                  behavior: SnackBarBehavior.floating,
                ));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChapters(VnPalette p) {
    final steps = _video.keySteps;
    if (steps.isEmpty) return const SizedBox.shrink();
    final active = _activeChapter;
    final fg = p.isDark ? const Color(0xFFCCFBF1) : const Color(0xFF134E4A);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.brandWash,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: p.brandDeep),
              const SizedBox(width: 6),
              Text('AI summary · chapters', style: VnText.body(13, weight: FontWeight.w800, color: p.brandDeep)),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            InkWell(
              onTap: _controller != null && steps[i].time.contains(':')
                  ? () => _controller!.seekTo(seconds: _parseDuration(steps[i].time).toDouble(), allowSeekAhead: true)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 46,
                      child: Text(
                        steps[i].time,
                        style: VnText.body(13, weight: FontWeight.w700, color: p.brand),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        i == active ? '${steps[i].action} (now playing)' : steps[i].action,
                        style: VnText.body(13,
                            weight: i == active ? FontWeight.w700 : FontWeight.w400, color: fg, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComments(VnPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Material(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _watchOnYouTube,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comments', style: VnText.body(15, weight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.forum_outlined, size: 20, color: p.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Read and join the discussion on YouTube',
                        style: VnText.body(13, color: p.ink, height: 1.45),
                      ),
                    ),
                    Icon(Icons.open_in_new_rounded, size: 16, color: p.muted),
                  ],
                ),
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text('Up next', style: VnText.heading(16, color: p.ink))),
          const SizedBox(height: 14),
          for (final v in next) ...[
            VideoListRow(
              video: v,
              thumbWidth: 160,
              thumbHeight: 90,
              onTap: () {
                _store.takeNextQueued(excludingId: null);
                _changeVideo(v);
              },
              onMore: () => showVideoOptionsSheet(context, v),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}


/// Decorative skip marker shown either side of the play button (seeking is
/// done with the YouTube controls once playback starts).
class _RoundSkip extends StatelessWidget {
  final String label;
  const _RoundSkip({required this.label});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
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
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: selected,
        label: tooltip,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 36,
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: p.ink),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(label!, style: VnText.body(14, weight: FontWeight.w600, color: p.ink)),
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

  const _Pill({required this.icon, required this.label, required this.onTap, this.bg, this.fg, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final color = fg ?? p.ink;
    return Material(
      color: bg ?? p.surfaceAlt,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: VnText.body(14, weight: bold ? FontWeight.w700 : FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
