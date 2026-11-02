import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:vitanet/data/models/chat_message.dart';
import 'package:vitanet/data/models/user_profile.dart';

class FirestoreService {
  FirebaseFirestore? _firestore;

  FirestoreService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore? get _db {
    if (_firestore != null) return _firestore;
    if (Firebase.apps.isNotEmpty) {
      try {
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        debugPrint('Firestore instance initialization: $e');
      }
    }
    return _firestore;
  }

  Future<void> saveUserProfile(String userId, UserProfile profile) async {
    try {
      final db = _db;
      if (db == null || userId.isEmpty) return;
      await db.collection('users').doc(userId).set(
        profile.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error saving user profile: $e');
    }
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final db = _db;
      if (db == null || userId.isEmpty) return null;
      final doc = await db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> saveChatHistory(String userId, String conversationId, List<ChatMessage> messages) async {
    try {
      final db = _db;
      if (db == null || userId.isEmpty || conversationId.isEmpty) return;
      
      final serializedMessages = messages.map((m) => m.toMap()).toList();
      
      // Save entire history under user's conversations subcollection
      await db.collection('users').doc(userId).collection('conversations').doc(conversationId).set({
        'id': conversationId,
        'chatHistory': serializedMessages,
        'lastUpdated': FieldValue.serverTimestamp(),
        // Save first message text as title if available
        'title': messages.isNotEmpty ? messages.first.text : 'New Chat',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving chat history: $e');
    }
  }

  Future<List<ChatMessage>> getChatHistory(String userId, String conversationId) async {
    try {
      final db = _db;
      if (db == null || userId.isEmpty || conversationId.isEmpty) return [];
      
      final doc = await db.collection('users').doc(userId).collection('conversations').doc(conversationId).get();
      if (!doc.exists || doc.data() == null) return [];
      
      final data = doc.data()!;
      if (data.containsKey('chatHistory')) {
        final List<dynamic> historyData = data['chatHistory'];
        return historyData
            .map((item) => ChatMessage.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting chat history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
    try {
      final db = _db;
      if (db == null || userId.isEmpty) return [];
      final querySnapshot = await db
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .orderBy('lastUpdated', descending: true)
          .get()
          .timeout(const Duration(milliseconds: 2500));

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting user conversations (timeout or error): $e');
      return [];
    }
  }

  Future<void> deleteConversation(String userId, String conversationId) async {
    try {
      final db = _db;
      if (db == null || userId.isEmpty || conversationId.isEmpty) return;
      await db
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .doc(conversationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }
}
