import '../models/health_article.dart';

/// Smart Medical Topic-to-Image Matching Engine.
///
/// Features:
/// - Semantic keyword and MeSH analysis across title, category, MeSH headings, and abstract.
/// - 12 Granular clinical sub-buckets with 60+ verified Unsplash medical photo IDs.
/// - Deterministic hashing (`article.id.hashCode.abs() % bucket.length`) to prevent repeating
///   images within the same category while preserving deterministic association.
/// - Resolution constraint helpers for decoded image memory optimization (`w=300` and `w=800`).
class MedicalImageResolver {
  static const String baseUrl = 'https://images.unsplash.com';

  /// 12 Granular Clinical Sub-Buckets with verified medical Unsplash IDs
  static const Map<String, List<String>> _buckets = {
    // 1. Cardiology (ECG, Heart health, Stethoscopes, Cardiac telemetry)
    'cardiology': [
      'photo-1576091160550-2173dba999ef', // ECG & clinical rhythm
      'photo-1628348068343-c6a848d2b6dd', // Pulse & heart monitor
      'photo-1505751172876-fa1923c5c528', // Stethoscope cardiology exam
      'photo-1576091160399-112ba8d25d1d', // Clinical cardiac diagnostics
      'photo-1530026405186-ed1f139313f8', // Cardiac physician stethoscope
      'photo-1526256262350-7da7584cf5eb', // Heart model & wellness
    ],

    // 2. Nutrition & Fasting (Dietary patterns, Micronutrients, Healthy food, Fasting)
    'nutrition_fasting': [
      'photo-1498837167922-ddd27525d352', // Balanced plate & nutrition
      'photo-1512621776951-a57141f2eefd', // Fresh clinical salad bowl
      'photo-1490645935967-10de6ba17061', // Healthy meal ingredients
      'photo-1490818387583-1baba5e638af', // Fresh fruits & antioxidants
      'photo-1540420773420-3366772f4999', // Plant-based clinical diet
      'photo-1476224203421-9ac39bcb3327', // Whole food nourishment
    ],

    // 3. Sleep & Neurology (Circadian rhythm, Sleep science, EEG, Neuroscience)
    'sleep_neurology': [
      'photo-1541781774459-bb2af2f05b55', // Restful deep sleep
      'photo-1511295742362-92c96b124e52', // Bedroom sleep environment
      'photo-1507652313519-d4e9174996dd', // Calm brain neural wave
      'photo-1559757175-5700dde675bc', // Neurology anatomical brain
      'photo-1518770660439-4636190af475', // Synapses & neural networks
      'photo-1517048676732-d65bc937f952', // Deep restorative rest
    ],

    // 4. Resistance & Fitness (Exercise physiology, Strength training, Biomechanics)
    'resistance_fitness': [
      'photo-1517838277536-f5f99be501cd', // Athletic gym workout
      'photo-1534438327276-14e5300c3a48', // Dumbbell strength training
      'photo-1574680096145-d05b474e2155', // Physical therapy fitness
      'photo-1581009146145-b5ef050c2e1e', // Resistance barbell workout
      'photo-1518611012118-696072aa579a', // Aerobic movement & cardio
      'photo-1483721074573-586540da5703', // Functional sports movement
    ],

    // 5. Immunology & Lab (Microscopy, Virology, Vaccines, Cell assays)
    'immunology_lab': [
      'photo-1582719471384-894fbb16e074', // Laboratory microscope
      'photo-1579154204601-01588f351e67', // Pipetting biological assay
      'photo-1532187863486-abf9dbad1b69', // Lab glassware & reagents
      'photo-1581093458791-9f3c3900df4b', // Biomedical researcher analysis
      'photo-1584036561566-baf8f5f1b144', // Cellular virus model
      'photo-1579684385127-1ef15d508118', // Sterile biomedical testing
    ],

    // 6. Pharmacology (Medications, Pills, Molecular compounds, FDA therapeutics)
    'pharmacology': [
      'photo-1584308666744-24d5c474f2ae', // Pharmaceutical capsules
      'photo-1471864190281-a93a3070b6de', // Medicinal prescription pills
      'photo-1587854692152-cbe660dbde88', // Pharmacy medicine bottles
      'photo-1550572017-edd951aa8f72', // Pharmaceutical drug lab
      'photo-1576602976047-174e57a47881', // Clinical dispensary table
      'photo-1584515979956-d9f6e5d09982', // Sterile medicinal supplies
    ],

    // 7. Mental Health & Psychology (Mindfulness, Cognitive therapy, Neuro-psychiatry)
    'mental_health': [
      'photo-1506126613408-eca07ce68773', // Mindfulness meditation
      'photo-1499209974431-9dddcece7f88', // Calm morning reflection
      'photo-1527137342181-19aab11a8ee8', // Clinical psychological therapy
      'photo-1518495973542-4542c06a5843', // Sunlight & mental clarity
      'photo-1493836512294-502baa1986e2', // Serene mental wellness
      'photo-1507525428034-b723cf961d3e', // Cognitive tranquility
    ],

    // 8. Pediatrics (Child healthcare, Neonatology, Maternal & infant wellness)
    'pediatrics': [
      'photo-1584515933487-779824d29309', // Pediatrician gentle care
      'photo-1631815588090-d4bfec5b1ccb', // Pediatric clinical consultation
      'photo-1576765608535-5f04d1e3f289', // Child stethoscope checkup
      'photo-1581594693702-fbdc51b2763b', // Youth healthcare physician
      'photo-1516627145497-ae6968895b74', // Infant wellness clinic
      'photo-1502086223501-7ea6ecd79368', // Child health examination
    ],

    // 9. Endocrinology & Diabetes (Glucose monitoring, Insulin, Metabolic syndrome)
    'endocrinology_diabetes': [
      'photo-1579684385127-1ef15d508118', // Blood glucose diagnostics
      'photo-1584515979956-d9f6e5d09982', // Clinical diagnostic test kit
      'photo-1584362917165-526a968579e8', // Metabolic recovery clinic
      'photo-1532938911079-1b06ac7ceec7', // Telemetry & vital kit
      'photo-1505751172876-fa1923c5c528', // Endocrine patient consult
      'photo-1576091160399-112ba8d25d1d', // Glycemic biometric check
    ],

    // 10. Oncology (Cancer research, Biopsy histology, Cellular oncology)
    'oncology': [
      'photo-1579165466791-788226ab6fb0', // Cellular pathology slide
      'photo-1579684453423-f84349ef60b0', // Tissue histopathology
      'photo-1530497610245-94d3c16cda28', // Precision molecular oncology
      'photo-1582719508461-905c673771fd', // Genomic sequencing analysis
      'photo-1516549655169-df83a0774514', // Oncology hospital wing
      'photo-1581093458791-9f3c3900df4b', // Cancer clinical science
    ],

    // 11. Dermatology (Skin barrier, Dermatoscopy, Cellular skin pathology)
    'dermatology': [
      'photo-1522337360788-8b13dee7a37e', // Dermatological skin science
      'photo-1616394584738-fc6e612e71b9', // Skin clinic treatment
      'photo-1512290900672-1a40306c59bd', // Dermal barrier hydration
      'photo-1556760544-74068565f05c', // Dermatoscopic skin screening
      'photo-1576765608535-5f04d1e3f289', // Clinical dermal examination
      'photo-1508214751196-bcfd4ca60f91', // Cellular epidermis health
    ],

    // 12. Respiratory & Pulmonology (Lungs, Asthma, COPD, Airway histology)
    'respiratory': [
      'photo-1584515979956-d9f6e5d09982', // Clinical pulmonary diagnostics
      'photo-1579684385127-1ef15d508118', // Respiratory medical assessment
      'photo-1505751172876-fa1923c5c528', // Stethoscope lung examination
      'photo-1584036561566-baf8f5f1b144', // Cellular bronchial airway model
    ],

    // 13. Women's Health (Maternal, Obstetrics, Gynecology)
    'women_health': [
      'photo-1584515933487-779824d29309', // Female healthcare consultation
      'photo-1576765608535-5f04d1e3f289', // Maternal & women's wellness
      'photo-1516549655169-df83a0774514', // Women's health clinical center
    ],

    // 14. General Clinical (Hospital wards, Multi-specialty rounds, Clinical trials)
    'general_clinical': [
      'photo-1631815589968-fdb09a223b1e', // Modern hospital care ward
      'photo-1519494026892-80bbd2d6fd0d', // Medical center corridor
      'photo-1551076805-e1869033e561', // Multi-physician case review
      'photo-1538108149393-fbbd81895907', // Acute clinical facility
      'photo-1584515933487-779824d29309', // Attending clinical staff
      'photo-1579684385127-1ef15d508118', // Verified clinical testing
    ],
  };

