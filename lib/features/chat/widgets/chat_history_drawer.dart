import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/auth_provider.dart';
import 'package:vitanet/data/providers/providers.dart';

class ChatHistoryDrawer extends ConsumerWidget {
  const ChatHistoryDrawer({super.key});

  String _getGroupLabel(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    final difference = today.difference(date).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference <= 7) return 'Previous 7 Days';
    if (difference <= 30) return 'Previous 30 Days';
    return 'Older';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(chatHistoryListProvider);
    final isDark = context.isDark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F8),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Claude-like minimal header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chats',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_comment_rounded,
                      size: 20,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close drawer
                      ref.read(chatMessagesProvider.notifier).clear();
                      ref.read(chatMessagesProvider.notifier).addGreeting();
                      ref.read(aiServiceProvider).reset();
                      ref.read(currentConversationIdProvider.notifier).state = const Uuid().v4();
                    },
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, st) => const Center(child: Text('Error loading history')),
                data: (history) {
                  if (history.isEmpty) {
                    return Center(
                      child: Text(
                        'No previous chats',
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    );
                  }

                  // Sort history descending by date just in case
                  final sortedHistory = List<Map<String, dynamic>>.from(history)
                    ..sort((a, b) {
                      final timeA = (a['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final timeB = (b['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
                      return timeB.compareTo(timeA);
                    });

                  // Group by date categories
                  final Map<String, List<Map<String, dynamic>>> grouped = {};
                  for (var chat in sortedHistory) {
                    final timestamp = (chat['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final group = _getGroupLabel(timestamp);
                    grouped.putIfAbsent(group, () => []).add(chat);
                  }

                  final List<Widget> listItems = [];
                  for (var group in grouped.entries) {
                    // Group Header
                    listItems.add(
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text(
                          group.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                    );

                    // Group Items
                    for (var chat in group.value) {
                      final title = chat['title'] as String? ?? 'Consultation';
                      final conversationId = chat['id'] as String;
                      final isSelected = ref.read(currentConversationIdProvider) == conversationId;

                      listItems.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              ref.read(currentConversationIdProvider.notifier).state = conversationId;

                              final auth = ref.read(authProvider);
                              if (auth.user != null) {
                                final firestoreService = ref.read(firestoreServiceProvider);
                                final messagesNotifier = ref.read(chatMessagesProvider.notifier);
                                final userProfile = ref.read(userProfileProvider);
                                final aiService = ref.read(aiServiceProvider);
                                
                                Navigator.pop(context);
                                
                                final loadedMessages = await firestoreService.getChatHistory(auth.user!.uid, conversationId);
                                if (!context.mounted) return;
                                
                                messagesNotifier.state = loadedMessages;
                                aiService.loadHistory(loadedMessages, userProfile);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: listItems,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
