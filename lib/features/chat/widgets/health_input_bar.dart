import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class HealthInputBar extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String, {String? imagePath}) onSend;

  const HealthInputBar({
    super.key,
    required this.controller,
    required this.onSend,
  });

  @override
  State<HealthInputBar> createState() => _HealthInputBarState();
}

class _HealthInputBarState extends State<HealthInputBar> {
  String? _selectedImagePath;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImagePath = image.path;
      });
    }
  }

  void _submit() {
    if (widget.controller.text.trim().isNotEmpty || _selectedImagePath != null) {
      widget.onSend(widget.controller.text, imagePath: _selectedImagePath);
      setState(() {
        _selectedImagePath = null;
      });
    }
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
            onPressed: () => setState(() => _selectedImagePath = null),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: Colors.transparent, 
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.add_rounded,
                color: context.colorScheme.primary,
                size: 24,
              ),
              onPressed: () {
                context.showSnack('Document attachments coming soon!');
              },
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isDark ? context.colorScheme.surfaceContainerHighest : const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? context.colorScheme.outlineVariant.withValues(alpha: 0.3) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(left: 16, right: 8, top: 10, bottom: 10),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) => _submit(),
                      maxLines: 5,
                      minLines: 1,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                    IconButton(
                      icon: Icon(
                        Icons.image_rounded,
                        color: context.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: _pickImage,
                    padding: const EdgeInsets.only(right: 12, bottom: 10, top: 10, left: 8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.send_rounded, 
                color: Colors.white,
                size: 18,
              ),
              onPressed: _submit,
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    ),
  ],
);
  }
}
