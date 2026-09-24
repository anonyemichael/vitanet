import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
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
  
  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;
  final LayerLink _layerLink = LayerLink();
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _closeMenu();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to voice service changes for auto-submission
    final voiceService = ref.read(voiceServiceProvider);
    voiceService.addListener(_onVoiceServiceChanged);
  }

  void _onVoiceServiceChanged() {
    final voiceService = ref.read(voiceServiceProvider);
    // If it WAS listening, but is NOT listening now (e.g. auto stopped by silence)
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
    setState(() {
      _isComposing = widget.controller.text.trim().isNotEmpty || _selectedImagePath != null;
    });
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
      // The AI endpoint currently accepts images best. For text files we could extract text,
      // but for now we'll pass the file path to our sender which supports imagePath.
      // If the backend adds full PDF support, this path can be passed along identically.
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
      await voiceService.stopSpeaking(); // Stop AI speaking if user starts talking
      
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
              offset: const Offset(0, -170), // Opens above the button
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 220,
                  margin: const EdgeInsets.only(left: 16), // Align with input
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black87),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
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
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_selectedImagePath!),
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: context.colorScheme.onSurfaceVariant),
            onPressed: () {
              setState(() {
                _selectedImagePath = null;
                _isComposing = widget.controller.text.trim().isNotEmpty;
              });
            },
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedImagePath != null) _buildImagePreview(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.06) 
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 6),
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => RotationTransition(
                        turns: child.key == const ValueKey('open') 
                            ? Tween<double>(begin: -0.125, end: 0).animate(anim) 
                            : Tween<double>(begin: 0.125, end: 0).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Icon(
                        _isMenuOpen ? Icons.close_rounded : Icons.add_rounded,
                        key: ValueKey(_isMenuOpen ? 'open' : 'closed'),
                        color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        size: 24,
                      ),
                    ),
                    onPressed: _toggleMenu,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  decoration: InputDecoration(
                    hintText: 'Message AI...',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.only(top: 14, bottom: 14, left: 4, right: 8),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(isVoice: false),
                  maxLines: 5,
                  minLines: 1,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _isComposing || _isListening 
                        ? context.colorScheme.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isListening ? Icons.stop_rounded :
                      _isComposing ? Icons.arrow_upward_rounded : Icons.mic_rounded, 
                      color: _isComposing || _isListening 
                          ? context.colorScheme.onPrimary
                          : context.colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    onPressed: _isComposing ? () => _submit(isVoice: false) : _toggleListening,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
