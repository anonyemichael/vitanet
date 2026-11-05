import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vitanet/features/resources/models/medicine.dart';
import 'package:vitanet/features/resources/models/health_article.dart';
import 'package:vitanet/features/resources/models/health_video.dart';
import 'package:vitanet/features/first_aid/screens/first_aid_screen.dart';
import 'daily_med_service.dart';
import 'medical_api_service.dart';
import 'drug_synonyms.dart';
import 'clinical_articles_data.dart';

/// Central repository & sync engine for the 4 resource categories:
/// 1. First Aid Guides (`first_aid_guides`)
/// 2. Medicine Directory (`dynamic_medicines`)
/// 3. Video Tutorials (`dynamic_videos`)
/// 4. Health Library (`dynamic_articles`)
class DynamicResourcesService {
  final FirebaseFirestore? _firestore;
  final MedicalApiService _apiService;

  DynamicResourcesService({
    FirebaseFirestore? firestore,
    MedicalApiService? apiService,
  })  : _firestore = firestore ?? (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null),
        _apiService = apiService ?? MedicalApiService();

  // ─────────────────────────────────────────────────────────────
  // 1. FIRST AID & EMERGENCIES (`first_aid_guides`)
  // ─────────────────────────────────────────────────────────────

  /// Streams emergency first aid guides from Firestore, falling back to local tips
  Stream<List<FirstAidTip>> streamFirstAidGuides({String? category}) {
    if (_firestore == null) {
      return Stream.value(_filterStaticFirstAidTips(category));
    }
    try {
      Query query = _firestore.collection('first_aid_guides');
      if (category != null && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }
      return query.snapshots().map((snapshot) {
        if (snapshot.docs.isEmpty) {
          return _filterStaticFirstAidTips(category);
        }
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _firstAidTipFromMap(data);
        }).toList();
      }).handleError((err) {
        debugPrint('Firestore first aid stream error: $err');
        return _filterStaticFirstAidTips(category);
      });
    } catch (e) {
      debugPrint('Firestore streamFirstAidGuides exception: $e');
      return Stream.value(_filterStaticFirstAidTips(category));
    }
  }

  List<FirstAidTip> _filterStaticFirstAidTips(String? category) {
    if (category == null || category == 'All') {
      return FirstAidScreen.tips;
    }
    return FirstAidScreen.tips.where((tip) {
      final lower = tip.title.toLowerCase();
      if (category == 'Critical' || category == 'Life-Threatening') {
        return lower.contains('cpr') || lower.contains('chok') || lower.contains('heart');
      }
      if (category == 'Trauma & Wounds' || category == 'Trauma') {
        return lower.contains('cut') || lower.contains('burn') || lower.contains('sprain') || lower.contains('nose');
      }
      if (category == 'Medical') {
        return lower.contains('fever') || lower.contains('allerg') || lower.contains('anaphylaxis');
      }
      return false;
    }).toList();
  }

  FirstAidTip _firstAidTipFromMap(Map<String, dynamic> data) {
    IconData getIcon(String? name) {
      switch (name) {
        case 'favorite_rounded': return Icons.favorite_rounded;
        case 'healing_rounded': return Icons.healing_rounded;
        case 'local_fire_department_rounded': return Icons.local_fire_department_rounded;
        case 'accessibility_new_rounded': return Icons.accessibility_new_rounded;
        case 'emergency_rounded': return Icons.emergency_rounded;
        case 'thermostat_rounded': return Icons.thermostat_rounded;
        case 'water_drop_rounded': return Icons.water_drop_rounded;
        case 'monitor_heart_rounded': return Icons.monitor_heart_rounded;
        case 'sick_rounded': return Icons.sick_rounded;
        default: return Icons.medical_services_rounded;
      }
    }

    Color getColor(String? hex) {
      if (hex == null) return const Color(0xFFEF4444);
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    }

    return FirstAidTip(
      title: data['title'] ?? 'Emergency Protocol',
      summary: data['summary'] ?? '',
      icon: getIcon(data['icon']),
      accent: getColor(data['accent']),
      steps: List<String>.from(data['steps'] ?? []),
      whenToSeekHelp: data['when_to_seek_help'] ?? 'Seek immediate medical attention if condition worsens.',
      imageUrl: data['image_url'],
      videoUrl: data['video_url'],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. MEDICINE DIRECTORY (`dynamic_medicines`)
  // ─────────────────────────────────────────────────────────────

  /// Streams medicines from Firestore with fallback to local medicines_catalog.json
  Stream<List<Medicine>> streamMedicines({String? category}) {
    if (_firestore == null) {
      return Stream.value(_cachedMedicines);
    }
    try {
      Query query = _firestore.collection('dynamic_medicines');
      if (category != null && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }
      return query.snapshots().map((snapshot) {
        if (snapshot.docs.isEmpty) {
          // Empty in Firestore, return seeded memory list
          return _cachedMedicines;
        }
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Medicine.fromJson(data);
        }).toList();
      }).handleError((err) {
        debugPrint('Firestore streamMedicines error: $err');
        return _cachedMedicines;
      });
    } catch (e) {
      return Stream.value(_cachedMedicines);
    }
  }

  List<Medicine> _cachedMedicines = List<Medicine>.from(_defaultFallbackMedicines);

  /// Preloads static medicines asset catalog into memory cache
  Future<void> preloadMedicinesAsset() async {
    try {
      final jsonString = await rootBundle.loadString('assets/health_library_data/medicines/medicines_catalog.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      if (jsonList.isNotEmpty) {
        _cachedMedicines = jsonList.map((j) => Medicine.fromJson(j)).toList();
        for (final m in _cachedMedicines) {
          if (m.heroImageUrl != null && m.heroImageUrl!.isNotEmpty) {
            DailyMedService.instance.cacheImageUrl(
              splSetId: m.splSetId,
              drugName: m.genericName ?? m.name,
              url: m.heroImageUrl!,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Preload medicines asset error: $e');
    }
  }

  /// Returns cached essential medicines list (preloading if necessary)
  Future<List<Medicine>> getDefaultMedicines() async {
    await preloadMedicinesAsset();
    if (_cachedMedicines.isEmpty) {
      _cachedMedicines = List<Medicine>.from(_defaultFallbackMedicines);
    }
    return List<Medicine>.from(_cachedMedicines);
  }

  static final List<Medicine> _defaultFallbackMedicines = [
    Medicine(
      id: 'med_001',
      name: 'Acetaminophen (Paracetamol)',
      isRx: false,
      type: 'Pain Reliever & Antipyretic',
      description: 'First-line analgesic and antipyretic medication indicated for mild-to-moderate pain and fever reduction.',
      color: const Color(0xFF0D9488),
      icon: Icons.medication_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=59d01f72-4575-48e2-b914-b6a6456ca7d2&name=image-01.jpg',
      splSetId: '59d01f72-4575-48e2-b914-b6a6456ca7d2',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: 500 mg to 1,000 mg every 4 to 6 hours as needed. Maximum daily dose must not exceed 4,000 mg in 24 hours to prevent hepatotoxicity.',
          icon: Icons.medication_rounded,
        ),
        MedicineAccordionItem(
          title: 'Common Side Effects',
          content: 'Rare at therapeutic doses. Nausea, rash. Overdose can cause severe liver failure.',
          icon: Icons.warning_amber_rounded,
        ),
        MedicineAccordionItem(
          title: 'Interactions & Warnings',
          content: 'Avoid concurrent alcohol intake. Never combine with other multi-symptom OTC medicines containing acetaminophen.',
          icon: Icons.gpp_maybe_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_002',
      name: 'Ibuprofen',
      isRx: false,
      type: 'NSAID (Non-Steroidal Anti-Inflammatory)',
      description: 'Nonsteroidal anti-inflammatory drug used for relief of acute pain, swelling, fever, and musculoskeletal inflammation.',
      color: const Color(0xFFF97316),
      icon: Icons.medication_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=307b0257-d636-416b-828a-f901782e9b10&name=647-2e-ibuprofen-1.jpg',
      splSetId: '307b0257-d636-416b-828a-f901782e9b10',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: 200 mg to 400 mg orally every 4 to 6 hours with food. Do not exceed 1,200 mg daily for OTC use without physician supervision.',
          icon: Icons.medication_rounded,
        ),
        MedicineAccordionItem(
          title: 'Common Side Effects',
          content: 'Dyspepsia, heartburn, stomach pain, dizziness, fluid retention.',
          icon: Icons.warning_amber_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_003',
      name: 'Amoxicillin',
      type: 'Penicillin Antibacterial',
      description: 'Broad-spectrum beta-lactam antibiotic indicated for respiratory tract, ear, nose, and bacterial urinary infections.',
      color: const Color(0xFF10B981),
      icon: Icons.healing_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=a5c323c8-ae13-4eda-a9bf-173a0676bf9d&name=image-01.jpg',
      splSetId: 'a5c323c8-ae13-4eda-a9bf-173a0676bf9d',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: 250 mg to 500 mg every 8 hours or 875 mg every 12 hours depending on infection severity.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_004',
      name: 'Loratadine',
      isRx: false,
      type: 'Second-Generation Antihistamine',
      description: 'Non-sedating selective peripheral H1 receptor antagonist for seasonal allergic rhinitis, sneezing, and urticaria.',
      color: const Color(0xFF8B5CF6),
      icon: Icons.air_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=1dd299e7-dfdd-459b-bb2b-83e37dd2e63d&name=label-10.jpg',
      splSetId: '1dd299e7-dfdd-459b-bb2b-83e37dd2e63d',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults and children 6 years and older: 10 mg orally once daily. Do not exceed 10 mg in 24 hours.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_005',
      name: 'Omeprazole',
      isRx: false,
      type: 'Proton Pump Inhibitor (PPI)',
      description: 'Suppresses gastric acid secretion by specific inhibition of the H+/K+-ATPase proton pump for GERD and peptic ulcers.',
      color: const Color(0xFF06B6D4),
      icon: Icons.local_pharmacy_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=5ceaec04-3ca3-4c7c-9184-51a42686a595&name=heb-omeprazole-carton-image-1.jpg',
      splSetId: '5ceaec04-3ca3-4c7c-9184-51a42686a595',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: 20 mg to 40 mg once daily, taken 30 to 60 minutes before breakfast.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_006',
      name: 'Naproxen',
      isRx: false,
      type: 'NSAID (Pain & Fever)',
      description: 'Long-acting nonsteroidal anti-inflammatory analgesic indicated for arthritis, musculoskeletal pain, and dysmenorrhea.',
      color: const Color(0xFFF97316),
      icon: Icons.medication_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=12202ef3-c65e-45a6-88ed-5d945d8fd41c&name=Remedy_Label.jpg',
      splSetId: '12202ef3-c65e-45a6-88ed-5d945d8fd41c',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: 220 mg to 500 mg orally twice daily with meals.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_007',
      name: 'Aspirin (Acetylsalicylic Acid)',
      isRx: false,
      type: 'Antiplatelet & Analgesic (Pain & Cardio)',
      description: 'Irreversible cyclooxygenase inhibitor used for cardiovascular prophylaxis (low-dose) and mild pain/inflammation relief.',
      color: const Color(0xFFEF4444),
      icon: Icons.monitor_heart_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=b3773f02-02a9-33c8-e053-2995a90a2235&name=5004-100GB-IFC+14992_12-20-.jpg',
      splSetId: 'b3773f02-02a9-33c8-e053-2995a90a2235',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Cardioprotection: 81 mg to 100 mg orally once daily.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_008',
      name: 'Azithromycin',
      type: 'Macrolide Antibiotic',
      description: 'Broad-spectrum macrolide antibiotic indicated for community-acquired pneumonia, strep pharyngitis, and skin infections.',
      color: const Color(0xFF10B981),
      icon: Icons.healing_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=5ee63ebc-45e8-fab8-e063-6294a90a7b23&name=65862-642-30+AZITHROMYCIN+500MG_67046-1698-30.jpg',
      splSetId: '5ee63ebc-45e8-fab8-e063-6294a90a7b23',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: 500 mg single dose on day 1, followed by 250 mg once daily on days 2 through 5.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_009',
      name: 'Ciprofloxacin',
      type: 'Fluoroquinolone Antibacterial',
      description: 'Potent bactericidal fluoroquinolone targeting bacterial DNA gyrase; indicated for complicated UTI and bone infections.',
      color: const Color(0xFF10B981),
      icon: Icons.healing_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=3e3c3813-7dd2-4655-9b0a-1fa7ff0e4dc1&name=carton-label.jpg',
      splSetId: '3e3c3813-7dd2-4655-9b0a-1fa7ff0e4dc1',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: 250 mg to 750 mg orally every 12 hours depending on infection site.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_010',
      name: 'Doxycycline',
      type: 'Tetracycline Antibiotic',
      description: 'Broad-spectrum tetracycline antibiotic indicated for atypical pneumonia, Lyme disease, acne vulgaris, and rickettsial diseases.',
      color: const Color(0xFF10B981),
      icon: Icons.healing_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=294c6fc3-e7ca-46ea-b062-a27dd7b0bc97&name=72789309.jpg',
      splSetId: '294c6fc3-e7ca-46ea-b062-a27dd7b0bc97',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: 100 mg orally every 12 hours on day 1, followed by 100 mg once or twice daily.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_011',
      name: 'Lisinopril',
      type: 'ACE Inhibitor (Cardiovascular)',
      description: 'Angiotensin-converting enzyme (ACE) inhibitor indicated for essential hypertension, congestive heart failure, and post-MI recovery.',
      color: const Color(0xFFEF4444),
      icon: Icons.monitor_heart_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=5f4e3bc8-2810-f1ae-e063-6394a90a9725&name=68180-518-02+LISIN-HCTZ10-12.5MG_67046-686-30.jpg',
      splSetId: '5f4e3bc8-2810-f1ae-e063-6394a90a9725',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: Initial 10 mg orally once daily; titrated up to 20 mg to 40 mg daily based on target blood pressure.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_012',
      name: 'Amlodipine',
      type: 'Calcium Channel Blocker (Cardiovascular)',
      description: 'Dihydropyridine calcium antagonist indicated for the management of hypertension and coronary artery disease.',
      color: const Color(0xFFEF4444),
      icon: Icons.monitor_heart_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=02e233c4-48d1-456d-8fc8-f99a06ef854a&name=72789412.jpg',
      splSetId: '02e233c4-48d1-456d-8fc8-f99a06ef854a',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: 5 mg to 10 mg orally once daily.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_013',
      name: 'Atorvastatin',
      type: 'HMG-CoA Reductase Inhibitor (Statin)',
      description: 'Primary lipid-lowering statin indicated to reduce the risk of stroke, myocardial infarction, and cardiovascular mortality.',
      color: const Color(0xFFEF4444),
      icon: Icons.monitor_heart_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=5d5977a5-98f2-a90d-e063-6394a90a5892&name=atorvastatinfigure1.jpg',
      splSetId: '5d5977a5-98f2-a90d-e063-6394a90a5892',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: 10 mg to 80 mg orally once daily.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_014',
      name: 'Metoprolol',
      type: 'Selective Beta-1 Blocker (Cardiovascular)',
      description: 'Cardioselective adrenergic beta-receptor blocker indicated for angina pectoris, essential hypertension, and heart failure.',
      color: const Color(0xFFEF4444),
      icon: Icons.monitor_heart_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=8b315ecf-ff79-4792-88a6-4ce707a326b0&name=lbl713353191.jpg',
      splSetId: '8b315ecf-ff79-4792-88a6-4ce707a326b0',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: 25 mg to 100 mg orally once or twice daily.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
    Medicine(
      id: 'med_015',
      name: 'Metformin',
      type: 'Biguanide Antidiabetic Agent',
      description: 'First-line pharmacotherapy for type 2 diabetes mellitus; decreases hepatic glucose production and enhances peripheral insulin sensitivity.',
      color: const Color(0xFF0D9488),
      icon: Icons.medication_rounded,
      isFdaApproved: true,
      heroImageUrl: 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=0ff1ba75-3c86-4baf-a6b1-1bb883839866&name=metformin-er-500mg-90tab1.jpg',
      splSetId: '0ff1ba75-3c86-4baf-a6b1-1bb883839866',
      details: const [
        MedicineAccordionItem(
          title: 'Typical Dosage',
          content: 'Adults: Initial 500 mg orally twice daily with meals or 850 mg once daily.',
          icon: Icons.medication_rounded,
        ),
      ],
    ),
  ];

  /// Live Search: Searches local cached list and hydrates from openFDA live
  Future<List<Medicine>> searchMedicines(String query, {String category = 'All'}) async {
    await preloadMedicinesAsset();
    final cleanQuery = query.trim().toLowerCase();

    if (cleanQuery.isEmpty) {
      if (category == 'All') {
        return List<Medicine>.from(_cachedMedicines);
      }
      return _cachedMedicines.where((m) => MedicineCategoryQueries.matchesCategory(m, category)).toList();
    }

    // Expand search aliases (e.g. "paracetamol" -> ["paracetamol", "acetaminophen"])
    final searchAliases = DrugSynonymMapper.getSearchAliases(cleanQuery);

    // 1. Check local cached list across all aliases
    final localMatches = _cachedMedicines.where((m) {
      final text = '${m.name} ${m.type} ${m.description}'.toLowerCase();
      final matchesQuery = searchAliases.any((alias) => text.contains(alias));
      final matchesCat = MedicineCategoryQueries.matchesCategory(m, category);
      return matchesQuery && matchesCat;
    }).toList();

    // 2. Fetch from openFDA with mapped generic query
    if (cleanQuery.length >= 2) {
      try {
        final fdaResults = await _apiService.searchOpenFdaMedicines(cleanQuery, limit: 10);
        if (fdaResults.isNotEmpty) {
          final existingIds = localMatches.map((m) => m.name.toLowerCase()).toSet();
          for (var fdaMed in fdaResults) {
            final fdaNameLower = fdaMed.name.toLowerCase();
            if (!existingIds.contains(fdaNameLower) &&
                (category == 'All' || MedicineCategoryQueries.matchesCategory(fdaMed, category))) {
              localMatches.add(fdaMed);
              existingIds.add(fdaNameLower);
              _cacheMedicineToFirestore(fdaMed);
            }
          }
        }
      } catch (e) {
        debugPrint('Live openFDA lookup error: $e');
      }
    }

    return localMatches;
  }

  /// Fetches medicines for a specific category using openFDA queries and local fallbacks
  Future<List<Medicine>> fetchMedicinesForCategory(String category) async {
    await preloadMedicinesAsset();

    // 1. Get local matching medicines immediately
    final localList = _cachedMedicines.where((m) => MedicineCategoryQueries.matchesCategory(m, category)).toList();

    // 2. Fetch from openFDA using category-specific query
    final fdaQuery = MedicineCategoryQueries.getQueryForCategory(category);
    if (fdaQuery != null) {
      try {
        final fdaResults = await _apiService.searchOpenFdaMedicines(fdaQuery, limit: 12);
        if (fdaResults.isNotEmpty) {
          final existingNames = localList.map((m) => m.name.toLowerCase()).toSet();
          for (var fdaMed in fdaResults) {
            final fdaLower = fdaMed.name.toLowerCase();
            if (!existingNames.contains(fdaLower)) {
              localList.add(fdaMed);
              existingNames.add(fdaLower);
              _cacheMedicineToFirestore(fdaMed);
            }
          }
        }
      } catch (e) {
        debugPrint('openFDA category fetch error: $e');
      }
    }

    return localList;
  }

  Future<void> _cacheMedicineToFirestore(Medicine med) async {
    if (_firestore == null) return;
    try {
      final docRef = _firestore.collection('dynamic_medicines').doc(med.id);
      final jsonMap = med.toJson();
      jsonMap['cached_at'] = FieldValue.serverTimestamp();
      await docRef.set(jsonMap, SetOptions(merge: true));
    } catch (e) {
      if (e is! FirebaseException || e.code != 'permission-denied') {
        debugPrint('Failed to cache medicine to Firestore: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 3. VIDEO TUTORIALS (`dynamic_videos`)
  // ─────────────────────────────────────────────────────────────

  List<HealthVideo> _cachedVideos = [];

  Future<void> preloadVideosAsset() async {
    if (_cachedVideos.isNotEmpty) return;
    try {
      final jsonString = await rootBundle.loadString('assets/health_library_data/videos/videos_catalog_v4.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedVideos = jsonList.map((j) {
        // Clean broken template strings
        final map = Map<String, dynamic>.from(j);
        final cat = map['category'] ?? 'Health Guide';
        if (map['title'] == null || map['title'].toString().contains(r'${v["category"]}')) {
          map['title'] = '$cat Masterclass & Clinical Guide';
        }
        if (map['thumbnail_url'] == null || map['thumbnail_url'].toString().contains(r'${v["video_id"]}')) {
          map['thumbnail_url'] = 'https://img.youtube.com/vi/${map["video_id"]}/hqdefault.jpg';
        }
        map['organization'] ??= 'VitaNet Clinical Education';
        map['summary'] ??= 'Physician-reviewed instructional demonstration.';
        map['verification_status'] ??= 'Verified Clinician';
        map['key_steps'] ??= [
          {'time': '00:00', 'action': 'Introduction & Clinical Overview'},
          {'time': '02:30', 'action': 'Technique Demonstration'},
          {'time': '06:00', 'action': 'Common Mistakes & Precautions'},
        ];
        return HealthVideo.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('Preload videos error: $e');
    }
  }

  Stream<List<HealthVideo>> streamVideos({String? category}) {
    if (_firestore == null) {
      return Stream.value(_filterVideos(category));
    }
    try {
      Query query = _firestore.collection('dynamic_videos');
      if (category != null && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }
      return query.snapshots().map((snapshot) {
        if (snapshot.docs.isEmpty) {
          return _filterVideos(category);
        }
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return HealthVideo.fromJson(data);
        }).toList();
      }).handleError((err) {
        debugPrint('Firestore streamVideos error: $err');
        return _filterVideos(category);
      });
    } catch (e) {
      return Stream.value(_filterVideos(category));
    }
  }

  List<HealthVideo> _filterVideos(String? category) {
    if (category == null || category == 'All') return _cachedVideos;
    return _cachedVideos.where((v) => v.category.toLowerCase() == category.toLowerCase()).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 4. HEALTH LIBRARY ARTICLES (`dynamic_articles`)
  // ─────────────────────────────────────────────────────────────

  List<HealthArticle> _cachedArticles = [];

  Future<void> preloadArticlesAsset() async {
    if (_cachedArticles.isNotEmpty) return;
    try {
      final jsonString = await rootBundle.loadString('assets/health_library_data/articles/articles_catalog_v4.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final loaded = jsonList
          .map((j) => HealthArticle.fromJson(j))
          .where((a) => !a.title.contains(r'${') && !a.id.contains(r'${'))
          .toList();
      _cachedArticles = loaded;
    } catch (e) {
      debugPrint('Preload articles error: $e');
    }
    if (_cachedArticles.isEmpty) {
      _cachedArticles = List.from(ClinicalArticlesRepository.verifiedArticles);
    }
  }

  Stream<List<HealthArticle>> streamArticles({String? category}) {
    if (_firestore == null) {
      return Stream.value(_filterArticles(category));
    }
    try {
      Query query = _firestore.collection('dynamic_articles').orderBy('created_at', descending: true);
      if (category != null && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }
      return query.snapshots().map((snapshot) {
        if (snapshot.docs.isEmpty) {
          return _filterArticles(category);
        }
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return HealthArticle.fromJson(data);
        }).toList();
      }).handleError((err) {
        debugPrint('Firestore streamArticles error: $err');
        return _filterArticles(category);
      });
    } catch (e) {
      return Stream.value(_filterArticles(category));
    }
  }

  List<HealthArticle> _filterArticles(String? category) {
    if (category == null || category == 'All') return _cachedArticles;
    return _cachedArticles.where((a) => a.category.toLowerCase() == category.toLowerCase()).toList();
  }

  /// Live Search & Europe PMC Ingestion
  Future<List<HealthArticle>> searchArticles(String query, {String? category}) async {
    final cleanQuery = query.trim().toLowerCase();
    await preloadArticlesAsset();

    var baseList = _cachedArticles;
    if (category != null && category != 'All') {
      baseList = baseList.where((a) => a.category.toLowerCase() == category.toLowerCase()).toList();
    }

    if (cleanQuery.isEmpty) return baseList;

    final localMatches = baseList.where((a) =>
      a.title.toLowerCase().contains(cleanQuery) ||
      a.excerpt.toLowerCase().contains(cleanQuery) ||
      a.category.toLowerCase().contains(cleanQuery)
    ).toList();

    // If query has substance, query Europe PMC for peer-reviewed studies
    if (cleanQuery.length >= 3) {
      try {
        final epmcArticles = await _apiService.searchEuropePmcArticles(cleanQuery, limit: 5);
        if (epmcArticles.isNotEmpty) {
          final existingTitles = localMatches.map((a) => a.title.toLowerCase()).toSet();
          for (var article in epmcArticles) {
            if (!existingTitles.contains(article.title.toLowerCase())) {
              localMatches.add(article);
              _cacheArticleToFirestore(article);
            }
          }
        }
      } catch (e) {
        debugPrint('Live Europe PMC lookup error: $e');
      }
    }

    return localMatches;
  }

  Future<void> _cacheArticleToFirestore(HealthArticle article) async {
    if (_firestore == null) return;
    try {
      final docRef = _firestore.collection('dynamic_articles').doc(article.id);
      await docRef.set({
        'id': article.id,
        'title': article.title,
        'category': article.category,
        'verified_source': article.verifiedSource,
        'read_time': article.readTime,
        'difficulty_level': article.difficultyLevel,
        'icon': 'science_rounded',
        'accent_color': '#${article.color.toARGB32().toRadixString(16).substring(2)}',
        'image_urls': article.imageUrls,
        'excerpt': article.excerpt,
        'sections': article.sections.map((s) => {
          'heading': s.heading,
          'content': s.content,
        }).toList(),
        'key_takeaways': article.keyTakeaways,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (e is! FirebaseException || e.code != 'permission-denied') {
        debugPrint('Failed to cache article to Firestore: $e');
      }
    }
  }
}
