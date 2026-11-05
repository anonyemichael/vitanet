import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/data/services/voice_service.dart';

class HealthInputBar extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final void Function(String, {String? imagePath, bool isVoice}) onSend;

  const HealthInputBar({
    super.key,
    required this.controller,
    required this.onSend,
  });

  @override
  ConsumerState<HealthInputBar> createState() => _HealthInputBarState();
}

class _HealthInputBarState extends ConsumerState<HealthInputBar> {
  String? _selectedImagePath;
  final ImagePicker _picker = ImagePicker();
  bool _isComposing = false;
  bool _isListening = false;
  bool _isFocused = false;
  late final FocusNode _focusNode;

  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _closeMenu();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    try {
      ref.read(voiceServiceProvider).removeListener(_onVoiceServiceChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final voiceService = ref.read(voiceServiceProvider);
    voiceService.removeListener(_onVoiceServiceChanged);
    voiceService.addListener(_onVoiceServiceChanged);
  }

  void _onVoiceServiceChanged() {
    final voiceService = ref.read(voiceServiceProvider);
    if (_isListening && !voiceService.isListening) {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
        if (widget.controller.text.trim().isNotEmpty) {
          _submit(isVoice: true);
        }
      }
    }
  }

  void _onTextChanged() {
    final composing = widget.controller.text.trim().isNotEmpty || _selectedImagePath != null;
    if (composing != _isComposing) {
      setState(() {
        _isComposing = composing;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImagePath = image.path;
        _isComposing = true;
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedImagePath = image.path;
        _isComposing = true;
      });
    }
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'txt', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _selectedImagePath = result.files.single.path;
        _isComposing = true;
      });
    }
  }

  void _submit({bool isVoice = false}) {
    if (widget.controller.text.trim().isNotEmpty || _selectedImagePath != null) {
      widget.onSend(widget.controller.text, imagePath: _selectedImagePath, isVoice: isVoice);
      setState(() {
        _selectedImagePath = null;
        _isComposing = false;
        widget.controller.clear();
      });
    }
  }

  Future<void> _toggleListening() async {
    final voiceService = ref.read(voiceServiceProvider);

    if (_isListening) {
      await voiceService.stopListening();
      setState(() {
        _isListening = false;
      });
      if (widget.controller.text.trim().isNotEmpty) {
        _submit(isVoice: true);
      }
    } else {
      await voiceService.stopSpeaking();
      setState(() {
        _isListening = true;
      });
      await voiceService.startListening((recognizedText) {
        if (recognizedText.isNotEmpty) {
          widget.controller.text = recognizedText;
        }
      });
    }
  }

  void _closeMenu() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    if (mounted) {
      setState(() {
        _isMenuOpen = false;
      });
    }
  }

  void _openMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isMenuOpen = true;
    });
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  OverlayEntry _createOverlayEntry() {
    final isDark = context.isDark;
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMenu,
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Positioned(
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, -170),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      _buildMenuItem(Icons.image_outlined, 'Upload image', () {
                        _closeMenu();
                        _pickImage();
                      }),
                      _buildMenuItem(Icons.camera_alt_outlined, 'Take photo', () {
                        _closeMenu();
                        _takePhoto();
                      }),
                      _buildMenuItem(Icons.description_outlined, 'Upload document', () {
                        _closeMenu();
                        _pickDocument();
                      }),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap) {
    final isDark = context.isDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: const Color(0xFF0D9488),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_selectedImagePath!),
              width: 56,
              height: 56,
              cacheWidth: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: context.colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              setState(() {
                _selectedImagePath = null;
                _isComposing = widget.controller.text.trim().isNotEmpty;
              });
            },
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
         event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        // Shift + Enter: allow newline to be inserted
        return KeyEventResult.ignored;
      } else {
        // Enter without Shift: Submit message cleanly
        if (widget.controller.text.trim().isNotEmpty || _selectedImagePath != null) {
          _submit(isVoice: false);
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = _isFocused
        ? const Color(0xFF0D9488)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedImagePath != null) _buildImagePreview(),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : const Color(0x0A0F172A),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.14)
                    : const Color(0x050F172A),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Row: Multi-Row Text Input with Enter-to-Send
              Focus(
                onKeyEvent: _handleKeyEvent,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  minLines: 2,
                  maxLines: 6,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    height: 1.45,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe your symptoms, upload a lab result, or ask a health question...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    isDense: true,
                  ),
                ),
              ),

              // Bottom Row: Action Toolbar (Attach, Voice, Submit)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    // Attachment Action in 36x36 Circular IconButton
                    CompositedTransformTarget(
                      link: _layerLink,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isMenuOpen
                              ? const Color(0xFF0D9488).withValues(alpha: 0.12)
                              : Colors.transparent,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: IconButton(
                            tooltip: 'Attach file or image',
                            splashRadius: 18,
                            icon: Icon(
                              _isMenuOpen ? Icons.close_rounded : Icons.attach_file_rounded,
                              size: 19,
                              color: _isMenuOpen
                                  ? const Color(0xFF0D9488)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            onPressed: _toggleMenu,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            style: IconButton.styleFrom(
                              hoverColor: isDark
                                  ? const Color(0xFF334155).withValues(alpha: 0.5)
                                  : const Color(0xFFF1F5F9),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Voice Dictation Action in 36x36 Circular IconButton
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening
                            ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                            : Colors.transparent,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          tooltip: _isListening ? 'Stop listening' : 'Voice dictation',
                          splashRadius: 18,
                          icon: Icon(
                            _isListening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                            size: 19,
                            color: _isListening
                                ? const Color(0xFFEF4444)
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          onPressed: _toggleListening,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          style: IconButton.styleFrom(
                            hoverColor: isDark
                                ? const Color(0xFF334155).withValues(alpha: 0.5)
                                : const Color(0xFFF1F5F9),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Clean 36x36 Dynamic Submit Button (BorderRadius.circular(12))
                    MouseRegion(
                      cursor: (_isComposing || _isListening)
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (_isComposing || _isListening)
                              ? const Color(0xFF0D9488)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: (_isComposing || _isListening)
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _isComposing
                                ? () => _submit(isVoice: false)
                                : (_isListening ? _toggleListening : null),
                            child: Center(
                              child: Icon(
                                _isListening
                                    ? Icons.stop_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 18,
                                color: (_isComposing || _isListening)
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
