import 'package:flutter/material.dart';
import 'drug_synonyms.dart';

/// Clinical style specification for drug administration routes
class DrugRouteStyle {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final String label;

  const DrugRouteStyle({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.label,
  });
}

/// Clinical data sanitization and formatting engine for openFDA SPL Drug Monographs.
///
/// Resolves:
/// 1. Stripping raw SPL section numbers and headers ("1 INDICATIONS AND USAGE", "Use For").
/// 2. Converting ALL-CAPS generic/brand names to clean Title Case.
/// 3. Inverting generic marketing titles (e.g. "Pain Reliever Extra Strength" -> Acetaminophen).
/// 4. Eliminating meaningless "(Therapeutic Agent)" fallbacks by inferring clinical categories.
/// 5. Filtering out non-clinical cosmetic hand washes and sunscreens.
/// 6. Mapping administration routes to distinct clinical iconography and badge colorways.
class OpenFdaSanitizer {
  /// Regular expression to match raw FDA SPL numbering, section codes, and headers.
  static final RegExp _fdaHeaderRegex = RegExp(
    r'^(\d+(\.\d+)*\s*[-–—.]?\s*)?'
    r'(INDICATIONS\s+AND\s+USAGE\s*:?\s*|INDICATIONS?\s*:?\s*|Use\s+[Ff]or\s*:?\s*|USES?\s*:?\s*|Purpose\s*:?\s*|Active\s+Ingredient\s*:?\s*)',
    caseSensitive: false,
  );

  /// Bracketed cross-references like "[see Dosage and Administration (2.1)]"
  static final RegExp _bracketRefRegex = RegExp(
    r'\[see\s+[^\]]+\]',
    caseSensitive: false,
  );

  /// Common marketing phrases found in OTC packaging rather than true brand names
  static final List<String> _marketingPhrases = [
    'pain reliever',
    'pain relief',
    'fever reducer',
    'extra strength',
    'maximum strength',
    'ultra strength',
    'regular strength',
    'moisturizing',
    'quick action',
    'fast acting',
    'rapid release',
    'antibacterial',
    'antiseptic',
    'hand soap',
    'body wash',
    'foaming wash',
    'daily moisturizer',
    'multi-symptom',
    'nighttime',
    'daytime',
    'cold & flu',
    'cold and flu',
    'cough & cold',
    'sleep aid',
    'sleep-aid',
    'gas relief',
    'nasal spray',
    'anti-itch',
  ];

  /// Medical acronyms that should remain capitalized
  static const Set<String> _medicalAcronyms = {
    'FDA',
    'SPL',
    'OTC',
    'RX',
    'NSAID',
    'PPI',
    'ACE',
    'ARB',
    'SSRI',
    'SNRI',
    'DNA',
    'RNA',
    'XR',
    'ER',
    'SR',
    'CR',
    'HCL',
    'IV',
    'IM',
    'SC',
    'GI',
    'GERD',
    'UTI',
    'COPD',
    'BRAF',
    'MEK',
    'EGFR',
    'HER2',
    'HIV',
    'MG',
    'MCG',
    'ML',
  };

