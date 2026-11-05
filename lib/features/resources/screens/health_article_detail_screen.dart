import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

import '../models/health_article.dart';
import '../models/health_video.dart';
import '../widgets/resource_media.dart';
import 'general_health_library_screen.dart' show articlePhoto, cleanArticleSource;
import 'video_player_screen.dart';

/// Reader view for a health library article.
class HealthArticleDetailScreen extends StatefulWidget {
  final HealthArticle article;

  const HealthArticleDetailScreen({super.key, required this.article});

  @override
  State<HealthArticleDetailScreen> createState() => _HealthArticleDetailScreenState();
}

class _HealthArticleDetailScreenState extends State<HealthArticleDetailScreen> {
  final ScrollController _scroll = ScrollController();
  late final ConfettiController _confettiController;
  final Map<int, int> _selectedQuizOptions = {};
  double _progress = 0;
  double _textScale = 1;
  bool _isBookmarked = false;
  bool? _helpful;

  HealthArticle get a => widget.article;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final value = max <= 0 ? 1.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    if ((value - _progress).abs() > 0.01) setState(() => _progress = value);
  }

  void _cycleTextSize() {
    setState(() => _textScale = _textScale >= 1.3 ? 1 : (_textScale + 0.15));
  }

  void _toggleBookmark() {
    setState(() => _isBookmarked = !_isBookmarked);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(_isBookmarked ? 'Saved to bookmarks' : 'Removed from bookmarks'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _share() async {
    final link = a.doi != null && a.doi!.isNotEmpty ? '\nhttps://doi.org/${a.doi}' : '';
    try {
      await Share.share('${a.title}\n${cleanArticleSource(a)}$link', subject: a.title);
    } catch (_) {}
  }

  void _askAi() {
    final points = a.keyTakeaways.take(3).join('; ');
    askVitaNetAi(
      context,
      'I am reading "${a.title}" (${cleanArticleSource(a)}). '
      '${points.isNotEmpty ? 'Key points: $points. ' : ''}'
      'Can you explain what it means for me in plain language?',
    );
  }

  void _openVideo() {
    final id = a.relatedVideoId!;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          video: HealthVideo(
            videoId: id,
            title: 'Guide: ${a.title}',
            thumbnailUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
            duration: '',
            category: a.category,
            organization: 'Health Library',
            summary: a.excerpt,
            keySteps: a.keyTakeaways.map((t) => VideoKeyStep(time: '•', action: t)).toList(),
            verificationStatus: 'Verified Resource',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final photo = articlePhoto(a);
    final s = _textScale;
    final bodyColor = p.isDark ? p.inkSoft : const Color(0xFF1E293B);

    return vnReadableWidth(Scaffold(
      backgroundColor: p.surface,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      VnIconButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Back',
                        iconSize: 26,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Text size',
                        child: Semantics(
                          button: true,
                          label: 'Text size',
                          excludeSemantics: true,
                          child: InkWell(
                            onTap: _cycleTextSize,
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(child: Text('Aa', style: VnText.body(15, weight: FontWeight.w800, color: p.ink))),
                            ),
                          ),
                        ),
                      ),
                      VnIconButton(
                        icon: _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        tooltip: _isBookmarked ? 'Remove bookmark' : 'Save',
                        foreground: _isBookmarked ? p.brand : p.ink,
                        onPressed: _toggleBookmark,
                      ),
                      VnIconButton(icon: Icons.ios_share_rounded, tooltip: 'Share', onPressed: _share),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Reading progress ${(_progress * 100).round()} percent',
                  child: SizedBox(
                    height: 4,
                    child: ColoredBox(
                      color: p.surfaceAlt,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _progress,
                          child: ColoredBox(color: p.brand, child: const SizedBox.expand()),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.paddingOf(context).bottom + 120),
                    children: [
                      Text(a.category, style: VnText.body(13, weight: FontWeight.w700, color: p.brand)),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        child: Text(a.title,
                            style: VnText.heading(27 * s, color: p.ink, height: 1.25, letterSpacing: -0.3)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: VnPhoto(
                                VnPhotos.clinicianFemale,
                                alignment: const Alignment(0, -0.5),
                                cacheWidth: 120,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cleanArticleSource(a),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: VnText.body(14, weight: FontWeight.w600, color: p.ink)),
                                Text(
                                  [
                                    a.difficultyLevel,
                                    if (a.publishedDate != null && a.publishedDate!.isNotEmpty) a.publishedDate!,
                                    a.readTime.replaceAll(' read', ''),
                                  ].join(' · '),
                                  style: VnText.body(12, color: p.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          height: 200,
                          child: VnNetworkPhoto(
                            url: photo.url,
                            fallbackAsset: photo.asset,
                            alignment: const Alignment(0, -0.2),
                            cacheWidth: 900,
                          ),
                        ),
                      ),
                      if (a.keyTakeaways.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _KeyPoints(points: a.keyTakeaways, scale: s),
                      ],
                      if (a.excerpt.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(a.excerpt, style: VnText.body(16 * s, color: bodyColor, height: 1.75)),
                      ],
                      for (final section in a.sections) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          header: true,
                          child: Text(section.heading, style: VnText.heading(20 * s, color: p.ink)),
                        ),
                        const SizedBox(height: 16),
                        Text(section.content, style: VnText.body(16 * s, color: bodyColor, height: 1.75)),
                      ],
                      if (a.mythVsFact != null) ...[
                        const SizedBox(height: 16),
                        _PullQuote(myth: a.mythVsFact!.myth, fact: a.mythVsFact!.fact, scale: s),
                      ],
                      if (a.doi != null && a.doi!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        VnOutlineButton(
                          label: 'Read the full study',
                          icon: Icons.open_in_new_rounded,
                          foreground: p.brand,
                          borderColor: p.brand,
                          onPressed: () => LaunchHelpers.openWeb(context, 'https://doi.org/${a.doi}'),
                        ),
                      ],
                      if (a.relatedVideoId != null) ...[
                        const SizedBox(height: 20),
                        VnListGroup(children: [
                          VnListRow(
                            leading: const VnIconTile(
                              icon: Icons.play_arrow_rounded,
                              bg: Color(0xFFCCFBF1),
                              fg: Color(0xFF0F766E),
                            ),
                            title: 'Watch the video guide',
                            subtitle: a.category,
                            onTap: _openVideo,
                          ),
                        ]),
                      ],
                      if (a.interactiveQuizzes.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildQuiz(p),
                      ],
                      const SizedBox(height: 20),
                      _buildFeedback(p),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              child: _AskAiBar(onAsk: _askAi),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Color(0xFF0F766E), Color(0xFF2DD4BF), Color(0xFF6D28D9), Color(0xFFF59E0B)],
              ),
            ),
          ],
        ),
      ),
    ), maxWidth: 840, background: p.surface);
  }

  Widget _buildQuiz(VnPalette p) {
    final quizzes = a.interactiveQuizzes;
    return VnCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_outlined, size: 18, color: p.brand),
              const SizedBox(width: 8),
              Text('Check your understanding', style: VnText.heading(16, weight: FontWeight.w700, color: p.ink)),
            ],
          ),
          for (var qi = 0; qi < quizzes.length; qi++) ...[
            const SizedBox(height: 14),
            Text(quizzes[qi].question, style: VnText.body(15, weight: FontWeight.w600, color: p.ink, height: 1.4)),
            const SizedBox(height: 10),
            for (var oi = 0; oi < quizzes[qi].options.length; oi++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _QuizOption(
                  label: quizzes[qi].options[oi],
                  state: _selectedQuizOptions[qi] == null
                      ? _OptionState.idle
                      : oi == quizzes[qi].correctIndex
                          ? _OptionState.correct
                          : (_selectedQuizOptions[qi] == oi ? _OptionState.wrong : _OptionState.idle),
                  onTap: _selectedQuizOptions[qi] != null
                      ? null
                      : () {
                          setState(() => _selectedQuizOptions[qi] = oi);
                          if (oi == quizzes[qi].correctIndex && qi == quizzes.length - 1) {
                            _confettiController.play();
                          }
                        },
                ),
              ),
            if (_selectedQuizOptions[qi] != null)
              Text(quizzes[qi].explanation, style: VnText.body(13, color: p.inkSoft, height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedback(VnPalette p) {
    return Row(
      children: [
        Expanded(child: Text('Was this article helpful?', style: VnText.body(14, weight: FontWeight.w600, color: p.ink))),
        VnIconButton(
          icon: _helpful == true ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
          tooltip: 'Helpful',
          foreground: _helpful == true ? p.brand : p.muted,
          onPressed: () => setState(() => _helpful = true),
        ),
        VnIconButton(
          icon: _helpful == false ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
          tooltip: 'Not helpful',
          foreground: _helpful == false ? p.danger : p.muted,
          onPressed: () => setState(() => _helpful = false),
        ),
      ],
    );
  }
}

class _KeyPoints extends StatelessWidget {
  final List<String> points;
  final double scale;
  const _KeyPoints({required this.points, required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final fg = p.isDark ? const Color(0xFFCCFBF1) : const Color(0xFF134E4A);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.brandWash, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: p.brandDeep),
              const SizedBox(width: 6),
              Text('KEY POINTS',
                  style: VnText.body(12, weight: FontWeight.w800, color: p.brandDeep, letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 8),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 8 * scale, right: 10, left: 4),
                    child: Container(width: 5, height: 5, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
                  ),
                  Expanded(child: Text(point, style: VnText.body(14 * scale, color: fg, height: 1.6))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PullQuote extends StatelessWidget {
  final String myth;
  final String fact;
  final double scale;
  const _PullQuote({required this.myth, required this.fact, required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: p.brand, width: 4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Myth: $myth', style: VnText.body(14 * scale, color: p.muted, height: 1.5)),
          const SizedBox(height: 6),
          Text('"$fact"', style: VnText.heading(18 * scale, weight: FontWeight.w700, color: p.ink, height: 1.45)),
        ],
      ),
    );
  }
}

class _AskAiBar extends StatelessWidget {
  final VoidCallback onAsk;
  const _AskAiBar({required this.onAsk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x400F172A), blurRadius: 30, offset: Offset(0, 12))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Questions about this?', style: VnText.body(14, weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text('VitaNet AI can explain this article',
                    style: VnText.body(12, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          VnButton(
            label: 'Ask AI',
            icon: Icons.auto_awesome_rounded,
            height: 44,
            radius: 14,
            fontSize: 14,
            expand: false,
            background: const Color(0xFF2DD4BF),
            foreground: const Color(0xFF04201D),
            onPressed: onAsk,
          ),
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _QuizOption extends StatelessWidget {
  final String label;
  final _OptionState state;
  final VoidCallback? onTap;
  const _QuizOption({required this.label, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final (border, bg, icon) = switch (state) {
      _OptionState.correct => (const Color(0xFF10B981), p.tintBg(const Color(0xFFD1FAE5), const Color(0xFF047857)),
          Icons.check_circle_rounded),
      _OptionState.wrong => (p.danger, p.tintBg(const Color(0xFFFEE2E2), const Color(0xFFB91C1C)), Icons.cancel_rounded),
      _OptionState.idle => (p.line, p.surface, null),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(child: Text(label, style: VnText.body(14, color: p.ink))),
                if (icon != null) Icon(icon, size: 20, color: border),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
