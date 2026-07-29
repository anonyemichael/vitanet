import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vitanet/data/models/chat_message.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:uuid/uuid.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vitanet/data/services/health_service.dart';

/// Real AI service powered by OpenRouter API and Custom Disease Model.
class AiService {
  static const _uuid = Uuid();
  
  final Dio _openRouterDio = Dio(BaseOptions(
    baseUrl: 'https://openrouter.ai/api/v1/',
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  final Dio _diseaseModelDio = Dio(BaseOptions(
    baseUrl: 'https://corsproxy.io/?https://diseasmodel-production.up.railway.app',
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  List<Map<String, dynamic>> _history = [];
  
  int _questionCount = 0;
  static const int maxSafetyLimit = 15;
  bool _isTriageReady = false;
  String _primarySymptom = '';
  TriageResult? _finalResult;
  final HealthService? healthService;
  Map<String, dynamic> _biometrics = {};

  AiService({this.healthService}) {
    _initModel(null);
  }

  void updateContext(UserProfile? profile, {List<TriageResult>? pastTriages}) async {
    if (healthService != null) {
      _biometrics = await healthService!.fetchBiometrics();
    }
    _initModel(profile, pastTriages: pastTriages);
  }

  /// Loads full history from past sessions to give AI persistence memory
  void loadHistory(List<ChatMessage> messages, UserProfile? profile) {
    _questionCount = 0;
    _primarySymptom = '';
    _isTriageReady = false;
    _finalResult = null;
    _initModel(profile);

    for (var msg in messages) {
      if (msg.role == MessageRole.user) {
        if (_primarySymptom.isEmpty) _primarySymptom = msg.text;
        _history.add({"role": "user", "content": msg.text});
      } else if (msg.role == MessageRole.assistant) {
        _questionCount++;
        _history.add({"role": "assistant", "content": msg.text});
        
        // If it previously output a Triage action, flag it
        if (msg.actions != null && msg.actions!.isNotEmpty && (msg.actions!.first.label.contains('Hospital') || msg.actions!.first.label.contains('Pharmacy'))) {
          _isTriageReady = true;
        }
      }
    }
  }

  void _initModel(UserProfile? profile, {List<TriageResult>? pastTriages}) {
    String profileContext = "";
    if (profile != null) {
      profileContext = "User Profile Context:\n"
          "Name: ${profile.name}\n"
          "Age: ${profile.age}\n"
          "Gender: ${profile.sex}\n"
          "Blood Type: ${profile.bloodType}\n"
          "Height: ${profile.height} cm\n"
          "Weight: ${profile.weight} kg\n"
          "Allergies: ${profile.allergies.join(', ')}\n"
          "Chronic Conditions: ${profile.preExistingConditions.join(', ')}\n"
          "Medications: ${profile.medications.join(', ')}\n"
          "Family Medical History: ${profile.familyMedicalHistory.join(', ')}\n\n"
          "Please tailor your advice to this user context.";
    }

    if (_biometrics.isNotEmpty) {
      profileContext += "\n\nReal-Time Biometrics from Patient's Device:\n";
      if (_biometrics.containsKey('heart_rate')) profileContext += "- Heart Rate: ${_biometrics['heart_rate']} bpm\n";
      if (_biometrics.containsKey('systolic_bp') && _biometrics.containsKey('diastolic_bp')) {
        profileContext += "- Blood Pressure: ${_biometrics['systolic_bp']}/${_biometrics['diastolic_bp']} mmHg\n";
      }
      profileContext += "CRITICAL: You already have these vitals. DO NOT ask the user for them.\n";
    }

    String systemPrompt = 'You are Vitanet, an expert WHO-certified Chief Medical Officer performing a clinical consultation. '
        'Your goal is to perform a rigorous differential diagnosis by methodically assessing the user\'s symptoms using the OPQRST clinical framework:\n'
        '- Onset (when did it start, sudden or gradual?)\n'
        '- Provocation (what makes it better or worse?)\n'
        '- Quality (what does it feel like?)\n'
        '- Radiation (does it spread anywhere?)\n'
        '- Severity (1-10 scale)\n'
        '- Time (how long does it last?)\n'
        'Ask ONE targeted question at a time to fill in the missing OPQRST fields. '
        'Keep responses brief but empathetic (1-2 sentences). DO NOT provide a medical diagnosis yet. Just gather the data. '
        'Once you have sufficient information to make a diagnosis, inform the user you are analyzing their symptoms and set ready_for_triage to true. '
        '$profileContext\n';

    if (pastTriages != null && pastTriages.isNotEmpty) {
      String historyContext = "\n\nPast Triage History (Memory):\n";
      // Pass the 5 most recent triages
      for (var triage in pastTriages.take(5)) {
        historyContext += "- Date: ${triage.timestamp.toIso8601String().split('T')[0]}, Symptom: ${triage.primarySymptom}, Level: ${triage.level.name}, Summary: ${triage.summary}\n";
      }
      historyContext += "Use this past history context to understand the patient's ongoing conditions or recurring symptoms if relevant.\n";
      
      systemPrompt += historyContext;
    }

    systemPrompt += 'CRITICAL RULE: You MUST always respond with a raw JSON object and nothing else. '
        'The JSON must exactly match this schema:\n'
        '{\n'
        '  "text": "Your natural language response to the user.",\n'
        '  "ready_for_triage": false, // Set to true ONLY when you have fully collected the OPQRST data and are ready to diagnose.\n'
        '  "actions": [\n'
        '    {"label": "Button text", "type": "article|link|assessment", "payload": "relevant data"}\n'
        '  ]\n'
        '}\n'
        'Do not use markdown formatting like ```json around the response.';

    _history = [
      {
        "role": "system",
        "content": systemPrompt
      }
    ];
  }

  int _currentKeyIndex = 0;

  Future<String> _callOpenRouter(List<Map<String, dynamic>> messages) async {
    final keysString = dotenv.env['OPENROUTER_API_KEYS'] ?? dotenv.env['OPENROUTER_API_KEY'] ?? '';
    final keys = keysString.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();

    if (keys.isEmpty) {
      throw Exception('No API keys configured');
    }

    for (int i = 0; i < keys.length; i++) {
      final currentKey = keys[_currentKeyIndex];

      try {
        final response = await _openRouterDio.post('chat/completions', 
          options: Options(headers: {
            'Authorization': 'Bearer $currentKey',
            'HTTP-Referer': 'https://vitanet.app',
            'X-Title': 'VitaNet',
          }),
          data: {
            "model": "openrouter/auto", 
            "max_tokens": 1024,
            "messages": messages,
          }
        );
        return response.data['choices'][0]['message']['content'];
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        // 402 Payment Required, 403 Forbidden (Credits), 429 Too Many Requests
        if (statusCode == 402 || statusCode == 403 || statusCode == 429) {
          _currentKeyIndex = (_currentKeyIndex + 1) % keys.length;
          if (i == keys.length - 1) {
            rethrow; // All keys exhausted
          }
          // Quickly silently retry with the next key
          continue; 
        } else {
          rethrow; // Other network/server error, don't burn the key
        }
      }
    }
    
    throw Exception('Failed to get a response');
  }

  Future<Position?> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5)
      );
    } catch (e) {
      return null;
    }
  }

