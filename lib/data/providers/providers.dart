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
  final service = AiService();

  ref.listen(userProfileProvider, (prev, next) {
    service.updateContext(next, pastTriages: ref.read(triageHistoryProvider), vitals: ref.read(liveVitalsProvider));
  });
  ref.listen(triageHistoryProvider, (prev, next) {
    service.updateContext(ref.read(userProfileProvider), pastTriages: next, vitals: ref.read(liveVitalsProvider));
  });
  ref.listen(liveVitalsProvider, (prev, next) {
    service.updateContext(ref.read(userProfileProvider), pastTriages: ref.read(triageHistoryProvider), vitals: next);
  });

  service.updateContext(
    ref.read(userProfileProvider),
    pastTriages: ref.read(triageHistoryProvider),
    vitals: ref.read(liveVitalsProvider),
  );
  return service;
});

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

// ─── Live Vitals ───
/// Holds live device readings keyed by metric ID.
/// e.g. {'heart_rate': 74.0, 'blood_oxygen': 98.0}
final liveVitalsProvider =
    StateNotifierProvider<LiveVitalsNotifier, Map<String, double>>((ref) {
  return LiveVitalsNotifier();
});

class LiveVitalsNotifier extends StateNotifier<Map<String, double>> {
  LiveVitalsNotifier() : super(const {});

  void setVital(String metricId, double value) {
    state = {...state, metricId: value};
  }

  void connectDevice(String metricId) {
    // Real data will be fetched/streamed instead of simulating.
  }

  /// Updates heart rate continuously from the live card.
  void updateHeartRate(int bpm) => setVital('heart_rate', bpm.toDouble());
}

// ─── Theme ───

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
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
    final name = mode == ThemeMode.light
        ? 'light'
        : (mode == ThemeMode.dark ? 'dark' : 'system');
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
      final firestore = ref.watch(firestoreServiceProvider);
      final authState = ref.watch(authProvider);
      return UserProfileNotifier(storage, firestore, authState.user?.uid);
    });

class UserProfileNotifier extends StateNotifier<UserProfile?> {
  final LocalStorageService _storage;
  final FirestoreService _firestore;
  final String? _userId;

  UserProfileNotifier(this._storage, this._firestore, this._userId) 
      : super(_storage.getProfile()) {
    _init();
  }

  Future<void> _init() async {
    if (_userId != null) {
      final remoteProfile = await _firestore.getUserProfile(_userId!);
      if (remoteProfile != null) {
        await _storage.saveProfile(remoteProfile);
        if (mounted) {
          state = remoteProfile;
        }
      }
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    await _storage.saveProfile(profile);
    if (mounted) {
      state = profile;
    }
    
    if (_userId != null) {
      // Do not await the firestore save so it doesn't hang indefinitely 
      // if the client is offline, as Firebase queues writes locally.
      _firestore.saveUserProfile(_userId!, profile).catchError((e) {
        debugPrint('Failed to sync profile to firestore: $e');
      });
    }
  }

  Future<void> clearProfile() async {
    await _storage.saveProfile(const UserProfile(name: ''));
    if (mounted) {
      state = null;
    }
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

  void updateMessageText(String id, String newText) {
    state = [
      for (final msg in state)
        if (msg.id == id)
          ChatMessage(
            id: msg.id,
            role: msg.role,
            text: newText,
            timestamp: msg.timestamp,
            imagePath: msg.imagePath,
            actions: msg.actions,
            widgetType: msg.widgetType,
            widgetPayload: msg.widgetPayload,
            quickReplies: msg.quickReplies,
          )
        else
          msg
    ];
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

final chatHistoryListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) return [];

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserConversations(auth.user!.uid);
});

final specificChatHistoryProvider =
    FutureProvider.family<List<ChatMessage>, String>((
      ref,
      conversationId,
    ) async {
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
