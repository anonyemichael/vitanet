import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
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
/// Redesigned with frosted glass UI, verified clinician badges, quick
/// clinical protocol takeaways, and interactive right-rail controls.
class VideoShortsScreen extends StatefulWidget {
  final List<ClinicalVideo> shorts;
  final int initialIndex;

  const VideoShortsScreen({super.key, required this.shorts, this.initialIndex = 0});

  @override
  State<VideoShortsScreen> createState() => _VideoShortsScreenState();
}

class _VideoShortsScreenState extends State<VideoShortsScreen> {
  late final PageController _pageController;
  ShortsPlayback? _playback;
  StreamSubscription<YoutubePlayerValue>? _stateSub;
  final _store = VideoEngagementStore.instance;
  int _current = 0;
  bool _isMuted = true;
  bool _isPaused = false;
  // The cover photo hides the player until the current clip is playing and
  // the feed has stopped moving, so swipes never show a frozen frame.
  bool _playing = false;
  bool _settled = true;
  bool _stepsExpanded = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.shorts.isEmpty ? 0 : widget.shorts.length - 1);
    _pageController = PageController(initialPage: _current);
    if (widget.shorts.isNotEmpty) {
      final playback = ShortsPlayback(shorts: widget.shorts, initialIndex: _current);
      _playback = playback;
      _stateSub = playback.controller.stream.listen(_onPlayerValue);
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _playback?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPlayerValue(YoutubePlayerValue value) {
    if (!mounted) return;
    final state = value.playerState;
    if (state == PlayerState.ended) {
      _playback?.replay();
      return;
    }
    final playing = state == PlayerState.playing;
    if (playing != _playing) setState(() => _playing = playing);
  }

  void _onPageChanged(int index) {
    setState(() {
      _current = index;
      _isPaused = false;
      _playing = false;
      _stepsExpanded = false;
    });
    _playback
      ?..show(index)
      ..setMuted(_isMuted);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final moving = n is ScrollStartNotification || (n is ScrollUpdateNotification && n.dragDetails != null);
    final settled = n is ScrollEndNotification;
    if (moving && _settled) setState(() => _settled = false);
    if (settled && !_settled) setState(() => _settled = true);
    return false;
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _playback?.setMuted(_isMuted);
  }

  void _togglePlayPause() {
    if (_playback == null) return;
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _playback!.pause();
    } else {
      _playback!
        ..play()
        ..setMuted(_isMuted);
    }
  }

  void _showClinicalStepsSheet(ClinicalVideo short) {
    showVnSheet<void>(
      context,
      builder: (ctx) {
        final p = VnPalette.of(ctx);
        return VnSheet(
          gap: 12,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: p.brandTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.fact_check_rounded, color: p.brand, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Clinical Protocol Steps', style: VnText.heading(16, weight: FontWeight.w700, color: p.ink)),
                      Text(short.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: VnText.body(12, color: p.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (short.keyTakeaways.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No protocol steps listed for this clip.', style: VnText.body(14, color: p.muted)),
              )
            else
              for (var i = 0; i < short.keyTakeaways.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: p.brand,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: VnText.body(12, weight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          short.keyTakeaways[i],
                          style: VnText.body(14, weight: FontWeight.w600, color: p.ink, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
            VnButton(
              label: 'Ask AI About This Technique',
              icon: Icons.auto_awesome_rounded,
              onPressed: () {
                Navigator.of(ctx).pop();
                askVitaNetAi(context, askAiPromptFor(short));
              },
            ),
          ],
        );
      },
    );
  }

  String _handle(String channel) =>
      '@${channel.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';

  @override
  Widget build(BuildContext context) {
    final playback = _playback;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF090D14),
        body: playback == null
            ? Center(
                child: Text('No shorts available', style: VnText.body(15, color: Colors.white70)),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  // The one player, fixed in place under the feed.
                  Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: YoutubePlayer(controller: playback.controller, aspectRatio: 9 / 16),
                    ),
                  ),
                  // On the web the player is an iframe that would swallow
                  // every swipe and tap; the interceptor keeps them in Flutter.
                  PointerInterceptor(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: ListenableBuilder(
                        listenable: _store,
                        builder: (context, _) => PageView.builder(
                          physics: const VnAlwaysScrollablePhysics(),
                          scrollDirection: Axis.vertical,
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, index) => _buildShort(playback.videoAt(index), index),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildShort(ClinicalVideo short, int index) {
    final isCurrent = index == _current;
    final showVideo = isCurrent && _playing && _settled;
    final liked = _store.isLiked(short.youtubeId);
    final saved = _store.isSaved(short.youtubeId);
    final subscribed = _store.isSubscribed(short.channelName);
    final topPad = MediaQuery.paddingOf(context).top;
    final botPad = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover photo until this clip is actually playing; then the player
        // underneath shows through.
        AnimatedOpacity(
          opacity: showVideo ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF090D14)),
              VnNetworkPhoto(url: short.shortsThumbnailUrl, fallbackAsset: videoFallbackPhoto(short)),
              if (isCurrent && !_playing && !_isPaused)
                Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: const CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2DD4BF)),
                  ),
                ),
            ],
          ),
        ),

        // Elegant multi-stop gradient scrim
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.16, 0.5, 0.78, 1],
                colors: [
                  Color(0x99000000),
                  Color(0x33000000),
                  Color(0x00000000),
                  Color(0x88000000),
                  Color(0xE6060B12),
                ],
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(44),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0x66000000),
                            borderRadius: BorderRadius.circular(44),
                            border: Border.all(color: const Color(0x40FFFFFF)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                              const SizedBox(width: 8),
                              Text('Tap to resume', style: VnText.body(13, weight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),

        // Modern Frosted Glass Top Bar
        Positioned(
          top: topPad + 8,
          left: 12,
          right: 12,
          child: Row(
            children: [
              _GlassCircleButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Back',
                iconSize: 26,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              // Category / Pearl Capsule
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x4D000000),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x26FFFFFF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2DD4BF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          short.category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VnText.body(11, weight: FontWeight.w800, color: const Color(0xFFCCFBF1), letterSpacing: 0.8),
                        ),
                      ),
                      Text(
                        '${index + 1}/${widget.shorts.length}',
                        style: VnText.body(11, weight: FontWeight.w600, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _GlassCircleButton(
                icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                tooltip: _isMuted ? 'Turn sound on' : 'Turn sound off',
                iconSize: 20,
                onTap: _toggleMute,
              ),
              const SizedBox(width: 8),
              _GlassCircleButton(
                icon: Icons.search_rounded,
                tooltip: 'Search clinical videos',
                iconSize: 20,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VideoSearchScreen()),
                ),
              ),
            ],
          ),
        ),

        // Muted helper floating badge
        if (_isMuted && index == _current)
          Positioned(
            top: topPad + 56,
            left: 16,
            child: GestureDetector(
              onTap: _toggleMute,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x800F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x332DD4BF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.volume_off_rounded, color: Color(0xFF2DD4BF), size: 14),
                        const SizedBox(width: 6),
                        Text('Muted · Tap to hear clinician', style: VnText.body(11, weight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Sleek Right Action Rail (Frosted vertical floating bar)
        Positioned(
          right: 12,
          bottom: botPad + 36,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReelActionPill(
                icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: liked ? 'Liked' : 'Like',
                tooltip: liked ? 'Unlike' : 'Like',
                active: liked,
                activeColor: const Color(0xFFF43F5E),
                onTap: () => _store.toggleLike(short.youtubeId),
              ),
              const SizedBox(height: 16),
              _ReelActionPill(
                icon: Icons.fact_check_rounded,
                label: 'Steps',
                tooltip: 'View clinical steps',
                accent: true,
                onTap: () => _showClinicalStepsSheet(short),
              ),
              const SizedBox(height: 16),
              _ReelActionPill(
                icon: Icons.auto_awesome_rounded,
                label: 'Ask AI',
                tooltip: 'Ask VitaNet AI about this protocol',
                accent: true,
                onTap: () => askVitaNetAi(context, askAiPromptFor(short)),
              ),
              const SizedBox(height: 16),
              _ReelActionPill(
                icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                label: saved ? 'Saved' : 'Save',
                tooltip: saved ? 'Remove bookmark' : 'Save to clinical kit',
                active: saved,
                activeColor: const Color(0xFF2DD4BF),
                onTap: () {
                  final added = _store.toggleSaved(short);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(added ? 'Saved to clinical kit' : 'Removed from bookmarks'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ));
                },
              ),
              const SizedBox(height: 16),
              _ReelActionPill(
                icon: Icons.share_rounded,
                label: 'Share',
                tooltip: 'Share protocol',
                onTap: () => shareVideo(context, short),
              ),
              const SizedBox(height: 16),
              _ReelActionPill(
                icon: Icons.open_in_new_rounded,
                label: 'YouTube',
                tooltip: 'Open in YouTube',
                onTap: () => LaunchHelpers.openWeb(context, youtubeUrl(short)),
              ),
            ],
          ),
        ),

        // Bottom Info: Clinician Details & Clinical Pearl Takeaway
        Positioned(
          left: 14,
          right: 76,
          bottom: botPad + 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Clinician & Subscribe pill
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2DD4BF), width: 1.5),
                    ),
                    child: ChannelAvatar(channel: short.channelName, code: short.channelAvatarUrl, size: 34, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                short.channelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VnText.body(14, weight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2DD4BF)),
                          ],
                        ),
                        Text(
                          _handle(short.channelName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VnText.body(11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Subscribe toggle capsule
                  GestureDetector(
                    onTap: () => _store.toggleSubscribe(short.channelName),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: subscribed ? const Color(0x33FFFFFF) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: subscribed ? const Color(0x40FFFFFF) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (subscribed) ...[
                            const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            subscribed ? 'Subscribed' : 'Subscribe',
                            style: VnText.body(
                              11,
                              weight: FontWeight.w700,
                              color: subscribed ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title & Takeaway
              Text(
                short.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: VnText.heading(15, weight: FontWeight.w700, color: Colors.white, height: 1.3),
              ),

              // Expandable Key Clinical Steps Snippet
              if (short.keyTakeaways.isNotEmpty) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => setState(() => _stepsExpanded = !_stepsExpanded),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x4D0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x332DD4BF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 13, color: Color(0xFF2DD4BF)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'KEY PROTOCOL (${short.keyTakeaways.length} steps)',
                                style: VnText.body(11, weight: FontWeight.w800, color: const Color(0xFFCCFBF1)),
                              ),
                            ),
                            Icon(
                              _stepsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: const Color(0xFF2DD4BF),
                            ),
                          ],
                        ),
                        if (_stepsExpanded) ...[
                          const SizedBox(height: 6),
                          for (var s = 0; s < short.keyTakeaways.length && s < 3; s++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${s + 1}. ', style: VnText.body(11, weight: FontWeight.w700, color: const Color(0xFF2DD4BF))),
                                  Expanded(
                                    child: Text(
                                      short.keyTakeaways[s],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: VnText.body(11, color: Colors.white, height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ] else ...[
                          const SizedBox(height: 2),
                          Text(
                            short.keyTakeaways.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VnText.body(11, color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              // Audio / Clinical Badge
              Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Verified Clinical Education · ${short.channelName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VnText.body(11, color: const Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Glowing Playback Progress Scrubber at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 3.5,
          child: _ShortProgress(controller: isCurrent ? _playback?.controller : null, video: short),
        ),
      ],
    );
  }
}

/// Frosted circular button for the top bar
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final double iconSize;
  final VoidCallback onTap;

  const _GlassCircleButton({
    required this.icon,
    required this.tooltip,
    this.iconSize = 22,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0x4D000000),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted circular rail button for Reels actions
class _ReelActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;
  final bool accent;

  const _ReelActionPill({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.activeColor,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active
        ? (activeColor ?? const Color(0xFF2DD4BF))
        : (accent ? const Color(0xFF2DD4BF) : Colors.white);

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
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent
                          ? const Color(0x330F766E)
                          : (active ? (activeColor?.withValues(alpha: 0.2) ?? const Color(0x332DD4BF)) : const Color(0x33000000)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? (activeColor?.withValues(alpha: 0.6) ?? const Color(0x802DD4BF))
                            : (accent ? const Color(0x662DD4BF) : const Color(0x26FFFFFF)),
                        width: active || accent ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: fg, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: VnText.body(
                  11,
                  weight: active || accent ? FontWeight.w700 : FontWeight.w600,
                  color: active || accent ? fg : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortProgress extends StatelessWidget {
  final YoutubePlayerController? controller;
  final ClinicalVideo video;
  const _ShortProgress({required this.controller, required this.video});

  @override
  Widget build(BuildContext context) {
    const track = ColoredBox(color: Color(0x33FFFFFF));
    if (controller == null || video.durationSeconds <= 0) return track;
    return StreamBuilder<YoutubeVideoState>(
      stream: controller!.videoStateStream,
      builder: (context, snapshot) {
        final pos = snapshot.data?.position.inMilliseconds ?? 0;
        final fraction = (pos / (video.durationSeconds * 1000)).clamp(0.0, 1.0);
        return Stack(
          children: [
            const Positioned.fill(child: track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF2DD4BF)],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }
}
