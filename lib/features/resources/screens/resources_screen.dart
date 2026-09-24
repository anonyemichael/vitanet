import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/features/resources/screens/health_library_screen.dart';
import 'package:vitanet/features/resources/screens/general_health_library_screen.dart';
import 'package:vitanet/features/resources/screens/medicine_search_screen.dart';
import 'package:vitanet/features/resources/screens/video_library_screen.dart';
import 'package:vitanet/shared/widgets/premium_background.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85); // Increased width
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: Stack(
          children: [
            // Subtle, professional background blobs
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colorScheme.primary.withValues(alpha: 0.15),
                  boxShadow: [BoxShadow(color: context.colorScheme.primary.withValues(alpha: 0.15), blurRadius: 100, spreadRadius: 50)],
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colorScheme.primary.withValues(alpha: 0.1),
                  boxShadow: [BoxShadow(color: context.colorScheme.primary.withValues(alpha: 0.1), blurRadius: 100, spreadRadius: 50)],
                ),
              ),
            ),
            
            // Full Page Blur for the Blobs
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: const SizedBox(),
              ),
            ),
            
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.1),
                              child: child,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.explore_rounded,
                              size: 48,
                              color: context.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              context.colorScheme.primary,
                              const Color(0xFF10B981), // Emerald green
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'Resources Hub',
                            textAlign: TextAlign.center,
                            style: context.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Swipe to explore your health resources.',
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: context.isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 800;
                    final cards = [
                      _buildDashboardCard(
                        context,
                        title: 'Emergencies\n& First Aid',
                        icon: Icons.medical_services_rounded,
                        color: const Color(0xFFEF4444),
                        imagePath: 'assets/images/first_aid_real.jpg',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthLibraryScreen()));
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        title: 'Medicine\nDirectory',
                        icon: Icons.medication_liquid_rounded,
                        color: const Color(0xFF3B82F6),
                        imagePath: 'assets/images/medicine_real.jpg',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicineSearchScreen()));
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        title: 'Video\nTutorials',
                        icon: Icons.play_circle_fill_rounded,
                        color: const Color(0xFF8B5CF6),
                        imagePath: 'assets/images/video_real.jpg',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoLibraryScreen()));
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        title: 'Health\nLibrary',
                        icon: Icons.library_books_rounded,
                        color: const Color(0xFF10B981),
                        imagePath: 'assets/images/health_real.jpg',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const GeneralHealthLibraryScreen()));
                        },
                      ),
                    ];

                    if (isDesktop) {
                      return GridView.count(
                        crossAxisCount: 4,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                        mainAxisSpacing: AppSpacing.xl,
                        crossAxisSpacing: AppSpacing.xl,
                        childAspectRatio: 1.0,
                        children: cards,
                      );
                    }

                    return PageView.builder(
                      controller: _pageController,
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        return Center(
                          child: cards[index],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    ),
  );
}

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isDark ? context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
            width: 4,
          ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Real Image Background
                Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: color.withValues(alpha: 0.2),
                    child: Icon(icon, size: 64, color: color),
                  ),
                ),
                
                // Dark Gradient overlay for text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
                
                // Content
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 48),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