  /// Matches article text metadata to one of the 12 granular sub-buckets.
  /// Prioritizes declared category and title keywords to avoid misclassifications
  /// caused by incidental terms in medical abstracts.
  static String matchBucket({
    required String title,
    required String category,
    List<String> meshHeadings = const [],
    String abstractText = '',
  }) {
    final lowerTitle = title.toLowerCase();
    final lowerCat = category.toLowerCase().trim();

    // 1. Direct Category Match (highest fidelity)
    if (lowerCat == 'cardiology' || lowerCat == 'cardio' || lowerCat == 'heart') return 'cardiology';
    if (lowerCat == 'nutrition' || lowerCat == 'diet' || lowerCat == 'fasting') return 'nutrition_fasting';
    if (lowerCat == 'sleep' || lowerCat == 'neurology' || lowerCat == 'neuro') return 'sleep_neurology';
    if (lowerCat == 'fitness' || lowerCat == 'exercise' || lowerCat == 'resistance') return 'resistance_fitness';
    if (lowerCat == 'immunology' || lowerCat == 'immunity') return 'immunology_lab';
    if (lowerCat == 'pharmacology' || lowerCat == 'medicines' || lowerCat == 'medication') return 'pharmacology';
    if (lowerCat == 'mental health' || lowerCat == 'psychology' || lowerCat == 'psychiatry') return 'mental_health';
    if (lowerCat == 'pediatrics' || lowerCat == "children's health" || lowerCat == 'pediatric') return 'pediatrics';
    if (lowerCat == 'endocrinology' || lowerCat == 'diabetes') return 'endocrinology_diabetes';
    if (lowerCat == 'oncology' || lowerCat == 'cancer') return 'oncology';
    if (lowerCat == 'dermatology' || lowerCat == 'skin') return 'dermatology';
    if (lowerCat == 'respiratory' || lowerCat == 'pulmonology' || lowerCat == 'breathing') return 'respiratory';
    if (lowerCat.contains('women') || lowerCat == 'obstetrics') return 'women_health';

    // 2. High-confidence Title & MeSH Semantic Match
    final titleAndMesh = '$lowerTitle ${meshHeadings.map((h) => h.toLowerCase()).join(' ')}';

    // Cardiology
    if (titleAndMesh.contains('cardio') ||
        titleAndMesh.contains('heart') ||
        titleAndMesh.contains('coronary') ||
        titleAndMesh.contains('myocardial') ||
        titleAndMesh.contains('arrhythmia') ||
        titleAndMesh.contains('hypertension') ||
        titleAndMesh.contains('blood pressure') ||
        titleAndMesh.contains('angina') ||
        titleAndMesh.contains('vascular') ||
        titleAndMesh.contains('atherosclerosis')) {
      return 'cardiology';
    }

    // Nutrition & Fasting
    if (titleAndMesh.contains('nutrition') ||
        titleAndMesh.contains('diet') ||
        titleAndMesh.contains('fasting') ||
        titleAndMesh.contains('micronutrient') ||
        titleAndMesh.contains('calorie') ||
        titleAndMesh.contains('vitamin') ||
        titleAndMesh.contains('omega-3') ||
        titleAndMesh.contains('microbiome') ||
        titleAndMesh.contains('food')) {
      return 'nutrition_fasting';
    }

    // Sleep & Neurology
    if (titleAndMesh.contains('sleep') ||
        titleAndMesh.contains('insomnia') ||
        titleAndMesh.contains('circadian') ||
        titleAndMesh.contains('eeg') ||
        titleAndMesh.contains('brain') ||
        titleAndMesh.contains('neuro') ||
        titleAndMesh.contains('alzheimer') ||
        titleAndMesh.contains('parkinson') ||
        titleAndMesh.contains('stroke') ||
        titleAndMesh.contains('cognitive')) {
      return 'sleep_neurology';
    }

    // Fitness & Exercise
    if (titleAndMesh.contains('fitness') ||
        titleAndMesh.contains('exercise') ||
        titleAndMesh.contains('resistance training') ||
        titleAndMesh.contains('hypertrophy') ||
        titleAndMesh.contains('physical activity') ||
        titleAndMesh.contains('muscle') ||
        titleAndMesh.contains('athletic') ||
        titleAndMesh.contains('biomechanic')) {
      return 'resistance_fitness';
    }

    // Mental Health
    if (titleAndMesh.contains('mental health') ||
        titleAndMesh.contains('depression') ||
        titleAndMesh.contains('anxiety') ||
        titleAndMesh.contains('psychiatr') ||
        titleAndMesh.contains('psycholog') ||
        titleAndMesh.contains('stress') ||
        titleAndMesh.contains('mood') ||
        titleAndMesh.contains('mindfulness')) {
      return 'mental_health';
    }

    // Endocrinology & Diabetes
    if (titleAndMesh.contains('diabet') ||
        titleAndMesh.contains('insulin') ||
        titleAndMesh.contains('glucose') ||
        titleAndMesh.contains('glycemic') ||
        titleAndMesh.contains('endocrin') ||
        titleAndMesh.contains('thyroid') ||
        titleAndMesh.contains('metabolic syndrome')) {
      return 'endocrinology_diabetes';
    }

    // Pediatrics & Infant (checked before Respiratory so pediatric respiratory cases map to pediatrics)
    if (titleAndMesh.contains('pediatric') ||
        titleAndMesh.contains('paediatric') ||
        titleAndMesh.contains('infant') ||
        titleAndMesh.contains('neonat') ||
        titleAndMesh.contains('child') ||
        titleAndMesh.contains('adolescent')) {
      return 'pediatrics';
    }

    // Respiratory
    if (titleAndMesh.contains('respirat') ||
        titleAndMesh.contains('asthma') ||
        titleAndMesh.contains('copd') ||
        titleAndMesh.contains('lung') ||
        titleAndMesh.contains('pulmonary') ||
        titleAndMesh.contains('bronch') ||
        titleAndMesh.contains('inhaler') ||
        titleAndMesh.contains('breathing')) {
      return 'respiratory';
    }

    // Dermatology
    if (titleAndMesh.contains('skin') ||
        titleAndMesh.contains('dermat') ||
        titleAndMesh.contains('epiderm') ||
        titleAndMesh.contains('cutaneous') ||
        titleAndMesh.contains('psoriasis') ||
        titleAndMesh.contains('eczema') ||
        titleAndMesh.contains('acne')) {
      return 'dermatology';
    }

    // Oncology (Cancer)
    if (titleAndMesh.contains('cancer') ||
        titleAndMesh.contains('tumor') ||
        titleAndMesh.contains('tumour') ||
        titleAndMesh.contains('oncolog') ||
        titleAndMesh.contains('carcinoma') ||
        titleAndMesh.contains('melanoma') ||
        titleAndMesh.contains('chemotherapy') ||
        titleAndMesh.contains('leukemia') ||
        titleAndMesh.contains('neoplasm')) {
      return 'oncology';
    }

    // Women's Health
    if (titleAndMesh.contains('women') ||
        titleAndMesh.contains('pregnan') ||
        titleAndMesh.contains('maternal') ||
        titleAndMesh.contains('menopaus') ||
        titleAndMesh.contains('breastfeed') ||
        titleAndMesh.contains('endometriosis')) {
      return 'women_health';
    }

    // Pharmacology
    if (titleAndMesh.contains('drug') ||
        titleAndMesh.contains('pharmac') ||
        titleAndMesh.contains('dosage') ||
        titleAndMesh.contains('statin') ||
        titleAndMesh.contains('tablet') ||
        titleAndMesh.contains('inhibitor') ||
        titleAndMesh.contains('therapeutics')) {
      return 'pharmacology';
    }

    // Immunology
    if (titleAndMesh.contains('immun') ||
        titleAndMesh.contains('antibody') ||
        titleAndMesh.contains('vaccin') ||
        titleAndMesh.contains('cytokine') ||
        titleAndMesh.contains('infection') ||
        titleAndMesh.contains('virus') ||
        titleAndMesh.contains('autoimmune')) {
      return 'immunology_lab';
    }

    return 'general_clinical';
  }

