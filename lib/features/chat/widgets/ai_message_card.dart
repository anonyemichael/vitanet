import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/chat_message.dart';
import 'package:vitanet/features/chat/widgets/chat_legos.dart';
import 'package:url_launcher/url_launcher.dart';

class AiMessageCard extends StatelessWidget {
  final ChatMessage message;

  const AiMessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl, left: 16, right: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark 
                  ? context.colorScheme.surface.withValues(alpha: 0.6) 
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
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
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'VitaNet AI',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Markdown Content
                MarkdownBody(
                  data: message.text,
                  styleSheet: MarkdownStyleSheet(
                    p: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurface,
                      height: 1.6,
                      fontSize: 14.5,
                    ),
                    strong: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    listBullet: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                    h1: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    h2: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                
                // Custom Embedded Cards
                if (message.widgetType != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: _buildCustomWidget(context, message.widgetType!, message.widgetPayload ?? {}),
                  ),
                  
                // Actions
                if (message.actions != null && message.actions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: message.actions!.map((action) => _buildActionWidget(context, action)).toList(),
                    ),
                  ),
                  
                // Footer Disclaimer
                const SizedBox(height: 20),
                Divider(
                  height: 1,
                  color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'AI-generated health guidance. Always consult a real doctor.',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomWidget(BuildContext context, String type, Map<String, dynamic> payload) {
    switch (type) {
      case 'hospital_recommendation':
        return HospitalRecommendationCard(payload: payload);
      case 'heart_rate_check':
        return HeartRateCheckCard(payload: payload);
      case 'heart_rate_result':
        return HeartRateResultCard(payload: payload);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionWidget(BuildContext context, ChatAction action) {
    IconData icon;
    switch (action.type) {
      case 'call':
        icon = Icons.call_outlined;
        break;
      case 'directions':
        icon = Icons.navigation_outlined;
        break;
      case 'notify':
        icon = Icons.person_outline_rounded;
        break;
      case 'article':
        icon = Icons.article_rounded;
        break;
      case 'link':
        icon = Icons.open_in_new_rounded;
        break;
      case 'assessment':
        icon = Icons.health_and_safety_rounded;
        break;
      default:
        icon = Icons.touch_app_rounded;
    }

    return OutlinedButton.icon(
      onPressed: () async {
        if (action.payload != null && action.payload!.isNotEmpty && action.payload!.startsWith('http')) {
          final url = Uri.tryParse(action.payload!);
          if (url != null) {
            try {
              await launchUrl(url, mode: LaunchMode.externalApplication);
              return;
            } catch (_) {}
          }
        }
        context.showSnack('Action: ${action.label}');
      },
      icon: Icon(icon, size: 14),
      label: Text(action.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF3B82F6),
        side: BorderSide(color: context.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }
}