  /// Cleans raw openFDA indication text:
  /// - Strips leading SPL headers ("1 INDICATIONS AND USAGE", "Use For handwashing")
  /// - Removes bracketed clinical cross-references
  /// - Normalizes whitespace and capitalization
  /// - Limits length smoothly at word boundaries if [maxChars] is specified.
  static String cleanIndication(String? raw, {int maxChars = 220}) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Medication label information from the FDA.';
    }

    var text = raw.trim();

    // 1. Remove HTML tags if present
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // 2. Remove bracketed SPL cross-references: [see Dosage and Administration (2.1)]
    text = text.replaceAll(_bracketRefRegex, '');

    // 3. Strip leading FDA numbering and section headers
    text = text.replaceFirst(_fdaHeaderRegex, '');

    // 4. Strip stray leading bullets or punctuation (e.g. "• ", "- ", ": ")
    text = text.replaceFirst(RegExp(r'^[\s\d.:;•\-\*–—]+\s*'), '');

    // 5. Normalize whitespace (tabs, newlines, multiple spaces)
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.isEmpty) {
      return 'Medication label information from the FDA.';
    }

    // 6. Ensure initial capital letter
    text = text[0].toUpperCase() + text.substring(1);

    // 7. Word-boundary truncation
    if (text.length > maxChars) {
      final substring = text.substring(0, maxChars);
      final lastSpace = substring.lastIndexOf(' ');
      if (lastSpace > 60) {
        text = '${substring.substring(0, lastSpace)}...';
      } else {
        text = '$substring...';
      }
    }

    // Ensure ending with period if not ellipsis
    if (!text.endsWith('.') && !text.endsWith('...')) {
      text = '$text.';
    }

    return text;
  }

  /// Converts ALL-CAPS or raw text into clean medical Title Case.
  /// Retains established medical acronyms (FDA, OTC, NSAID, HCL, etc.).
  static String formatTitleCase(String? text) {
    if (text == null || text.trim().isEmpty) return '';

    final words = text.trim().split(RegExp(r'\s+'));
    final formatted = words.map((word) {
      // Check for punctuation attached to word
      final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      if (_medicalAcronyms.contains(cleanWord)) {
        return word.toUpperCase();
      }

      // Handle hyphenated words (e.g., "Non-Steroidal", "Co-Amoxiclav")
      if (word.contains('-')) {
        return word.split('-').map((part) => _capitalizeWord(part)).join('-');
      }

      // Handle slashed words (e.g., "Acetaminophen/Diphenhydramine")
      if (word.contains('/')) {
        return word.split('/').map((part) => _capitalizeWord(part)).join('/');
      }

      return _capitalizeWord(word);
    });

    return formatted.join(' ');
  }

  static String _capitalizeWord(String word) {
    if (word.isEmpty) return word;
    if (word.length == 1) return word.toUpperCase();
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }

  /// Normalizes brand and generic titles:
  /// - If the brand name is a marketing phrase (e.g., "Pain Reliever Extra Strength", "Quick Action"),
  ///   the generic substance name is made the primary title.
  /// - Substance names are converted to clean Title Case.
  /// - International synonyms are formatted seamlessly (e.g. "Acetaminophen (Paracetamol)").
  static ({String primaryTitle, String secondarySubtitle, bool isGenericPrimary}) formatDrugTitles({
    required String rawBrand,
    required String rawGeneric,
    String? substanceName,
  }) {
    final cleanBrand = formatTitleCase(rawBrand);
    final cleanGeneric = formatTitleCase(rawGeneric.isNotEmpty ? rawGeneric : (substanceName ?? ''));

    final brandLower = cleanBrand.toLowerCase();

    // Check if brand is generic marketing noise
    final isMarketingBrand = _marketingPhrases.any((phrase) => brandLower.contains(phrase));

    if (isMarketingBrand && cleanGeneric.isNotEmpty) {
      // Invert: Generic is primary, marketing phrase is secondary
      final displayGeneric = DrugSynonymMapper.formatDisplayTitle(cleanGeneric);
      return (
        primaryTitle: displayGeneric,
        secondarySubtitle: cleanBrand,
        isGenericPrimary: true,
      );
    }

    if (cleanBrand.isNotEmpty) {
      final displayBrand = DrugSynonymMapper.formatDisplayTitle(cleanBrand, cleanGeneric);
      return (
        primaryTitle: displayBrand,
        secondarySubtitle: cleanGeneric.isNotEmpty ? cleanGeneric : '',
        isGenericPrimary: false,
      );
    }

    final displayGeneric = DrugSynonymMapper.formatDisplayTitle(
      cleanGeneric.isNotEmpty ? cleanGeneric : 'Medication Monograph',
    );
    return (
      primaryTitle: displayGeneric,
      secondarySubtitle: '',
      isGenericPrimary: true,
    );
  }

  /// Resolves pharmacological class without ever returning "(Therapeutic Agent)".
  /// Infers clinical class from route, indications, or generic substance when openFDA EPC is missing.
  static String resolveDrugClass({
    String? pharmClassEpc,
    String? pharmClassCs,
    String? route,
    String? indications,
    String? genericName,
  }) {
    // 1. Check explicit EPC / CS class
    final explicitClass = (pharmClassEpc != null && pharmClassEpc.trim().isNotEmpty)
        ? pharmClassEpc
        : pharmClassCs;

    if (explicitClass != null && explicitClass.trim().isNotEmpty) {
      final cleaned = explicitClass
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .trim();

      // Ensure not the generic fallback
      if (cleaned.isNotEmpty && !cleaned.toLowerCase().contains('therapeutic agent')) {
        return formatTitleCase(cleaned);
      }
    }

    // 2. Infer from clinical indications / substance / route
    final text = '${genericName ?? ''} ${indications ?? ''}'.toLowerCase();
    final routeLower = (route ?? '').toLowerCase();

    if (text.contains('kinase') || text.contains('melanoma') || text.contains('oncolog') || text.contains('antineoplastic') || text.contains('tumor')) {
      return 'Oncology / Kinase Inhibitor';
    }
    if (text.contains('penicillin') || text.contains('antibacter') || text.contains('antibiotic') || text.contains('infection')) {
      return 'Antimicrobial / Antibacterial';
    }
    if (text.contains('hypertens') || text.contains('blood pressure') || text.contains('cardio') || text.contains('heart') || text.contains('statin') || text.contains('beta-blocker')) {
      return 'Cardiovascular Agent';
    }
    if (text.contains('antidepress') || text.contains('ssri') || text.contains('anxiety') || text.contains('psych') || text.contains('bipolar')) {
      return 'Psychotropic / Neuroactive';
    }
    if (text.contains('pain') || text.contains('analgesic') || text.contains('fever') || text.contains('antipyretic') || text.contains('nsaid')) {
      return 'Analgesic & Antipyretic';
    }
    if (text.contains('asthma') || text.contains('broncho') || text.contains('albuterol') || text.contains('inhal')) {
      return 'Respiratory / Bronchodilator';
    }
    if (text.contains('allergy') || text.contains('antihistamine') || text.contains('rhinitis')) {
      return 'Antihistamine / Antiallergic';
    }
    if (text.contains('diabetes') || text.contains('hypoglycemic') || text.contains('insulin') || text.contains('glucose')) {
      return 'Antidiabetic Agent';
    }
    if (text.contains('gerd') || text.contains('proton pump') || text.contains('acid') || text.contains('ulcer') || text.contains('antacid')) {
      return 'Gastrointestinal Agent';
    }

    // 3. Fallback based on administration route
    if (routeLower.contains('topical')) {
      if (text.contains('antiseptic') || text.contains('bacteria') || text.contains('wash')) {
        return 'Topical Antiseptic';
      }
      return 'Topical Formulation';
    }
    if (routeLower.contains('ophthalmic')) {
      return 'Ophthalmic Preparation';
    }
    if (routeLower.contains('otic')) {
      return 'Otic Preparation';
    }
    if (routeLower.contains('injection') || routeLower.contains('intravenous') || routeLower.contains('subcutaneous')) {
      return 'Injectable Pharmacotherapy';
    }
    if (routeLower.contains('inhalation') || routeLower.contains('respiratory')) {
      return 'Inhalation Aerosol';
    }

    // Default clean classification
    return 'Regulated Pharmacotherapy';
  }

  /// Parses the administration route string from openFDA
  static String resolveRoute(List? routes, [String? dosageForm]) {
    if (routes != null && routes.isNotEmpty) {
      final first = routes.first.toString().toUpperCase().trim();
      if (first.contains('ORAL')) return 'ORAL';
      if (first.contains('TOPICAL')) return 'TOPICAL';
      if (first.contains('INTRAVENOUS') || first.contains('INJECTION') || first.contains('SUBCUTANEOUS') || first.contains('INTRAMUSCULAR')) {
        return 'INJECTION';
      }
      if (first.contains('OPHTHALMIC')) return 'OPHTHALMIC';
      if (first.contains('INHALATION') || first.contains('RESPIRATORY')) return 'INHALATION';
      if (first.contains('OTIC')) return 'OTIC';
      if (first.contains('TRANSDERMAL')) return 'TRANSDERMAL';
      if (first.contains('RECTAL')) return 'RECTAL';
      return first;
    }

    // Infer from dosage form if available
    final df = (dosageForm ?? '').toUpperCase();
    if (df.contains('TABLET') || df.contains('CAPSULE') || df.contains('SYRUP') || df.contains('SUSPENSION')) {
      return 'ORAL';
    }
    if (df.contains('CREAM') || df.contains('OINTMENT') || df.contains('GEL') || df.contains('LOTION') || df.contains('SOLUTION')) {
      return 'TOPICAL';
    }
    if (df.contains('INJECTION') || df.contains('VIAL')) {
      return 'INJECTION';
    }

    return 'ORAL';
  }

  /// Returns route-specific iconography, colors, and badge styling
  static DrugRouteStyle resolveRouteStyle(String? route, bool isDark) {
    final r = (route ?? 'ORAL').toUpperCase().trim();

    if (r.contains('TOPICAL')) {
      return DrugRouteStyle(
        icon: Icons.water_drop_rounded,
        iconColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
        backgroundColor: isDark ? const Color(0xFF0369A1).withValues(alpha: 0.22) : const Color(0xFFE0F2FE),
        borderColor: isDark ? const Color(0xFF0284C7).withValues(alpha: 0.40) : const Color(0xFFBAE6FD),
        label: 'Topical',
      );
    }

    if (r.contains('INJECTION') || r.contains('INTRAVENOUS') || r.contains('SUBCUTANEOUS')) {
      return DrugRouteStyle(
        icon: Icons.vaccines_rounded,
        iconColor: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
        backgroundColor: isDark ? const Color(0xFF6D28D9).withValues(alpha: 0.22) : const Color(0xFFF3E8FF),
        borderColor: isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.40) : const Color(0xFFDDD6FE),
        label: 'Injection',
      );
    }

    if (r.contains('OPHTHALMIC')) {
      return DrugRouteStyle(
        icon: Icons.visibility_rounded,
        iconColor: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
        backgroundColor: isDark ? const Color(0xFFC2410C).withValues(alpha: 0.22) : const Color(0xFFFFEDD5),
        borderColor: isDark ? const Color(0xFFEA580C).withValues(alpha: 0.40) : const Color(0xFFFED7AA),
        label: 'Ophthalmic',
      );
    }

    if (r.contains('INHALATION') || r.contains('RESPIRATORY')) {
      return DrugRouteStyle(
        icon: Icons.air_rounded,
        iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
        backgroundColor: isDark ? const Color(0xFF047857).withValues(alpha: 0.22) : const Color(0xFFD1FAE5),
        borderColor: isDark ? const Color(0xFF059669).withValues(alpha: 0.40) : const Color(0xFFA7F3D0),
        label: 'Inhalation',
      );
    }

    // Default ORAL
    return DrugRouteStyle(
      icon: Icons.medication_rounded,
      iconColor: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
      backgroundColor: isDark ? const Color(0xFF0D9488).withValues(alpha: 0.20) : const Color(0xFFCCFBF1),
      borderColor: isDark ? const Color(0xFF0D9488).withValues(alpha: 0.35) : const Color(0xFF99F6E4),
      label: 'Oral',
    );
  }

  /// Determines whether a drug record is FDA Approved, Rx Only, OTC, or Homeopathic/Unverified
  static ({bool isFdaApproved, bool isRx, bool isHomeopathic, String regulatoryStatus}) resolveRegulatoryStatus(
    Map<String, dynamic> item,
  ) {
    final openfda = item['openfda'] as Map<String, dynamic>? ?? {};
    final productType = (openfda['product_type'] as List?)?.join(' ').toUpperCase() ?? '';
    final isHomeo = productType.contains('HOMEOPATHIC') ||
        (item['purpose'] as List?)?.join(' ').toUpperCase().contains('HOMEOPATHIC') == true;

    final appNum = openfda['application_number'] as List?;
    final hasNda = appNum != null && appNum.any((n) {
      final s = n.toString().toUpperCase();
      return s.startsWith('NDA') || s.startsWith('ANDA') || s.startsWith('BLA');
    });

    // openfda.product_type is authoritative when present
    // ("HUMAN OTC DRUG" vs "HUMAN PRESCRIPTION DRUG").
    final isExplicitOtc = productType.contains('OTC');
    final isExplicitRx = !isExplicitOtc && productType.contains('PRESCRIPTION');

    final bool isRx;
    if (isExplicitOtc) {
      isRx = false;
    } else if (isExplicitRx) {
      isRx = true;
    } else {
      // No product_type: infer from the label itself. An ANDA/NDA number alone
      // says nothing about Rx vs OTC (most OTC generics are ANDA products).
      // OTC monograph products use "M###" / "part###" application numbers, and
      // OTC "Drug Facts" labels carry purpose / ask-a-doctor sections, while
      // prescription labels carry clinical pharmacology / boxed warnings.
      final isMonograph = appNum != null &&
          appNum.any((n) {
            final s = n.toString().toUpperCase();
            return RegExp(r'^M\d').hasMatch(s) || s.startsWith('PART');
          });
      bool has(String key) => item[key] is List && (item[key] as List).isNotEmpty;
      final drugFacts = has('purpose') ||
          has('keep_out_of_reach_of_children') ||
          has('ask_doctor') ||
          has('stop_use');
      final rxSections = has('clinical_pharmacology') ||
          has('boxed_warning') ||
          has('contraindications') ||
          has('spl_patient_package_insert');
      if (isMonograph || (drugFacts && !rxSections)) {
        isRx = false;
      } else {
        isRx = rxSections || hasNda;
      }
    }

    if (isHomeo) {
      return (
        isFdaApproved: false,
        isRx: false,
        isHomeopathic: true,
        regulatoryStatus: 'Homeopathic / Unverified',
      );
    }

    final isApproved = hasNda || (openfda['nui'] != null && (openfda['nui'] as List).isNotEmpty);

    return (
      isFdaApproved: isApproved,
      isRx: isRx,
      isHomeopathic: false,
      regulatoryStatus: isRx ? 'Rx Only' : 'OTC',
    );
  }

  /// Filters out non-clinical cosmetic noise such as hand soaps, sunscreens, and body lotions
  /// unless the user specifically searched for those terms.
  static bool isCosmeticNoise(Map<String, dynamic> item, {String query = ''}) {
    final q = query.toLowerCase().trim();
    // If the user deliberately searched for "soap" or "sunscreen", do not filter it out
    if (q.contains('soap') || q.contains('wash') || q.contains('sunscreen') || q.contains('lotion')) {
      return false;
    }

    final openfda = item['openfda'] as Map<String, dynamic>? ?? {};
    final productType = (openfda['product_type'] as List?)?.join(' ').toUpperCase() ?? '';

    if (productType.contains('COSMETIC')) {
      return true;
    }

    final brandName = (openfda['brand_name'] as List?)?.join(' ').toLowerCase() ?? '';
    final substanceName = (openfda['substance_name'] as List?)?.join(' ').toLowerCase() ?? '';

    // Filter benzalkonium chloride hand washes/soaps unless searched
    if (substanceName.contains('benzalkonium chloride')) {
      if (brandName.contains('soap') || brandName.contains('hand wash') || brandName.contains('sanitizer')) {
        return true;
      }
    }

    final noiseKeywords = [
      'hand soap',
      'body wash',
      'hand wash',
      'foaming wash',
      'sunscreen',
      'sunblock',
      'shampoo',
      'conditioner',
      'body lotion',
    ];

    return noiseKeywords.any((keyword) => brandName.contains(keyword));
  }
}
