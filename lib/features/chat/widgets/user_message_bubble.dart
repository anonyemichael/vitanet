import 'package:flutter/material.dart';
import 'dart:io';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/chat_message.dart';

class UserMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const UserMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(left: 64, right: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primary, // Changed to primary
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(4), // Flattened bottom right
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.imagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(message.imagePath!),
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                if (message.text.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.text.isNotEmpty)
                Text(
                  message.text,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary, // Changed to onPrimary
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
