import 'dart:ui' as dart_ui;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/data/models/chat_message.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/data/services/firestore_service.dart';
import 'package:vitanet/data/services/voice_service.dart';

import 'package:vitanet/features/chat/widgets/ai_message_card.dart';
import 'package:vitanet/shared/widgets/premium_background.dart';
import 'package:vitanet/features/chat/widgets/chat_header.dart';
import 'package:vitanet/features/chat/widgets/chat_history_drawer.dart';
import 'package:vitanet/features/chat/widgets/health_input_bar.dart';
import 'package:vitanet/features/chat/widgets/typing_indicator.dart';
import 'package:vitanet/features/chat/widgets/user_message_bubble.dart';

/// A single slash command surfaced in the composer.
class _SlashCommand {
  const _SlashCommand({
    required this.trigger,
    required this.label,
    required this.description,
    required this.icon,
    required this.prompt,
  });

  final String trigger;
  final String label;
  final String description;
  final IconData icon;
  final String prompt;
}

const _slashCommands = <_SlashCommand>[
  _SlashCommand(
    trigger: 'symptoms',
    label: 'Check symptoms',
    description: 'Start a guided symptom check',
    icon: Icons.health_and_safety_outlined,
    prompt: 'I want to check my symptoms',
  ),
  _SlashCommand(
    trigger: 'medication',
    label: 'Medication help',
    description: 'Ask about a medicine or interaction',
    icon: Icons.medication_outlined,
    prompt: 'I have a question about a medication',
  ),
  _SlashCommand(
    trigger: 'appointment',
    label: 'Book appointment',
    description: 'Find a doctor or schedule a visit',
    icon: Icons.event_available_outlined,
    prompt: 'I want to book an appointment',
  ),
  _SlashCommand(
    trigger: 'history',
    label: 'Review history',
    description: 'Look back at a past conversation',
    icon: Icons.history_outlined,
    prompt: 'Show me my chat history',
  ),
  _SlashCommand(
    trigger: 'emergency',
    label: 'Emergency guidance',
    description: 'Get urgent care guidance now',
    icon: Icons.emergency_outlined,
    prompt: 'This might be an emergency',
  ),
];

