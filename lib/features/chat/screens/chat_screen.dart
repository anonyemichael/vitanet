import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/data/models/chat_message.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/data/services/voice_service.dart';

import 'package:vitanet/features/chat/widgets/ai_message_card.dart';
import 'package:vitanet/features/chat/widgets/chat_history_drawer.dart';
import 'package:vitanet/features/chat/widgets/lab_values_sheet.dart';
import 'package:vitanet/features/chat/widgets/typing_indicator.dart';
import 'package:vitanet/features/chat/widgets/user_message_bubble.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

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
    description: 'Start a guided symptom triage',
    icon: Icons.health_and_safety_outlined,
    prompt: 'I want to check my symptoms. Please ask structured triage questions.',
  ),
  _SlashCommand(
    trigger: 'medication',
    label: 'Medication help',
    description: 'Ask about a medicine or interaction',
    icon: Icons.medication_outlined,
    prompt: 'I have a question about medication usage and potential interactions.',
  ),
  _SlashCommand(
    trigger: 'lab',
    label: 'Lab interpretation',
    description: 'Explain blood tests or diagnostic values',
    icon: Icons.science_outlined,
    prompt: 'Please help me interpret my clinical lab values.',
  ),
  _SlashCommand(
    trigger: 'emergency',
    label: 'Emergency first-aid',
    description: 'Instant urgent care protocols',
    icon: Icons.emergency_outlined,
    prompt: 'This is an emergency. Provide immediate first-aid instructions.',
  ),
];

