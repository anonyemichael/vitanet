import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vitanet/core/network/backend.dart';
import 'package:vitanet/data/services/clinical_articles_data.dart';

import '../models/health_article.dart';

class LibraryPage {
  final List<HealthArticle> articles;
  final int? nextCursor;
  final bool fromBackend;

  const LibraryPage(this.articles, this.nextCursor, {this.fromBackend = true});

  bool get hasMore => nextCursor != null;
}

/// Plain-language health articles from the VitaNet backend (`/library/feed`, `/library/search`): MedlinePlus
/// (U.S. National Library of Medicine) and MyHealthfinder (U.S. Office of Disease Prevention and Health
/// Promotion), collected and kept on the server. When the backend cannot be reached the app's own built-in
/// articles are shown, filtered by the same topic or words.
class HealthLibraryService {
  HealthLibraryService({http.Client? client}) : _client = client;

  final http.Client? _client;
  static final Map<String, LibraryPage> _memory = {};

  /// Topic chips (label shown = topic name the backend understands; 'For you' = everything).
  static const topics = <String>[
    'For you',
    'Infections',
    'Heart',
    'Women & children',
    'Mental health',
    'Nutrition',
    'Chronic conditions',
    'First aid & safety',
    'Breathing',
    'Fitness',
  ];

  Future<LibraryPage> feed({String topic = 'For you', int cursor = 0, int limit = 12}) =>
      _get('library/feed', {if (topic != 'For you') 'topic': topic, 'cursor': '$cursor', 'limit': '$limit'},
          fallback: () => _builtIn(topic: topic, cursor: cursor, limit: limit));

  Future<LibraryPage> search(String query, {int cursor = 0, int limit = 12}) =>
      _get('library/search', {'q': query, 'cursor': '$cursor', 'limit': '$limit'},
          fallback: () => _builtIn(query: query, cursor: cursor, limit: limit));

  Future<LibraryPage> _get(String path, Map<String, String> params, {required LibraryPage Function() fallback}) async {
    final uri = BackendConfig.uri(path).replace(queryParameters: params);
    final key = uri.toString();
    final hit = _memory[key];
    if (hit != null) return hit;
    try {
      final c = _client;
      final res = await (c != null ? c.get(uri) : http.get(uri)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('library ${res.statusCode}');
      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final page = LibraryPage(
        [
          for (final j in (data['articles'] as List? ?? const []))
            if (j is Map) HealthArticle.fromJson(Map<String, dynamic>.from(j)),
        ],
        (data['next_cursor'] as num?)?.toInt(),
      );
      if (_memory.length > 200) _memory.clear();
      _memory[key] = page;
      return page;
    } catch (e) {
      debugPrint('Health library: backend unavailable, using built-in articles ($e)');
      return fallback();
    }
  }

  static LibraryPage _builtIn({String topic = 'For you', String query = '', int cursor = 0, int limit = 12}) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    final t = topic.toLowerCase().split(' ').first;
    final pool = ClinicalArticlesRepository.verifiedArticles.where((a) {
      final text = '${a.title} ${a.category} ${a.excerpt}'.toLowerCase();
      if (words.isNotEmpty) return words.every(text.contains);
      return topic == 'For you' || text.contains(t);
    }).toList();
    final page = pool.skip(cursor).take(limit).toList();
    return LibraryPage(page, cursor + limit < pool.length ? cursor + limit : null, fromBackend: false);
  }
}
