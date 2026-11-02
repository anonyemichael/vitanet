import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Chat history list used inside the slide-in drawer.
class ChatHistoryContent extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const ChatHistoryContent({super.key, this.onClose});

  @override
  ConsumerState<ChatHistoryContent> createState() => _ChatHistoryContentState();
}

class _ChatHistoryContentState extends ConsumerState<ChatHistoryContent> {
  String _query = '';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];

  String _group(DateTime t) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(t.year, t.month, t.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff < 7) return 'This week';
    return t.year == now.year ? _monthNames[t.month - 1] : '${_monthNames[t.month - 1]} ${t.year}';
  }

  String _when(DateTime t) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(t.year, t.month, t.day))
        .inDays;
    if (diff == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    if (diff < 7) return _weekdays[t.weekday - 1];
    return '${t.day} ${_months[t.month - 1]}';
  }

  /// Dot colour and label from the conversation's stored triage level, if any.
  (Color, String) _level(Map<String, dynamic> chat) {
    final raw = (chat['triageLevel'] ?? chat['level'] ?? '').toString().toLowerCase();
    if (raw.contains('emerg') || raw.contains('urgent')) return (const Color(0xFFDC2626), 'Urgent');
    if (raw.contains('doctor')) return (const Color(0xFFF97316), 'See a doctor');
    if (raw.contains('pharm')) return (const Color(0xFFF59E0B), 'Pharmacist');
    if (raw.contains('self')) return (const Color(0xFF10B981), 'Self-care');
    return (const Color(0xFF64748B), 'Chat');
  }

  void _startNewChat() {
    widget.onClose?.call();
    ref.read(chatMessagesProvider.notifier).clear();
    ref.read(chatMessagesProvider.notifier).addGreeting();
    ref.read(aiServiceProvider).reset();
    ref.read(currentConversationIdProvider.notifier).state = const Uuid().v4();
  }

  Future<void> _open(String conversationId) async {
    ref.read(currentConversationIdProvider.notifier).state = conversationId;
    widget.onClose?.call();

    final auth = ref.read(authProvider);
    if (auth.user != null) {
      final firestoreService = ref.read(firestoreServiceProvider);
      final messagesNotifier = ref.read(chatMessagesProvider.notifier);
      final userProfile = ref.read(userProfileProvider);
      final aiService = ref.read(aiServiceProvider);

      final loadedMessages = await firestoreService.getChatHistory(auth.user!.uid, conversationId);
      messagesNotifier.setMessages(loadedMessages);
      aiService.loadHistory(loadedMessages, userProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final historyAsync = ref.watch(chatHistoryListProvider);
    final currentId = ref.watch(currentConversationIdProvider);
    final router = GoRouter.of(context);

    Widget footerLink(IconData icon, String label, VoidCallback onTap) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                Icon(icon, size: 20, color: p.inkSoft),
                const SizedBox(width: 12),
                Text(label, style: VnText.body(14, weight: FontWeight.w600, color: p.ink)),
              ]),
            ),
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const VitaNetLogo(size: 32),
              const SizedBox(width: 10),
              Expanded(child: Text('Your chats', style: VnText.heading(18, color: p.ink))),
            ]),
            const SizedBox(height: 16),
            VnButton(
              label: 'New chat',
              icon: Icons.add_rounded,
              height: 48,
              radius: 14,
              fontSize: 15,
              onPressed: _startNewChat,
            ),
            const SizedBox(height: 16),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.search_rounded, size: 18, color: p.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    style: VnText.body(14, color: p.ink),
                    decoration: InputDecoration(
                      hintText: 'Search chats',
                      hintStyle: VnText.body(14, color: p.muted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: historyAsync.when(
                loading: () => Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: p.brand),
                  ),
                ),
                error: (e, _) => _empty(p, 'Could not load your chats. Check your connection.'),
                data: (chats) {
                  final sorted = [...chats]
                    ..sort((a, b) {
                      final ta = (a['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final tb = (b['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
                      return tb.compareTo(ta);
                    });
                  final filtered = sorted
                      .where((c) =>
                          _query.isEmpty ||
                          (c['title'] as String? ?? '').toLowerCase().contains(_query))
                      .toList();
                  if (filtered.isEmpty) {
                    return _empty(
                        p,
                        _query.isEmpty
                            ? 'Your conversations and triage checks will appear here.'
                            : 'No chats match your search.');
                  }
                  final items = <Widget>[];
                  String? lastGroup;
                  for (final chat in filtered) {
                    final t = (chat['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final g = _group(t);
                    if (g != lastGroup) {
                      items.add(Padding(
                        padding: EdgeInsets.fromLTRB(8, lastGroup == null ? 6 : 12, 8, 6),
                        child: Text(g, style: VnText.body(12, weight: FontWeight.w700, color: p.muted)),
                      ));
                      lastGroup = g;
                    }
                    final id = chat['id'] as String;
                    final title = chat['title'] as String? ?? 'Consultation';
                    final (dot, label) = _level(chat);
                    final selected = id == currentId;
                    items.add(Semantics(
                      button: true,
                      selected: selected,
                      child: Material(
                        color: selected ? p.brandWash : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _open(id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: VnText.body(14, weight: FontWeight.w600, color: p.ink)),
                                  ),
                                ]),
                                const SizedBox(height: 2),
                                Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Text('$label · ${_when(t)}',
                                      style: VnText.body(12, color: p.muted)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ));
                  }
                  return ListView(padding: EdgeInsets.zero, children: items);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
              child: Column(children: [
                footerLink(Icons.history_rounded, 'All check history', () {
                  widget.onClose?.call();
                  router.push('/history');
                }),
                footerLink(Icons.settings_outlined, 'Settings', () {
                  widget.onClose?.call();
                  router.push('/settings');
                }),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(VnPalette p, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.forum_outlined, size: 36, color: p.faint),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: VnText.body(13, color: p.muted, height: 1.5)),
          ]),
        ),
      );
}

/// Drawer wrapper (316px, rounded right edge) around [ChatHistoryContent].
class ChatHistoryDrawer extends StatelessWidget {
  const ChatHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Drawer(
      width: 316,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: ChatHistoryContent(onClose: () => Navigator.of(context).pop()),
    );
  }
}
