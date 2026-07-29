import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/data/providers/providers.dart';

import 'package:vitanet/features/splash/screens/splash_screen.dart';
import 'package:vitanet/features/onboarding/screens/onboarding_screen.dart';
import 'package:vitanet/features/home/screens/home_screen.dart';
import 'package:vitanet/features/chat/screens/chat_screen.dart';
import 'package:vitanet/features/triage_result/screens/triage_result_screen.dart';
import 'package:vitanet/features/history/screens/history_screen.dart';
import 'package:vitanet/features/profile/screens/profile_screen.dart';
import 'package:vitanet/features/profile/screens/edit_profile_screen.dart';
import 'package:vitanet/features/settings/screens/settings_screen.dart';
import 'package:vitanet/features/settings/screens/privacy_screen.dart';
import 'package:vitanet/features/settings/screens/about_screen.dart';
import 'package:vitanet/features/settings/screens/disclaimer_screen.dart';
import 'package:vitanet/features/settings/screens/help_center_screen.dart';
import 'package:vitanet/features/first_aid/screens/emergency_center_screen.dart';
import 'package:vitanet/features/pharmacy/screens/pharmacy_screen.dart';
import 'package:vitanet/features/assessment/screens/assessment_wizard_screen.dart';
import 'package:vitanet/features/resources/screens/resources_screen.dart';

import 'package:vitanet/features/auth/screens/role_selection_screen.dart';
import 'package:vitanet/features/auth/screens/patient_login_screen.dart';
import 'package:vitanet/features/auth/screens/registration_form_screen.dart';
import 'package:vitanet/features/auth/screens/patient_completion_screen.dart';

// Admin screens
import 'package:vitanet/features/admin/screens/admin_main_navigation_screen.dart';
import 'package:vitanet/features/admin/screens/case_management_screen.dart';

import 'package:vitanet/features/devices/screens/device_connection_screen.dart';
import 'package:vitanet/features/health_trends/screens/health_trends_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final profile = ref.read(userProfileProvider);
      final isHealthWorker = profile?.role == 'health_worker' || profile?.role == 'admin';
      
      if (state.uri.path.startsWith('/admin')) {
        if (!isHealthWorker) {
          return '/home'; // Redirect normal users away from admin dashboard
        }
      } else if (state.uri.path == '/home' && isHealthWorker) {
        return '/admin'; // Redirect health workers to their admin UI
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminMainNavigationScreen(),
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
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/first-aid',
        builder: (context, state) => const EmergencyCenterScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/pharmacy',
        builder: (context, state) => const PharmacyScreen(),
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
        builder: (context, state) => const EditProfileScreen(),
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

  const _ScaffoldWithNavBar({
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final isHealthWorker = profile?.role == 'health_worker' || profile?.role == 'admin';

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1E1E1E) 
                : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _buildNavItems(context, isHealthWorker),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNavItems(BuildContext context, bool showAdminTabs) {
    final items = showAdminTabs
        ? [
            _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
            _NavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: 'Alerts'),
            _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Patients'),
            _NavItem(icon: Icons.business_outlined, activeIcon: Icons.business, label: 'Hospital'),
            _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
          ]
        : [
            _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
            _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat'),
            _NavItem(icon: Icons.library_books_outlined, activeIcon: Icons.library_books_rounded, label: 'Resources'),
            _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
          ];

    return List.generate(items.length, (index) {
      final isSelected = navigationShell.currentIndex == index;
      final item = items[index];

      return GestureDetector(
        onTap: () => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                size: 26,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: -0.2,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavItem({required this.icon, required this.activeIcon, required this.label});
}
