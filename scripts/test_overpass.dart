import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final lat = 5.6037;
  final lon = -0.1870;
  final query = '''
    [out:json];
    node["amenity"="hospital"](around:5000, $lat, $lon);
    out 3;
  ''';
  final url = Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}');
  print('Fetching...');
  final res = await http.get(url);
  print(res.body);
}
