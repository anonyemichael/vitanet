import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/home/screens/home_search_screen.dart';
import 'package:vitanet/features/home/widgets/filter_bottom_sheet.dart';
import 'package:vitanet/features/notifications/screens/notifications_screen.dart';

class HeaderSection extends ConsumerWidget {
  const HeaderSection({super.key});


  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final authState = ref.watch(authProvider);
    final greeting = _getGreeting();
    final name = profile?.name ?? 'Alex';

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxxl, AppSpacing.xl, AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        border: Border(
          bottom: BorderSide(
            color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        boxShadow: [
          if (!context.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: GoogleFonts.inter(
                        color: context.isDark ? Colors.white60 : Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        color: context.isDark ? Colors.white : Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w500, // Medium, not bold
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (!context.isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            color: context.isDark ? Colors.white : Colors.black87,
                            size: 24,
                          ),
                          Positioned(
                            top: 10,
                            right: 12,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  GestureDetector(
                    onTap: () => StatefulNavigationShell.of(context).goBranch(3),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                        image: authState.user?.photoURL != null
                            ? DecorationImage(
                                image: NetworkImage(authState.user!.photoURL!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: authState.user?.photoURL == null
                          ? Center(
                              child: Text(
                                _getInitials(name),
                                style: TextStyle(
                                  color: context.isDark ? Colors.white : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // Search Bar
          Hero(
            tag: 'home_search_bar',
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.search_rounded,
                      color: context.isDark ? Colors.white54 : Colors.black45,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        readOnly: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => const HomeSearchScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        style: TextStyle(
                          color: context.isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search health, insights...',
                          hintStyle: TextStyle(
                            color: context.isDark ? Colors.white38 : Colors.black38,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showFilter(context),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.tune_rounded,
                          color: context.isDark ? Colors.white54 : Colors.black45,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
