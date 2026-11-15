
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() {
  try {
    final file = File('assets/health_library_data/articles/articles_catalog.json');
    if (file.existsSync()) {
      final articlesJsonString = file.readAsStringSync();
      final List<dynamic> articlesJsonList = json.decode(articlesJsonString);
      print('Articles list length: ${articlesJsonList.length}');
    }
  } catch (e) {
    print('Error parsing articles: $e');
  }
}

