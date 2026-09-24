import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/health_article.dart';
import '../models/health_video.dart';
import 'video_player_screen.dart';
class HealthArticleDetailScreen extends StatefulWidget {
  final HealthArticle article;

  const HealthArticleDetailScreen({super.key, required this.article});

  @override
  State<HealthArticleDetailScreen> createState() => _HealthArticleDetailScreenState();
}

class _HealthArticleDetailScreenState extends State<HealthArticleDetailScreen> {
  bool _isBookmarked = false;
  bool _isHelpful = false;
  final Map<int, int> _selectedQuizOptions = {};
  final PageController _quizPageController = PageController();
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _quizPageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(context),
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeaderInfo(context),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildBodyContent(context),
                    if (widget.article.relatedVideoId != null) ...[
                      const SizedBox(height: AppSpacing.xxxl),
                      _buildVideoSection(context),
                    ],
                    if (widget.article.interactiveQuizzes.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxxl),
                      _buildQuizSection(context),
                    ],
                    const SizedBox(height: AppSpacing.xxxl),
                    _buildInteractiveFeedback(context),
                    const SizedBox(height: 120), // Bottom padding
                  ]),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive, // radial explosion
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple], 
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300.0,
      pinned: true,
      backgroundColor: widget.article.color,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: Icon(_isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded),
          onPressed: () {
            setState(() => _isBookmarked = !_isBookmarked);
            context.showSnack(_isBookmarked ? 'Saved to bookmarks' : 'Removed from bookmarks');
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.article.imageUrls.isEmpty)
              Container(
                color: widget.article.color.withValues(alpha: 0.1),
                child: Center(
                  child: Icon(
                    widget.article.icon,
                    size: 120,
                    color: widget.article.color.withValues(alpha: 0.5),
                  ),
                ),
              )
            else if (widget.article.imageUrls.length == 1)
              Image.network(
                widget.article.imageUrls.first,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: widget.article.color.withValues(alpha: 0.1),
                  child: Center(
                    child: Icon(
                      widget.article.icon,
                      size: 120,
                      color: widget.article.color.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              )
            else
              PageView.builder(
                itemCount: widget.article.imageUrls.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    widget.article.imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: widget.article.color.withValues(alpha: 0.1),
                      child: Center(
                        child: Icon(
                          widget.article.icon,
                          size: 120,
                          color: widget.article.color.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  );
                },
              ),
            // Gradient overlay for text readability on the app bar when scrolling up
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    widget.article.color.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.article.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.article.category.toUpperCase(),
                style: TextStyle(
                  color: widget.article.color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const Spacer(),
            Icon(Icons.schedule_rounded, size: 16, color: context.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              widget.article.readTime,
              style: TextStyle(
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          widget.article.title,
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.article.excerpt,
          style: TextStyle(
            fontSize: 20,
            height: 1.6,
            fontWeight: FontWeight.w500,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        ...widget.article.sections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.article.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notes_rounded, color: widget.article.color, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            section.heading,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: widget.article.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    section.content,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: context.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            )),
        if (widget.article.keyTakeaways.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: widget.article.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_rounded, color: widget.article.color),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Key Takeaways',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.article.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ...widget.article.keyTakeaways.map((takeaway) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•', style: TextStyle(fontSize: 20, color: widget.article.color, fontWeight: FontWeight.bold)),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              takeaway,
                              style: TextStyle(fontSize: 16, height: 1.5, color: context.colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
        if (widget.article.mythVsFact != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.compare_arrows_rounded, color: Colors.orange),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Myth vs. Fact',
                      style: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Myth:', style: TextStyle(fontWeight: FontWeight.bold, color: context.colorScheme.error)),
                Text(widget.article.mythVsFact!.myth, style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: AppSpacing.md),
                Text('Fact:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade600)),
                Text(widget.article.mythVsFact!.fact),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuizSection(BuildContext context) {
    final quizzes = widget.article.interactiveQuizzes;
    return Container(
      height: 520, // Fixed height for the PageView container
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.article.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_rounded, color: widget.article.color),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Test Your Knowledge',
                style: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: widget.article.color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: PageView.builder(
              controller: _quizPageController,
              physics: const NeverScrollableScrollPhysics(), // Only slide on button press
              itemCount: quizzes.length,
              itemBuilder: (context, quizIndex) {
                final quiz = quizzes[quizIndex];
                final selectedOption = _selectedQuizOptions[quizIndex];
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Question ${quizIndex + 1} of ${quizzes.length}', style: TextStyle(color: widget.article.color, fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(quiz.question, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.lg),
                      ...List.generate(quiz.options.length, (index) {
                        final isSelected = selectedOption == index;
                        final isCorrect = index == quiz.correctIndex;
                        final showResult = selectedOption != null;
                        
                        Color? bgColor;
                        Color? borderColor;
                        
                        if (showResult) {
                          if (isCorrect) {
                            bgColor = Colors.green.withValues(alpha: 0.1);
                            borderColor = Colors.green;
                          } else if (isSelected && !isCorrect) {
                            bgColor = Colors.red.withValues(alpha: 0.1);
                            borderColor = Colors.red;
                          }
                        }

                        Widget optionCard = Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: bgColor ?? (isSelected ? widget.article.color.withValues(alpha: 0.1) : Colors.transparent),
                            border: Border.all(color: borderColor ?? (isSelected ? widget.article.color : context.colorScheme.outlineVariant)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(quiz.options[index])),
                              if (showResult && isCorrect)
                                const Icon(Icons.check_circle_rounded, color: Colors.green),
                              if (showResult && isSelected && !isCorrect)
                                const Icon(Icons.cancel_rounded, color: Colors.red),
                            ],
                          ),
                        );

                        if (showResult && isSelected && !isCorrect) {
                           optionCard = optionCard.animate().shake(duration: 400.ms, hz: 4);
                        } else if (showResult && isCorrect) {
                           optionCard = optionCard.animate().scale(duration: 300.ms, curve: Curves.easeOutBack, begin: const Offset(1,1), end: const Offset(1.02, 1.02));
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: InkWell(
                            onTap: showResult ? null : () {
                              setState(() => _selectedQuizOptions[quizIndex] = index);
                              if (index == quiz.correctIndex) {
                                // Trigger short confetti or full confetti if last question
                                if (quizIndex == quizzes.length - 1) {
                                  _confettiController.play();
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: optionCard,
                          ),
                        );
                      }),
                      if (selectedOption != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: selectedOption == quiz.correctIndex 
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            quiz.explanation,
                            style: TextStyle(
                              color: selectedOption == quiz.correctIndex ? Colors.green.shade700 : Colors.orange.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (quizIndex < quizzes.length - 1)
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: () {
                                _quizPageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                              label: const Text('Next Question'),
                              style: FilledButton.styleFrom(
                                backgroundColor: widget.article.color,
                              ),
                            ),
                          )
                        else
                          Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.md),
                              child: Text(
                                'Quiz Completed! 🎉',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: widget.article.color,
                                  fontSize: 18,
                                ),
                              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack).shimmer(delay: 500.ms),
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection(BuildContext context) {
    if (widget.article.relatedVideoId == null) return const SizedBox.shrink();
    
    final videoId = widget.article.relatedVideoId!;
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Video Guide',
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: widget.article.color,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(
                    video: HealthVideo(
                      videoId: videoId,
                      title: 'Guide: ${widget.article.title}',
                      thumbnailUrl: thumbnailUrl,
                      duration: '',
                      category: widget.article.category,
                      organization: 'Health Library',
                      summary: widget.article.excerpt,
                      keySteps: widget.article.keyTakeaways
                          .map((t) => VideoKeyStep(time: '•', action: t))
                          .toList(),
                      verificationStatus: 'Verified Resource',
                    ),
                  ),
                ),
              );
            },
            child: Ink(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                image: DecorationImage(
                  image: NetworkImage(thumbnailUrl),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.black.withValues(alpha: 0.4),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.article.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.article.color.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveFeedback(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: widget.article.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.article.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            'Was this article helpful?',
            style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  setState(() => _isHelpful = true);
                  context.showSnack('Thank you for your feedback!');
                },
                icon: Icon(_isHelpful ? Icons.thumb_up_alt_rounded : Icons.thumb_up_off_alt_rounded),
                label: const Text('Yes'),
                style: FilledButton.styleFrom(
                  backgroundColor: _isHelpful ? widget.article.color.withValues(alpha: 0.2) : null,
                  foregroundColor: _isHelpful ? widget.article.color : null,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              FilledButton.tonalIcon(
                onPressed: () {
                  setState(() => _isHelpful = false);
                  context.showSnack('Thank you for your feedback!');
                },
                icon: const Icon(Icons.thumb_down_off_alt_rounded),
                label: const Text('No'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

