import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:vitanet/data/models/chat_message.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/models/user_profile.dart';

/// Direct Gemini AI service — no backend relay needed.
/// Builds a rich system prompt from user profile + live vitals.
class AiService {
  static const _uuid = Uuid();

  UserProfile? _profile;
  Map<String, double> _vitals = {};
  List<TriageResult> _pastTriages = [];
  int _questionCount = 0;
  String? _currentAddress;
  bool _isGeocoding = false;

  final List<Map<String, String>> _history = [];

  void updateContext(
    UserProfile? profile, {
    List<TriageResult>? pastTriages,
    Map<String, double>? vitals,
  }) {
    _profile = profile;
    _pastTriages = pastTriages ?? [];
    if (vitals != null) _vitals = vitals;
    
    if (_profile?.latitude != null && _profile?.longitude != null && _currentAddress == null && !_isGeocoding) {
      _fetchAddress(_profile!.latitude!, _profile!.longitude!);
    }
  }

  Future<void> _fetchAddress(double lat, double lon) async {
    _isGeocoding = true;
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json');
      final response = await http.get(url, headers: {'User-Agent': 'VitaNet/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['display_name'] != null) {
          _currentAddress = data['display_name'];
        }
      }
    } catch (_) {
    } finally {
      _isGeocoding = false;
    }
  }

  void loadHistory(List<ChatMessage> messages, UserProfile? profile) {
    _questionCount = messages.where((m) => m.role == MessageRole.user).length;
    _history.clear();
    for (final m in messages) {
      if (m.role == MessageRole.user) {
        _history.add({'role': 'user', 'content': m.text});
      } else if (m.role == MessageRole.assistant) {
        _history.add({'role': 'model', 'content': m.text});
      }
    }
  }

  String _buildSystemPrompt() {
    final buf = StringBuffer();
    buf.writeln(
      'You are VitaNet AI, a compassionate and knowledgeable health assistant acting as a virtual triage nurse. '
      'If the user is asking about symptoms or a potential medical condition, you must follow WHO guidelines for medical triage: DO NOT give a diagnosis based on just one symptom, and ALWAYS ask follow-up questions (duration, severity) before suggesting a condition. '
      'HOWEVER, if the user asks a direct question (e.g., finding a hospital, checking operating hours, asking for general health info, or asking their location), DO NOT force them to provide symptoms. Give them a direct and straight answer immediately. '
      'Do not blindly recommend the hospital for minor symptoms, but for severe cases, direct them to a hospital. '
      'Factor in the user\'s geographic location for regional diseases. '
      'You are free to answer questions about the user\'s location (e.g., if they ask "where am I") using their Location Address. Do not print raw latitude/longitude numerical coordinates in the chat, use them only to generate links. '
      'When the user needs to find a hospital, clinic, lab, or pharmacy near them, you MUST provide a clickable Google Maps search link. '
      'If real-time web search results are provided in your context, you MUST use them to list the actual names, addresses, and details of the facilities directly in the chat, in addition to providing the Google Maps link. Do NOT say you cannot list them. '
      'If you have their exact location coordinates in the patient profile below, you have ALL the information you need. DO NOT ask the user to confirm their city or region. Format the link EXACTLY like this: [Find a nearby <facility>](https://www.google.com/maps/search/<facility>/@<LATITUDE>,<LONGITUDE>,14z) (replace <facility> with hospital, clinic, lab, or pharmacy, and replace <LATITUDE> and <LONGITUDE> with the numbers). '
      'If you do NOT have their coordinates in the profile, ONLY THEN should you politely ask for their city, or format the link like this: [Find a nearby <facility>](https://www.google.com/maps/search/<facility>+near+me) '
      'Format responses clearly. Use bullet points for lists. Keep responses under 300 words unless detail is critical.',
    );

    if (_profile != null) {
      buf.writeln('\n--- PATIENT PROFILE ---');
      if (_profile!.latitude != null && _profile!.longitude != null) {
        buf.writeln('Location Coordinates: ${_profile!.latitude}, ${_profile!.longitude} (Use these to generate the Google Maps URL, but do not print the raw numbers to the user.)');
        if (_currentAddress != null) {
          buf.writeln('Location Address: $_currentAddress');
        }
      } else {
        buf.writeln('Location: Unknown (If needed, politely ask the user what city they are in. DO NOT guess.)');
      }
      buf.writeln('Name: ${_profile!.name}');
      if (_profile!.age != null) buf.writeln('Age: ${_profile!.age}');
      if (_profile!.sex != null) buf.writeln('Biological Sex: ${_profile!.sex}');
      if (_profile!.bloodType != null) buf.writeln('Blood Type: ${_profile!.bloodType}');
      if (_profile!.height != null) buf.writeln('Height: ${_profile!.height} cm');
      if (_profile!.weight != null) buf.writeln('Weight: ${_profile!.weight} kg');
      if (_profile!.preExistingConditions.isNotEmpty) {
        buf.writeln('Conditions: ${_profile!.preExistingConditions.join(', ')}');
      }
      if (_profile!.allergies.isNotEmpty) {
        buf.writeln('Allergies: ${_profile!.allergies.join(', ')}');
      }
      if (_profile!.medications.isNotEmpty) {
        buf.writeln('Medications: ${_profile!.medications.join(', ')}');
      }
      buf.writeln('Smoking: ${_profile!.smoking ? 'Yes' : 'No'}');
      buf.writeln('Alcohol: ${_profile!.alcohol ? 'Yes' : 'No'}');
      if (_profile!.exerciseFrequency != null) {
        buf.writeln('Exercise: ${_profile!.exerciseFrequency}');
      }
    }

    if (_vitals.isNotEmpty) {
      buf.writeln('\n--- LIVE VITALS (from connected devices) ---');
      if (_vitals.containsKey('heart_rate')) {
        buf.writeln('Heart Rate: ${_vitals['heart_rate']!.round()} bpm');
      }
      if (_vitals.containsKey('blood_oxygen')) {
        buf.writeln('Blood Oxygen (SpO2): ${_vitals['blood_oxygen']!.toStringAsFixed(1)}%');
      }
      if (_vitals.containsKey('temperature')) {
        buf.writeln('Body Temperature: ${_vitals['temperature']!.toStringAsFixed(1)}°C');
      }
      if (_vitals.containsKey('respiratory_rate')) {
        buf.writeln('Respiratory Rate: ${_vitals['respiratory_rate']!.round()} breaths/min');
      }
    }

    if (_pastTriages.isNotEmpty) {
      buf.writeln('\n--- RECENT TRIAGE HISTORY ---');
      for (final t in _pastTriages.take(3)) {
        buf.writeln('• ${t.primarySymptom}: ${t.level.name} (${t.timestamp.toLocal().toString().split(' ')[0]})');
      }
    }

    return buf.toString();
  }

  Future<String?> _searchTavily(String query) async {
    final apiKey = dotenv.env['TAVILY_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('https://api.tavily.com/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': apiKey,
          'query': query,
          'search_depth': 'basic',
          'include_answer': true,
          'max_results': 3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['answer'] != null) {
          return 'Tavily Answer: ${data['answer']}\nSources: ${(data['results'] as List).map((e) => e['title']).join(', ')}';
        }
        return (data['results'] as List)
            .map((e) => '${e['title']}: ${e['content']}')
            .join('\n');
      }
    } catch (e) {
      debugPrint('Tavily search error: $e');
    }
    return null;
  }

  Future<String?> _searchGoogle(String query) async {
    final apiKey = dotenv.env['GOOGLE_API_KEY'];
    final cx = dotenv.env['GOOGLE_CSE_ID'];
    if (apiKey == null || apiKey.isEmpty || cx == null || cx.isEmpty) return null;

    try {
      final url = Uri.parse('https://www.googleapis.com/customsearch/v1?key=$apiKey&cx=$cx&q=${Uri.encodeComponent(query)}&num=3');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          return items.map((e) => '${e['title']}: ${e['snippet']}').join('\n');
        }
      }
    } catch (e) {
      debugPrint('Google search error: $e');
    }
    return null;
  }

  Future<String?> _checkSearchIntent(String userMessage) async {
    final apiKeyString = dotenv.env['OPENROUTER_API_KEYS'] ?? '';
    final apiKeys = apiKeyString.split(',').where((k) => k.trim().isNotEmpty).toList();
    if (apiKeys.isEmpty) return null;
    final apiKey = apiKeys.first.trim();

    final prompt = '''
You are an intent classifier. Does the user's message require fetching real-time information from the web (e.g., live operating hours, today's news, current events, or searching for specific places/hospitals/clinics near them)?
If yes, reply strictly in this format: YES: <optimized search query>
If no, reply strictly: NO

User message: "$userMessage"
''';

    final body = {
      'model': 'google/gemini-2.5-flash',
      'messages': [{'role': 'user', 'content': prompt}],
      'temperature': 0.1,
      'max_tokens': 30,
    };

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices'][0]['message']['content'] as String? ?? '';
        if (text.trim().startsWith('YES:')) {
          return text.substring(4).trim();
        }
      }
    } catch (e) {
      debugPrint('Intent check error: $e');
    }
    return null;
  }

  Stream<String> getResponseStream(String userMessage, {String? base64Image}) async* {
    _questionCount++;

    final apiKeyString = dotenv.env['OPENROUTER_API_KEYS'] ?? '';
    final apiKeys = apiKeyString.split(',').where((k) => k.trim().isNotEmpty).toList();
    if (apiKeys.isEmpty) {
      yield 'OpenRouter API key not configured.';
      return;
    }
    final apiKey = apiKeys.first.trim();

    // Check if web search is needed
    String? searchContext;
    final searchQuery = await _checkSearchIntent(userMessage);
    if (searchQuery != null && searchQuery.isNotEmpty) {
      String? results = await _searchTavily(searchQuery);
      results ??= await _searchGoogle(searchQuery);
      
      if (results != null && results.isNotEmpty) {
        searchContext = '\n--- REAL-TIME WEB SEARCH RESULTS ---\nQuery: $searchQuery\n$results\nUse this live information to answer the user accurately.';
      }
    }

    final messages = <Map<String, dynamic>>[];
    var systemPrompt = _buildSystemPrompt();
    if (searchContext != null) {
      systemPrompt += searchContext;
    }
    messages.add({'role': 'system', 'content': systemPrompt});
    
    for (final msg in _history) {
      messages.add({
        'role': msg['role'] == 'model' ? 'assistant' : 'user',
        'content': msg['content']
      });
    }

    if (base64Image != null) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': userMessage},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,$base64Image'
            }
          }
        ]
      });
    } else {
      messages.add({'role': 'user', 'content': userMessage});
    }

    final body = {
      'model': 'google/gemini-2.5-flash',
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 1024,
      'top_p': 0.95,
      'stream': true,
    };

    final request = http.Request('POST', Uri.parse('https://openrouter.ai/api/v1/chat/completions'));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.body = jsonEncode(body);

    try {
      final response = await http.Client().send(request);
      if (response.statusCode != 200) {
        final err = await response.stream.bytesToString();
        debugPrint('OpenRouter stream error ${response.statusCode}: $err');
        yield 'AI service error (${response.statusCode}). Please try again.';
        return;
      }

      String fullText = '';
      await for (var line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data: ') && line != 'data: [DONE]') {
          try {
            final data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
            final choices = data['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              if (delta != null && delta['content'] != null) {
                final chunk = delta['content'] as String;
                fullText += chunk;
                yield fullText;
              }
            }
          } catch (e) {
            // Ignore parse errors on incomplete chunks
          }
        }
      }

      _history.add({'role': 'user', 'content': userMessage});
      _history.add({'role': 'model', 'content': fullText});
      if (_history.length > 40) {
        _history.removeRange(0, _history.length - 40);
      }
    } catch (e) {
      debugPrint('AiService stream error: $e');
      yield 'Connection error. Check your internet and try again.';
    }
  }

  Future<List<ChatMessage>> getResponse(
    String userMessage, {
    String? base64Image,
  }) async {
    _questionCount++;

    final apiKeyString = dotenv.env['OPENROUTER_API_KEYS'] ?? '';
    final apiKeys = apiKeyString.split(',').where((k) => k.trim().isNotEmpty).toList();
    if (apiKeys.isEmpty) {
      return [_errorMessage('OpenRouter API key not configured.')];
    }
    // We'll just use the first key for now, could randomly pick for rotation
    final apiKey = apiKeys.first.trim();

    // Check if web search is needed
    String? searchContext;
    final searchQuery = await _checkSearchIntent(userMessage);
    if (searchQuery != null && searchQuery.isNotEmpty) {
      String? results = await _searchTavily(searchQuery);
      results ??= await _searchGoogle(searchQuery);
      
      if (results != null && results.isNotEmpty) {
        searchContext = '\n--- REAL-TIME WEB SEARCH RESULTS ---\nQuery: $searchQuery\n$results\nUse this live information to answer the user accurately.';
      }
    }

    // Build conversation history for context
    final messages = <Map<String, dynamic>>[];
    var systemPrompt = _buildSystemPrompt();
    if (searchContext != null) {
      systemPrompt += searchContext;
    }
    messages.add({'role': 'system', 'content': systemPrompt});
    
    for (final msg in _history) {
      messages.add({
        'role': msg['role'] == 'model' ? 'assistant' : 'user',
        'content': msg['content']
      });
    }

    if (base64Image != null) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': userMessage},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,$base64Image'
            }
          }
        ]
      });
    } else {
      messages.add({'role': 'user', 'content': userMessage});
    }

    final body = {
      'model': 'google/gemini-2.5-flash',
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 1024,
      'top_p': 0.95,
    };

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          if (message != null) {
            final text = message['content'] as String? ?? '';
            // Add to history for context
            _history.add({'role': 'user', 'content': userMessage});
            _history.add({'role': 'model', 'content': text});
            // Keep history manageable (last 20 turns)
            if (_history.length > 40) {
              _history.removeRange(0, _history.length - 40);
            }
            return [
              ChatMessage(
                id: _uuid.v4(),
                role: MessageRole.assistant,
                text: text,
                timestamp: DateTime.now(),
              ),
            ];
          }
        }
        return [_errorMessage('Empty response from AI.')];
      } else {
        debugPrint('OpenRouter error ${response.statusCode}: ${response.body}');
        return [_errorMessage('AI service error (${response.statusCode}). Please try again.')];
      }
    } catch (e) {
      debugPrint('AiService error: $e');
      return [_errorMessage('Connection error. Check your internet and try again.')];
    }
  }

  ChatMessage _errorMessage(String text) => ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        text: text,
        timestamp: DateTime.now(),
      );

  bool get isReadyForTriage => _questionCount >= 3;
  int get questionCount => _questionCount;
  double get progress => (_questionCount / 5).clamp(0.0, 1.0);

  TriageResult generateTriageResult() => TriageResult(
        id: _uuid.v4(),
        level: TriageLevel.selfCare,
        summary: 'Triage is provided by the VitaNet assistant.',
        recommendations: const [],
        monitorSymptoms: const [],
        primarySymptom: '',
        timestamp: DateTime.now(),
      );

  void reset() {
    _questionCount = 0;
    _history.clear();
  }

  Future<String> generateHealthReport({
    required String metricName,
    required String currentValue,
    required String unit,
    required String avg,
    required String high,
    required String low,
  }) async {
    final apiKeyString = dotenv.env['OPENROUTER_API_KEYS'] ?? '';
    final apiKeys = apiKeyString.split(',').where((k) => k.trim().isNotEmpty).toList();
    if (apiKeys.isEmpty) return 'Error: API key not configured.';
    final apiKey = apiKeys.first.trim();

    final prompt = '''
You are a medical AI assistant analyzing health data for a user.
Provide a concise, professional, and easy-to-understand analysis of this metric based on WHO guidelines. 
Keep it under 4 sentences and use bullet points if necessary. Do not provide a formal diagnosis.

Metric: $metricName
Current: $currentValue $unit
Average (recent): $avg $unit
Highest (recent): $high $unit
Lowest (recent): $low $unit
''';

    final body = {
      'model': 'google/gemini-2.5-flash',
      'messages': [{'role': 'user', 'content': prompt}],
      'temperature': 0.7,
      'max_tokens': 300,
    };

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? 'Unable to generate report.';
      }
      return 'AI service error (${response.statusCode}).';
    } catch (e) {
      return 'Connection error. Check your internet and try again.';
    }
  }
}