/// Clinically safe ChatScreen for VitaNet AI.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  static const _uuid = Uuid();

  bool _isFocused = false;
  bool _isComposing = false;
  bool _showSlashMenu = false;
  String _slashQuery = '';
  String? _attachedFilePath;
  String? _attachedFileName;
  bool _isVoiceListening = false;

  DateTime _lastScrollTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChange);
    _focusNode.addListener(_handleFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navBarVisibleProvider.notifier).state = true;
      if (ref.read(chatMessagesProvider).isEmpty) {
        ref.read(aiServiceProvider).reset();
      }
    });
  }

  void _handleFocusChange() {
    if (mounted && _isFocused != _focusNode.hasFocus) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  void _handleTextChange() {
    final text = _textController.text;
    final isSlash = text.startsWith('/');
    final query = isSlash ? text.substring(1).trim().toLowerCase() : '';

    final composing = text.trim().isNotEmpty || _attachedFilePath != null;
    if (composing != _isComposing || isSlash != _showSlashMenu || (isSlash && query != _slashQuery)) {
      setState(() {
        _isComposing = composing;
        _showSlashMenu = isSlash;
        _slashQuery = query;
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChange);
    _focusNode.removeListener(_handleFocusChange);
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _handleNewChat() {
    ref.read(chatMessagesProvider.notifier).clear();
    ref.read(aiServiceProvider).reset();
    ref.read(currentConversationIdProvider.notifier).state = const Uuid().v4();
    setState(() {
      _attachedFilePath = null;
      _attachedFileName = null;
      _textController.clear();
      _isComposing = false;
    });
  }

  void _checkProfileCompletionAndProceed(String text, {String? imagePath, bool isVoice = false}) {
    if (text.trim().isEmpty && imagePath == null && _attachedFilePath == null) return;

    final resolvedImagePath = imagePath ?? _attachedFilePath;

    final profile = ref.read(userProfileProvider);
    final needsCompletion = profile == null ||
        profile.bloodType == null ||
        profile.bloodType!.trim().isEmpty ||
        profile.weight == null ||
        profile.height == null ||
        profile.dob == null ||
        profile.dob!.trim().isEmpty;

    final lower = text.toLowerCase();
    final isSymptomRelated = lower.contains('symptom') ||
        lower.contains('headache') ||
        lower.contains('pain') ||
        lower.contains('sick') ||
        lower.contains('fever') ||
        ref.read(chatMessagesProvider).length <= 1;

    if (needsCompletion && isSymptomRelated) {
      showDialog(
        context: context,
        builder: (dialogContext) {
          final p = VnPalette.of(dialogContext);
          return VnDialog(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.brandTint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.badge_outlined, color: p.brand, size: 26),
              ),
              Text('Complete your health profile', style: VnText.heading(20, color: p.ink)),
              Text(
                'For accurate triage and safe dosing advice, add your date of birth, height, weight and blood type.',
                style: VnText.body(14, color: p.inkSoft, height: 1.55),
              ),
              Row(
                children: [
                  Expanded(
                    child: VnOutlineButton(
                      label: 'Continue anyway',
                      fontSize: 14,
                      background: p.surfaceAlt,
                      borderColor: Colors.transparent,
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _sendMessage(text, imagePath: resolvedImagePath, isVoice: isVoice);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: VnButton(
                      label: 'Update profile',
                      height: 52,
                      fontSize: 14,
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        context.push('/edit-profile');
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } else {
      _sendMessage(text, imagePath: resolvedImagePath, isVoice: isVoice);
    }
  }

  Future<void> _sendMessage(String text, {String? imagePath, bool isVoice = false}) async {
    final query = text.trim();
    if (query.isEmpty && imagePath == null) return;

    _textController.clear();
    setState(() {
      _attachedFilePath = null;
      _attachedFileName = null;
      _isComposing = false;
    });
    ref.read(quickRepliesProvider.notifier).state = [];

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      text: query.isEmpty ? 'Attached clinical document for analysis.' : query,
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
    final stream = aiService.getResponseStream(
      query.isEmpty ? 'Please analyze this clinical report or image in detail.' : query,
      base64Image: base64Image,
    );

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
      ref.read(isAiTypingProvider.notifier).state = false;
    }

    if (isVoice && fullResponse.isNotEmpty) {
      final voiceService = ref.read(voiceServiceProvider);
      final cleanText = fullResponse
          .replaceAll(RegExp(r'[*_#]+'), '')
          .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), 'a link');
      voiceService.speak(cleanText);
    }

    _scrollToBottom(force: true);

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

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;
    // Don't auto-scroll if user has intentionally scrolled up to read earlier history
    final isNearBottom =
        (_scrollController.position.maxScrollExtent - _scrollController.offset) < 160;
    if (!force && !isNearBottom) return;

    final now = DateTime.now();
    if (!force && now.difference(_lastScrollTime).inMilliseconds < 100) {
      return;
    }
    _lastScrollTime = now;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final target = _scrollController.position.maxScrollExtent;
        if (force) {
          _scrollController.jumpTo(target);
        } else {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        setState(() {
          _attachedFilePath = image.path;
          _attachedFileName = image.name;
          _isComposing = true;
        });
      }
    } catch (e) {
      debugPrint('Gallery pick error: $e');
    }
  }

  Future<void> _takePhotoWithCamera() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (image != null) {
        setState(() {
          _attachedFilePath = image.path;
          _attachedFileName = image.name;
          _isComposing = true;
        });
      }
    } catch (e) {
      debugPrint('Camera pick error: $e');
    }
  }

  Future<void> _pickDocumentFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _attachedFilePath = result.files.single.path;
          _attachedFileName = result.files.single.name;
          _isComposing = true;
        });
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  void _toggleVoiceRecording() async {
    final voiceService = ref.read(voiceServiceProvider);
    if (_isVoiceListening) {
      await voiceService.stopListening();
      setState(() => _isVoiceListening = false);
    } else {
      final available = await voiceService.initializeSpeech();
      if (!available) {
        if (mounted) context.showSnack('Speech recognition not available on this device');
        return;
      }
      setState(() => _isVoiceListening = true);
      voiceService.startListening((recognizedWords) {
        setState(() {
          _textController.text = recognizedWords;
          _isComposing = recognizedWords.trim().isNotEmpty;
        });
      });
    }
  }

  // ==========================================
  // SHEETS
  // ==========================================

  void _showAttachmentOptionsSheet(BuildContext context) {
    showVnSheet<void>(
      context,
      builder: (sheetContext) {
        final p = VnPalette.of(sheetContext);
        Widget tile(String label, IconData icon, Color wash, Color solid, VoidCallback onTap) =>
            Expanded(
              child: Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                child: Material(
                  color: p.isDark ? solid.withValues(alpha: 0.16) : wash,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onTap();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: solid,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(icon, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(label,
                              textAlign: TextAlign.center,
                              style: VnText.body(13, weight: FontWeight.w600, color: p.ink)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );

        Widget row(IconData icon, String title, String sub, VoidCallback onTap) => VnListRow(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: p.brand),
              ),
              title: title,
              subtitle: sub,
              onTap: () {
                Navigator.pop(sheetContext);
                onTap();
              },
            );

        return VnSheet(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add to your chat', style: VnText.heading(20, color: p.ink)),
                const SizedBox(height: 4),
                Text('VitaNet reads lab reports, prescriptions and photos of skin conditions.',
                    style: VnText.body(14, color: p.muted)),
              ],
            ),
            Row(
              children: [
                tile('Camera', Icons.photo_camera_outlined, const Color(0xFFF0FDFA),
                    const Color(0xFF0F766E), _takePhotoWithCamera),
                const SizedBox(width: 10),
                tile('Photo library', Icons.photo_library_outlined, const Color(0xFFF5F3FF),
                    const Color(0xFF6D28D9), _pickImageFromGallery),
                const SizedBox(width: 10),
                tile('PDF report', Icons.picture_as_pdf_outlined, const Color(0xFFEFF6FF),
                    const Color(0xFF1D4ED8), _pickDocumentFile),
              ],
            ),
            const VnSectionLabel('Lab results', padding: EdgeInsets.only(top: 4)),
            VnListGroup(
              children: [
                row(Icons.document_scanner_outlined, 'Photograph a lab report',
                    'Paper printout from the pathology lab', _takePhotoWithCamera),
                row(Icons.upload_file_outlined, 'Upload PDF or screenshot',
                    'Full blood count, lipid panel, kidney function', _pickDocumentFile),
                row(Icons.edit_note_rounded, 'Type values directly',
                    'WBC, haemoglobin, creatinine, cholesterol', _openLabValues),
              ],
            ),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: p.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Files are encrypted and never used to train models.',
                      style: VnText.body(12, color: p.muted)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _openLabValues() async {
    final prompt = await showLabValuesSheet(context);
    if (prompt != null && mounted) _checkProfileCompletionAndProceed(prompt);
  }

  void _showEmergencyFirstAidModal(BuildContext context) {
    const protocols = <(IconData, String, String, String)>[
      (Icons.favorite_border_rounded, 'Chest pain or heart attack',
          'Pressure, tightness, pain spreading to arm or jaw',
          'Possible heart attack: chest pain spreading to my arm. What do I do right now while waiting for help?'),
      (Icons.air_rounded, 'Choking or trouble breathing', 'Cannot speak, cough or breathe',
          'Someone is choking and cannot breathe. Give me step-by-step first aid now.'),
      (Icons.water_drop_outlined, 'Heavy bleeding', 'Bleeding that will not stop with pressure',
          'There is heavy bleeding that will not stop. Give me immediate first-aid steps.'),
      (Icons.psychology_alt_outlined, 'Stroke signs', 'Face drooping, arm weakness, slurred speech',
          'I think someone is having a stroke. What should I do right now?'),
      (Icons.local_fire_department_outlined, 'Burns', 'Scalds, fire or chemical burns',
          'Someone has a burn. Give me immediate first-aid steps.'),
    ];

    showVnSheet<void>(
      context,
      builder: (sheetContext) {
        final p = VnPalette.of(sheetContext);
        return VnSheet(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emergency first aid', style: VnText.heading(20, color: p.ink)),
                const SizedBox(height: 4),
                Text('If someone is in danger, call emergency services first.',
                    style: VnText.body(14, color: p.muted)),
              ],
            ),
            VnButton(
              label: 'Call emergency services (112)',
              icon: Icons.call_rounded,
              background: AppColors.danger,
              foreground: Colors.white,
              onPressed: () => LaunchHelpers.dialOrSnack(sheetContext, '112'),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const VnAlwaysScrollablePhysics(),
                child: VnListGroup(
                  children: [
                    for (final (icon, title, sub, prompt) in protocols)
                      VnListRow(
                        leading: VnIconTile(
                          icon: icon,
                          bg: const Color(0xFFFEE2E2),
                          fg: const Color(0xFFB91C1C),
                          size: 40,
                        ),
                        title: title,
                        subtitle: sub,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _sendMessage(prompt);
                        },
                      ),
                  ],
                ),
              ),
            ),
            VnOutlineButton(
              label: 'Open first-aid guides',
              icon: Icons.menu_book_outlined,
              borderColor: p.brand,
              foreground: p.brand,
              onPressed: () {
                Navigator.pop(sheetContext);
                context.push('/first-aid');
              },
            ),
          ],
        );
      },
    );
  }

  void _showMedicationInteractionModal(BuildContext context) {
    final med1Controller = TextEditingController();
    final med2Controller = TextEditingController();

    showVnSheet<void>(
      context,
      builder: (sheetContext) {
        final p = VnPalette.of(sheetContext);
        return VnSheet(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Medication help', style: VnText.heading(20, color: p.ink)),
                const SizedBox(height: 4),
                Text('Check whether two medicines are safe together, or ask about one.',
                    style: VnText.body(14, color: p.muted)),
              ],
            ),
            VnTextField(
              label: 'First medicine',
              controller: med1Controller,
              hint: 'e.g. Ibuprofen',
              prefixIcon: Icons.medication_outlined,
            ),
            VnTextField(
              label: 'Second medicine (optional)',
              controller: med2Controller,
              hint: 'e.g. Lisinopril',
              prefixIcon: Icons.medication_outlined,
            ),
            VnButton(
              label: 'Ask VitaNet AI',
              icon: Icons.auto_awesome_rounded,
              onPressed: () {
                final a = med1Controller.text.trim();
                final b = med2Controller.text.trim();
                if (a.isEmpty) return;
                Navigator.pop(sheetContext);
                _sendMessage(b.isEmpty
                    ? 'Tell me how to take $a safely: dose, common side effects and what to avoid.'
                    : 'Is it safe to take $a together with $b? Explain any interaction and what I should do.');
              },
            ),
            VnOutlineButton(
              label: 'Search the medicine library',
              icon: Icons.search_rounded,
              borderColor: Colors.transparent,
              background: p.surfaceAlt,
              onPressed: () {
                Navigator.pop(sheetContext);
                context.push('/resources/medicines');
              },
            ),
          ],
        );
      },
    ).whenComplete(() {
      med1Controller.dispose();
      med2Controller.dispose();
    });
  }

  void _showHealthProfileSummaryModal(BuildContext context) {
    final profile = ref.read(userProfileProvider);
    final vitals = ref.read(liveVitalsProvider);

    String orDash(String? v) => (v == null || v.trim().isEmpty) ? 'Not set' : v;
    String list(List<String>? l) => (l == null || l.isEmpty) ? 'None recorded' : l.join(', ');
    String num(double? v, String unit) => v == null ? 'Not set' : '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} $unit';

    showVnSheet<void>(
      context,
      builder: (sheetContext) {
        final p = VnPalette.of(sheetContext);
        final rows = <(String, String)>[
          ('Age', profile?.age?.toString() ?? 'Not set'),
          ('Sex', orDash(profile?.sex)),
          ('Blood type', orDash(profile?.bloodType)),
          ('Height', num(profile?.height, 'cm')),
          ('Weight', num(profile?.weight, 'kg')),
          ('Allergies', list(profile?.allergies)),
          ('Conditions', list(profile?.preExistingConditions)),
          ('Medications', list(profile?.medications)),
          if (vitals['heart_rate'] != null) ('Heart rate', '${vitals['heart_rate']!.round()} bpm'),
          if (vitals['blood_oxygen'] != null) ('Blood oxygen', '${vitals['blood_oxygen']!.round()}%'),
          if (vitals['temperature'] != null) ('Temperature', '${vitals['temperature']!.toStringAsFixed(1)} °C'),
        ];
        return VnSheet(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What VitaNet AI knows', style: VnText.heading(20, color: p.ink)),
                const SizedBox(height: 4),
                Text('This context personalises every answer in this chat.',
                    style: VnText.body(14, color: p.muted)),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const VnAlwaysScrollablePhysics(),
                child: VnListGroup(
                  children: [
                    for (final (k, v) in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(k, style: VnText.body(14, color: p.muted)),
                            ),
                            Expanded(
                              child: Text(v,
                                  style: VnText.body(14, weight: FontWeight.w600, color: p.ink)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            VnButton(
              label: 'Update medical profile',
              onPressed: () {
                Navigator.pop(sheetContext);
                context.push('/edit-profile?tab=medical');
              },
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // TOP HEADER
  // ==========================================

  Widget _buildTopHeader(BuildContext context) {
    final p = VnPalette.of(context);
    final liveVitals = ref.watch(liveVitalsProvider).isNotEmpty;
    final canPop = Navigator.of(context).canPop();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          Builder(
            builder: (scaffoldContext) => VnIconButton(
              icon: canPop ? Icons.chevron_left_rounded : Icons.menu_rounded,
              tooltip: canPop ? 'Back' : 'Chat history',
              iconSize: canPop ? 26 : 22,
              onPressed: () {
                if (canPop) {
                  Navigator.of(context).pop();
                } else {
                  Scaffold.of(scaffoldContext).openDrawer();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: true,
              label: 'VitaNet AI. View the health context used in this chat',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showHealthProfileSummaryModal(context),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: p.surface, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('VitaNet AI', style: VnText.heading(16, color: p.ink)),
                          Text(
                            liveVitals ? 'Reading your live vitals' : 'Personalised with your health profile',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VnText.body(12,
                                weight: FontWeight.w600,
                                color: p.isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          VnIconButton(
            icon: Icons.edit_square,
            tooltip: 'New chat',
            iconSize: 20,
            background: p.brandWash,
            foreground: p.brand,
            onPressed: _handleNewChat,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EMPTY STATE
  // ==========================================

  Widget _buildEmptyState(BuildContext context) {
    final p = VnPalette.of(context);
    final profile = ref.watch(userProfileProvider);
    final vitals = ref.watch(liveVitalsProvider);
    final rawName = profile?.name.trim().split(' ').first ?? '';

    Widget vital(String value, String unit) => Text.rich(
          TextSpan(children: [
            TextSpan(text: value, style: VnText.body(13, weight: FontWeight.w700, color: p.ink)),
            TextSpan(text: ' $unit', style: VnText.body(13, color: p.inkSoft)),
          ]),
        );

    final infoFg = p.isDark ? const Color(0xFF7DD3FC) : const Color(0xFF075985);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            rawName.isNotEmpty ? 'How are you feeling, $rawName?' : 'How are you feeling today?',
            textAlign: TextAlign.center,
            style: VnText.heading(22, color: p.ink, height: 1.25),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              'Describe your symptoms, ask about a medicine or share a lab result. I will ask follow-up questions like a triage nurse would.',
              textAlign: TextAlign.center,
              style: VnText.body(14, color: p.muted, height: 1.5),
            ),
          ),
          if (vitals.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: p.isDark ? const Color(0xFF0C2A3A) : const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.isDark ? const Color(0xFF155E75) : const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monitor_heart_outlined, size: 16, color: infoFg),
                      const SizedBox(width: 6),
                      Text('Vitals I am using',
                          style: VnText.body(12, weight: FontWeight.w700, color: infoFg)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 18,
                    runSpacing: 4,
                    children: [
                      if (vitals['heart_rate'] != null) vital(vitals['heart_rate']!.round().toString(), 'bpm'),
                      if (vitals['blood_oxygen'] != null) vital('${vitals['blood_oxygen']!.round()}%', 'SpO2'),
                      if (vitals['temperature'] != null) vital(vitals['temperature']!.toStringAsFixed(1), '°C'),
                      if (vitals['respiratory_rate'] != null)
                        vital(vitals['respiratory_rate']!.round().toString(), '/min'),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('AI can make mistakes. In an emergency call 112.',
              textAlign: TextAlign.center, style: VnText.body(12, color: p.muted)),
        ],
      ),
    );
  }

  // ==========================================
  // SHORTCUT CHIPS (ABOVE THE COMPOSER)
  // ==========================================

  Widget _buildShortcutChips(BuildContext context) {
    final p = VnPalette.of(context);
    final chips = <(IconData, String, VoidCallback)>[
      (
        Icons.health_and_safety_outlined,
        'Check symptoms',
        () => _checkProfileCompletionAndProceed(
              'I want to check my symptoms. Please ask structured triage questions to evaluate what I am experiencing.',
            ),
      ),
      (Icons.science_outlined, 'Lab results', _openLabValues),
      (Icons.medication_outlined, 'Medication help', () => _showMedicationInteractionModal(context)),
      (Icons.emergency_outlined, 'First aid', () => _showEmergencyFirstAidModal(context)),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (icon, label, onTap) = chips[i];
          return Center(
            child: Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: Material(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: p.inkSoft),
                        const SizedBox(width: 6),
                        Text(label, style: VnText.body(13, weight: FontWeight.w600, color: p.ink)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // COMPOSER
  // ==========================================

  Widget _buildComposer(BuildContext context) {
    final p = VnPalette.of(context);
    final isDark = p.isDark;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;
    // Leave room for the shell's floating bottom navigation bar without layout thrashing.
    final navInset =
        (!isDesktop && !keyboardOpen && !Navigator.of(context).canPop()) ? 74.0 : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      padding: EdgeInsets.only(top: 10, bottom: 18 + navInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showSlashMenu && _filteredCommands.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _SlashCommandList(commands: _filteredCommands, onSelected: _runCommand),
                ),
              _buildShortcutChips(context),
              const SizedBox(height: 10),
              if (_attachedFilePath != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  decoration: BoxDecoration(
                    color: p.brandWash,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.brandBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file_rounded, size: 16, color: p.brand),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _attachedFileName ?? 'Attached file',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VnText.body(13, weight: FontWeight.w600, color: p.ink),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove attachment',
                        icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                        onPressed: () => setState(() {
                          _attachedFilePath = null;
                          _attachedFileName = null;
                          _isComposing = _textController.text.trim().isNotEmpty;
                        }),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    VnIconButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Attach a photo, PDF or lab result',
                      size: 46,
                      radius: 10,
                      background: p.surfaceAlt,
                      onPressed: () => _showAttachmentOptionsSheet(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        constraints: const BoxConstraints(minHeight: 46),
                        padding: const EdgeInsets.only(left: 16, right: 1),
                        decoration: BoxDecoration(
                          color: p.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isFocused ? p.brand : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _focusNode,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  style: VnText.body(15, color: p.ink),
                                  decoration: InputDecoration(
                                    hintText: _isVoiceListening ? 'Listening…' : 'Describe how you feel…',
                                    hintStyle: VnText.body(15, color: p.faint),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (val) => _checkProfileCompletionAndProceed(val),
                                ),
                              ),
                            ),
                            VnIconButton(
                              icon: _isVoiceListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                              tooltip: _isVoiceListening ? 'Stop voice input' : 'Voice input',
                              size: 44,
                              radius: 22,
                              iconSize: 20,
                              background: _isVoiceListening ? p.dangerTint : null,
                              foreground: _isVoiceListening ? p.danger : p.inkSoft,
                              onPressed: _toggleVoiceRecording,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    VnIconButton(
                      icon: Icons.send_rounded,
                      tooltip: 'Send',
                      size: 46,
                      radius: 10,
                      iconSize: 20,
                      background: _isComposing ? p.brand : p.surfaceAlt,
                      foreground: _isComposing ? p.onBrand : p.faint,
                      onPressed: _isComposing
                          ? () => _checkProfileCompletionAndProceed(_textController.text)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ROOT BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isTyping = ref.watch(isAiTypingProvider);
    final quickReplies = ref.watch(quickRepliesProvider);
    final p = VnPalette.of(context);

    ref.listen<String?>(searchActionProvider, (previous, next) {
      if (next != null && next.isNotEmpty) {
        Future.microtask(() {
          _checkProfileCompletionAndProceed(next);
          ref.read(searchActionProvider.notifier).state = null;
        });
      }
    });

    String stamp(DateTime t) {
      final today = DateUtils.isSameDay(t, DateTime.now());
      final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      return today ? 'Today · $hm' : '${t.day}/${t.month}/${t.year} · $hm';
    }

    return Scaffold(
      backgroundColor: p.page,
      drawer: const ChatHistoryDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(context),
            Expanded(
              child: (messages.isEmpty && !isTyping)
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const VnAlwaysScrollablePhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: _buildEmptyState(context),
                        ),
                      ),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const VnAlwaysScrollablePhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                          itemCount: messages.length + (isTyping ? 1 : 0) + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              final first =
                                  messages.isNotEmpty ? messages.first.timestamp : DateTime.now();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: p.surfaceAlt,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(stamp(first),
                                        style: VnText.body(12, weight: FontWeight.w600, color: p.muted)),
                                  ),
                                ),
                              );
                            }
                            final i = index - 1;
                            if (i == messages.length && isTyping) {
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: RepaintBoundary(
                                  child: _MessageEntrance(
                                    key: ValueKey('typing-indicator'),
                                    child: TypingIndicator(),
                                  ),
                                ),
                              );
                            }
                            final message = messages[i];
                            final isRecent = DateTime.now().difference(message.timestamp).inMilliseconds < 1200;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: RepaintBoundary(
                                child: _MessageEntrance(
                                  key: ValueKey(message.id),
                                  animate: isRecent,
                                  child: message.role == MessageRole.user
                                      ? UserMessageBubble(message: message)
                                      : AiMessageCard(message: message),
                                ),
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
            _buildComposer(context),
          ],
        ),
      ),
    );
  }
}

/// Fade + slight rise entrance for newly received messages.
class _MessageEntrance extends StatefulWidget {
  const _MessageEntrance({super.key, required this.child, this.animate = true});

  final Widget child;
  final bool animate;

  @override
  State<_MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<_MessageEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _curve;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      )..forward();
      _curve = CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || _controller == null || _curve == null) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _curve!,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(_curve!),
        child: widget.child,
      ),
    );
  }
}

class _QuickReplyRow extends StatelessWidget {
  const _QuickReplyRow({required this.replies, required this.onSelected});

  final List<String> replies;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
        itemCount: replies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Center(
          child: Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(replies[i]),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.brand),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                child: Text(replies[i],
                    style: VnText.body(14, weight: FontWeight.w600, color: p.brand)),
              ),
            ),
          ),
        ),
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
    final p = VnPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final command in commands)
          InkWell(
            onTap: () => onSelected(command),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.brandTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(command.icon, size: 18, color: p.brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(command.label,
                            style: VnText.body(14, weight: FontWeight.w600, color: p.ink)),
                        Text(command.description, style: VnText.body(12, color: p.muted)),
                      ],
                    ),
                  ),
                  Text('/${command.trigger}', style: VnText.body(12, color: p.muted)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
