import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/splash/screens/splash_screen.dart';
import 'package:vitanet/features/onboarding/screens/onboarding_screen.dart';
import 'package:vitanet/features/home/screens/home_screen.dart';
import 'package:vitanet/features/chat/screens/chat_screen.dart';
import 'package:vitanet/features/triage_result/screens/triage_result_screen.dart';
import 'package:vitanet/features/profile/screens/profile_screen.dart';
import 'package:vitanet/features/profile/screens/edit_profile_screen.dart';
import 'package:vitanet/features/settings/screens/settings_screen.dart';
import 'package:vitanet/features/settings/screens/privacy_screen.dart';
import 'package:vitanet/features/settings/screens/about_screen.dart';
import 'package:vitanet/features/settings/screens/disclaimer_screen.dart';
import 'package:vitanet/features/settings/screens/help_center_screen.dart';
import 'package:vitanet/features/resources/screens/resources_screen.dart';
import 'package:vitanet/features/resources/screens/emergency_protocols_screen.dart';
import 'package:vitanet/features/resources/screens/general_health_library_screen.dart';
import 'package:vitanet/features/resources/screens/medicine_search_screen.dart';
import 'package:vitanet/features/resources/screens/video_library_screen.dart';

import 'package:vitanet/features/auth/screens/role_selection_screen.dart';
import 'package:vitanet/features/auth/screens/patient_login_screen.dart';
import 'package:vitanet/features/auth/screens/registration_form_screen.dart';
import 'package:vitanet/features/auth/screens/patient_completion_screen.dart';

// Hospital portal
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/portal_gate_screen.dart';

import 'package:vitanet/features/devices/screens/device_connection_screen.dart';
import 'package:vitanet/features/assessment/screens/assessment_wizard_screen.dart';
import 'package:vitanet/features/pharmacy/screens/pharmacy_screen.dart';
import 'package:vitanet/features/first_aid/screens/first_aid_screen.dart';
import 'package:vitanet/features/history/screens/history_screen.dart';
import 'package:vitanet/features/notifications/screens/notifications_screen.dart';
import 'package:vitanet/features/health_trends/screens/health_trends_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _routerRefreshStream = Provider<_AuthChangeNotifier>((ref) {
  final notifier = _AuthChangeNotifier();
  ref.listen<AuthState>(authProvider, (_, next) {
    notifier.notify();
  });
  // Re-run redirects when staff access (GET /staff/me) resolves or changes.
  ref.listen<AsyncValue<StaffAccess>>(staffAccessProvider, (_, next) {
    notifier.notify();
  });
  return notifier;
});

