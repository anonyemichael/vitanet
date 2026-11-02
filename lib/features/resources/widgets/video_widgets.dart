import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

import '../models/clinical_video.dart';
import 'resource_media.dart';
import 'video_engagement.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

bool isCprVideo(ClinicalVideo v) {
  final t = v.title.toLowerCase();
  return t.contains('cpr') || t.contains('cardiopulmonary');
}

/// Local photo that matches the video topic (used offline / while loading).
String videoFallbackPhoto(ClinicalVideo v) =>
    VnPhotos.forTopic('${v.title} ${v.category}', fallback: VnPhotos.doctorOnPhone);

String videoViews(ClinicalVideo v) => '${v.viewsCount} views';

String videoAgo(ClinicalVideo v) => v.publishedAgo
    .replaceAll(' yrs ', ' years ')
    .replaceAll(' yr ', ' year ')
    .replaceAll(' mos ', ' months ')
    .replaceAll(' mo ', ' month ')
    .replaceAll(' wks ', ' weeks ')
    .replaceAll(' wk ', ' week ');

String videoMeta(ClinicalVideo v) => '${videoViews(v)} · ${videoAgo(v)}';

String youtubeUrl(ClinicalVideo v) => 'https://www.youtube.com/watch?v=${v.youtubeId}';

const _avatarPairs = <List<Color>>[
  [Color(0xFFFEE2E2), Color(0xFF991B1B)],
  [Color(0xFFDBEAFE), Color(0xFF1E40AF)],
  [Color(0xFFEDE9FE), Color(0xFF5B21B6)],
  [Color(0xFFD1FAE5), Color(0xFF065F46)],
  [Color(0xFFFEF3C7), Color(0xFF92400E)],
  [Color(0xFFFCE7F3), Color(0xFF9D174D)],
  [Color(0xFFE0F2FE), Color(0xFF075985)],
];

List<Color> channelColors(String channel) {
  var hash = 0;
  for (final c in channel.codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  return _avatarPairs[hash % _avatarPairs.length];
}

String channelInitials(String channel, [String code = '']) {
  if (code.isNotEmpty && code.length <= 3 && !code.startsWith('http')) {
    return code.length > 2 ? code.substring(0, 2) : code;
  }
  final words = channel.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// Channel avatar
// ─────────────────────────────────────────────────────────────────────────────

class ChannelAvatar extends StatelessWidget {
  final String channel;
  final String code;
  final double size;
  final double fontSize;

  const ChannelAvatar({
    super.key,
    required this.channel,
    this.code = '',
    this.size = 36,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final c = channelColors(channel);
    return Semantics(
      label: '$channel channel',
      image: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: p.tintBg(c[0], c[1]), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          channelInitials(channel, code),
          style: VnText.body(fontSize, weight: FontWeight.w800, color: p.tintFg(c[1])),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Designed CPR thumbnails (no CPR photo exists in the asset set)
// ─────────────────────────────────────────────────────────────────────────────

class _PulsePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  const _PulsePainter(this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(5 * s, 12 * s)
      ..lineTo(8.5 * s, 12 * s)
      ..lineTo(10 * s, 9 * s)
      ..lineTo(13 * s, 15 * s)
      ..lineTo(14.5 * s, 12 * s)
      ..lineTo(19 * s, 12 * s);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.color != color;
}

/// White heart with a red pulse line through it.
class HeartPulseMark extends StatelessWidget {
  final double size;
  final Color heart;
  final Color pulse;
  const HeartPulseMark({
    super.key,
    required this.size,
    this.heart = Colors.white,
    this.pulse = const Color(0xFFDC2626),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.favorite_rounded, size: size, color: heart),
          CustomPaint(size: Size(size, size), painter: _PulsePainter(pulse, 1.8)),
        ],
      ),
    );
  }
}

/// Full 16:9 designed thumbnail: "HANDS-ONLY / CPR IN 3 MIN / SAVE A LIFE".
class CprDesignedThumbnail extends StatelessWidget {
  const CprDesignedThumbnail({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hands-only CPR in 3 minutes. Save a life.',
      image: true,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)],
          ),
        ),
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 390,
              height: 219,
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: -40,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x14FFFFFF), width: 24),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        const HeartPulseMark(size: 84),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('HANDS-ONLY',
                                style: VnText.heading(14,
                                    color: const Color(0xFFFECACA), letterSpacing: 2)),
                            const SizedBox(height: 4),
                            Text('CPR\nIN 3 MIN',
                                style: VnText.heading(38,
                                    color: Colors.white, height: 0.95, letterSpacing: -1)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE047),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('SAVE A LIFE',
                                  style: VnText.heading(13, color: const Color(0xFF422006))),
                            ),
                          ],
                        ),
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