/// The premium conversational symptom checker chat interface.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  static const _uuid = Uuid();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _showSlashMenu = false;
  String _slashQuery = '';

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(chatMessagesProvider).isEmpty) {
        ref.read(aiServiceProvider).reset();
      }
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChange);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final text = _textController.text;
    final isSlash = text.startsWith('/');
    setState(() {
      _showSlashMenu = isSlash;
      _slashQuery = isSlash ? text.substring(1).trim().toLowerCase() : '';
    });
  }

  List<_SlashCommand> get _filteredCommands {
    if (_slashQuery.isEmpty) return _slashCommands;
    return _slashCommands
        .where(
          (c) =>
              c.trigger.contains(_slashQuery) ||
              c.label.toLowerCase().contains(_slashQuery),
        )
        .toList();
  }

  void _runCommand(_SlashCommand command) {
    _textController.clear();
    setState(() => _showSlashMenu = false);
    _checkProfileCompletionAndProceed(command.prompt);
  }

  void _checkProfileCompletionAndProceed(String text, {String? imagePath, bool isVoice = false}) {
    if (text.trim().isEmpty && imagePath == null) return;

    final profile = ref.read(userProfileProvider);
    final needsCompletion = profile == null || 
        profile.bloodType == null || profile.bloodType!.trim().isEmpty ||
        profile.weight == null || profile.height == null ||
        profile.dob == null || profile.dob!.trim().isEmpty;

    final isSymptomRelated = text.toLowerCase().contains('symptom') || 
        text.toLowerCase().contains('headache') || 
        text.toLowerCase().contains('pain') ||
        text.toLowerCase().contains('sick') ||
        ref.read(chatMessagesProvider).length <= 1; // Greeting is 1

    if (needsCompletion && isSymptomRelated) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Your Profile'),
          content: const Text('For an accurate AI health assessment, please update your profile with your age, weight, height, and blood type.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _sendMessage(text, imagePath: imagePath, isVoice: isVoice);
              },
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/edit-profile');
              },
              child: const Text('Update Profile'),
            ),
          ],
        ),
      );
    } else {
      _sendMessage(text, imagePath: imagePath, isVoice: isVoice);
    }
  }

  Future<void> _sendMessage(String text, {String? imagePath, bool isVoice = false}) async {
    if (text.trim().isEmpty && imagePath == null) return;

    _textController.clear();
    ref.read(quickRepliesProvider.notifier).state = [];

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      text: text.trim(),
      timestamp: DateTime.now(),
      imagePath: imagePath,
    );
    ref.read(chatMessagesProvider.notifier).addMessage(userMessage);
    _scrollToBottom();

    ref.read(isAiTypingProvider.notifier).state = true;

    String? base64Image;
    if (imagePath != null) {
      try {
        final bytes = await File(imagePath).readAsBytes();
        base64Image = base64Encode(bytes);
      } catch (e) {
        debugPrint('Error encoding image: $e');
      }
    }

    final aiService = ref.read(aiServiceProvider);
    final stream = aiService.getResponseStream(text.trim(), base64Image: base64Image);
    
    final responseId = _uuid.v4();
    bool isFirst = true;
    String fullResponse = '';

    await for (final chunk in stream) {
      fullResponse = chunk;
      if (isFirst) {
        ref.read(chatMessagesProvider.notifier).addMessage(ChatMessage(
          id: responseId,
          role: MessageRole.assistant,
          text: chunk,
          timestamp: DateTime.now(),
        ));
        isFirst = false;
        ref.read(isAiTypingProvider.notifier).state = false;
      } else {
        ref.read(chatMessagesProvider.notifier).updateMessageText(responseId, chunk);
      }
      _scrollToBottom();
    }

    if (isFirst) {
      // In case the stream was empty or failed immediately
      ref.read(isAiTypingProvider.notifier).state = false;
    }

    if (isVoice && fullResponse.isNotEmpty) {
      final voiceService = ref.read(voiceServiceProvider);
      final cleanText = fullResponse
          .replaceAll(RegExp(r'[*_#]+'), '')
          .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), 'a link');
      voiceService.speak(cleanText);
    }

    // TODO: Quick replies can be injected here if needed

    _scrollToBottom();

    // Save to Firestore
    final auth = ref.read(authProvider);
    if (auth.user != null) {
      final currentMessages = ref.read(chatMessagesProvider);
      final conversationId = ref.read(currentConversationIdProvider);
      ref
          .read(firestoreServiceProvider)
          .saveChatHistory(auth.user!.uid, conversationId, currentMessages);
      ref.invalidate(chatHistoryListProvider);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isTyping = ref.watch(isAiTypingProvider);
    final quickReplies = ref.watch(quickRepliesProvider);
    final colorScheme = context.colorScheme;

    ref.listen<String?>(searchActionProvider, (previous, next) {
      if (next != null && next.isNotEmpty) {
        Future.microtask(() {
          _checkProfileCompletionAndProceed(next);
          ref.read(searchActionProvider.notifier).state = null;
        });
      }
    });

    final composer = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _Composer(
          showSlashMenu: _showSlashMenu,
          commands: _filteredCommands,
          onCommandSelected: _runCommand,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HealthInputBar(
                controller: _textController,
                onSend: _checkProfileCompletionAndProceed,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0, top: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 12,
                      color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI can make mistakes. Please verify medical information.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent, // Required to see PremiumBackground
      extendBodyBehindAppBar: true,
      appBar: ChatHeader(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        onNewChatPressed: () {
          ref.read(chatMessagesProvider.notifier).clear();
          ref.read(aiServiceProvider).reset();
          ref.read(currentConversationIdProvider.notifier).state =
              const Uuid().v4();
        },
        onProfilePressed: () {
          context.showSnack('Profile not implemented yet');
        },
      ),
      drawer: const ChatHistoryDrawer(),
      body: PremiumBackground(
        child: messages.isEmpty && !isTyping
            ? Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _EmptyState(),
                      const SizedBox(height: 32),
                      composer,
                    ],
                  ),
                ),
              )
            : Column(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          top: kToolbarHeight +
                              MediaQuery.of(context).padding.top +
                              AppSpacing.lg,
                          left: AppSpacing.md,
                          right: AppSpacing.md,
                          bottom: 120,
                        ),
                        itemCount: messages.length + (isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length && isTyping) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.md),
                              child: _MessageEntrance(
                                key: ValueKey('typing-indicator'),
                                child: TypingIndicator(),
                              ),
                            );
                          }

                          final message = messages[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _MessageEntrance(
                              key: ValueKey(message.id),
                              child: message.role == MessageRole.user
                                  ? UserMessageBubble(message: message)
                                  : AiMessageCard(message: message),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (quickReplies.isNotEmpty)
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _QuickReplyRow(
                        replies: quickReplies,
                        onSelected: _checkProfileCompletionAndProceed,
                      ),
                    ),
                  ),
                composer,
              ],
            ),
      ),
    );
  }
}
/// One-shot fade + rise entrance animation for chat bubbles.
///
/// Keyed by message id so existing items in the list are never
/// re-animated when the list rebuilds for unrelated state changes.
class _MessageEntrance extends StatefulWidget {
  const _MessageEntrance({required super.key, required this.child});