/// A [ChangeNotifier] that [GoRouter] can listen to for refreshes.
class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.read(_routerRefreshStream);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      // Portal access comes only from the backend staff account, never from
      // the Firestore profile role. Null while loading / unavailable.
      final staffAsync = ref.read(staffAccessProvider);
      final staffAccess = staffAsync.isLoading ? null : staffAsync.valueOrNull;

      final path = state.uri.path;

      // Public routes â€” always accessible
      final publicRoutes = ['/splash', '/login', '/onboarding', '/privacy', '/disclaimer'];
      final isPublic =
          publicRoutes.any((r) => path == r || path.startsWith('$r/'));

      // If user is not authenticated and tries to access a protected route
      final isUnauthenticated =
          authState.status == AuthStatus.unauthenticated ||
          authState.status == AuthStatus.error;
      if (isUnauthenticated && !isPublic) {
        return '/login';
      }

      // Staff routing: patients away from /admin, staff away from the
      // patient home/chat. The /admin gate itself shows pending / rejected /
      // suspended / create-hospital states.
      if (isUnauthenticated) return null;
      final staffRedirect = staffRouteRedirect(path, staffAccess);
      if (staffRedirect != null) return staffRedirect;
      if (path == '/') return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/admin',
        builder: (context, state) => const PortalGate(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/login/patient',
        builder: (context, state) => const PatientLoginScreen(),
      ),
      GoRoute(
        path: '/login/hospital_personnel',
        builder: (context, state) => const RegistrationFormScreen(),
      ),
      GoRoute(
        path: '/login/patient_completion',
        builder: (context, state) => const PatientCompletionScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/triage-result',
        builder: (context, state) => const TriageResultScreen(),
      ),
      // Settings is now a top-level route so it pushes over the bottom nav bar
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/help-center',
        builder: (context, state) => const HelpCenterScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/disclaimer',
        builder: (context, state) => const DisclaimerScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/edit-profile',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'] ?? (state.extra as String?);
          return EditProfileScreen(initialTab: tab);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/assessment',
        builder: (context, state) => const AssessmentWizardScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/pharmacy',
        builder: (context, state) => const PharmacyScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/first-aid',
        builder: (context, state) => const FirstAidScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/device-connection/:metricId',
        builder: (context, state) {
          final metricId = state.pathParameters['metricId']!;
          return DeviceConnectionScreen(metricId: metricId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/health-trends/:metricId',
        builder: (context, state) {
          final metricId = state.pathParameters['metricId']!;
          return HealthTrendsScreen(metricId: metricId);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _ScaffoldWithNavBar(
            navigationShell: navigationShell,
            currentPath: state.uri.path,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/resources',
                builder: (context, state) => const ResourcesScreen(),
                routes: [
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'emergency',
                    builder: (context, state) => const EmergencyHubScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'medicines',
                    builder: (context, state) => const MedicineSearchScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'videos',
                    builder: (context, state) => const VideoLibraryScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'health-library',
                    builder: (context, state) => const GeneralHealthLibraryScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _ScaffoldWithNavBar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final String currentPath;

  const _ScaffoldWithNavBar({
    required this.navigationShell,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Staff use the hospital portal (/admin); this shell is the patient app.
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const topLevelPaths = {'/home', '/chat', '/resources', '/profile'};
    final isTopLevel = topLevelPaths.contains(currentPath);

    const activeColor = AppColors.brand;
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: false,
      extendBodyBehindAppBar: false,
      body: isDesktop
          ? Row(
              children: [
                _buildDesktopSidebar(context, ref),
                Expanded(
                  child: Column(
                    children: [
                      _buildDesktopBreadcrumb(context),
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) => handleScrollNotification(n, ref),
                          child: navigationShell,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) => handleScrollNotification(n, ref),
                    child: navigationShell,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
                      final isNavVisible = ref.watch(navBarVisibleProvider);
                      final showMobileNav = isTopLevel && !isKeyboardOpen && isNavVisible;

                      return AnimatedSlide(
                        offset: showMobileNav ? Offset.zero : const Offset(0, 1.2),
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        child: AnimatedOpacity(
                          opacity: showMobileNav ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOutCubic,
                          child: IgnorePointer(
                            ignoring: !showMobileNav,
                            child: _buildFullWidthBottomNavBar(
                              context,
                              activeColor,
                              inactiveColor,
                              isDark,
                              ref,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: null,
    );
  }

  Widget _buildFullWidthBottomNavBar(
    BuildContext context,
    Color activeColor,
    Color inactiveColor,
    bool isDark,
    WidgetRef ref,
  ) {
    final p = VnPalette.of(context);

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.line, width: 1.0)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: SizedBox(
              height: 56,
              child: Row(
                children: _buildNavItems(
                  context,
                  activeColor,
                  inactiveColor,
                  isDark,
                  ref,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  static final _patientNavItems = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _NavItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_outline_rounded,
      label: 'AI Chat',
    ),
    _NavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, label: 'Resources'),
    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  List<Widget> _buildNavItems(
    BuildContext context,
    Color activeColor,
    Color inactiveColor,
    bool isDark,
    WidgetRef ref,
  ) {
    final items = _patientNavItems;

    return List.generate(items.length, (index) {
      final isSelected = navigationShell.currentIndex == index;
      final item = items[index];

      return _MobileNavItemWidget(
        item: item,
        isSelected: isSelected,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        isDark: isDark,
        onTap: () {
          ref.read(navBarVisibleProvider.notifier).state = true;
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      );
    });
  }

  Widget _buildDesktopBreadcrumb(BuildContext context) {
    const titles = ['Home', 'Chat', 'Resources', 'Profile'];
    
    final currentIndex = navigationShell.currentIndex;
    final currentTitle = currentIndex >= 0 && currentIndex < titles.length 
        ? titles[currentIndex] 
        : '';
        
    if (currentTitle == 'Chat') {
      return const SizedBox.shrink();
    }

    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
        child: Row(
          children: [
            Text(
              'VitaNet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            Text(
              currentTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, WidgetRef ref) {
    final items = _patientNavItems;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = const Color(0xFF0D9488);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final sidebarBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return SizedBox(
      width: 256,
      height: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: sidebarBg,
          border: Border(
            right: BorderSide(color: borderColor, width: 1.0),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 24, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand Mark
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => navigationShell.goBranch(0),
                      child: Row(
                        children: [
                          const VitaNetLogo(size: 32),
                          const SizedBox(width: 10),
                          Text(
                            'VitaNet',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Navigation Items
                ...List.generate(items.length, (index) {
                  final isSelected = navigationShell.currentIndex == index;
                  final item = items[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _DesktopNavItemRow(
                      item: item,
                      isSelected: isSelected,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      isDark: isDark,
                      onTap: () => navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
                      ),
                    ),
                  );
                }),

                const Spacer(),

                // Anchored Interactive User Profile Card
                _DesktopSidebarUserFooter(
                  navigationShell: navigationShell,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavItemWidget extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDark;

  const _MobileNavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDark,
  });

  @override
  State<_MobileNavItemWidget> createState() => _MobileNavItemWidgetState();
}

class _MobileNavItemWidgetState extends State<_MobileNavItemWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutBack,
      ),
    );
    if (widget.isSelected) {
      _scaleController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _MobileNavItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isSelected && widget.isSelected) {
      _scaleController.forward(from: 0.0);
    } else if (oldWidget.isSelected && !widget.isSelected) {
      _scaleController.reverse();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final effectiveColor = widget.isSelected
        ? (widget.isDark ? AppColors.mintLight : AppColors.brand)
        : (_isHovered ? p.ink : p.muted);

    return Expanded(
      child: Semantics(
        button: true,
        selected: widget.isSelected,
        label: widget.item.label,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: _handleTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isSelected ? p.brandTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Icon(
                      widget.isSelected ? widget.item.activeIcon : widget.item.icon,
                      color: effectiveColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.label,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: effectiveColor,
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

class _DesktopSidebarUserFooter extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final bool isDark;

  const _DesktopSidebarUserFooter({
    required this.navigationShell,
    required this.isDark,
  });

  @override
  ConsumerState<_DesktopSidebarUserFooter> createState() =>
      _DesktopSidebarUserFooterState();
}

class _DesktopSidebarUserFooterState
    extends ConsumerState<_DesktopSidebarUserFooter> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final rawName = profile?.name.trim() ?? '';
    final displayName = rawName.isNotEmpty ? rawName : 'Anonye';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A';
    const roleText = 'Patient';
    final isSelected = widget.navigationShell.currentIndex == 3;

    final bgColor = isSelected
        ? (widget.isDark
            ? const Color(0xFF0D9488).withValues(alpha: 0.15)
            : const Color(0xFFE6F4F1))
        : (_isHovered
            ? (widget.isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF1F5F9))
            : Colors.transparent);

    final borderColor = isSelected
        ? const Color(0xFF0D9488).withValues(alpha: 0.3)
        : (_isHovered
            ? (widget.isDark
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0))
            : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.navigationShell.goBranch(3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      roleText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: widget.isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.settings_outlined,
                size: 16,
                color: _isHovered || isSelected
                    ? const Color(0xFF0D9488)
                    : (widget.isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItemRow extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDark;

  const _DesktopNavItemRow({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDark,
  });

  @override
  State<_DesktopNavItemRow> createState() => _DesktopNavItemRowState();
}

class _DesktopNavItemRowState extends State<_DesktopNavItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.isSelected
        ? widget.activeColor
        : (_isHovered
            ? (widget.isDark ? Colors.white : const Color(0xFF0F172A))
            : widget.inactiveColor);

    final bgColor = widget.isSelected
        ? (widget.isDark
            ? const Color(0xFF0D9488).withValues(alpha: 0.15)
            : const Color(0xFFE6F4F1))
        : (_isHovered
            ? (widget.isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF1F5F9))
            : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                if (widget.isSelected)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 3.5,
                    child: Container(
                      color: widget.activeColor,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(
                        widget.isSelected ? widget.item.activeIcon : widget.item.icon,
                        color: effectiveColor,
                        size: 19,
                        shadows: widget.isSelected
                            ? [
                                Shadow(
                                  color: widget.activeColor.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.item.label,
                          style: GoogleFonts.plusJakartaSans(
                            color: effectiveColor,
                            fontSize: 13.5,
                            fontWeight:
                                widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
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

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavItem({required this.icon, required this.activeIcon, required this.label});
}