/// Small designed CPR thumbnail used inside list rows (heart + "CPR").
class CprMiniThumbnail extends StatelessWidget {
  const CprMiniThumbnail({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)],
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text('CPR', style: VnText.heading(13, color: Colors.white, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thumbnails
// ─────────────────────────────────────────────────────────────────────────────

class DurationBadge extends StatelessWidget {
  final String text;
  final double fontSize;
  const DurationBadge(this.text, {super.key, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize >= 12 ? 5 : 4, vertical: fontSize >= 12 ? 2 : 1),
      decoration: BoxDecoration(
        color: const Color(0xD90F172A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: VnText.body(fontSize, weight: FontWeight.w600, color: Colors.white)),
    );
  }
}

/// Video thumbnail with duration badge and watch-progress bar.
class VideoThumbnail extends StatelessWidget {
  final ClinicalVideo video;
  final double durationFontSize;
  final bool mini;
  final bool showProgress;

  const VideoThumbnail({
    super.key,
    required this.video,
    this.durationFontSize = 12,
    this.mini = false,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final store = VideoEngagementStore.instance;
    final cpr = isCprVideo(video);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cpr)
          (mini ? const CprMiniThumbnail() : const CprDesignedThumbnail())
        else
          VnNetworkPhoto(
            url: video.thumbnailUrl,
            fallbackAsset: videoFallbackPhoto(video),
          ),
        Positioned(
          right: mini ? 5 : 8,
          bottom: mini ? 5 : 8,
          child: DurationBadge(video.formattedDuration, fontSize: durationFontSize),
        ),
        if (showProgress)
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final progress = store.progressOf(video.youtubeId);
              if (progress <= 0) return const SizedBox.shrink();
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 3,
                child: ColoredBox(
                  color: const Color(0x66FFFFFF),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: const ColoredBox(color: Color(0xFF0F766E)),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feed card (Home) and compact rows (Search / Up next / Saved)
// ─────────────────────────────────────────────────────────────────────────────

class VideoFeedCard extends StatelessWidget {
  final ClinicalVideo video;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const VideoFeedCard({super.key, required this.video, required this.onTap, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: video.title,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onTap,
              child: AspectRatio(aspectRatio: 390 / 219, child: VideoThumbnail(video: video)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChannelAvatar(channel: video.channelName, code: video.channelAvatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: VnText.body(15, weight: FontWeight.w600, color: p.ink, height: 1.35)),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: video.channelName),
                            if (video.isVerifiedChannel)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Semantics(
                                    label: 'Verified clinician',
                                    child: Icon(Icons.verified_rounded, size: 13, color: p.muted),
                                  ),
                                ),
                              ),
                            TextSpan(text: ' · ${videoMeta(video)}'),
                          ]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: VnText.body(12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                VnIconButton(
                  icon: Icons.more_vert_rounded,
                  tooltip: 'More options',
                  size: 40,
                  iconSize: 20,
                  onPressed: onMore,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoListRow extends StatelessWidget {
  final ClinicalVideo video;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final double thumbWidth;
  final double thumbHeight;
  final bool showBadge;
  final double titleSize;

  const VideoListRow({
    super.key,
    required this.video,
    required this.onTap,
    this.onMore,
    this.thumbWidth = 168,
    this.thumbHeight = 94,
    this.showBadge = false,
    this.titleSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: thumbWidth,
              height: thumbHeight,
              child: VideoThumbnail(video: video, mini: true, durationFontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(video.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: VnText.body(titleSize, weight: FontWeight.w600, color: p.ink, height: 1.35)),
                const SizedBox(height: 4),
                Text(video.channelName, style: VnText.body(12, color: p.muted)),
                Text(videoMeta(video), style: VnText.body(12, color: p.muted)),
                if (showBadge && video.isVerifiedChannel) ...[
                  const SizedBox(height: 4),
                  const VnTag(
                    label: 'Clinician verified',
                    bg: Color(0xFFCCFBF1),
                    fg: Color(0xFF115E59),
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    radius: 4,
                  ),
                ],
              ],
            ),
          ),
          if (onMore != null)
            VnIconButton(
              icon: Icons.more_vert_rounded,
              tooltip: 'More options',
              size: 36,
              iconSize: 18,
              onPressed: onMore,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Options sheet (VideoSheet design)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> shareVideo(BuildContext context, ClinicalVideo video) async {
  try {
    await Share.share('${video.title}\n${youtubeUrl(video)}', subject: video.title);
  } catch (_) {
    if (context.mounted) await LaunchHelpers.openWeb(context, youtubeUrl(video));
  }
}

String askAiPromptFor(ClinicalVideo video) {
  final points = video.keyTakeaways.take(3).join('; ');
  return 'I just watched the video "${video.title}" by ${video.channelName}. '
      '${points.isNotEmpty ? 'Its key points are: $points. ' : ''}'
      'Can you explain it simply and tell me what matters for me?';
}

void _snack(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, action: action));
}

/// Shows the "⋮" options sheet for a video as a real modal bottom sheet.
Future<void> showVideoOptionsSheet(BuildContext context, ClinicalVideo video) {
  final store = VideoEngagementStore.instance;
  final messengerContext = context;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C0F172A),
    builder: (ctx) {
      final p = VnPalette.of(ctx);
      Widget item(IconData icon, String label, VoidCallback onTap, {bool accent = false}) {
        final color = accent ? p.brand : p.ink;
        return InkWell(
          onTap: () {
            Navigator.of(ctx).pop();
            onTap();
          },
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(label,
                        style: VnText.body(15,
                            weight: accent ? FontWeight.w600 : FontWeight.w400, color: color)),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final inWatchLater = store.isInWatchLater(video.youtubeId);
      final saved = store.isSaved(video.youtubeId);

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              label: 'Video options',
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(top: 4, bottom: 8),
                        decoration: BoxDecoration(
                          color: p.isDark ? const Color(0xFF404040) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 88,
                              height: 50,
                              child: VideoThumbnail(video: video, mini: true, showProgress: false, durationFontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(video.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: VnText.body(14, weight: FontWeight.w700, color: p.ink, height: 1.3)),
                                const SizedBox(height: 2),
                                Text('${video.channelName} · ${video.formattedDuration}',
                                    style: VnText.body(12, color: p.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: p.divider),
                    item(Icons.queue_play_next_rounded, 'Play next in queue', () {
                      store.enqueue(video);
                      _snack(messengerContext, 'Will play next: ${video.title}');
                    }),
                    item(Icons.schedule_rounded, inWatchLater ? 'Remove from Watch later' : 'Save to Watch later', () {
                      final added = store.toggleWatchLater(video);
                      _snack(messengerContext, added ? 'Saved to Watch later' : 'Removed from Watch later');
                    }),
                    item(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        saved ? 'Remove from clinical bookmarks' : 'Save to clinical bookmarks', () {
                      final added = store.toggleSaved(video);
                      _snack(messengerContext, added ? 'Saved to clinical bookmarks' : 'Removed from clinical bookmarks');
                    }),
                    item(Icons.download_rounded, 'Download for offline use', () {
                      _snack(messengerContext, 'Opening YouTube, where this video can be saved offline');
                      LaunchHelpers.openWeb(messengerContext, youtubeUrl(video));
                    }),
                    item(Icons.ios_share_rounded, 'Share', () => shareVideo(messengerContext, video)),
                    item(Icons.auto_awesome_rounded, 'Ask VitaNet AI about this video',
                        () => askVitaNetAi(messengerContext, askAiPromptFor(video)),
                        accent: true),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Divider(height: 1, thickness: 1, color: p.divider),
                    ),
                    item(Icons.block_rounded, 'Not interested', () {
                      store.hide(video.youtubeId);
                      _snack(messengerContext, 'Video hidden from your feed',
                          action: SnackBarAction(label: 'Undo', onPressed: () => store.unhide(video.youtubeId)));
                    }),
                    item(Icons.flag_outlined, 'Report medical misinformation',
                        () => _confirmReport(messengerContext, video)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _confirmReport(BuildContext context, ClinicalVideo video) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final p = VnPalette.of(ctx);
      return VnDialog(
        children: [
          VnIconTile(
            icon: Icons.flag_outlined,
            bg: const Color(0xFFFEE2E2),
            fg: const Color(0xFFB91C1C),
            size: 56,
            radius: 18,
            iconSize: 26,
          ),
          Text('Report this video?', style: VnText.heading(20, color: p.ink)),
          Text(
            '"${video.title}" will be hidden and flagged for review by the VitaNet clinical team.',
            style: VnText.body(14, color: p.inkSoft, height: 1.55),
          ),
          Row(
            children: [
              Expanded(
                child: VnOutlineButton(
                  label: 'Cancel',
                  background: p.surfaceAlt,
                  borderColor: Colors.transparent,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: VnButton(
                  label: 'Report',
                  height: 52,
                  background: p.danger,
                  foreground: Colors.white,
                  fontSize: 15,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  if (ok == true) {
    VideoEngagementStore.instance.report(video.youtubeId);
    if (context.mounted) _snack(context, 'Thanks. This video has been reported.');
  }
}
