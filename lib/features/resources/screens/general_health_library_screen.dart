import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'health_article_detail_screen.dart';

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/health_article.dart';

class GeneralHealthLibraryScreen extends StatefulWidget {
  const GeneralHealthLibraryScreen({super.key});

  @override
  State<GeneralHealthLibraryScreen> createState() => _GeneralHealthLibraryScreenState();
}

class _GeneralHealthLibraryScreenState extends State<GeneralHealthLibraryScreen> with SingleTickerProviderStateMixin {
  final List<String> _categories = ['All', 'Nutrition', 'Mental Health', 'Fitness', 'Sleep', 'Heart Health'];
  String _selectedCategory = 'All';

  List<HealthArticle> _articles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final articlesJsonString = await rootBundle.loadString('assets/health_library_data/articles/articles_catalog_v4.json');
      final List<dynamic> articlesJsonList = json.decode(articlesJsonString);
      
      setState(() {
        _articles = articlesJsonList.map((json) => HealthArticle.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading library data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.colorScheme.surface,
        appBar: AppBar(
          title: Text(
            'Health Library',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          backgroundColor: context.colorScheme.surface,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final filteredArticles = _selectedCategory == 'All'
        ? _articles
        : _articles.where((a) => a.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Health Library',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        backgroundColor: context.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;
          return Column(
            children: [
              _buildSearchBar(context, isDesktop),
              _buildCategoryChips(context),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _buildArticlesTab(context, filteredArticles, isDesktop),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildArticlesTab(BuildContext context, List<HealthArticle> articles, bool isDesktop) {
    if (articles.isEmpty) {
        return _buildEmptyState(context, 'No articles found for this category.');
    }
    
    if (isDesktop) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 450,
          mainAxisSpacing: AppSpacing.xl,
          crossAxisSpacing: AppSpacing.xl,
          mainAxisExtent: 180,
        ),
        itemCount: articles.length,
        itemBuilder: (context, index) => _buildArticleCard(context, articles[index]),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      itemCount: articles.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (context, index) => _buildArticleCard(context, articles[index]),
    );
  }


  Widget _buildEmptyState(BuildContext context, String message) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Icon(Icons.search_off_rounded, size: 64, color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                      message,
                      style: TextStyle(
                          color: context.colorScheme.onSurfaceVariant,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                      ),
                  ),
              ],
          ),
      );
  }

  Widget _buildSearchBar(BuildContext context, bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? AppSpacing.xxl : AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search health library...',
          hintStyle: TextStyle(color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
          prefixIcon: Icon(Icons.search_rounded, color: context.colorScheme.primary),
          filled: true,
          fillColor: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedCategory = category);
              }
            },
            backgroundColor: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            selectedColor: context.colorScheme.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: isSelected ? context.colorScheme.primary : context.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? context.colorScheme.primary.withValues(alpha: 0.3) : Colors.transparent,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, HealthArticle article) {
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: article.color.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => HealthArticleDetailScreen(article: article)));
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon / Avatar container
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: article.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(article.icon, color: article.color, size: 32),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: article.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                article.category.toUpperCase(),
                                style: TextStyle(
                                  color: article.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            article.readTime,
                            style: TextStyle(
                              color: context.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        article.title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurface,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        article.excerpt,
                        style: TextStyle(
                          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontSize: 14,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

