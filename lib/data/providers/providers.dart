import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:vitanet/data/models/chat_message.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/services/ai_service.dart';
import 'package:vitanet/data/services/local_storage_service.dart';
import 'package:vitanet/data/services/api_service.dart';
import 'package:vitanet/data/services/firestore_service.dart';
import 'package:vitanet/core/constants/app_strings.dart';
import 'package:vitanet/data/services/health_service.dart';

import 'package:vitanet/data/providers/auth_provider.dart';
export 'package:vitanet/data/providers/auth_provider.dart';

// --- Core Services ---

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});

final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService(ref.watch(sharedPreferencesProvider));
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

final aiServiceProvider = Provider<AiService>((ref) {
  final profile = ref.watch(userProfileProvider);
  final healthService = ref.watch(healthServiceProvider);
  final history = ref.watch(triageHistoryProvider);
  final service = AiService(healthService: healthService);
  service.updateContext(profile, pastTriages: history);
  return service;
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

// ─── Theme ───

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final LocalStorageService _storage;

  ThemeModeNotifier(this._storage) : super(_resolveTheme(_storage.themeMode));

  static ThemeMode _resolveTheme(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final name =
        mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system');
    await _storage.setThemeMode(name);
  }
}

// ─── Onboarding ───

final onboardingCompleteProvider = StateProvider<bool>((ref) {
  return ref.watch(localStorageProvider).isOnboardingComplete;
});

// ─── User Profile ───

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile?>((ref) {
  final storage = ref.watch(localStorageProvider);
  final api = ref.watch(apiServiceProvider);
  return UserProfileNotifier(storage, api);
});

class UserProfileNotifier extends StateNotifier<UserProfile?> {
  final LocalStorageService _storage;
  final ApiService _apiService;

  UserProfileNotifier(this._storage, this._apiService) : super(_storage.getProfile());

  Future<void> updateProfile(UserProfile profile) async {
    await _storage.saveProfile(profile);
    state = profile;
    await _apiService.syncUserProfile(profile);
  }
}

// ─── Chat ───

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier();
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier() : super([]);

  static const _uuid = Uuid();

  void addGreeting() {
    state = [
      ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        text: AppStrings.chatGreeting,
        timestamp: DateTime.now(),
      ),
    ];
  }

  void addMessage(ChatMessage message) {
    state = [...state, message];
  }

  void clear() => state = [];
}

final isAiTypingProvider = StateProvider<bool>((ref) => false);

final quickRepliesProvider = StateProvider<List<String>>((ref) => []);

// ─── Triage Result ───

final triageResultProvider = StateProvider<TriageResult?>((ref) => null);

// ─── Triage History ───

final currentConversationIdProvider = StateProvider<String>((ref) {
  return const Uuid().v4();
});

final chatHistoryListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) return [];
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserConversations(auth.user!.uid);
});

final specificChatHistoryProvider = FutureProvider.family<List<ChatMessage>, String>((ref, conversationId) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) return [];
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getChatHistory(auth.user!.uid, conversationId);
});

final triageHistoryProvider =
    StateNotifierProvider<TriageHistoryNotifier, List<TriageResult>>((ref) {
  final storage = ref.watch(localStorageProvider);
  return TriageHistoryNotifier(storage);
});

class TriageHistoryNotifier extends StateNotifier<List<TriageResult>> {
  final LocalStorageService _storage;

  TriageHistoryNotifier(this._storage) : super(_storage.getHistory());

  Future<void> add(TriageResult result) async {
    await _storage.addTriageResult(result);
    state = _storage.getHistory();
  }

  Future<void> remove(String id) async {
    await _storage.deleteTriageResult(id);
    state = _storage.getHistory();
  }

  Future<void> clearAll() async {
    await _storage.clearHistory();
    state = [];
  }
}

// --- Device Connection State (Mock Backend) ---
final deviceConnectionProvider = FutureProvider<Map<String, bool>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getDeviceConnections();
});

