import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Real, correctly named stock photos used by the redesigned resource screens.
class VnPhotos {
  VnPhotos._();

  static const _base = 'assets/images/photos';
  static const doctorOnPhone = '$_base/doctor_on_phone.jpg';
  static const smartwatchWrist = '$_base/smartwatch_wrist.jpg';
  static const holdingHands = '$_base/holding_hands.jpg';
  static const doctorWithPatient = '$_base/doctor_with_patient.jpg';
  static const bloodPressureCheck = '$_base/blood_pressure_check.jpg';
  static const bpCuff = '$_base/bp_cuff.jpg';
  static const pillsColorful = '$_base/pills_colorful.jpg';
  static const pillsOrange = '$_base/pills_orange.jpg';
  static const blisterPacks = '$_base/blister_packs.jpg';
  static const pharmacyStore = '$_base/pharmacy_store.jpg';
  static const firstAidKit = '$_base/first_aid_kit.jpg';
  static const meditation = '$_base/meditation.jpg';
  static const sleep = '$_base/sleep.jpg';
  static const healthyPlate = '$_base/healthy_plate.jpg';
  static const saladBowl = '$_base/salad_bowl.jpg';
  static const workout = '$_base/workout.jpg';
  static const vaccination = '$_base/vaccination.jpg';
  static const operatingTheatre = '$_base/operating_theatre.jpg';
  static const surgicalTeam = '$_base/surgical_team.jpg';
  static const laptopStethoscope = '$_base/laptop_stethoscope.jpg';
  static const clinicianFemale = '$_base/clinician_female.jpg';
  static const physicianMale = '$_base/physician_male.jpg';
  static const doctorPortrait = '$_base/doctor_portrait.jpg';
  static const medicalTeam = '$_base/medical_team.jpg';
  static const doctorsWithChild = '$_base/doctors_with_child.jpg';
  static const xray = '$_base/xray.jpg';

  // Authentic clinical photographic assets (local JPEG)
  static const respiratoryHealth = '$_base/respiratory_health.jpg';
  static const glucoseMonitoring = '$_base/glucose_monitoring.jpg';
  static const cardiologyEcg = '$_base/cardiology_ecg.jpg';
  static const circadianSleep = '$_base/circadian_sleep.jpg';
  static const metabolicNutrition = '$_base/metabolic_nutrition.jpg';
  static const mindfulnessWellness = '$_base/mindfulness_wellness.jpg';
  static const fitnessVitality = '$_base/fitness_vitality.jpg';
  static const stethoscopeDiagnostics = '$_base/stethoscope_diagnostics.jpg';
  static const cprResuscitation = '$_base/cpr_resuscitation.jpg';
  static const bandageTherapy = '$_base/bandage_therapy.jpg';
  static const woundCare = '$_base/wound_care.jpg';
  static const digitalHealth = '$_base/digital_health.jpg';
  static const clinicalExamination = '$_base/clinical_examination.jpg';

  /// Picks the local photo whose subject matches the given topic text.
  ///
  /// Matching is word-boundary based (see [VnTopics]); when nothing matches
  /// confidently, [fallback] is returned rather than a loosely related photo.
  static String forTopic(String text, {String fallback = laptopStethoscope}) {
    if (VnTopics._matches(text, _firstAidPattern)) return firstAidKit;
    if (VnTopics._matches(text, _xrayPattern)) return xray;
    final topic = VnTopics.classify(text);
    return topic == null ? fallback : topic.photoFor(text);
  }

  static const _firstAidPattern =
      r'first aid|cpr|resuscitat|bleed|burns?\b|chok|wounds?\b|recovery position|trauma|defibrillat|\baed\b';
  static const _xrayPattern = r'fractur|x-ray|xray|orthop';
}

/// One health-library topic: its display category and matching photo(s).
class VnTopic {
  /// Category label stored on articles (e.g. "Cardiology").
  final String category;

  /// Regex alternation of word-start stems that identify the topic.
  final String pattern;

  /// Default photo for the topic.
  final String photo;

  /// Optional (pattern, photo) refinements checked before [photo].
  final List<(String, String)> refinements;

  const VnTopic(this.category, this.pattern, this.photo, [this.refinements = const []]);

  /// Most specific photo for [text] within this topic.
  String photoFor(String text) {
    for (final (pattern, photo) in refinements) {
      if (VnTopics._matches(text, pattern)) return photo;
    }
    return photo;
  }
}

/// Strict, word-boundary topic classification shared by the library feed,
/// article photos and video fallbacks.
class VnTopics {
  VnTopics._();

  /// Neutral category used when no topic matches confidently.
  static const research = 'Research';

