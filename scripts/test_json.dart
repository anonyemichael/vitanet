
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  try {
    final articlesJsonString = File('C:/Users/atubt/OneDrive/Desktop/App projects/Vitanet/assets/health_library_data/articles/articles_catalog.json').readAsStringSync();
    final List<dynamic> articlesJsonList = json.decode(articlesJsonString);
    print('Articles list length: ' + articlesJsonList.length.toString());
  } catch (e) {
    print('Error parsing articles: ' + e.toString());
  }
}

