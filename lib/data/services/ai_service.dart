import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vitanet/core/network/backend.dart';
import 'package:uuid/uuid.dart';
import 'package:vitanet/data/models/chat_message.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/services/api_service.dart';

/// VitaNet AI service.
///
/// The app no longer talks to any outside AI (Gemini / OpenRouter were removed). Every chat message goes to our own
/// backend, `POST /chat/{uid}`, where the VitaNet model answers with its tools (your vitals and profile, nearby
/// hospitals, pharmacies, medicine look-up, symptom checker, ...) and the safety layer adds a danger-sign warning
/// when needed. The backend keeps the conversation history, the system prompt and the profile, so none of that is
/// built here any more. Health-trend notes come from `POST /ai/health-report`.
class AiService {
  static const _uuid = Uuid();
  static const _offline =
      'VitaNet AI is unavailable right now. Please try again in a moment. If you feel very unwell, call 112 or 193.';

  UserProfile? _profile;
  Map<String, double> _vitals = {};
  int _questionCount = 0;

  /// Buttons and card from the most recent reply (call the hospital, directions, notify a caregiver, ...).
  List<ChatAction> lastActions = const [];
  String? lastWidgetType;
  Map<String, dynamic>? lastWidgetPayload;

  void updateContext(
    UserProfile? profile, {
    List<TriageResult>? pastTriages,
    Map<String, double>? vitals,
  }) {
    _profile = profile;
    if (vitals != null) _vitals = vitals;
  }

  /// Conversation history now lives on the server; this only restores the question counter for the UI.
  void loadHistory(List<ChatMessage> messages, UserProfile? profile) {
    _profile = profile ?? _profile;
    _questionCount = messages.where((m) => m.role == MessageRole.user).length;
  }

  String? get _uid => Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid;

  /// Sends the message to the VitaNet assistant and yields the reply. The backend answers in one piece (tools run
  /// on the server first), so this yields once; buttons and cards are left in [lastActions] / [lastWidgetType].
  Stream<String> getResponseStream(String userMessage, {String? base64Image}) async* {
    final messages = await getResponse(userMessage, base64Image: base64Image);
    yield messages.first.text;
  }

  Future<List<ChatMessage>> getResponse(String userMessage, {String? base64Image}) async {
    _questionCount++;
    lastActions = const [];
    lastWidgetType = null;
    lastWidgetPayload = null;

    final uid = _uid;
    if (uid == null) {
      return [_message('Please sign in to chat with the VitaNet assistant. If you feel very unwell, call 112 or 193.')];
    }

    try {
      final response = await http
          .post(
            BackendConfig.uri('chat/$uid'),
            headers: await BackendConfig.authHeaders(),
            body: jsonEncode({
              'message': userMessage,
              'image_base64': ?base64Image,
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        debugPrint('VitaNet chat error ${response.statusCode}: ${response.body}');
        return [_message(_offline)];
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = (data['reply'] as String?)?.trim();
      _readBlocks((data['blocks'] as List?) ?? const []);
      return [
        ChatMessage(
          id: _uuid.v4(),
          role: MessageRole.assistant,
          text: (reply == null || reply.isEmpty) ? _offline : reply,
          timestamp: DateTime.now(),
          actions: lastActions.isEmpty ? null : lastActions,
          widgetType: lastWidgetType,
          widgetPayload: lastWidgetPayload,
        ),
      ];
    } catch (e) {
      debugPrint('AiService error: $e');
      return [_message('Connection error. Check your internet and try again. If you feel very unwell, call 112 or 193.')];
    }
  }

  /// Backend blocks -> the app's existing cards and buttons.
  void _readBlocks(List blocks) {
    final actions = <ChatAction>[];
    for (final raw in blocks) {
      if (raw is! Map) continue;
      final b = Map<String, dynamic>.from(raw);
      switch (b['type']) {
        case 'hospital_recommendation':
          final km = (b['distance_km'] as num?)?.toDouble();
          lastWidgetType = 'hospital_recommendation';
          lastWidgetPayload = {
            'name': b['name'],
            if (km != null) 'distance': '${km.toStringAsFixed(1)} km away from you',
            if (b['est_time_min'] != null) 'estTime': '${b['est_time_min']} min',
            if (b['crowd_level'] != null) 'crowdLevel': b['crowd_level'],
            if (b['address'] != null) 'address': b['address'],
          };
          break;
        case 'action_buttons':
          for (final btn in (b['buttons'] as List? ?? const [])) {
            if (btn is! Map) continue;
            actions.add(ChatAction(
              label: '${btn['label'] ?? ''}',
              type: switch (btn['action']) {
                'call_hospital' => 'call',
                'get_directions' => 'directions',
                'notify_caregiver' => 'notify',
                'emergency_checkin' => 'assessment',
                _ => 'button',
              },
              payload: '${btn['url'] ?? ''}',
            ));
          }
          break;
      }
    }
    lastActions = actions;
  }

  ChatMessage _message(String text) => ChatMessage(
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

  Future<TriageResult> generateTriageResultFromML({
    required List<String> symptoms,
    String? primarySymptom,
  }) async {
    // Only readings that really came from the watch / health platform are
    // sent. Missing ones stay missing; the server scores without them.
    final ml = await ApiService().predictTriage(
      symptoms: symptoms,
      age: _profile?.age,
      gender: _profile?.sex,
      heartRate: _vitals['heart_rate'],
      temperature: _vitals['temperature'],
      bloodOxygen: _vitals['blood_oxygen'],
      systolicBp: _vitals['systolic_bp'],
      diastolicBp: _vitals['diastolic_bp'],
    );

    if (ml != null) {
      final level = switch (ml.severity) {
        'urgent' => TriageLevel.emergency,
        'doctor' => TriageLevel.doctor,
        _ => TriageLevel.selfCare,
      };

      return TriageResult(
        id: _uuid.v4(),
        level: level,
        summary: '${ml.disease} (${ml.confidence} confidence): ${ml.recommendation}',
        recommendations: [ml.recommendation, ...ml.precautions],
        monitorSymptoms: symptoms,
        primarySymptom: primarySymptom ?? (symptoms.isNotEmpty ? symptoms.first : ml.disease),
        timestamp: DateTime.now(),
      );
    }

    return generateTriageResult();
  }

  void reset() {
    _questionCount = 0;
    lastActions = const [];
    lastWidgetType = null;
    lastWidgetPayload = null;
  }

  /// Short note about one health metric, written by the VitaNet model on the server (a plain summary of the numbers
  /// when the model is offline).
  Future<String> generateHealthReport({
    required String metricName,
    required String currentValue,
    required String unit,
    required String avg,
    required String high,
    required String low,
  }) async {
    try {
      final response = await http
          .post(
            BackendConfig.uri('ai/health-report'),
            headers: await BackendConfig.authHeaders(),
            body: jsonEncode({
              'metric_name': metricName,
              'current_value': currentValue,
              'unit': unit,
              'avg': avg,
              'high': high,
              'low': low,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['report'] as String?) ?? 'Unable to generate report.';
      }
      return _offline;
    } catch (e) {
      return 'Connection error. Check your internet and try again.';
    }
  }
}