  /// Ordered by priority: the first topic that matches wins, so specific
  /// patient-facing subjects (mental health, sleep, heart) beat broad ones.
  static const List<VnTopic> all = [
    VnTopic(
      'Mental Health',
      r'mental health|mental illness|depress|anxiety|anxious|psychiatr|psycholog|well-?being|'
          r'(?<!oxidative )(?<!oxidant )stress(?!-strain)|burnout|suicid|loneli|mood|ptsd|mindful|meditat|'
          r'grief|bereave|schizophren|bipolar|eating disorder|self-harm|panic',
      VnPhotos.meditation,
      [
        (r'depress|grief|bereave|loneli|suicid|caregiv|carers?\b|dementia', VnPhotos.holdingHands),
        (r'mindful|wellness|calm|reflection|tranquil', VnPhotos.mindfulnessWellness),
      ],
    ),
    VnTopic(
      'Sleep',
      r'sleep|insomnia|circadian|melatonin|apnoea|apnea|napping',
      VnPhotos.sleep,
      [
        (r'circadian|melatonin|architecture|rhythm|chronobiol', VnPhotos.circadianSleep),
      ],
    ),
    VnTopic(
      'Cardiology',
      r'hearts?\b|cardiac|cardio|hypertens|blood pressure|strokes?\b|atrial|arrhythm|myocard|coronary|'
          r'cholesterol|atheroscl|heart failure',
      VnPhotos.bloodPressureCheck,
      [
        (r'atrial|arrhythm|heart rate|wearable|smartwatch', VnPhotos.smartwatchWrist),
        (r'ecg\b|electrocardiog|telemetry|infarct|cardiac arrest|rhythm', VnPhotos.cardiologyEcg),
      ],
    ),
    VnTopic(
      'Respiratory',
      r'asthma|copd\b|lungs?\b|pulmonar|respirator|breath|pneumon|inhaler|bronch',
      VnPhotos.respiratoryHealth,
      [
        (r'stethoscope|auscultat', VnPhotos.stethoscopeDiagnostics),
      ],
    ),
    VnTopic(
      'Endocrinology',
      r'diabet|insulin|glucose|glycaem|glycem|thyroid|hba1c',
      VnPhotos.glucoseMonitoring,
      [
        (r'metabolic|metabolism|syndrome|fatty liver|ketone', VnPhotos.metabolicNutrition),
      ],
    ),
    VnTopic(
      'Nutrition',
      r'nutrition|nutrient|diets?\b|dietary|food|eating|meals?\b|fasting|vitamin|obes|mediterranean|'
          r'healthy plate|fruit|vegetable|salt intake|sugar intake',
      VnPhotos.healthyPlate,
      [
        (r'fruit|vegetable|plant-based|vegan|vegetarian|mediterranean', VnPhotos.saladBowl),
        (r'fasting|intermittent|metabolic|macronutrient', VnPhotos.metabolicNutrition),
      ],
    ),
    VnTopic(
      'Medicines',
      r'medications?\b|drugs?\b|antibiotic|pharmac|prescri|analgesic|paracetamol|acetaminophen|ibuprofen|'
          r'statins?\b|opioid|polypharmacy|dosing|tablets?\b|adherence',
      VnPhotos.pillsOrange,
      [(r'pharmac', VnPhotos.blisterPacks)],
    ),
    VnTopic(
      'Immunology',
      r'vaccin|immun|antibod|infection|infectious|virus|viral|covid|sars-cov|influenza|\bflu\b|hiv\b|antimicrobial',
      VnPhotos.vaccination,
    ),
    VnTopic(
      'Oncology',
      r'cancer|tumou?r|oncolog|chemo|carcinoma|leuka?emia|lymphoma|melanoma',
      VnPhotos.medicalTeam,
      [(r'surg', VnPhotos.operatingTheatre)],
    ),
    VnTopic(
      "Women's Health",
      r'pregnan|maternal|menopaus|women|prenatal|antenatal|postpartum|breastfeed|contracept|endometriosis|menstru',
      VnPhotos.clinicianFemale,
    ),
    VnTopic(
      "Children's Health",
      r'child|paediatric|pediatric|infant|neonat|kids\b|adolescen',
      VnPhotos.doctorsWithChild,
    ),
    VnTopic(
      'Fitness',
      r'exercis|fitness|physical activity|sports?\b|athlet|olympi|strength training|resistance training|'
          r'muscle|running|walking|yoga|physiotherap|sedentary',
      VnPhotos.workout,
      [(r'vitality|aerobic|running|cardio|stamina', VnPhotos.fitnessVitality)],
    ),
    VnTopic(
      'Longevity',
      r'ageing|aging|longevity|older adults|frailty|senescen',
      VnPhotos.holdingHands,
    ),
    VnTopic(
      'Surgery',
      r'surg',
      VnPhotos.operatingTheatre,
      [(r'surgical team|surgeons', VnPhotos.surgicalTeam)],
    ),
  ];

  static final Map<String, RegExp> _cache = {};

