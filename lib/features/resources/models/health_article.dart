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

  const HealthArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.verifiedSource,
    required this.readTime,
    required this.difficultyLevel,
    required this.icon,
    required this.color,
    required this.imageUrls,
    required this.excerpt,
    required this.sections,
    required this.keyTakeaways,
    this.mythVsFact,
    this.interactiveQuizzes = const [],
    this.relatedVideoId,
  });

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

    return HealthArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      verifiedSource: json['verified_source'] as String,
      readTime: json['read_time'] as String,
      difficultyLevel: json['difficulty_level'] as String,
      icon: getIcon(json['icon'] as String),
      color: getColor(json['accent_color'] as String),
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      excerpt: json['excerpt'] as String,
      sections: (json['sections'] as List).map((s) => ArticleSection.fromJson(s)).toList(),
      keyTakeaways: List<String>.from(json['key_takeaways']),
      mythVsFact: json['myth_vs_fact'] != null ? MythVsFact.fromJson(json['myth_vs_fact']) : null,
      interactiveQuizzes: json['interactive_quizzes'] != null 
          ? (json['interactive_quizzes'] as List).map((q) => InteractiveQuiz.fromJson(q)).toList()
          : (json['interactive_quiz'] != null ? [InteractiveQuiz.fromJson(json['interactive_quiz'])] : []),
      relatedVideoId: json['related_video_id'] as String?,
    );
  }
}
