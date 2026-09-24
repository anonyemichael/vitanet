import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/features/first_aid/screens/first_aid_screen.dart';
import 'package:vitanet/features/resources/widgets/emergency_widgets.dart';

class HealthLibraryScreen extends StatelessWidget {
  const HealthLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Emergencies & First Aid'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) {
            return _buildMobileLayout(context);
          } else {
            return _buildDesktopLayout(context);
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        120, // Add bottom padding to prevent nav bar from covering content
      ),
      children: [
        const EmergencyCallCard(),
        const SizedBox(height: AppSpacing.md),
        const LiveLocationCard(),
        const SizedBox(height: AppSpacing.xxl),
        _buildOfflineBanner(context),
        const SizedBox(height: AppSpacing.xxl),
        _buildFeaturedCarousel(context),
        const SizedBox(height: AppSpacing.xxl),
        Text('All First Aid Guides', style: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.md),
        ...FirstAidScreen.tips.map((tip) => _buildTipCard(context, tip)),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        120, // Add bottom padding to prevent nav bar from covering content
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(child: EmergencyCallCard()),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: LiveLocationCard()),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          _buildOfflineBanner(context),
          const SizedBox(height: AppSpacing.xxl),
          _buildFeaturedCarousel(context, isDesktop: true),
          const SizedBox(height: AppSpacing.xxxl),
          Text('All First Aid Guides', style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.lg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              mainAxisExtent: 90, // Fixed height for cards
            ),
            itemCount: FirstAidScreen.tips.length,
            itemBuilder: (context, index) {
              return _buildTipCard(context, FirstAidScreen.tips[index], isDesktop: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorScheme.tertiary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.offline_bolt_rounded, color: context.colorScheme.tertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Offline',
                  style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: context.colorScheme.onSurface),
                ),
                Text(
                  'These emergency guides are stored on your device so you can access them anywhere, anytime.',
                  style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCarousel(BuildContext context, {bool isDesktop = false}) {
    final featuredTips = FirstAidScreen.tips.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Critical Emergencies', style: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: isDesktop ? 220 : 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: featuredTips.length,
            separatorBuilder: (context, _) => const SizedBox(width: AppSpacing.lg),
            itemBuilder: (context, index) {
              return _buildFeaturedCard(context, featuredTips[index], isDesktop);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(BuildContext context, FirstAidTip tip, bool isDesktop) {
    return Container(
      width: isDesktop ? 350 : 280,
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tip.accent.withValues(alpha: 0.3)),
        boxShadow: [
          if (!context.isDark)
            BoxShadow(
              color: tip.accent.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => FirstAidDetailScreen(tip: tip)));
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (tip.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.darken,
                    child: Image.network(
                      tip.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: tip.accent.withValues(alpha: 0.15),
                        child: Center(
                          child: Icon(tip.icon, color: tip.accent, size: 48),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tip.accent.withValues(alpha: tip.imageUrl != null ? 0.9 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(tip.icon, color: tip.imageUrl != null ? Colors.white : tip.accent, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      tip.title,
                      style: context.textTheme.titleLarge?.copyWith(
                        color: tip.imageUrl != null ? Colors.white : context.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        shadows: tip.imageUrl != null ? const [
                          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))
                        ] : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tip.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: tip.imageUrl != null ? Colors.white.withValues(alpha: 0.9) : context.colorScheme.onSurfaceVariant,
                        shadows: tip.imageUrl != null ? const [
                          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))
                        ] : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard(BuildContext context, FirstAidTip tip, {bool isDesktop = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isDesktop ? 0 : AppSpacing.md),
      child: Material(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => FirstAidDetailScreen(tip: tip)));
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                if (tip.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      tip.imageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: tip.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(tip.icon, color: tip.accent),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: tip.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tip.icon, color: tip.accent),
                  ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tip.title,
                        style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tip.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
