import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';

class MedicineSearchScreen extends StatefulWidget {
  const MedicineSearchScreen({super.key});

  @override
  State<MedicineSearchScreen> createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends State<MedicineSearchScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final _allMeds = [
    _Medicine(name: 'Paracetamol', type: 'Pain Reliever', desc: 'Used to treat mild to moderate pain and reduce fever.', color: const Color(0xFF3B82F6), icon: Icons.medication_liquid_rounded),
    _Medicine(name: 'Ibuprofen', type: 'NSAID', desc: 'Reduces fever, pain and inflammation.', color: const Color(0xFFF97316), icon: Icons.medication_rounded),
    _Medicine(name: 'Amoxicillin', type: 'Antibiotic', desc: 'Used to treat bacterial infections.', color: const Color(0xFF10B981), icon: Icons.healing_rounded),
    _Medicine(name: 'Loratadine', type: 'Antihistamine', desc: 'Relieves allergy symptoms.', color: const Color(0xFF8B5CF6), icon: Icons.air_rounded),
    _Medicine(name: 'Omeprazole', type: 'Antacid', desc: 'Treats acid reflux and stomach ulcers.', color: const Color(0xFF14B8A6), icon: Icons.local_pharmacy_rounded),
  ];

  final _popularSearches = ['Paracetamol', 'Ibuprofen', 'Amoxicillin'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onPopularSearchTap(String query) {
    _searchController.text = query;
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return _buildMobileLayout(context);
        } else {
          return _buildDesktopLayout(context);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final filteredMeds = _allMeds.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        _buildHeaderArea(context),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
            itemCount: filteredMeds.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              return _buildMedicineCard(context, filteredMeds[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final filteredMeds = _allMeds.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        _buildHeaderArea(context, isDesktop: true),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl, vertical: AppSpacing.lg),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 450,
              mainAxisSpacing: AppSpacing.lg,
              crossAxisSpacing: AppSpacing.lg,
              mainAxisExtent: 140, // Height of card
            ),
            itemCount: filteredMeds.length,
            itemBuilder: (context, index) {
              return _buildMedicineCard(context, filteredMeds[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderArea(BuildContext context, {bool isDesktop = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? AppSpacing.xxxl : AppSpacing.xl,
        AppSpacing.xl,
        isDesktop ? AppSpacing.xxxl : AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: context.colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: context.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: 'Search medicines, symptoms...',
                prefixIcon: Icon(Icons.search_rounded, color: context.colorScheme.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: context.colorScheme.surface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Popular:',
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                ..._popularSearches.map((search) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ActionChip(
                    label: Text(search),
                    backgroundColor: context.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    labelStyle: TextStyle(color: context.colorScheme.primary, fontWeight: FontWeight.w600),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onPressed: () => _onPopularSearchTap(search),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context, _Medicine med) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: med.color.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: med.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(med.icon, color: med.color, size: 28),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name, style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: med.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          med.type, 
                          style: context.textTheme.labelSmall?.copyWith(
                            color: med.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        med.desc, 
                        style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Medicine {
  final String name;
  final String type;
  final String desc;
  final Color color;
  final IconData icon;

  _Medicine({
    required this.name, 
    required this.type, 
    required this.desc,
    required this.color,
    required this.icon,
  });
}
