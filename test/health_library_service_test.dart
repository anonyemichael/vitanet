import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vitanet/features/resources/screens/general_health_library_screen.dart';
import 'package:vitanet/features/resources/services/health_library_service.dart';

void main() {
  // test/fixtures_library_page.json: a real backend answer (two articles from the copy shipped with the backend)
  test('Reads real library articles from the backend, with sections, source and link', () async {
    final asked = <Uri>[];
    final svc = HealthLibraryService(client: MockClient((req) async {
      asked.add(req.url);
      return http.Response.bytes(File('test/fixtures_library_page.json').readAsBytesSync(), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final res = await svc.feed(topic: 'Infections', cursor: 0);
    expect(asked.single.path, endsWith('library/feed'));
    expect(asked.single.queryParameters, containsPair('topic', 'Infections'));
    final malaria = res.articles.firstWhere((a) => a.id == 'mp-malaria');
    expect(malaria.title, 'Malaria');
    expect(malaria.sections, isNotEmpty);
    expect(malaria.sourceUrl, startsWith('https://medlineplus.gov/'));
    expect(cleanArticleSource(malaria), 'MedlinePlus');
    final heart = res.articles.firstWhere((a) => a.id == 'hf-25');
    expect(heart.imageUrls, isNotEmpty);
    expect(heart.sections.last.heading, 'In Ghana');
    expect(heart.excerpt.endsWith(':'), isFalse);
    expect(res.nextCursor, 2);
    expect(res.fromBackend, isTrue);

    await svc.feed(topic: 'Infections', cursor: 0); // same page again: from memory
    expect(asked, hasLength(1));
  });

  test('Search goes to /library/search; "For you" sends no topic', () async {
    final asked = <Uri>[];
    final svc = HealthLibraryService(client: MockClient((req) async {
      asked.add(req.url);
      return http.Response('{"articles": [], "next_cursor": null}', 200);
    }));
    await svc.search('typhoid fever');
    await svc.feed(topic: 'For you', cursor: 24);
    expect(asked[0].path, endsWith('library/search'));
    expect(asked[0].queryParameters['q'], 'typhoid fever');
    expect(asked[1].queryParameters.containsKey('topic'), isFalse);
    expect(asked[1].queryParameters['cursor'], '24');
  });

  test('Backend down: built-in articles, no error', () async {
    final svc = HealthLibraryService(client: MockClient((req) async => http.Response('down', 503)));
    final res = await svc.feed(topic: 'For you', cursor: 1000);
    expect(res.fromBackend, isFalse);
    final all = await HealthLibraryService(client: MockClient((req) async => throw const SocketException('offline')))
        .feed(topic: 'For you');
    expect(all.articles, isNotEmpty);
    expect(all.fromBackend, isFalse);
  });
}
