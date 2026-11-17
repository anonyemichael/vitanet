// ignore_for_file: avoid_print
import 'package:dio/dio.dart';

void main() async {
  final openRouterDio = Dio(BaseOptions(
    baseUrl: 'https://openrouter.ai/api/v1/',
    headers: {
      'Content-Type': 'application/json',
    },
  ));
  
  try {
    print("Testing OpenRouter...");
    final response = await openRouterDio.post('chat/completions', 
      data: {
        "model": "google/gemini-2.0-flash-exp:free", 
        "messages": [{"role": "user", "content": "hello"}],
      }
    );
    print(response.statusCode);
  } catch(e) {
    print(e);
  }
}
