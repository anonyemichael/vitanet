import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';

/// Find a Pharmacy feature — opens maps with useful nearby search shortcuts.
class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  final _controller = TextEditingController();

  static const _shortcuts = <_PharmacyShortcut>[
    _PharmacyShortcut(
      label: 'Pharmacy near me',
      query: 'pharmacy near me',
      icon: Icons.near_me_rounded,
      color: Color(0xFF6366F1),
    ),
    _PharmacyShortcut(
      label: '24-hour pharmacy',
      query: '24 hour pharmacy near me',
      icon: Icons.nightlight_round,
      color: Color(0xFF8B5CF6),
    ),
    _PharmacyShortcut(
      label: 'Open now',
      query: 'pharmacy open now',
      icon: Icons.schedule_rounded,
      color: Color(0xFF10B981),
    ),
    _PharmacyShortcut(
      label: 'Drive-thru pharmacy',
      query: 'drive thru pharmacy near me',
      icon: Icons.directions_car_rounded,
      color: Color(0xFFF59E0B),
    ),
    _PharmacyShortcut(
      label: 'Emergency Room',
      query: 'emergency room hospital near me',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFFEF4444),
    ),
    _PharmacyShortcut(
      label: 'Urgent Care',
      query: 'urgent care near me',
      icon: Icons.healing_rounded,
      color: Color(0xFFF43F5E),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search([String? query]) async {
    final q = (query ?? _controller.text).trim();
    if (q.isEmpty) {
      await LaunchHelpers.openPharmacyOrSnack(context);
      return;
    }
    await LaunchHelpers.openPharmacyOrSnack(context, q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Care'),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        _buildHeader(),
        const SizedBox(height: AppSpacing.xxl),
        _buildSearchBar(),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Quick Shortcuts',
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ..._shortcuts.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildShortcutCard(s),
            )),
        const SizedBox(height: AppSpacing.xl),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _buildHeader()),
                const SizedBox(width: AppSpacing.xxxl),
                Expanded(child: _buildSearchBar()),
              ],
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              'Quick Shortcuts',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.lg,
                childAspectRatio: 2.5,
              ),
              itemCount: _shortcuts.length,
              itemBuilder: (context, index) {
                return _buildShortcutCard(_shortcuts[index]);
              },
            ),
            const SizedBox(height: AppSpacing.xxxl),
            _buildDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.map_rounded,
            color: context.colorScheme.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Locate Nearby Facilities',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Find a pharmacy or urgent care center instantly when VitaNet recommends a visit.',
          style: context.textTheme.bodyLarge?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          if (!context.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Search pharmacies, area, or store...',
              filled: true,
              fillColor: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_forward_rounded, color: context.colorScheme.onPrimary, size: 20),
                ),
                onPressed: () => _search(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _search('pharmacy near me'),
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Use my current location'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutCard(_PharmacyShortcut s) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _search(s.query),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: context.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(s.icon, color: s.color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    s.label,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 20,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: context.colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Maps opens in your device browser or maps app. Availability and hours depend on local listings.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PharmacyShortcut {
  final String label;
  final String query;
  final IconData icon;
  final Color color;

  const _PharmacyShortcut({
    required this.label,
    required this.query,
    required this.icon,
    required this.color,
  });
}
