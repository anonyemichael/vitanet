import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/data/services/daily_med_service.dart';
import 'package:vitanet/data/services/drug_synonyms.dart';
import 'package:vitanet/features/resources/models/medicine.dart';
import 'package:vitanet/features/resources/screens/medicine_search_screen.dart';

void main() {
  group('DrugSynonymMapper Tests', () {
    test('Correctly maps international names to USAN/openFDA names', () {
      expect(DrugSynonymMapper.mapToFdaQuery('paracetamol'), equals('acetaminophen'));
      expect(DrugSynonymMapper.mapToFdaQuery('Paracetamol'), equals('acetaminophen'));
      expect(DrugSynonymMapper.mapToFdaQuery('salbutamol'), equals('albuterol'));
      expect(DrugSynonymMapper.mapToFdaQuery('adrenaline'), equals('epinephrine'));
      expect(DrugSynonymMapper.mapToFdaQuery('frusemide'), equals('furosemide'));
      expect(DrugSynonymMapper.mapToFdaQuery('ibuprofen'), equals('ibuprofen'));
      expect(DrugSynonymMapper.mapToFdaQuery('amoxicillin'), equals('amoxicillin'));
    });

    test('Returns search aliases containing both international and USAN terms', () {
      final paracetamolAliases = DrugSynonymMapper.getSearchAliases('paracetamol');
      expect(paracetamolAliases, contains('paracetamol'));
      expect(paracetamolAliases, contains('acetaminophen'));

      final acetaminophenAliases = DrugSynonymMapper.getSearchAliases('acetaminophen');
      expect(acetaminophenAliases, contains('acetaminophen'));
      expect(acetaminophenAliases, contains('paracetamol'));
    });

    test('Formats display title clearly with both names', () {
      expect(
        DrugSynonymMapper.formatDisplayTitle('Acetaminophen'),
        equals('Acetaminophen (Paracetamol)'),
      );
      expect(
        DrugSynonymMapper.formatDisplayTitle('Paracetamol'),
        equals('Acetaminophen (Paracetamol)'),
      );
      expect(
        DrugSynonymMapper.formatDisplayTitle('Salbutamol'),
        equals('Albuterol (Salbutamol)'),
      );
      expect(
        DrugSynonymMapper.formatDisplayTitle('Albuterol'),
        equals('Albuterol (Salbutamol)'),
      );
      expect(
        DrugSynonymMapper.formatDisplayTitle('Ibuprofen'),
        equals('Ibuprofen'),
      );
    });
  });

  group('MedicineCategoryQueries Tests', () {
    test('Maps categories to exact openFDA query strings', () {
      expect(
        MedicineCategoryQueries.getQueryForCategory('All'),
        equals('_exists_:openfda.brand_name'),
      );
      expect(
        MedicineCategoryQueries.getQueryForCategory('Pain & Fever'),
        equals('openfda.generic_name:("acetaminophen"+OR+"ibuprofen"+OR+"naproxen"+OR+"aspirin")'),
      );
      expect(
        MedicineCategoryQueries.getQueryForCategory('Antibiotics'),
        equals('openfda.generic_name:("amoxicillin"+OR+"azithromycin"+OR+"ciprofloxacin"+OR+"doxycycline")'),
      );
      expect(
        MedicineCategoryQueries.getQueryForCategory('Cardiovascular'),
        equals('openfda.generic_name:("lisinopril"+OR+"amlodipine"+OR+"atorvastatin"+OR+"metoprolol")'),
      );
    });

    test('Correctly classifies local fallback medicines by category', () {
      const paracetamol = Medicine(
        id: '1',
        name: 'Acetaminophen (Paracetamol)',
        type: 'Analgesic & Antipyretic',
        description: 'Pain and fever reduction',
        color: Colors.teal,
        icon: Icons.medication,
        details: [],
        isFdaApproved: true,
      );

      const amoxicillin = Medicine(
        id: '2',
        name: 'Amoxicillin',
        type: 'Penicillin Antibacterial',
        description: 'Bacterial infections',
        color: Colors.green,
        icon: Icons.healing,
        details: [],
        isFdaApproved: true,
      );

      const lisinopril = Medicine(
        id: '3',
        name: 'Lisinopril',
        type: 'ACE Inhibitor (Cardiovascular)',
        description: 'Hypertension and heart failure',
        color: Colors.red,
        icon: Icons.monitor_heart,
        details: [],
        isFdaApproved: true,
      );

      expect(MedicineCategoryQueries.matchesCategory(paracetamol, 'Pain & Fever'), isTrue);
      expect(MedicineCategoryQueries.matchesCategory(paracetamol, 'Antibiotics'), isFalse);
      expect(MedicineCategoryQueries.matchesCategory(paracetamol, 'All'), isTrue);

      expect(MedicineCategoryQueries.matchesCategory(amoxicillin, 'Antibiotics'), isTrue);
      expect(MedicineCategoryQueries.matchesCategory(amoxicillin, 'Cardiovascular'), isFalse);

      expect(MedicineCategoryQueries.matchesCategory(lisinopril, 'Cardiovascular'), isTrue);
      expect(MedicineCategoryQueries.matchesCategory(lisinopril, 'Pain & Fever'), isFalse);
    });
  });

  group('Medicines Catalog File Verification', () {
    test('Verifies medicines_catalog.json has top 20 essential verified monographs', () {
      final file = File('assets/health_library_data/medicines/medicines_catalog.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final List<dynamic> list = json.decode(content);
      expect(list.length, equals(20));

      final medicines = list.map((j) => Medicine.fromJson(j as Map<String, dynamic>)).toList();
      expect(medicines.length, equals(20));

      // Verify essential verified monographs exist
      final names = medicines.map((m) => m.name.toLowerCase()).toList();
      expect(names.any((n) => n.contains('acetaminophen') || n.contains('paracetamol')), isTrue);
      expect(names.any((n) => n.contains('ibuprofen')), isTrue);
      expect(names.any((n) => n.contains('amoxicillin')), isTrue);
      expect(names.any((n) => n.contains('lisinopril')), isTrue);
      expect(names.any((n) => n.contains('omeprazole')), isTrue);
      expect(names.any((n) => n.contains('metformin')), isTrue);
      expect(names.any((n) => n.contains('azithromycin')), isTrue);
      expect(names.any((n) => n.contains('loratadine')), isTrue);
      expect(names.any((n) => n.contains('albuterol') || n.contains('salbutamol')), isTrue);

      // Verify all 20 have official NIH DailyMed SPL packaging photo URLs (not stock Unsplash)
      for (final med in medicines) {
        expect(med.heroImageUrl, isNotNull);
        expect(med.heroImageUrl, contains('dailymed.nlm.nih.gov'));
        expect(med.splSetId, isNotNull);
        expect(med.splSetId!.length, greaterThan(10));
      }
    });
  });

  group('MedicineSearchScreen Widget Tests', () {
    testWidgets('Renders Medicines screen with top bar, class chips, and never shows 0 Found on initial load', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MedicineSearchScreen(),
          ),
        ),
      );

      // Verify the top bar title and the AI interactions shortcut
      expect(find.text('Medicines'), findsOneWidget);
      expect(find.text('Interactions'), findsOneWidget);
      expect(find.text('Search by brand or generic name'), findsOneWidget);

      // Verify therapeutic class chips are present with full unclipped text
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Pain & fever'), findsOneWidget);
      expect(find.text('Antibiotics'), findsOneWidget);
      expect(find.text('Heart & BP'), findsOneWidget);
      // Verify that "0 Found / No medications match your filter" is NEVER shown on initial open
      expect(find.text('0 Found'), findsNothing);
      expect(find.text('No medications match your filter.'), findsNothing);
    });
  });

  group('DailyMedService & Real Image Resolution Tests', () {
    test('Caches and retrieves SPL media URLs synchronously', () {
      final service = DailyMedService.instance;
      const testSetId = 'test-setid-12345';
      const testUrl = 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=test-setid-12345&name=box.jpg';

      expect(service.getCachedImageUrl(splSetId: testSetId), isNull);

      service.cacheImageUrl(
        splSetId: testSetId,
        drugName: 'Amoxicillin (500mg)',
        url: testUrl,
      );

      expect(service.getCachedImageUrl(splSetId: testSetId), equals(testUrl));
      expect(service.getCachedImageUrl(drugName: 'amoxicillin'), equals(testUrl));
    });

    test('Medicine copyWith supports splSetId and heroImageUrl', () {
      const med = Medicine(
        id: 'test_med',
        name: 'Test Drug',
        type: 'Analgesic',
        description: 'Test description',
        color: Color(0xFF0D9488),
        icon: Icons.medication_rounded,
        isFdaApproved: true,
        details: [],
      );

      expect(med.heroImageUrl, isNull);
      expect(med.splSetId, isNull);

      final updated = med.copyWith(
        heroImageUrl: 'https://dailymed.nlm.nih.gov/test.jpg',
        splSetId: 'setid-999',
      );

      expect(updated.heroImageUrl, equals('https://dailymed.nlm.nih.gov/test.jpg'));
      expect(updated.splSetId, equals('setid-999'));
      expect(updated.name, equals('Test Drug'));
    });
  });
}
