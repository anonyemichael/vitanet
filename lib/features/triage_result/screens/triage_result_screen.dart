import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/constants/app_strings.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/utils/triage_level_style.dart';
import 'package:vitanet/shared/widgets/disclaimer_banner.dart';

/// Displays the AI triage recommendation after a chat session.
class TriageResultScreen extends ConsumerWidget {
  final bool isEmbedded;
  const TriageResultScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(triageResultProvider);

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Triage Result')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 56,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('No result available', style: context.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Start a symptom check to get a triage recommendation.',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final style = TriageLevelStyle.of(result.level);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            leading: isEmbedded
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () {
                      ref.read(chatMessagesProvider.notifier).clear();
                      context.go('/home');
                    },
                  ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [style.color, style.color.withValues(alpha: 0.72)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              child: Icon(
                                style.icon,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        style.fullLabel,
                        style: context.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.primarySymptom,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.summary, style: context.textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Recommendations', style: context.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  ...result.recommendations.map(
                    (rec) => _RecommendationCard(text: rec, color: style.color),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('What to Monitor', style: context.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: result.monitorSymptoms
                          .map(
                            (s) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.visibility_rounded,
                                    size: 18,
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      s,
                                      style: context.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (result.level == TriageLevel.emergency) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            LaunchHelpers.dialOrSnack(context, '911'),
                        icon: const Icon(Icons.phone),
                        label: const Text('Call Emergency Services'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colorScheme.error,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/pharmacy'),
                        icon: const Icon(Icons.local_pharmacy_rounded),
                        label: const Text('Find a Pharmacy'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (result.level == TriageLevel.pharmacist) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/pharmacy'),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text('Find a Pharmacy Nearby'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  const DisclaimerBanner(),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Share.share(
                              'VitaNet Triage Result\n\n'
                              'Level: ${style.fullLabel}\n'
                              'Symptom: ${result.primarySymptom}\n'
                              '${result.summary}\n\n'
                              'Recommendations:\n'
                              '${result.recommendations.map((r) => '• $r').join('\n')}\n\n'
                              '⚠️ ${AppStrings.disclaimer}',
                            );
                          },
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref.read(chatMessagesProvider.notifier).clear();
                            context.go('/home');
                            context.push('/chat');
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('New Check'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final String text;
  final Color color;

  const _RecommendationCard({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: context.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