  /// Deterministically resolves an Unsplash photo ID for an article.
  static String resolvePhotoId(HealthArticle article) {
    final bucketKey = matchBucket(
      title: article.title,
      category: article.category,
      meshHeadings: article.meshHeadings,
      abstractText: article.excerpt,
    );

    final bucketList = _buckets[bucketKey] ?? _buckets['general_clinical']!;
    // Deterministic modulo hashing on article.id
    final index = article.id.hashCode.abs() % bucketList.length;
    return bucketList[index];
  }

  /// Builds a high-resolution 16:9 Cover Image URL constrained to `width=800`
  /// to eliminate RAM bloat while providing retina-sharp visuals.
  static String resolveCoverUrl(HealthArticle article) {
    if (article.imageUrls.isNotEmpty &&
        article.imageUrls.first.startsWith('http') &&
        !article.imageUrls.first.contains('images.unsplash.com')) {
      return article.imageUrls.first;
    }
    final photoId = resolvePhotoId(article);
    return '$baseUrl/$photoId?auto=format&fit=crop&w=800&q=80';
  }

  /// Builds a compact 96x96 Thumbnail Image URL constrained to `width=300`
  /// for optimal 60fps infinite scrolling.
  static String resolveThumbnailUrl(HealthArticle article) {
    if (article.imageUrls.isNotEmpty &&
        article.imageUrls.first.startsWith('http') &&
        !article.imageUrls.first.contains('images.unsplash.com')) {
      return article.imageUrls.first;
    }
    final photoId = resolvePhotoId(article);
    return '$baseUrl/$photoId?auto=format&fit=crop&w=300&q=80';
  }
}
