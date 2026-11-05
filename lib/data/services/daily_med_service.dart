import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitanet/core/network/backend.dart';
import 'package:vitanet/features/resources/models/medicine.dart';

/// Service for resolving real pharmaceutical package and pill photographs
/// directly from the NIH National Library of Medicine (DailyMed REST API v2).
///
/// DailyMed hosts the official Structured Product Labeling (SPL) media submitted
/// by manufacturers to the U.S. FDA, providing genuine, non-synthetic photos of
/// actual medication packaging, bottles, blister packs, and pills.
class DailyMedService {
  DailyMedService._internal({http.Client? client}) : _client = client ?? http.Client() {
    _ensureInit();
  }

  static final DailyMedService instance = DailyMedService._internal();

  final http.Client _client;
  SharedPreferences? _prefs;
  bool _isInit = false;

  /// Cache mapping `setid:<id>` or `name:<name>` to resolved image URL
  final Map<String, String> _imageCache = {};

  /// Negative cache to avoid repeated failed lookups
  final Set<String> _negativeCache = {};

  /// In-flight requests deduplication map
  final Map<String, Future<String?>> _inFlight = {};

  void _ensureInit() {
    init().catchError((_) {});
  }

  /// Initializes persistent disk cache from SharedPreferences
  Future<void> init() async {
    if (_isInit) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      final keys = _prefs?.getKeys() ?? {};
      for (final k in keys) {
        if (k.startsWith('vitanet_spl_img_')) {
          final mappedKey = k.substring('vitanet_spl_img_'.length);
          final url = _prefs?.getString(k);
          if (url != null && url.isNotEmpty) {
            _imageCache[mappedKey] = url;
          }
        }
      }
      _isInit = true;
    } catch (e) {
      debugPrint('DailyMedService init error: $e');
    }
  }

  /// Returns a web-safe, CORS-friendly URL for DailyMed images.
  ///
  /// DailyMed server omits `Access-Control-Allow-Origin: *` headers, causing
  /// HTML5 CanvasKit to reject rendering on web. We route DailyMed URLs through
  /// the VitaNet server-side `/media/proxy` caching proxy on web.
  static String safeImageUrl(String url) {
    if (url.isEmpty) return url;
    if (kIsWeb && (url.contains('dailymed.nlm.nih.gov') || url.contains('nlm.nih.gov'))) {
      return BackendConfig.uri('media/proxy?url=${Uri.encodeComponent(url)}').toString();
    }
    return url;
  }

  /// Synchronous cache lookup for instant widget rendering
  String? getCachedImageUrl({String? splSetId, String? drugName}) {
    if (splSetId != null && splSetId.isNotEmpty) {
      final key = 'setid:$splSetId';
      final cached = _imageCache[key] ?? _checkDiskSync(key);
      if (cached != null) return safeImageUrl(cached);
    }
    if (drugName != null && drugName.isNotEmpty) {
      final key = 'name:${_normalizeDrugName(drugName)}';
      final cached = _imageCache[key] ?? _checkDiskSync(key);
      if (cached != null) return safeImageUrl(cached);
    }
    return null;
  }

  String? _checkDiskSync(String key) {
    if (_prefs == null) return null;
    final val = _prefs!.getString('vitanet_spl_img_$key');
    if (val != null && val.isNotEmpty) {
      _imageCache[key] = val;
      return val;
    }
    return null;
  }

  /// Manually populate the cache (e.g. for preloaded catalog medicines)
  void cacheImageUrl({String? splSetId, String? drugName, required String url}) {
    if (url.isEmpty) return;
    if (splSetId != null && splSetId.isNotEmpty) {
      final key = 'setid:$splSetId';
      _imageCache[key] = url;
      _saveToDisk(key, url);
    }
    if (drugName != null && drugName.isNotEmpty) {
      final key = 'name:${_normalizeDrugName(drugName)}';
      _imageCache[key] = url;
      _saveToDisk(key, url);
    }
  }

  void _saveToDisk(String key, String url) {
    if (_prefs != null) {
      _prefs!.setString('vitanet_spl_img_$key', url);
    } else {
      SharedPreferences.getInstance().then((p) {
        _prefs = p;
        p.setString('vitanet_spl_img_$key', url);
      }).catchError((_) {});
    }
  }

  /// Fire-and-forget prefetch for a medicine
  void prefetch(Medicine medicine) {
    if (medicine.heroImageUrl != null && medicine.heroImageUrl!.isNotEmpty) {
      cacheImageUrl(
        splSetId: medicine.splSetId,
        drugName: medicine.genericName ?? medicine.name,
        url: medicine.heroImageUrl!,
      );
      return;
    }
    resolveMedicineImageUrl(
      splSetId: medicine.splSetId,
      drugName: medicine.genericName ?? medicine.name,
    ).catchError((_) => null);
  }

  /// Asynchronously resolves the authentic manufacturer photograph URL for a drug
  /// using NIH DailyMed REST API v2.
  Future<String?> resolveMedicineImageUrl({String? splSetId, String? drugName}) async {
    final cleanSetId = splSetId?.trim();
    final cleanName = drugName != null ? _normalizeDrugName(drugName) : null;

    final dedupeKey = cleanSetId != null && cleanSetId.isNotEmpty
        ? 'setid:$cleanSetId'
        : (cleanName != null ? 'name:$cleanName' : null);

    if (dedupeKey == null) return null;

    // 1. Check in-memory cache
    if (_imageCache.containsKey(dedupeKey)) {
      return _imageCache[dedupeKey];
    }
    if (_negativeCache.contains(dedupeKey)) {
      return null;
    }

    // 2. Return in-flight future if already fetching
    if (_inFlight.containsKey(dedupeKey)) {
      return _inFlight[dedupeKey];
    }

    final future = _executeResolve(cleanSetId, cleanName, dedupeKey);
    _inFlight[dedupeKey] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _inFlight.remove(dedupeKey);
    }
  }

  Future<String?> _executeResolve(String? setId, String? drugName, String dedupeKey) async {
    try {
      String? targetSetId = setId;

      // If we don't have an SPL setid, search DailyMed by drug name
      if (targetSetId == null || targetSetId.isEmpty) {
        if (drugName == null || drugName.isEmpty) {
          _negativeCache.add(dedupeKey);
          return null;
        }
        targetSetId = await _findSplSetIdByName(drugName);
      }

      if (targetSetId == null || targetSetId.isEmpty) {
        _negativeCache.add(dedupeKey);
        return null;
      }

      // Query DailyMed SPL media endpoint
      final imageUrl = await _fetchMediaForSetId(targetSetId);

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final safe = safeImageUrl(imageUrl);
        cacheImageUrl(splSetId: targetSetId, drugName: drugName, url: safe);
        return safe;
      } else {
        _negativeCache.add(dedupeKey);
        return null;
      }
    } catch (e) {
      debugPrint('DailyMed resolve exception for $dedupeKey: $e');
      return null;
    }
  }

  /// Queries DailyMed search API to get the primary SPL setid for a drug name
  Future<String?> _findSplSetIdByName(String drugName) async {
    try {
      final encoded = Uri.encodeComponent(drugName);
      final uri = Uri.parse(
        'https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?drug_name=$encoded&page=1&pagesize=1',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data'] as List?;
        if (list != null && list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          return first['setid']?.toString();
        }
      }
    } catch (e) {
      debugPrint('DailyMed findSplSetIdByName error: $e');
    }
    return null;
  }

  /// Fetches media from DailyMed for a known SPL setid and selects the best package/pill photo
  Future<String?> _fetchMediaForSetId(String setId) async {
    try {
      final uri = Uri.parse(
        'https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/$setId/media.json',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final mediaList = data['data']?['media'] as List?;
        if (mediaList == null || mediaList.isEmpty) return null;

        return _pickBestPhoto(mediaList, setId);
      }
    } catch (e) {
      debugPrint('DailyMed _fetchMediaForSetId error: $e');
    }
    return null;
  }

  /// Filters and ranks media items to prioritize actual drug package/pill photos
  /// and exclude chemical structure diagrams
  String? _pickBestPhoto(List<dynamic> mediaList, String setId) {
    final imageItems = <Map<String, dynamic>>[];

    for (final item in mediaList) {
      if (item is Map<String, dynamic>) {
        final mime = (item['mime_type']?.toString() ?? '').toLowerCase();
        if (mime.startsWith('image/')) {
          imageItems.add(item);
        }
      }
    }

    if (imageItems.isEmpty) return null;

    // Filter out chemical formula/structure diagrams
    final nonStructures = imageItems.where((item) {
      final name = (item['name']?.toString() ?? '').toLowerCase();
      return !name.contains('structure') &&
          !name.contains('formula') &&
          !name.contains('chemical') &&
          !name.contains('chem');
    }).toList();

    final candidates = nonStructures.isNotEmpty ? nonStructures : imageItems;

    // Preferred keywords for product packaging, bottles, and pills
    final preferredKeywords = [
      'package',
      'carton',
      'bottle',
      'box',
      'label',
      'pill',
      'tablet',
      'capsule',
      'blister',
      'foil',
      'pic',
      'photo',
      'figure',
      'image',
    ];

    Map<String, dynamic>? bestMatch;
    for (final candidate in candidates) {
      final name = (candidate['name']?.toString() ?? '').toLowerCase();
      if (preferredKeywords.any((kw) => name.contains(kw))) {
        bestMatch = candidate;
        break;
      }
    }

    bestMatch ??= candidates.first;

    // Check if url is directly provided, or construct from setId and filename
    final rawUrl = bestMatch['url']?.toString();
    if (rawUrl != null && rawUrl.isNotEmpty) {
      return rawUrl;
    }

    final filename = bestMatch['name']?.toString();
    if (filename != null && filename.isNotEmpty) {
      return 'https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=$setId&name=$filename';
    }

    return null;
  }

  String _normalizeDrugName(String raw) {
    var s = raw.toLowerCase().trim();
    // Strip parentheticals like "Acetaminophen (Paracetamol)" -> "acetaminophen"
    if (s.contains('(')) {
      s = s.split('(').first.trim();
    }
    // Strip dosage forms like "amoxicillin 500mg" or "tablet"
    s = s.replaceAll(RegExp(r'\b\d+\s*(?:mg|mcg|ml|g)\b'), '').trim();
    s = s.replaceAll(RegExp(r'[^a-z0-9\s-]'), '').trim();
    return s;
  }
}