  /// Processes a user message and returns an AI response.
  Future<List<ChatMessage>> getResponse(String userMessage, {String? base64Image}) async {
    if (_questionCount == 0) {
      _primarySymptom = userMessage;
    }
    
    _questionCount++;

    try {
      if (base64Image != null) {
        _history.add({
          "role": "user", 
          "content": [
            {"type": "text", "text": userMessage},
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,$base64Image"
              }
            }
          ]
        });
      } else {
        _history.add({"role": "user", "content": userMessage});
      }

      if (!_isTriageReady && _questionCount < maxSafetyLimit) {
        // Normal conversation turn
        final responseText = await _callOpenRouter(_history);
        _history.add({"role": "assistant", "content": responseText});
        
        final parsedMsg = _parseAiResponse(responseText);
        
        try {
          final targetJson = _extractJsonString(responseText);
          final Map<String, dynamic> data = jsonDecode(targetJson);
          if (data['ready_for_triage'] == true) {
            _isTriageReady = true;
          }
        } catch (_) {}

        if (!_isTriageReady) {
          return [parsedMsg];
        } else {
          // It just became ready, run triage flow immediately
          final diagnosisMsg = await _runTriageFlow();
          return [parsedMsg, diagnosisMsg];
        }
      } else {
        // Fallback if we exceeded safety limit without triggering triage
        _isTriageReady = true;
        final diagnosisMsg = await _runTriageFlow();
        return [diagnosisMsg];
      }
    } catch (e) {
      return [_createAiMessage('I encountered an error connecting to the AI: $e')];
    }
  }

  Future<ChatMessage> _runTriageFlow() async {
    try {
      // Step 1: Extract PatientData
      final extractionPrompt = 'Based on the conversation, extract the patient data into this exact JSON schema. '
          'Only output raw JSON, no markdown blocks.\n'
          '{\n'
          '  "age": 45,\n'
          '  "gender": 0, // 0 for male, 1 for female\n'
          '  "fever": 1.0, // 1.0 if fever mentioned, else 0.0\n'
          '  "cough": 1.0, // 1.0 if cough mentioned, else 0.0\n'
          '  "headache": 0.0, // 1.0 if headache mentioned, else 0.0\n'
          '  "temperature": 37.0,\n'
          '  "heart_rate": 75.0,\n'
          '  "o2_saturation": 98,\n'
          '  "systolic_bp": 120,\n'
          '  "diastolic_bp": 80,\n'
          '  "symptoms": ["symptom1", "symptom2"]\n'
          '}';
          
      final extractMessages = List<Map<String, dynamic>>.from(_history);
      extractMessages.add({"role": "user", "content": extractionPrompt});
      
      final extractedJsonString = await _callOpenRouter(extractMessages);
      
      // Parse extracted JSON
      final targetJson = _extractJsonString(extractedJsonString);
      final Map<String, dynamic> patientData = jsonDecode(targetJson);
      
      // Step 2: Call Disease Model
      final diseaseResponse = await _diseaseModelDio.post('/predict', data: patientData);
      final predictionResult = diseaseResponse.data;
      
      // Step 3: Fetch Location for Map
      final position = await _getUserLocation();
      String locationContext = "User location is unknown. Suggest searching their maps manually.";
      String hospitalUrl = "https://www.google.com/maps/search/hospital";
      String pharmacyUrl = "https://www.google.com/maps/search/pharmacy";
      if (position != null) {
        locationContext = "User is at Latitude: ${position.latitude}, Longitude: ${position.longitude}.";
        hospitalUrl = "https://www.google.com/maps/search/hospital+near+${position.latitude},${position.longitude}";
        pharmacyUrl = "https://www.google.com/maps/search/pharmacy+near+${position.latitude},${position.longitude}";
      }

      // Step 4: Format the prediction result for the user
      final explainPrompt = 'As a WHO-certified doctor, the disease prediction model analyzed the patient data and returned: \n'
          'Prediction: ${jsonEncode(predictionResult)}\n'
          'Patient Data Used: ${jsonEncode(patientData)}\n\n'
          'CRITICAL OBJECTIVE: Reduce unnecessary hospital load. Perform a strict triage.\n'
          '- Triage Level 1 (Minor/Mild): Recommend self-care, hydration, rest, and generic over-the-counter (OTC) medications (e.g. Paracetamol). DO NOT recommend a hospital.\n'
          '- Triage Level 2 (Moderate): Recommend visiting a pharmacy for stronger OTC meds or basic diagnostic tests.\n'
          '- Triage Level 3 (Severe/Red Flags): ONLY recommend a hospital if there are clear WHO red flags (e.g. sudden thunderclap headache, crushing chest pain, severe breathing difficulty).\n\n'
          '$locationContext\n'
          'Use the user\'s geographic location to weigh epidemiological risks and endemic diseases for that region (e.g., malaria in West Africa). Rule out statistically unlikely diseases from the differential diagnosis based on their area.\n\n'
          'Explain this diagnosis to the user in a highly professional, clinical, yet empathetic manner. '
          'Always respond with a raw JSON object matching this schema: '
          '{ "text": "explanation and triage recommendation...", "actions": [{"label": "Action Button Name", "type": "link", "payload": "URL"}] }\n'
          'For the action button, if Triage Level 1 or 2, use label "Find Nearby Pharmacy" with payload "$pharmacyUrl". '
          'If Triage Level 3, use label "Find Nearby Hospital" with payload "$hospitalUrl".';
          
      final explainMessages = List<Map<String, dynamic>>.from(_history);
      explainMessages.add({"role": "system", "content": explainPrompt});
      explainMessages.add({"role": "user", "content": "I have provided all my symptoms. What is your diagnosis doctor, and what should I do next?"});
      
      final finalResponseText = await _callOpenRouter(explainMessages);
      
      _history.add({"role": "assistant", "content": "Diagnosis provided."});
      await _generateTriageResult();
      
      return _parseAiResponse(finalResponseText);
    } catch (e) {
      return _createAiMessage('I encountered an error connecting to the AI: $e');
    }
  }

  String _extractJsonString(String rawString) {
    final cleanJson = rawString.replaceAll('```json', '').replaceAll('```', '').trim();
    String targetJson = cleanJson;
    final startIdx = cleanJson.indexOf('{');
    final endIdx = cleanJson.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      targetJson = cleanJson.substring(startIdx, endIdx + 1);
    }
    return targetJson;
  }

  ChatMessage _parseAiResponse(String rawJson) {
    try {
      final targetJson = _extractJsonString(rawJson);
      final Map<String, dynamic> data = jsonDecode(targetJson);
      
      final text = data['text'] as String? ?? 'Sorry, I could not generate a proper response.';
      List<ChatAction>? actions;
      
      if (data['actions'] != null) {
        actions = (data['actions'] as List)
            .map((a) => ChatAction.fromMap(a as Map<String, dynamic>))
            .toList();
      }

      return ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        text: text,
        timestamp: DateTime.now(),
        actions: actions,
      );
    } catch (e) {
      // Fallback if parsing fails
      return _createAiMessage(rawJson);
    }
  }

  Future<void> _generateTriageResult() async {
    try {
      final summaryPrompt = 'Based on the entire conversation history, output a JSON object representing the triage result. '
          'It MUST have this exact structure (no markdown formatting, just raw JSON):\n'
          '{\n'
          '  "level": "selfCare" or "pharmacist" or "doctor" or "emergency",\n'
          '  "recommendations": ["string1", "string2"],\n'
          '  "monitorSymptoms": ["string1", "string2"]\n'
          '}';
          
      final messages = List<Map<String, dynamic>>.from(_history);
      messages.add({"role": "user", "content": summaryPrompt});
      final responseText = await _callOpenRouter(messages);
      
      final targetJson = _extractJsonString(responseText);
      final Map<String, dynamic> data = jsonDecode(targetJson);
      
      final levelStr = data['level'] as String? ?? 'selfCare';
      TriageLevel level = TriageLevel.selfCare;
      if (levelStr == 'emergency') level = TriageLevel.emergency;
      if (levelStr == 'doctor') level = TriageLevel.doctor;
      if (levelStr == 'pharmacist') level = TriageLevel.pharmacist;

      _finalResult = TriageResult(
        id: _uuid.v4(),
        level: level,
        summary: 'Triage assessment complete based on reported symptoms.',
        recommendations: List<String>.from(data['recommendations'] ?? []),
        monitorSymptoms: List<String>.from(data['monitorSymptoms'] ?? []),
        primarySymptom: _primarySymptom,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      // Fallback if parsing fails
      _finalResult = TriageResult(
        id: _uuid.v4(),
        level: TriageLevel.selfCare,
        summary: 'Error generating AI triage result. Defaulting to self-care.',
        recommendations: ['Please consult a human healthcare professional.'],
        monitorSymptoms: [],
        primarySymptom: _primarySymptom,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Returns the AI-generated triage result.
  TriageResult generateTriageResult() {
    return _finalResult ?? TriageResult(
      id: _uuid.v4(),
      level: TriageLevel.selfCare,
      summary: 'Data unavailable.',
      recommendations: [],
      monitorSymptoms: [],
      primarySymptom: _primarySymptom,
      timestamp: DateTime.now(),
    );
  }

  /// Whether we have enough data to produce a triage result.
  bool get isReadyForTriage => _isTriageReady;

  /// Current question step (0 before first answer).
  int get questionCount => _questionCount;

  /// Progress from 0.0–1.0 for the chat step indicator.
  /// Since questions are dynamic, we estimate 15% per question up to 90% until ready.
  double get progress => _isTriageReady ? 1.0 : (_questionCount * 0.15).clamp(0.0, 0.90);

  /// Reset the conversation state for a new session.
  void reset() {
    _questionCount = 0;
    _isTriageReady = false;
    _primarySymptom = '';
    _finalResult = null;
    _initModel(null);
  }

  ChatMessage _createAiMessage(String text, {List<String>? quickReplies}) {
    return ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      text: text,
      timestamp: DateTime.now(),
      quickReplies: quickReplies,
    );
  }
}
