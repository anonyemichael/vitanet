import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vitanet/data/models/chat_message.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Right-aligned teal bubble for the user's messages (20/20/6/20 radius).
class UserMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const UserMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 64),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: p.isDark ? const Color(0xFF0F766E) : p.brand,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (message.imagePath != null && !kIsWeb) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(message.imagePath!),
                          width: 200,
                          cacheWidth: 400,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.attach_file_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('Attachment', style: VnText.body(13, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                      if (message.text.isNotEmpty) const SizedBox(height: 8),
                    ],
                    if (message.text.isNotEmpty)
                      Text(
                        message.text,
                        style: VnText.body(15, color: Colors.white, height: 1.5),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
