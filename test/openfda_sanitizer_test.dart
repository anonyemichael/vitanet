import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/data/services/openfda_sanitizer.dart';
import 'package:vitanet/features/resources/models/medicine.dart';
import 'package:vitanet/features/resources/screens/medicine_search_screen.dart';

void main() {
  group('OpenFdaSanitizer - cleanIndication Tests', () {
    test('Strips leading FDA numbering and section headers', () {
      const raw1 = '1 INDICATIONS AND USAGE MEKINIST is indicated as a single agent for melanoma.';
      expect(
        OpenFdaSanitizer.cleanIndication(raw1),
        equals('MEKINIST is indicated as a single agent for melanoma.'),
      );

      const raw2 = '1.1 INDICATIONS AND USAGE: Treatment of hypertension.';
      expect(
        OpenFdaSanitizer.cleanIndication(raw2),
        equals('Treatment of hypertension.'),
      );

      const raw3 = 'Use For handwashing to decrease bacteria on the skin.';
      expect(
        OpenFdaSanitizer.cleanIndication(raw3),
        equals('Handwashing to decrease bacteria on the skin.'),
      );

      const raw4 = 'Uses: For temporary relief of minor aches and pains.';
      expect(
        OpenFdaSanitizer.cleanIndication(raw4),
        equals('For temporary relief of minor aches and pains.'),
      );

      const raw5 = 'Purpose: Antiseptic';
      expect(
        OpenFdaSanitizer.cleanIndication(raw5),
        equals('Antiseptic.'),
      );
    });

    test('Strips bracketed clinical cross-references', () {
      const raw = 'Take as prescribed [see Dosage and Administration (2.1)] for optimal results.';
      expect(
        OpenFdaSanitizer.cleanIndication(raw),
        equals('Take as prescribed for optimal results.'),
      );
    });

    test('Handles empty and whitespace-only indications with clinical fallback', () {
      expect(
        OpenFdaSanitizer.cleanIndication(null),
        equals('Prescription medication monograph verified by the FDA.'),
      );
      expect(
        OpenFdaSanitizer.cleanIndication('   '),
        equals('Prescription medication monograph verified by the FDA.'),
      );
    });

    test('Capitalizes first character and formats sentence ending', () {
      const raw = 'relieves pain and reduces fever';
      expect(
        OpenFdaSanitizer.cleanIndication(raw),
        equals('Relieves pain and reduces fever.'),
      );
    });

    test('Truncates smoothly at word boundary when exceeding maxChars', () {
      final longText = 'This is a very long indication description for a potent cardiovascular medication ' * 5;
      final cleaned = OpenFdaSanitizer.cleanIndication(longText, maxChars: 80);
      expect(cleaned.endsWith('...'), isTrue);
      expect(cleaned.length, lessThanOrEqualTo(85));
    });
  });

  group('OpenFdaSanitizer - formatTitleCase Tests', () {
    test('Converts ALL-CAPS text to clean Title Case', () {
      expect(
        OpenFdaSanitizer.formatTitleCase('BENZALKONIUM CHLORIDE'),
        equals('Benzalkonium Chloride'),
      );
      expect(
        OpenFdaSanitizer.formatTitleCase('GLIMEPIRIDE TABLETS'),
        equals('Glimepiride Tablets'),
      );
    });

    test('Preserves established medical acronyms', () {
      expect(OpenFdaSanitizer.formatTitleCase('IBUPROFEN OTC'), equals('Ibuprofen OTC'));
      expect(OpenFdaSanitizer.formatTitleCase('FDA APPROVED'), equals('FDA Approved'));
      expect(OpenFdaSanitizer.formatTitleCase('METFORMIN HCL ER'), equals('Metformin HCL ER'));
      expect(OpenFdaSanitizer.formatTitleCase('LISINOPRIL ACE INHIBITOR'), equals('Lisinopril ACE Inhibitor'));
      expect(OpenFdaSanitizer.formatTitleCase('ADVIL NSAID'), equals('Advil NSAID'));
    });

    test('Handles slashed and hyphenated compound drug names', () {
      expect(
        OpenFdaSanitizer.formatTitleCase('ACETAMINOPHEN/DIPHENHYDRAMINE'),
        equals('Acetaminophen/Diphenhydramine'),
      );
      expect(
        OpenFdaSanitizer.formatTitleCase('CO-AMOXICLAV'),
        equals('Co-Amoxiclav'),
      );
    });
  });

  group('OpenFdaSanitizer - formatDrugTitles Tests', () {
    test('Inverts generic marketing brand titles so generic substance is primary', () {
      final titles = OpenFdaSanitizer.formatDrugTitles(
        rawBrand: 'PAIN RELIEVER EXTRA STRENGTH',
        rawGeneric: 'ACETAMINOPHEN',
      );

      // Primary should be generic name with international synonym
      expect(titles.primaryTitle, equals('Acetaminophen (Paracetamol)'));
      expect(titles.secondarySubtitle, equals('Pain Reliever Extra Strength'));
      expect(titles.isGenericPrimary, isTrue);
    });

    test('Inverts other marketing phrases like Quick Action or Moisturizing', () {
      final titles = OpenFdaSanitizer.formatDrugTitles(
        rawBrand: 'QUICK ACTION ACNE WASH',
        rawGeneric: 'BENZOYL PEROXIDE',
      );

      expect(titles.primaryTitle, equals('Benzoyl Peroxide'));
      expect(titles.secondarySubtitle, equals('Quick Action Acne Wash'));
      expect(titles.isGenericPrimary, isTrue);
    });

    test('Keeps real brand names as primary title', () {
      final titles = OpenFdaSanitizer.formatDrugTitles(
        rawBrand: 'LIPITOR',
        rawGeneric: 'ATORVASTATIN CALCIUM',
      );

      expect(titles.primaryTitle, equals('Lipitor'));
      expect(titles.secondarySubtitle, equals('Atorvastatin Calcium'));
      expect(titles.isGenericPrimary, isFalse);
    });
  });

  group('OpenFdaSanitizer - resolveDrugClass Tests', () {
    test('Eliminates "(Therapeutic Agent)" and never returns it', () {
      final result1 = OpenFdaSanitizer.resolveDrugClass(
        pharmClassEpc: 'Therapeutic Agent',
        genericName: 'TRAMETINIB',
        indications: 'Kinase inhibitor for unresectable melanoma',
      );
      expect(result1.contains('Therapeutic Agent'), isFalse);
      expect(result1, equals('Oncology / Kinase Inhibitor'));

      final result2 = OpenFdaSanitizer.resolveDrugClass(
        pharmClassEpc: '(Therapeutic Agent)',
        route: 'TOPICAL',
        genericName: 'BENZALKONIUM CHLORIDE',
        indications: 'Antiseptic handwash',
      );
      expect(result2.contains('Therapeutic Agent'), isFalse);
      expect(result2, equals('Topical Antiseptic'));
    });

    test('Cleans EPC pharmacological class strings by stripping brackets', () {
      final result = OpenFdaSanitizer.resolveDrugClass(
        pharmClassEpc: 'HMG-CoA Reductase Inhibitor [EPC]',
      );
      expect(result, equals('Hmg-Coa Reductase Inhibitor'));
    });

    test('Infers appropriate clinical categories from indication keywords', () {
      expect(
        OpenFdaSanitizer.resolveDrugClass(indications: 'hypertension and heart failure'),
        equals('Cardiovascular Agent'),
      );
      expect(
        OpenFdaSanitizer.resolveDrugClass(indications: 'bacterial infection treated with penicillin'),
        equals('Antimicrobial / Antibacterial'),
      );
      expect(
        OpenFdaSanitizer.resolveDrugClass(indications: 'fever and mild to moderate pain relief'),
        equals('Analgesic & Antipyretic'),
      );
      expect(
        OpenFdaSanitizer.resolveDrugClass(indications: 'bronchospasm in asthma with albuterol'),
        equals('Respiratory / Bronchodilator'),
      );
      expect(
        OpenFdaSanitizer.resolveDrugClass(indications: 'type 2 diabetes mellitus'),
        equals('Antidiabetic Agent'),
      );
    });

    test('Falls back to clean default if no match without therapeutic agent placeholder', () {
      final fallback = OpenFdaSanitizer.resolveDrugClass(
        pharmClassEpc: null,
        pharmClassCs: null,
        route: null,
        indications: null,
        genericName: null,
      );
      expect(fallback, equals('Regulated Pharmacotherapy'));
    });
  });

  group('OpenFdaSanitizer - resolveRoute and resolveRouteStyle Tests', () {
    test('Resolves routes from openFDA list or dosage form', () {
      expect(OpenFdaSanitizer.resolveRoute(['ORAL']), equals('ORAL'));
      expect(OpenFdaSanitizer.resolveRoute(['TOPICAL']), equals('TOPICAL'));
      expect(OpenFdaSanitizer.resolveRoute(['INTRAVENOUS']), equals('INJECTION'));
      expect(OpenFdaSanitizer.resolveRoute(['SUBCUTANEOUS']), equals('INJECTION'));
      expect(OpenFdaSanitizer.resolveRoute(['OPHTHALMIC']), equals('OPHTHALMIC'));
      expect(OpenFdaSanitizer.resolveRoute(['INHALATION']), equals('INHALATION'));
      expect(OpenFdaSanitizer.resolveRoute([], 'CAPSULE'), equals('ORAL'));
      expect(OpenFdaSanitizer.resolveRoute([], 'CREAM'), equals('TOPICAL'));
      expect(OpenFdaSanitizer.resolveRoute([], 'VIAL INJECTION'), equals('INJECTION'));
    });

    test('Returns distinct route style specifications', () {
      final oral = OpenFdaSanitizer.resolveRouteStyle('ORAL', false);
      expect(oral.icon, equals(Icons.medication_rounded));
      expect(oral.label, equals('Oral'));

      final topical = OpenFdaSanitizer.resolveRouteStyle('TOPICAL', false);
      expect(topical.icon, equals(Icons.water_drop_rounded));
      expect(topical.label, equals('Topical'));

      final injection = OpenFdaSanitizer.resolveRouteStyle('INJECTION', false);
      expect(injection.icon, equals(Icons.vaccines_rounded));
      expect(injection.label, equals('Injection'));

      final ophthalmic = OpenFdaSanitizer.resolveRouteStyle('OPHTHALMIC', false);
      expect(ophthalmic.icon, equals(Icons.visibility_rounded));
      expect(ophthalmic.label, equals('Ophthalmic'));

      final inhalation = OpenFdaSanitizer.resolveRouteStyle('INHALATION', false);
      expect(inhalation.icon, equals(Icons.air_rounded));
      expect(inhalation.label, equals('Inhalation'));
    });
  });

  group('OpenFdaSanitizer - resolveRegulatoryStatus Tests', () {
    test('Identifies Rx prescription medications with NDA application', () {
      final item = {
        'openfda': {
          'product_type': ['HUMAN PRESCRIPTION DRUG'],
          'application_number': ['NDA022406'],
        },
      };
      final status = OpenFdaSanitizer.resolveRegulatoryStatus(item);
      expect(status.isRx, isTrue);
      expect(status.isFdaApproved, isTrue);
      expect(status.isHomeopathic, isFalse);
      expect(status.regulatoryStatus, equals('Rx Only'));
    });

    test('Identifies OTC medications', () {
      final item = {
        'openfda': {
          'product_type': ['HUMAN OTC DRUG'],
          'application_number': ['ANDA075010'],
        },
      };
      final status = OpenFdaSanitizer.resolveRegulatoryStatus(item);
      expect(status.isRx, isFalse);
      expect(status.isFdaApproved, isTrue);
      expect(status.isHomeopathic, isFalse);
      expect(status.regulatoryStatus, equals('OTC'));
    });

    test('Identifies Homeopathic / Unverified records', () {
      final item = {
        'openfda': {
          'product_type': ['HOMEOPATHIC'],
        },
      };
      final status = OpenFdaSanitizer.resolveRegulatoryStatus(item);
      expect(status.isHomeopathic, isTrue);
      expect(status.isFdaApproved, isFalse);
      expect(status.regulatoryStatus, equals('Homeopathic / Unverified'));
    });
  });

  group('OpenFdaSanitizer - isCosmeticNoise Tests', () {
    test('Filters cosmetic hand soap and body wash records', () {
      final soap = {
        'openfda': {
          'brand_name': ['Antibacterial Foaming Hand Soap'],
          'substance_name': ['BENZALKONIUM CHLORIDE'],
        },
      };
      expect(OpenFdaSanitizer.isCosmeticNoise(soap), isTrue);

      final sunscreen = {
        'openfda': {
          'brand_name': ['Ultra Protect Sunscreen Lotion SPF 50'],
        },
      };
      expect(OpenFdaSanitizer.isCosmeticNoise(sunscreen), isTrue);
    });

    test('Allows cosmetic records when user explicitly searched for them', () {
      final soap = {
        'openfda': {
          'brand_name': ['Antibacterial Foaming Hand Soap'],
        },
      };
      expect(OpenFdaSanitizer.isCosmeticNoise(soap, query: 'hand soap'), isFalse);
    });

    test('Does not filter essential medicines', () {
      final amoxicillin = {
        'openfda': {
          'brand_name': ['Amoxicillin Trihydrate'],
          'product_type': ['HUMAN PRESCRIPTION DRUG'],
        },
      };
      expect(OpenFdaSanitizer.isCosmeticNoise(amoxicillin), isFalse);
    });
  });

  group('Medicine Model Integration Tests', () {
    test('Medicine model serializes and deserializes route and regulatory fields', () {
      const med = Medicine(
        id: 'test-1',
        name: 'Amoxicillin',
        type: 'Penicillin Antibacterial',
        description: 'Used for bacterial infections.',
        color: Colors.teal,
        icon: Icons.medication,
        details: [],
        isFdaApproved: true,
        route: 'ORAL',
        isRx: true,
        isHomeopathic: false,
        brandName: 'Amoxil',
        genericName: 'Amoxicillin',
      );

      final json = med.toJson();
      expect(json['route'], equals('ORAL'));
      expect(json['is_rx'], isTrue);
      expect(json['is_homeopathic'], isFalse);
      expect(json['brand_name'], equals('Amoxil'));
      expect(json['generic_name'], equals('Amoxicillin'));

      final restored = Medicine.fromJson(json);
      expect(restored.route, equals('ORAL'));
      expect(restored.isRx, isTrue);
      expect(restored.isHomeopathic, isFalse);
      expect(restored.brandName, equals('Amoxil'));
      expect(restored.genericName, equals('Amoxicillin'));
    });
  });

  group('MedicineSearchScreen Pinned Header & Route Badges Widget Test', () {
    testWidgets('Displays Pinned Search Bar, Category Chips, and route-aware cards', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MedicineSearchScreen(),
          ),
        ),
      );

      // Verify Pinned Header Elements
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search by brand or generic name'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Pain & fever'), findsOneWidget);
      expect(find.text('Antibiotics'), findsOneWidget);

      // Verify that "Scroll to Top" button is not visible initially
      expect(find.byTooltip('Scroll to top'), findsNothing);
    });
  });
}
