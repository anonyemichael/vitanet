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

  /// Picks the local photo whose subject matches the given topic text.
  /// Keyword order matters: the most specific subjects are checked first.
  static String forTopic(String text, {String fallback = laptopStethoscope}) {
    final t = text.toLowerCase();
    bool has(List<String> keys) => keys.any(t.contains);

    if (has(['smartwatch', 'wearable', 'atrial', 'arrhythm', 'fibrillation', 'heart rate', 'pulse'])) {
      return smartwatchWrist;
    }
    if (has(['blood pressure', 'hypertens', 'systolic', 'bp '])) return bloodPressureCheck;
    if (has(['child', 'pediatric', 'paediatric', 'infant', 'neonat', 'kids'])) return doctorsWithChild;
    if (has(['sleep', 'insomnia', 'circadian', 'melatonin'])) return sleep;
    if (has(['breath', 'meditat', 'mindful', 'panic', 'stress', 'anxiety', 'vagal', 'grounding'])) return meditation;
    if (has(['mental', 'depress', 'caregiv', 'carer', 'burnout', 'loneliness', 'grief', 'psychiat'])) return holdingHands;
    if (has(['vaccin', 'immun', 'antibod', 'infection', 'virus', 'viral'])) return vaccination;
    if (has(['antibiotic', 'medicine', 'medication', 'drug', 'pharmac', 'dose', 'tablet'])) return pillsOrange;
    if (has(['diet', 'nutrition', 'food', 'eating', 'fasting', 'gut', 'plate', 'meal', 'dash'])) return healthyPlate;
    if (has(['exercise', 'fitness', 'training', 'physical activity', 'physio', 'posture', 'spine', 'muscle', 'sciatica', 'lumbar'])) {
      return workout;
    }
    if (has(['fracture', 'x-ray', 'xray', 'bone', 'orthop'])) return xray;
    if (has(['surgery', 'surgical', 'cancer', 'tumor', 'tumour', 'oncolog', 'chemo'])) return operatingTheatre;
    if (has(['first aid', 'cpr', 'bleed', 'burn', 'choking', 'wound', 'recovery position', 'trauma'])) return firstAidKit;
    if (has(['cardio', 'heart', 'stroke', 'atheroscl', 'cholesterol', 'vital'])) return bloodPressureCheck;
    if (has(['women', 'pregnan', 'menopaus', 'maternal'])) return doctorWithPatient;
    return fallback;
  }
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
