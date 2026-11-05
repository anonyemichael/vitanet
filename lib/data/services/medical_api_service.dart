import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vitanet/features/resources/models/medicine.dart';
import 'package:vitanet/features/resources/models/health_article.dart';
import 'daily_med_service.dart';
import 'drug_synonyms.dart';
import 'openfda_sanitizer.dart';

/// Service for communicating with live open medical APIs:
/// - openFDA (Drug labels, active ingredients, warnings, indications)
/// - Europe PMC / PubMed (Biomedical research, clinical discoveries, abstracts)
class MedicalApiService {
  final http.Client _client;

  MedicalApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Queries openFDA Drug Label API for medication details
  Future<List<Medicine>> searchOpenFdaMedicines(String query, {int limit = 10}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final String searchParam;
      final bool isStructured = cleanQuery.contains('openfda.') || cleanQuery.contains('_exists_:');

      if (isStructured) {
        // Structured category query: preserve openFDA query syntax and exclude cosmetic noise
        var param = cleanQuery.replaceAll(' ', '+').replaceAll('"', '%22');
        if (!param.contains('product_type')) {
          param = '$param+AND+NOT+openfda.product_type:%22COSMETIC%22';
        }
        searchParam = param;
      } else {
        // Map international synonym (e.g. paracetamol -> acetaminophen)
        final mapped = DrugSynonymMapper.mapToFdaQuery(cleanQuery);
        final encoded = Uri.encodeComponent(mapped);
        searchParam = '(openfda.brand_name:"$encoded"+OR+openfda.generic_name:"$encoded"+OR+openfda.substance_name:"$encoded")+AND+NOT+openfda.product_type:%22COSMETIC%22';
      }

      final url = Uri.parse(
        'https://api.fda.gov/drug/label.json?search=$searchParam&limit=$limit',
      );

      final response = await _client.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final list = results
              .where((r) => !OpenFdaSanitizer.isCosmeticNoise(r as Map<String, dynamic>, query: cleanQuery))
              .map((r) => _parseFdaDrug(r as Map<String, dynamic>))
              .toList();
          for (final med in list) {
            DailyMedService.instance.prefetch(med);
          }
          return list;
        }
      } else if (response.statusCode == 404 && !isStructured) {
        // Fallback: broaden search without exact quotes
        final mapped = DrugSynonymMapper.mapToFdaQuery(cleanQuery);
        final encoded = Uri.encodeComponent(mapped);
        final broadUrl = Uri.parse(
          'https://api.fda.gov/drug/label.json?search=$encoded+AND+NOT+openfda.product_type:%22COSMETIC%22&limit=$limit',
        );
        final broadResp = await _client.get(broadUrl).timeout(const Duration(seconds: 6));
        if (broadResp.statusCode == 200) {
          final broadData = json.decode(broadResp.body);
          final broadResults = broadData['results'] as List?;
          if (broadResults != null) {
            final broadList = broadResults
                .where((r) => !OpenFdaSanitizer.isCosmeticNoise(r as Map<String, dynamic>, query: cleanQuery))
                .map((r) => _parseFdaDrug(r as Map<String, dynamic>))
                .toList();
            for (final med in broadList) {
              DailyMedService.instance.prefetch(med);
            }
            return broadList;
          }
        }
      }
    } catch (e) {
      debugPrint('openFDA search exception: $e');
    }
    return [];
  }

  Medicine _parseFdaDrug(Map<String, dynamic> item) {
    final openfda = item['openfda'] as Map<String, dynamic>? ?? {};
    final brandNames = openfda['brand_name'] as List?;
    final genericNames = openfda['generic_name'] as List?;
    final substanceNames = openfda['substance_name'] as List?;

    final rawBrand = (brandNames != null && brandNames.isNotEmpty) ? brandNames.first.toString() : '';
    final rawGeneric = (genericNames != null && genericNames.isNotEmpty) ? genericNames.first.toString() : '';
    final rawSubstance = (substanceNames != null && substanceNames.isNotEmpty) ? substanceNames.first.toString() : '';

    // 1. Smart Title & Subtitle Normalization
    final titles = OpenFdaSanitizer.formatDrugTitles(
      rawBrand: rawBrand,
      rawGeneric: rawGeneric,
      substanceName: rawSubstance,
    );

    // 2. Administration Route & Clinical Styling
    final routes = openfda['route'] as List?;
    final dosageForm = (openfda['dosage_form'] as List?)?.firstOrNull?.toString();
    final route = OpenFdaSanitizer.resolveRoute(routes, dosageForm);
    final routeStyle = OpenFdaSanitizer.resolveRouteStyle(route, false);

    // 3. Clinical Indications & Descriptions (Sanitized of raw SPL headers like "1 INDICATIONS AND USAGE")
    final indications = item['indications_and_usage'] as List?;
    final purpose = item['purpose'] as List?;
    final rawIndication = (indications != null && indications.isNotEmpty)
        ? indications.first.toString()
        : ((purpose != null && purpose.isNotEmpty) ? purpose.first.toString() : '');

    final cleanDesc = OpenFdaSanitizer.cleanIndication(rawIndication, maxChars: 220);

    // 4. Eliminate "(Therapeutic Agent)" fallback - infer precise clinical class
    final resolvedClass = OpenFdaSanitizer.resolveDrugClass(
      pharmClassEpc: (openfda['pharm_class_epc'] as List?)?.firstOrNull?.toString(),
      pharmClassCs: (openfda['pharm_class_cs'] as List?)?.firstOrNull?.toString(),
      route: route,
      indications: rawIndication,
      genericName: titles.isGenericPrimary ? titles.secondarySubtitle : titles.primaryTitle,
    );

    // Clean composite subtitle
    final String subtitleType;
    if (titles.secondarySubtitle.isNotEmpty && titles.secondarySubtitle != titles.primaryTitle) {
      subtitleType = '${titles.secondarySubtitle} • $resolvedClass';
    } else {
      subtitleType = resolvedClass;
    }

    // 5. Regulatory Status (Rx Only vs OTC, FDA Approved vs Homeopathic/Unverified)
    final regStatus = OpenFdaSanitizer.resolveRegulatoryStatus(item);

    // 6. Structured Clinical Accordions
    final warnings = item['warnings'] as List? ?? item['warnings_and_cautions'] as List?;
    final dosage = item['dosage_and_administration'] as List?;
    final activeIng = item['active_ingredient'] as List?;

    final accordionDetails = <MedicineAccordionItem>[];

    if (activeIng != null && activeIng.isNotEmpty) {
      accordionDetails.add(MedicineAccordionItem(
        title: 'Active Ingredients',
        content: OpenFdaSanitizer.cleanIndication(activeIng.first.toString(), maxChars: 600),
        icon: Icons.science_rounded,
      ));
    }

    if (indications != null && indications.isNotEmpty) {
      accordionDetails.add(MedicineAccordionItem(
        title: 'Indications & Clinical Usage',
        content: OpenFdaSanitizer.cleanIndication(indications.first.toString(), maxChars: 1200),
        icon: Icons.info_outline_rounded,
      ));
    }

    if (dosage != null && dosage.isNotEmpty) {
      accordionDetails.add(MedicineAccordionItem(
        title: 'Dosage & Administration',
        content: OpenFdaSanitizer.cleanIndication(dosage.first.toString(), maxChars: 1200),
        icon: Icons.medication_rounded,
      ));
    }

    if (warnings != null && warnings.isNotEmpty) {
      accordionDetails.add(MedicineAccordionItem(
        title: 'Warnings & Precautions',
        content: OpenFdaSanitizer.cleanIndication(warnings.first.toString(), maxChars: 1200),
        icon: Icons.warning_amber_rounded,
      ));
    }

    // 7. Structured Product Labeling (SPL) set_id for real manufacturer packaging photos
    final rawSplSetId = item['set_id']?.toString() ??
        (openfda['spl_set_id'] as List?)?.firstOrNull?.toString();
    final genericOrPrimary = titles.isGenericPrimary ? titles.primaryTitle : titles.secondarySubtitle;
    final cachedHeroUrl = DailyMedService.instance.getCachedImageUrl(
      splSetId: rawSplSetId,
      drugName: genericOrPrimary.isNotEmpty ? genericOrPrimary : titles.primaryTitle,
    );

    return Medicine(
      id: 'fda_${titles.primaryTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      name: titles.primaryTitle,
      type: subtitleType,
      description: cleanDesc,
      color: routeStyle.iconColor,
      icon: routeStyle.icon,
      details: accordionDetails,
      isFdaApproved: regStatus.isFdaApproved,
      route: route,
      isRx: regStatus.isRx,
      isHomeopathic: regStatus.isHomeopathic,
      brandName: titles.isGenericPrimary ? titles.secondarySubtitle : titles.primaryTitle,
      genericName: titles.isGenericPrimary ? titles.primaryTitle : titles.secondarySubtitle,
      heroImageUrl: cachedHeroUrl,
      relatedVideoId: null,
      splSetId: rawSplSetId,
    );
  }

  /// Queries Europe PMC REST API for peer-reviewed medical discoveries and articles
  Future<List<HealthArticle>> searchEuropePmcArticles(String query, {int limit = 6}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final encoded = Uri.encodeComponent('$cleanQuery AND (has_abstract:y)');
      final url = Uri.parse(
        'https://europepmc.org/RestfulWebService/pubmed/search?query=$encoded&resultType=core&pageSize=$limit&format=json',
      );

      final response = await _client.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final resultList = data['resultList']?['result'] as List?;
        if (resultList != null && resultList.isNotEmpty) {
          return resultList.map((r) => _parseEuropePmcArticle(r, cleanQuery)).toList();
        }
      }
    } catch (e) {
      debugPrint('Europe PMC search exception: $e');
    }
    return [];
  }

  HealthArticle _parseEuropePmcArticle(Map<String, dynamic> item, String queryCategory) {
    final id = item['id']?.toString() ?? UniqueKey().toString();
    final rawTitle = item['title']?.toString() ?? 'Biomedical Discovery';
    final cleanTitle = rawTitle.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    final abstractText = item['abstractText']?.toString() ?? 'Research findings published in biomedical life sciences.';
    final cleanAbstract = _cleanClinicalText(abstractText);

    final journal = item['journalInfo']?['journal']?['title']?.toString() ?? 'Europe PMC Open Access';
    final pubYear = item['pubYear']?.toString() ?? 'Recent';

    // Key Takeaways extracted from abstract or structured sections
    final takeaways = <String>[];
    final sentences = cleanAbstract.split(RegExp(r'\.\s+'));
    for (var s in sentences) {
      if (s.trim().isNotEmpty && takeaways.length < 3) {
        takeaways.add(s.trim());
      }
    }
    if (takeaways.isEmpty) {
      takeaways.add('Peer-reviewed biomedical findings from $journal ($pubYear).');
    }

    final sections = <ArticleSection>[
      ArticleSection(
        heading: 'Clinical Abstract & Study Overview',
        content: cleanAbstract,
      ),
      ArticleSection(
        heading: 'Source Verification',
        content: 'Published in $journal ($pubYear). Verified peer-reviewed literature indexed by NCBI / Europe PMC.',
      ),
    ];

    // High quality imagery tailored to medical topics
    final imageList = _getCuratedPhotosForCategory(queryCategory);

    return HealthArticle(
      id: 'epmc_$id',
      title: cleanTitle,
      category: _normalizeCategory(queryCategory),
      verifiedSource: '$journal ($pubYear)',
      readTime: '4 min read',
      difficultyLevel: 'Intermediate',
      icon: Icons.science_rounded,
      color: const Color(0xFF06B6D4),
      imageUrls: imageList,
      excerpt: _cleanClinicalText(cleanAbstract, maxChars: 180),
      sections: sections,
      keyTakeaways: takeaways,
      mythVsFact: MythVsFact(
        myth: 'Clinical trial outcomes always match early observational claims.',
        fact: 'Rigorous peer-reviewed double-blind studies provide the definitive medical standard.',
      ),
      interactiveQuizzes: const [],
      relatedVideoId: null,
    );
  }

  String _cleanClinicalText(String text, {int? maxChars}) {
    var cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (maxChars != null && cleaned.length > maxChars) {
      cleaned = '${cleaned.substring(0, maxChars)}...';
    }
    return cleaned;
  }

  String _normalizeCategory(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('nutrit') || lower.contains('diet')) return 'Nutrition';
    if (lower.contains('mental') || lower.contains('brain') || lower.contains('anxiet')) return 'Mental Health';
    if (lower.contains('sleep')) return 'Sleep';
    if (lower.contains('cardio') || lower.contains('heart')) return 'Heart Health';
    if (lower.contains('fit') || lower.contains('exercise')) return 'Fitness';
    return 'Medical Science';
  }

  List<String> _getCuratedPhotosForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('nutrit')) {
      return ['https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=800&q=80'];
    }
    if (lower.contains('mental')) {
      return ['https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=800&q=80'];
    }
    if (lower.contains('sleep')) {
      return ['https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?auto=format&fit=crop&w=800&q=80'];
    }
    if (lower.contains('heart') || lower.contains('cardio')) {
      return ['https://images.unsplash.com/photo-1505751172876-fa1923c5c528?auto=format&fit=crop&w=800&q=80'];
    }
    return ['https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=800&q=80'];
  }
}
