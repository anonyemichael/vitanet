import 'package:flutter/material.dart';

class ArticleSection {
  final String heading;
  final String content;

  const ArticleSection({
    required this.heading,
    required this.content,
  });

  factory ArticleSection.fromJson(Map<String, dynamic> json) {
    return ArticleSection(
      heading: json['heading'] as String,
      content: json['content'] as String,
    );
  }
}

class MythVsFact {
  final String myth;
  final String fact;

  const MythVsFact({
    required this.myth,
    required this.fact,
  });

  factory MythVsFact.fromJson(Map<String, dynamic> json) {
    return MythVsFact(
      myth: json['myth'] as String,
      fact: json['fact'] as String,
    );
  }
}

class InteractiveQuiz {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const InteractiveQuiz({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory InteractiveQuiz.fromJson(Map<String, dynamic> json) {
    return InteractiveQuiz(
      question: json['question'] as String,
      options: List<String>.from(json['options']),
      correctIndex: json['correct_index'] as int,
      explanation: json['explanation'] as String,
    );
  }
}

class HealthArticle {
  final String id;
  final String title;
  final String category;
  final String verifiedSource;
  final String readTime;
  final String difficultyLevel;
  final IconData icon;
  final Color color;
  final List<String> imageUrls;
  final String excerpt;
  final List<ArticleSection> sections;
  final List<String> keyTakeaways;
  final MythVsFact? mythVsFact;
  final List<InteractiveQuiz> interactiveQuizzes;
  final String? relatedVideoId;
  final String? doi;
  final String? publishedDate;
  final List<String> meshHeadings;

  // Convenient property getters requested for Clean Clinical Repository
  String get source => verifiedSource;
  String get snippet => excerpt;
  String get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : '';

  const HealthArticle({
    required this.id,
    required this.title,
    required this.category,
    String? source,
    String? verifiedSource,
    required this.readTime,
    this.difficultyLevel = 'Intermediate',
    this.icon = Icons.article_rounded,
    this.color = const Color(0xFF0D9488),
    this.imageUrls = const [],
    String? snippet,
    String? excerpt,
    this.sections = const [],
    this.keyTakeaways = const [],
    this.mythVsFact,
    this.interactiveQuizzes = const [],
    this.relatedVideoId,
    this.doi,
    this.publishedDate,
    this.meshHeadings = const [],
  })  : verifiedSource = verifiedSource ?? source ?? 'Europe PMC • Peer Reviewed',
        excerpt = excerpt ?? snippet ?? '';

  HealthArticle copyWith({
    String? id,
    String? title,
    String? category,
    String? verifiedSource,
    String? readTime,
    String? difficultyLevel,
    IconData? icon,
    Color? color,
    List<String>? imageUrls,
    String? excerpt,
    List<ArticleSection>? sections,
    List<String>? keyTakeaways,
    MythVsFact? mythVsFact,
    List<InteractiveQuiz>? interactiveQuizzes,
    String? relatedVideoId,
    String? doi,
    String? publishedDate,
    List<String>? meshHeadings,
  }) {
    return HealthArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      verifiedSource: verifiedSource ?? this.verifiedSource,
      readTime: readTime ?? this.readTime,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      imageUrls: imageUrls ?? this.imageUrls,
      excerpt: excerpt ?? this.excerpt,
      sections: sections ?? this.sections,
      keyTakeaways: keyTakeaways ?? this.keyTakeaways,
      mythVsFact: mythVsFact ?? this.mythVsFact,
      interactiveQuizzes: interactiveQuizzes ?? this.interactiveQuizzes,
      relatedVideoId: relatedVideoId ?? this.relatedVideoId,
      doi: doi ?? this.doi,
      publishedDate: publishedDate ?? this.publishedDate,
      meshHeadings: meshHeadings ?? this.meshHeadings,
    );
  }

  factory HealthArticle.fromJson(Map<String, dynamic> json) {
    IconData getIcon(String iconName) {
      switch (iconName) {
        case 'psychology_rounded':
          return Icons.psychology_rounded;
        case 'favorite_rounded':
          return Icons.favorite_rounded;
        case 'nightlight_round':
          return Icons.nightlight_round;
        case 'self_improvement_rounded':
          return Icons.self_improvement_rounded;
        case 'restaurant_rounded':
          return Icons.restaurant_rounded;
        case 'fitness_center_rounded':
          return Icons.fitness_center_rounded;
        default:
          return Icons.article_rounded;
      }
    }

    Color getColor(String hexCode) {
      final hex = hexCode.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    }

    final rawImageUrls = json['image_urls'] as List? ?? (json['image_url'] != null ? [json['image_url']] : []);

    return HealthArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      verifiedSource: (json['verified_source'] ?? json['source'] ?? 'Europe PMC • Peer Reviewed') as String,
      readTime: (json['read_time'] ?? json['readTime'] ?? '5 min read') as String,
      difficultyLevel: (json['difficulty_level'] ?? 'Intermediate') as String,
      icon: getIcon(json['icon'] as String? ?? ''),
      color: json['accent_color'] != null ? getColor(json['accent_color'] as String) : const Color(0xFF0D9488),
      imageUrls: List<String>.from(rawImageUrls),
      excerpt: (json['excerpt'] ?? json['snippet'] ?? '') as String,
      sections: (json['sections'] as List?)?.map((s) => ArticleSection.fromJson(s)).toList() ?? const [],
      keyTakeaways: List<String>.from(json['key_takeaways'] ?? const []),
      mythVsFact: json['myth_vs_fact'] != null ? MythVsFact.fromJson(json['myth_vs_fact']) : null,
      interactiveQuizzes: json['interactive_quizzes'] != null 
          ? (json['interactive_quizzes'] as List).map((q) => InteractiveQuiz.fromJson(q)).toList()
          : (json['interactive_quiz'] != null ? [InteractiveQuiz.fromJson(json['interactive_quiz'])] : const []),
      relatedVideoId: json['related_video_id'] as String?,
      doi: json['doi'] as String?,
      publishedDate: (json['published_date'] ?? json['publishedDate']) as String?,
      meshHeadings: json['mesh_headings'] != null
          ? List<String>.from(json['mesh_headings'])
          : (json['meshHeadings'] != null ? List<String>.from(json['meshHeadings']) : const []),
    );
  }
}
