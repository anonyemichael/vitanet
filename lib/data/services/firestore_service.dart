import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitanet/data/models/chat_message.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> saveChatHistory(String userId, String conversationId, List<ChatMessage> messages) async {
    try {
      if (userId.isEmpty || conversationId.isEmpty) return;
      
      final serializedMessages = messages.map((m) => m.toMap()).toList();
      
      // Save entire history under user's conversations subcollection
      await _firestore.collection('users').doc(userId).collection('conversations').doc(conversationId).set({
        'id': conversationId,
        'chatHistory': serializedMessages,
        'lastUpdated': FieldValue.serverTimestamp(),
        // Save first message text as title if available
        'title': messages.isNotEmpty ? messages.first.text : 'New Chat',
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving chat history: $e');
    }
  }

  Future<List<ChatMessage>> getChatHistory(String userId, String conversationId) async {
    try {
      if (userId.isEmpty || conversationId.isEmpty) return [];
      
      final doc = await _firestore.collection('users').doc(userId).collection('conversations').doc(conversationId).get();
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
      print('Error getting chat history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
    try {
      if (userId.isEmpty) return [];
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .orderBy('lastUpdated', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting user conversations: $e');
      return [];
    }
  }

  Future<void> deleteConversation(String userId, String conversationId) async {
    try {
      if (userId.isEmpty || conversationId.isEmpty) return;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .doc(conversationId)
          .delete();
    } catch (e) {
      print('Error deleting conversation: $e');
    }
  }
}