  final Widget child;

  @override
  State<_MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<_MessageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Flat, low-contrast quick reply chips — one accent used sparingly.
class _QuickReplyRow extends StatelessWidget {
  const _QuickReplyRow({required this.replies, required this.onSelected});

  final List<String> replies;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: replies
              .map(
                (reply) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onSelected(reply),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          reply,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// Flat, bordered composer. Expands upward to show a slash command
/// list when the input begins with "/" — no elevation tricks, no
/// background clutter, just a single quiet accent on the icon chip.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.child,
    required this.showSlashMenu,
    required this.commands,
    required this.onCommandSelected,
  });

  final Widget child;
  final bool showSlashMenu;
  final List<_SlashCommand> commands;
  final ValueChanged<_SlashCommand> onCommandSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isKeyboardOpen = MediaQueryData.fromView(View.of(context)).viewInsets.bottom > 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: isKeyboardOpen 
            ? 10 
            : MediaQuery.of(context).padding.bottom + 24, // Padding for bottom nav bar when keyboard is closed
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.bottomCenter,
            child: showSlashMenu && commands.isNotEmpty
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ],
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: _SlashCommandList(
                      commands: commands,
                      onSelected: onCommandSelected,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerStatefulWidget {
  const _EmptyState();

  @override
  ConsumerState<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends ConsumerState<_EmptyState> {
  late String _greetingPrefix;

  @override
  void initState() {
    super.initState();
    final greetings = [
      'How are you feeling today',
      'What\'s on your mind',
      'How can I support your health',
      'Ready to check in on your health',
      'What would you like to discuss',
    ];
    greetings.shuffle();
    _greetingPrefix = greetings.first;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final userName = profile?.name?.split(' ').first ?? 'Anony';
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32).copyWith(
        top: MediaQuery.of(context).size.height * 0.20,
      ),
      child: Text(
        '$_greetingPrefix, $userName?',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w500,
          color: context.isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SlashCommandList extends StatelessWidget {
  const _SlashCommandList({required this.commands, required this.onSelected});

  final List<_SlashCommand> commands;
  final ValueChanged<_SlashCommand> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: commands
          .map(
            (command) => InkWell(
              onTap: () => onSelected(command),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        command.icon,
                        size: 17,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            command.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            command.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '/${command.trigger}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}