import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/clinical_video.dart';
import '../widgets/resource_media.dart';
import '../widgets/shorts_controller_pool.dart';
import '../widgets/video_engagement.dart';
import '../widgets/video_widgets.dart';
import 'video_search_screen.dart';

/// Legacy name kept for callers that still open the Shorts player by it.
typedef ShortsPlayerModal = VideoShortsScreen;

/// Full-screen vertical Shorts player (swipe up / down between clips).
class VideoShortsScreen extends StatefulWidget {
  final List<ClinicalVideo> shorts;
  final int initialIndex;

  const VideoShortsScreen({super.key, required this.shorts, this.initialIndex = 0});

  @override
  State<VideoShortsScreen> createState() => _VideoShortsScreenState();
}

class _VideoShortsScreenState extends State<VideoShortsScreen> {
  late final PageController _pageController;
  late final ShortsControllerPool _pool;
  final _store = VideoEngagementStore.instance;
  int _current = 0;
  bool _isMuted = true;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.shorts.isEmpty ? 0 : widget.shorts.length - 1);
    _pageController = PageController(initialPage: _current);
    _pool = ShortsControllerPool(shorts: widget.shorts, initialIndex: _current);
  }

  @override
  void dispose() {
    _pool.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _current = index;
      _isPaused = false;
      _pool.onPageChanged(index);
    });
    final ctrl = _pool.getController(index);
    if (ctrl != null) {
      if (!_isMuted) {
        ctrl.unMute();
      } else {
        ctrl.mute();
      }
      ctrl.playVideo();
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    final ctrl = _pool.getController(_current);
    if (ctrl != null) {
      if (_isMuted) {
        ctrl.mute();
      } else {
        ctrl.unMute();
      }
    }
  }

  void _togglePlayPause() {
    final ctrl = _pool.getController(_current);
    if (ctrl == null) return;
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      ctrl.pauseVideo();
    } else {
      ctrl.playVideo();
      if (!_isMuted) ctrl.unMute();
    }
  }

  String _handle(String channel) =>
      '@${channel.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: widget.shorts.isEmpty
            ? Center(
                child: Text('No shorts available', style: VnText.body(15, color: Colors.white70)),
              )
            : ListenableBuilder(
                listenable: _store,
                builder: (context, _) => PageView.builder(
                  scrollDirection: Axis.vertical,
                  physics: const ClampingScrollPhysics(),
                  controller: _pageController,
                  itemCount: widget.shorts.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) => _buildShort(widget.shorts[index], index),
                ),
              ),
      ),
    );
  }

  Widget _buildShort(ClinicalVideo short, int index) {
    final controller = _pool.getController(index);
    final liked = _store.isLiked(short.youtubeId);
    final subscribed = _store.isSubscribed(short.channelName);
    final topPad = MediaQuery.paddingOf(context).top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover photo stays underneath while the embed loads.
        VnNetworkPhoto(url: short.shortsThumbnailUrl, fallbackAsset: videoFallbackPhoto(short)),
        if (controller != null && index == _current)
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: YoutubePlayer(controller: controller, aspectRatio: 9 / 16),
            ),
          ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.22, 0.55, 1],
                colors: [Color(0x73000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
              ),
            ),
          ),
        ),

        // Full-screen tap to play / pause
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _togglePlayPause,
            child: _isPaused && index == _current
                ? Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0x8C000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),

        // Top bar
        Positioned(
          top: topPad + 12,
          left: 8,
          right: 8,
          child: Row(
            children: [
              VnIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Back',
                iconSize: 28,
                foreground: Colors.white,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(child: Text('Shorts', style: VnText.heading(20, color: Colors.white))),
              VnIconButton(
                icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                tooltip: _isMuted ? 'Turn sound on' : 'Turn sound off',
                iconSize: 24,
                foreground: Colors.white,
                onPressed: _toggleMute,
              ),
              VnIconButton(
                icon: Icons.open_in_new_rounded,
                tooltip: 'Open in YouTube',
                iconSize: 22,
                foreground: Colors.white,
                onPressed: () => LaunchHelpers.openWeb(context, youtubeUrl(short)),
              ),
              VnIconButton(
                icon: Icons.search_rounded,
                tooltip: 'Search',
                iconSize: 24,
                foreground: Colors.white,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VideoSearchScreen()),
                ),
              ),
            ],
          ),
        ),

        // Muted helper badge
        if (_isMuted && index == _current)
          Positioned(
            top: topPad + 60,
            left: 16,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.volume_off_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Muted · Tap for sound', style: VnText.body(12, weight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),

        // Right action rail
        Positioned(
          right: 8,
          bottom: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RailAction(
                icon: liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                label: liked ? 'Liked' : 'Like',
                tooltip: liked ? 'Remove like' : 'Like',
                onTap: () => _store.toggleLike(short.youtubeId),
              ),
              const SizedBox(height: 18),
              _RailAction(
                icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                label: _isMuted ? 'Muted' : 'Sound',
                tooltip: _isMuted ? 'Unmute' : 'Mute',
                onTap: _toggleMute,
              ),
              const SizedBox(height: 18),
              _RailAction(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Comments',
                tooltip: 'Open comments on YouTube',
                onTap: () => LaunchHelpers.openWeb(context, youtubeUrl(short)),
              ),
              const SizedBox(height: 18),
              _RailAction(
                icon: Icons.auto_awesome_rounded,
                label: 'Ask AI',
                tooltip: 'Ask VitaNet AI about this short',
                accent: true,
                onTap: () => askVitaNetAi(context, askAiPromptFor(short)),
              ),
              const SizedBox(height: 18),
              _RailAction(
                icon: Icons.ios_share_rounded,
                label: 'Share',
                tooltip: 'Share',
                onTap: () => shareVideo(context, short),
              ),
            ],
          ),
        ),

        // Bottom metadata
        Positioned(
          left: 14,
          right: 76,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ChannelAvatar(channel: short.channelName, code: short.channelAvatarUrl, size: 34, fontSize: 12),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(_handle(short.channelName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VnText.body(14, weight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    toggled: subscribed,
                    child: Material(
                      color: subscribed ? const Color(0x33FFFFFF) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _store.toggleSubscribe(short.channelName),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Center(
                              widthFactor: 1,
                              child: Text(
                                subscribed ? 'Subscribed' : 'Subscribe',
                                style: VnText.body(12,
                                    weight: FontWeight.w700,
                                    color: subscribed ? Colors.white : const Color(0xFF0F172A)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                short.keyTakeaways.isNotEmpty ? '${short.title}: ${short.keyTakeaways.first}' : short.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: VnText.body(15, weight: FontWeight.w600, color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.music_note_rounded, size: 14, color: Color(0xFFE2E8F0)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('Original audio · ${short.channelName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VnText.body(12, color: const Color(0xFFE2E8F0))),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Playback progress
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 3,
          child: _ShortProgress(controller: index == _current ? controller : null, video: short),
        ),
      ],
    );
  }
}

class _ShortProgress extends StatelessWidget {
  final YoutubePlayerController? controller;
  final ClinicalVideo video;
  const _ShortProgress({required this.controller, required this.video});

  @override
  Widget build(BuildContext context) {
    final track = const ColoredBox(color: Color(0x4DFFFFFF));
    if (controller == null || video.durationSeconds <= 0) return track;
    return StreamBuilder<YoutubeVideoState>(
      stream: controller!.videoStateStream,
      builder: (context, snapshot) {
        final pos = snapshot.data?.position.inMilliseconds ?? 0;
        final fraction = (pos / (video.durationSeconds * 1000)).clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned.fill(child: track),
            FractionallySizedBox(
              widthFactor: fraction,
              child: const ColoredBox(color: Colors.white, child: SizedBox.expand()),
            ),
          ],
        );
      },
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool accent;

  const _RailAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent ? const Color(0xFF0F766E) : const Color(0x26FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 4),
              Text(label, style: VnText.body(12, weight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
