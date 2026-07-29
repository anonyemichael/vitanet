import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet_frontend/providers/account_type_pro.dart';
import 'package:vitanet_frontend/screens/personal_register_screen.dart';
import 'package:vitanet_frontend/themes/app_theme.dart';
import 'package:vitanet_frontend/themes/responsive_design.dart';
import 'package:vitanet_frontend/widgets/account_type_card.dart';
import 'package:vitanet_frontend/widgets/logo.dart';

/// SCREEN 1 of the VitaNet Registration Flow: "Welcome to VitaNet".
///
/// Pure UI. All state/decisions live in [accountTypeSelectionProvider];
/// this widget only reads state and dispatches intents.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = ref.watch(accountTypeSelectionProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: isDark ? 0.12 : 0.35,
                child: const _SkylineDecoration(),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.maxContentWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.horizontalPadding,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      const VitaNetLogo(),
                      const SizedBox(height: 36),
                      Text(
                        'Welcome to VitaNet',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: context.responsiveFont(26),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'How will you use VitaNet?',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 32),
                      AccountTypeCard(
                        type: AccountType.healthcareProfessional,
                        icon: Icons.local_hospital_outlined,
                        accentColor: AppColors.brandGreen,
                        selected: selected == AccountType.healthcareProfessional,
                        onTap: () => _onSelect(
                          context,
                          ref,
                          AccountType.healthcareProfessional,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AccountTypeCard(
                        type: AccountType.personal,
                        icon: Icons.person_outline_rounded,
                        accentColor: AppColors.brandBlue,
                        selected: selected == AccountType.personal,
                        onTap: () => _onSelect(
                          context,
                          ref,
                          AccountType.personal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSelect(BuildContext context, WidgetRef ref, AccountType type) {
    ref.read(accountTypeSelectionProvider.notifier).select(type);

    if (type == AccountType.personal) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PersonalRegistrationScreen()),
      );
      return;
    }

    // Healthcare professional flow isn't built yet — this is out of
    // scope for now, so just acknowledge the selection.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${type.title} onboarding is coming soon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// Minimal, dependency-free skyline silhouette to echo the reference art
/// without shipping an image asset.
class _SkylineDecoration extends StatelessWidget {
  const _SkylineDecoration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: CustomPaint(
        painter: _SkylinePainter(color: AppColors.brandGreen),
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  final Color color;
  _SkylinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.5);
    final hill = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.3,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, paint);

    final buildingPaint = Paint()..color = color.withValues(alpha: 0.35);
    final buildingWidths = [40.0, 55.0, 70.0, 50.0, 45.0];
    double x = size.width * 0.08;
    for (var i = 0; i < buildingWidths.length; i++) {
      final h = 60.0 + (i.isEven ? 30 : 10);
      canvas.drawRect(
        Rect.fromLTWH(x, size.height * 0.55 - h, buildingWidths[i], h),
        buildingPaint,
      );
      x += buildingWidths[i] + 14;
    }
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) =>
      oldDelegate.color != color;
}