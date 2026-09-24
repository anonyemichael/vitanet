import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';

import '../models/medicine.dart';
import 'video_player_screen.dart';
import '../models/health_video.dart';

class MedicineDetailScreen extends StatelessWidget {
  final Medicine medicine;

  const MedicineDetailScreen({
    super.key,
    required this.medicine,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text(medicine.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () => context.showSnack('Sharing ${medicine.name} info...'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroImage(context),
            const SizedBox(height: AppSpacing.xxl),
            _buildInfoCard(context),
            const SizedBox(height: AppSpacing.xxl),
            if (medicine.relatedVideoId != null) ...[
              _buildRelatedVideo(context),
              const SizedBox(height: AppSpacing.xxl),
            ],
            _buildInteractiveTabs(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: medicine.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: medicine.color.withValues(alpha: 0.2)),
        image: medicine.heroImageUrl != null 
            ? DecorationImage(
                image: NetworkImage(medicine.heroImageUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.2), BlendMode.darken),
              )
            : null,
      ),
      child: medicine.heroImageUrl == null
          ? Center(
              child: Hero(
                tag: 'med_icon_${medicine.name}',
                child: Icon(medicine.icon, size: 80, color: medicine.color),
              ),
            )
          : null,
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.isDark ? context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!context.isDark)
            BoxShadow(
              color: medicine.color.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: medicine.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  medicine.type.toUpperCase(),
                  style: TextStyle(
                    color: medicine.color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (medicine.isFdaApproved) ...[
                Icon(Icons.verified_rounded, color: context.colorScheme.primary),
                const SizedBox(width: 4),
                Text('FDA Approved', style: context.textTheme.labelMedium),
              ]
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            medicine.name,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            medicine.description,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTabs(BuildContext context) {
    if (medicine.details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Information',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...medicine.details.map((detail) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildAccordion(
            context,
            title: detail.title,
            icon: detail.icon,
            content: detail.content,
          ),
        )),
      ],
    );
  }

  Widget _buildRelatedVideo(BuildContext context) {
    // In a real app we would load the video from the video catalog based on relatedVideoId.
    // Here we'll create a dummy video that links to the player.
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              video: HealthVideo(
                videoId: medicine.relatedVideoId ?? 'wUjEwJ19gW4',
                title: 'How to safely take ${medicine.name}',
                summary: 'A quick guide on safely administering this medication and what to watch out for.',
                duration: '3:45',
                category: 'Medication Guide',
                organization: 'VitaNet Health',
                thumbnailUrl: medicine.heroImageUrl ?? 'https://images.unsplash.com/photo-1576602976047-174e57a47881?auto=format&fit=crop&q=80',
                keySteps: [],
                verificationStatus: 'Verified Medical Guide',
              ),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: context.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video Guide',
                    style: TextStyle(
                      color: context.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How to take ${medicine.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordion(BuildContext context, {required String title, required IconData icon, required String content}) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none), // Remove borders on expand
        leading: Icon(icon, color: medicine.color),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              content,
              style: TextStyle(
                height: 1.6,
                color: context.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