  static bool _matches(String text, String pattern) {
    final re = _cache.putIfAbsent(pattern, () => RegExp('\\b(?:$pattern)', caseSensitive: false));
    return re.hasMatch(text);
  }

  /// First topic whose keywords appear in [text], or `null`.
  static VnTopic? classify(String text) {
    if (text.trim().isEmpty) return null;
    for (final t in all) {
      if (_matches(text, t.pattern)) return t;
    }
    return null;
  }

  /// Topic for a stored category label (case-insensitive), or `null`.
  static VnTopic? byCategory(String category) {
    final c = category.trim().toLowerCase();
    if (c == 'sleep science' || c == 'sleep') return all[1];
    if (c == 'metabolic health' || c == 'diabetes') return all[4];
    if (c == 'breathing' || c == 'pulmonology') return all[3];
    if (c == 'heart') return all[2];
    if (c == 'sports medicine' || c == 'exercise') return all.firstWhere((t) => t.category == 'Fitness');
    if (c == 'immunity' || c == 'virology') return all.firstWhere((t) => t.category == 'Immunology');
    for (final t in all) {
      if (t.category.toLowerCase() == c) return t;
    }
    return null;
  }

  /// Category for a research article: title first, then MeSH headings,
  /// otherwise the neutral [research] category.
  static String categorize(String title, {List<String> meshHeadings = const []}) {
    return classify(title)?.category ??
        (meshHeadings.isEmpty ? null : classify(meshHeadings.join(' ; '))?.category) ??
        research;
  }

  /// Photo for an article that matches its category (neutral when unknown).
  static String photoForArticle(String title, String category) {
    final topic = byCategory(category);
    if (topic != null) return topic.photoFor(title);
    final classified = classify(title);
    if (classified != null) return classified.photoFor(title);
    return VnPhotos.laptopStethoscope;
  }
}

/// Centres [child] in a column no wider than [maxWidth] on tablets / desktop
/// so cards and photos don't stretch across the whole window. The side
/// gutters are painted with [background] so they blend with the page.
Widget vnReadableWidth(Widget child, {double maxWidth = 960, required Color background}) {
  return ColoredBox(
    color: background,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}

/// Opens the AI chat tab and hands it a prompt to answer.
void askVitaNetAi(BuildContext context, String prompt) {
  final ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
    GoRouter.of(context).go('/chat');
  } catch (_) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('AI chat is not available right now')),
    );
    return;
  }
  Future.delayed(const Duration(milliseconds: 450), () {
    container.read(searchActionProvider.notifier).state = prompt;
  });
}

/// Asset photo that degrades to a tinted icon block if the asset is missing.
class VnPhoto extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;
  final int? cacheWidth;

  const VnPhoto(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.cacheWidth = 800,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheWidth,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      errorBuilder: (_, _, _) => Container(
        width: width,
        height: height,
        color: p.surfaceAlt,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, color: p.faint),
      ),
    );
  }
}

/// Network image (e.g. a YouTube thumbnail) that falls back to a matching
/// local photo while loading or when offline.
class VnNetworkPhoto extends StatelessWidget {
  final String url;
  final String fallbackAsset;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;

  const VnNetworkPhoto({
    super.key,
    required this.url,
    required this.fallbackAsset,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth = 640,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = VnPhoto(fallbackAsset, fit: fit, alignment: alignment);
    if (url.isEmpty) return fallback;
    if (url.startsWith('assets/')) {
      return VnPhoto(url, fit: fit, alignment: alignment);
    }
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheWidth,
      excludeFromSemantics: true,
      loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Small "Over the counter" / "Prescription" style tag.
class VnTag extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double radius;
  final FontWeight weight;

  const VnTag({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.radius = 8,
    this.weight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.tintBg(bg, fg),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: VnText.body(fontSize, weight: weight, color: p.tintFg(fg)),
      ),
    );
  }
}

/// Horizontally scrolling chip row with the page's 20px gutter.
class VnChipRow extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double gap;

  const VnChipRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.gap = 8,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(SizedBox(width: gap));
      items.add(children[i]);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      clipBehavior: Clip.none,
      child: Row(children: items),
    );
  }
}

/// Selectable pill with the dark "ink" selected style used by the library,
/// video and pharmacy filters (design: #0F172A selected, white unselected).
class VnInkChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final double fontSize;
  final bool flat;

  const VnInkChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 38,
    this.radius = 999,
    this.fontSize = 14,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final bg = selected ? p.ink : (flat ? p.surfaceAlt : p.surface);
    final fg = selected ? p.page : p.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: flat ? BorderSide.none : BorderSide(color: selected ? p.ink : p.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height,
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label, style: VnText.body(fontSize, weight: FontWeight.w600, color: fg)),
          ),
        ),
      ),
    );
  }
}
