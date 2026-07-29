import 'dart:convert';
import 'package:http/http.dart' as http;
void main() async {
  final r = await http.get(Uri.parse('https://openrouter.ai/api/v1/models'));
  final m = jsonDecode(r.body)['data'];
  for (var x in m) {
    if (x['id'].toString().contains('free')) print(x['id']);
  }
}
