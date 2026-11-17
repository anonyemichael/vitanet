import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/resources/models/health_article.dart';
import 'package:vitanet/features/resources/screens/general_health_library_screen.dart';
import 'package:vitanet/features/resources/widgets/resource_media.dart';

void main() {
  // the real library copy shipped with the backend (180 articles; MedlinePlus ones have no picture)
  final raw = json.decode(File('vitanet-backend/app/services/library_seed.json').readAsStringSync()) as Map;
  final articles = [for (final j in raw['articles'] as List) HealthArticle.fromJson(Map<String, dynamic>.from(j))];
  final noImage = articles.where((a) => a.imageUrls.isEmpty).toList();

  test('Articles without a picture no longer all share one photo per topic', () {
    expect(noImage.length, greaterThan(50));
    final now = noImage.map((a) => articlePhoto(a).asset).toSet();
    final before = noImage.map((a) => VnTopics.photoForArticle(a.title, a.category)).toSet();
    // ignore: avoid_print
    print('distinct photos for ${noImage.length} articles: before ${before.length}, now ${now.length}');
    expect(now.length, greaterThan(before.length));
    expect(now.length, greaterThanOrEqualTo(20));
    final infections = noImage.where((a) => a.category == 'Infections').map((a) => articlePhoto(a).asset).toSet();
    expect(infections.length, greaterThanOrEqualTo(4));
  });

  test('Same article, same photo every time; own picture wins; credit is read', () {
    final a = noImage.first;
    expect(articlePhoto(a).asset, articlePhoto(a).asset);
    final withOwn = HealthArticle.fromJson({
      'id': 'mp-x', 'title': 'Malaria', 'category': 'Infections', 'read_time': '1 min read',
      'image_urls': ['https://images.pexels.com/photos/1/large.jpg'],
      'image_credit': 'Photo: Ama / Pexels', 'image_credit_url': 'https://www.pexels.com/photo/1/',
    });
    expect(articlePhoto(withOwn).url, 'https://images.pexels.com/photos/1/large.jpg');
    expect(withOwn.imageCredit, 'Photo: Ama / Pexels');
  });
}
