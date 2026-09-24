import 'package:flutter/material.dart';

class MedicineAccordionItem {
  final String title;
  final String content;
  final IconData icon;

  const MedicineAccordionItem({
    required this.title,
    required this.content,
    required this.icon,
  });

  factory MedicineAccordionItem.fromJson(Map<String, dynamic> json) {
    IconData getIcon(String iconName) {
      switch (iconName) {
        case 'medication_rounded':
          return Icons.medication_rounded;
        case 'warning_amber_rounded':
          return Icons.warning_amber_rounded;
        case 'gpp_maybe_rounded':
          return Icons.gpp_maybe_rounded;
        case 'info_rounded':
          return Icons.info_rounded;
        default:
          return Icons.label_rounded;
      }
    }

    return MedicineAccordionItem(
      title: json['title'] as String,
      content: json['content'] as String,
      icon: getIcon(json['icon'] as String),
    );
  }
}

class Medicine {
  final String id;
  final String name;
  final String type;
  final String description;
  final Color color;
  final IconData icon;
  final String? heroImageUrl;
  final List<MedicineAccordionItem> details;
  final String? relatedVideoId;
  final bool isFdaApproved;

  const Medicine({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.color,
    required this.icon,
    this.heroImageUrl,
    required this.details,
    this.relatedVideoId,
    required this.isFdaApproved,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    IconData getIcon(String iconName) {
      switch (iconName) {
        case 'medication_liquid_rounded':
          return Icons.medication_liquid_rounded;
        case 'medication_rounded':
          return Icons.medication_rounded;
        case 'healing_rounded':
          return Icons.healing_rounded;
        case 'air_rounded':
          return Icons.air_rounded;
        case 'local_pharmacy_rounded':
          return Icons.local_pharmacy_rounded;
        case 'bloodtype_rounded':
          return Icons.bloodtype_rounded;
        case 'monitor_heart_rounded':
          return Icons.monitor_heart_rounded;
        case 'favorite_rounded':
          return Icons.favorite_rounded;
        case 'medical_services_rounded':
          return Icons.medical_services_rounded;
        case 'psychology_rounded':
          return Icons.psychology_rounded;
        case 'monitor_weight_rounded':
          return Icons.monitor_weight_rounded;
        default:
          return Icons.local_pharmacy_rounded;
      }
    }

    Color getColor(String hexCode) {
      final hex = hexCode.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    }

    return Medicine(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      color: getColor(json['accent_color'] as String),
      icon: getIcon(json['icon'] as String),
      heroImageUrl: json['hero_image_url'] as String?,
      details: (json['details'] as List?)?.map((s) => MedicineAccordionItem.fromJson(s)).toList() ?? [],
      relatedVideoId: json['related_video_id'] as String?,
      isFdaApproved: json['is_fda_approved'] as bool? ?? true,
    );
  }
}
