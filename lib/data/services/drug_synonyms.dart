import 'package:vitanet/features/resources/models/medicine.dart';

/// International-to-FDA USAN synonym mapper
class DrugSynonymMapper {
  /// Maps international generic names (INN/BAN) to USAN generic names used by openFDA
  static const Map<String, String> _internationalToUsan = {
    'paracetamol': 'acetaminophen',
    'salbutamol': 'albuterol',
    'adrenaline': 'epinephrine',
    'frusemide': 'furosemide',
    'lignocaine': 'lidocaine',
    'glibenclamide': 'glyburide',
    'co-amoxiclav': 'amoxicillin and clavulanate potassium',
  };

  /// Maps USAN back to International generic names
  static const Map<String, String> _usanToInternational = {
    'acetaminophen': 'paracetamol',
    'albuterol': 'salbutamol',
    'epinephrine': 'adrenaline',
    'furosemide': 'frusemide',
    'lidocaine': 'lignocaine',
    'glyburide': 'glibenclamide',
  };

  /// Returns the query translated to openFDA USAN naming if a match exists.
  /// e.g. "Paracetamol" -> "acetaminophen"
  static String mapToFdaQuery(String query) {
    final clean = query.trim().toLowerCase();
    if (_internationalToUsan.containsKey(clean)) {
      return _internationalToUsan[clean]!;
    }
    // Check if query contains any of the known international terms
    for (final entry in _internationalToUsan.entries) {
      if (clean.contains(entry.key)) {
        return clean.replaceAll(entry.key, entry.value);
      }
    }
    return query.trim();
  }

  /// Returns all search aliases for a given query (both USAN and International names).
  /// e.g. for "paracetamol" -> ["paracetamol", "acetaminophen"]
  static List<String> getSearchAliases(String query) {
    final clean = query.trim().toLowerCase();
    final results = <String>{clean};

    if (_internationalToUsan.containsKey(clean)) {
      results.add(_internationalToUsan[clean]!);
    }
    if (_usanToInternational.containsKey(clean)) {
      results.add(_usanToInternational[clean]!);
    }

    return results.toList();
  }

  /// Formats the card display title to show both names clearly.
  /// e.g. "Acetaminophen" -> "Acetaminophen (Paracetamol)"
  /// or "Paracetamol" -> "Acetaminophen (Paracetamol)"
  static String formatDisplayTitle(String name, [String? genericName]) {
    final lowerName = name.toLowerCase().trim();
    final lowerGeneric = genericName?.toLowerCase().trim() ?? '';

    // If title already has parentheses with synonyms, return it
    if (lowerName.contains('(') && lowerName.contains(')')) {
      return name;
    }

    // Check international <-> USAN
    for (final entry in _internationalToUsan.entries) {
      final intl = entry.key;
      final usan = entry.value;

      if (lowerName == intl || lowerName == usan) {
        return '${_capitalize(usan)} (${_capitalize(intl)})';
      }
      if (lowerGeneric == intl || lowerGeneric == usan) {
        return '$name (${_capitalize(usan)} / ${_capitalize(intl)})';
      }
    }

    return name;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}

/// Category to openFDA Query and Local Filter Helper
class MedicineCategoryQueries {
  static const String defaultAllQuery = '_exists_:openfda.brand_name';
  static const String painAndFeverQuery = 'openfda.generic_name:("acetaminophen"+OR+"ibuprofen"+OR+"naproxen"+OR+"aspirin")';
  static const String antibioticsQuery = 'openfda.generic_name:("amoxicillin"+OR+"azithromycin"+OR+"ciprofloxacin"+OR+"doxycycline")';
  static const String cardiovascularQuery = 'openfda.generic_name:("lisinopril"+OR+"amlodipine"+OR+"atorvastatin"+OR+"metoprolol")';
  static const String mentalHealthQuery = 'openfda.generic_name:("sertraline"+OR+"escitalopram"+OR+"fluoxetine"+OR+"duloxetine")';
  static const String respiratoryQuery = 'openfda.generic_name:("albuterol"+OR+"loratadine"+OR+"cetirizine"+OR+"fluticasone")';
  static const String gastrointestinalQuery = 'openfda.generic_name:("omeprazole"+OR+"pantoprazole"+OR+"famotidine"+OR+"esomeprazole")';

  static String? getQueryForCategory(String category) {
    switch (category) {
      case 'All':
        return defaultAllQuery;
      case 'Pain & Fever':
        return painAndFeverQuery;
      case 'Antibiotics':
        return antibioticsQuery;
      case 'Cardiovascular':
        return cardiovascularQuery;
      case 'Mental Health':
        return mentalHealthQuery;
      case 'Respiratory':
        return respiratoryQuery;
      case 'Gastrointestinal':
        return gastrointestinalQuery;
      default:
        return null;
    }
  }

  /// Determines if a medicine belongs to a given category filter for local fallback matching
  static bool matchesCategory(Medicine med, String category) {
    if (category == 'All') return true;
    final text = '${med.name} ${med.type} ${med.description}'.toLowerCase();

    switch (category) {
      case 'Pain & Fever':
        return text.contains('acetaminophen') ||
            text.contains('paracetamol') ||
            text.contains('ibuprofen') ||
            text.contains('naproxen') ||
            text.contains('aspirin') ||
            text.contains('pain') ||
            text.contains('fever') ||
            text.contains('analgesic') ||
            text.contains('nsaid');
      case 'Antibiotics':
        return text.contains('amoxicillin') ||
            text.contains('azithromycin') ||
            text.contains('ciprofloxacin') ||
            text.contains('doxycycline') ||
            text.contains('antibiotic') ||
            text.contains('antibacterial') ||
            text.contains('penicillin') ||
            text.contains('macrolide') ||
            text.contains('fluoroquinolone') ||
            text.contains('tetracycline');
      case 'Cardiovascular':
        return text.contains('lisinopril') ||
            text.contains('amlodipine') ||
            text.contains('atorvastatin') ||
            text.contains('metoprolol') ||
            text.contains('aspirin') ||
            text.contains('cardio') ||
            text.contains('heart') ||
            text.contains('blood pressure') ||
            text.contains('statin') ||
            text.contains('ace inhibitor') ||
            text.contains('beta-blocker') ||
            text.contains('calcium channel');
      case 'Mental Health':
        return text.contains('sertraline') ||
            text.contains('escitalopram') ||
            text.contains('antidepressant') ||
            text.contains('ssri') ||
            text.contains('anxiety') ||
            text.contains('depression') ||
            text.contains('mental');
      case 'Respiratory':
        return text.contains('albuterol') ||
            text.contains('salbutamol') ||
            text.contains('loratadine') ||
            text.contains('cetirizine') ||
            text.contains('respiratory') ||
            text.contains('asthma') ||
            text.contains('broncho') ||
            text.contains('allergy') ||
            text.contains('antihistamine');
      case 'Gastrointestinal':
        return text.contains('omeprazole') ||
            text.contains('pantoprazole') ||
            text.contains('famotidine') ||
            text.contains('gastro') ||
            text.contains('proton pump') ||
            text.contains('acid') ||
            text.contains('ulcer') ||
            text.contains('gerd');
      default:
        return true;
    }
  }
}
