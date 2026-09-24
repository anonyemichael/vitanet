import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer YOUR_API_KEY_HERE',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "model": "google/gemini-2.5-flash",
      "messages": [{"role": "user", "content": "hi"}]
    })
  );
  print(response.statusCode);
  print(response.body);
}
