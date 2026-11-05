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
  final String route;
  final bool isRx;
  final bool isHomeopathic;
  final String? brandName;
  final String? genericName;
  final String? splSetId;

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
    this.route = 'ORAL',
    this.isRx = true,
    this.isHomeopathic = false,
    this.brandName,
    this.genericName,
    this.splSetId,
  });

  /// Active ingredients commonly sold over the counter (at standard OTC
  /// strengths) in the US/UK/EU. Used only when a record carries no explicit
  /// `is_rx` flag, e.g. older Firestore documents.
  static const Set<String> commonOtcIngredients = {
    'acetaminophen',
    'paracetamol',
    'ibuprofen',
    'naproxen',
    'aspirin',
    'loratadine',
    'cetirizine',
    'fexofenadine',
    'diphenhydramine',
    'chlorphenamine',
    'chlorpheniramine',
    'omeprazole',
    'esomeprazole',
    'lansoprazole',
    'famotidine',
    'loperamide',
    'calcium carbonate',
    'simethicone',
    'bisacodyl',
    'docusate',
    'guaifenesin',
    'dextromethorphan',
    'pseudoephedrine',
    'phenylephrine',
    'oxymetazoline',
    'hydrocortisone',
    'clotrimazole',
    'miconazole',
    'terbinafine',
  };

  /// Whether [name] refers to a commonly OTC medicine (word-boundary match).
  static bool isCommonOtc(String name) {
    final n = name.toLowerCase();
    return commonOtcIngredients
        .any((i) => RegExp('\\b${RegExp.escape(i)}\\b').hasMatch(n));
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    IconData getIcon(String iconName) {
      switch (iconName) {
        case 'medication_liquid_rounded':
          return Icons.medication_liquid_rounded;
        case 'medication_rounded':
          return Icons.medication_rounded;
        case 'water_drop_rounded':
          return Icons.water_drop_rounded;
        case 'vaccines_rounded':
          return Icons.vaccines_rounded;
        case 'visibility_rounded':
          return Icons.visibility_rounded;
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
          return Icons.medication_rounded;
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
      route: json['route'] as String? ?? 'ORAL',
      isRx: json['is_rx'] as bool? ?? !isCommonOtc(json['name'] as String? ?? ''),
      isHomeopathic: json['is_homeopathic'] as bool? ?? false,
      brandName: json['brand_name'] as String?,
      genericName: json['generic_name'] as String?,
      splSetId: json['spl_set_id'] as String?,
    );
  }

  Medicine copyWith({
    String? id,
    String? name,
    String? type,
    String? description,
    Color? color,
    IconData? icon,
    String? heroImageUrl,
    List<MedicineAccordionItem>? details,
    String? relatedVideoId,
    bool? isFdaApproved,
    String? route,
    bool? isRx,
    bool? isHomeopathic,
    String? brandName,
    String? genericName,
    String? splSetId,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      details: details ?? this.details,
      relatedVideoId: relatedVideoId ?? this.relatedVideoId,
      isFdaApproved: isFdaApproved ?? this.isFdaApproved,
      route: route ?? this.route,
      isRx: isRx ?? this.isRx,
      isHomeopathic: isHomeopathic ?? this.isHomeopathic,
      brandName: brandName ?? this.brandName,
      genericName: genericName ?? this.genericName,
      splSetId: splSetId ?? this.splSetId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'accent_color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      'icon': 'medication_rounded',
      'hero_image_url': heroImageUrl,
      'details': details.map((d) => {
        'title': d.title,
        'content': d.content,
        'icon': 'medication_rounded',
      }).toList(),
      'related_video_id': relatedVideoId,
      'is_fda_approved': isFdaApproved,
      'route': route,
      'is_rx': isRx,
      'is_homeopathic': isHomeopathic,
      'brand_name': brandName,
      'generic_name': genericName,
      'spl_set_id': splSetId,
    };
  }
}
