import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'medicine_detail_screen.dart';
import '../models/medicine.dart';

class MedicineSearchScreen extends StatefulWidget {
  const MedicineSearchScreen({super.key});

  @override
  State<MedicineSearchScreen> createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends State<MedicineSearchScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Medicine> _allMeds = [];
  bool _isLoading = true;

  final _popularSearches = ['Paracetamol', 'Ibuprofen', 'Amoxicillin', 'Loratadine', 'Omeprazole'];

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    try {
      final jsonString = await rootBundle.loadString('assets/health_library_data/medicines/medicines_catalog.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      setState(() {
        _allMeds = jsonList.map((json) => Medicine.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading medicines: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.colorScheme.surface,
        appBar: AppBar(
          title: const Text('Medicine Directory'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Medicine Directory'),
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
    final filteredMeds = _allMeds.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        _buildHeaderArea(context),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              120, // Add bottom padding to prevent nav bar from covering content
            ),
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxxl,
              AppSpacing.lg,
              AppSpacing.xxxl,
              120, // Add bottom padding to prevent nav bar from covering content
            ),
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

  Widget _buildMedicineCard(BuildContext context, Medicine med) {
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MedicineDetailScreen(medicine: med),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (med.heroImageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      med.heroImageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: med.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(med.icon, color: med.color, size: 28),
                      ),
                    ),
                  )
                else
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
                        med.description, 
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

