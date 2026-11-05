import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';
import 'package:vitanet/data/models/chat_message.dart';
import 'package:vitanet/features/chat/widgets/chat_legos.dart';
import 'package:url_launcher/url_launcher.dart';

class AiMessageCard extends StatelessWidget {
  final ChatMessage message;

  const AiMessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final body = VnText.body(15, color: p.ink, height: 1.55);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'VitaNet AI',
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: p.surface,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: p.line),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('AI response copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: MarkdownBody(
                      data: message.text,
                      selectable: false,
                      styleSheet: MarkdownStyleSheet(
                        p: body,
                        strong: body.copyWith(fontWeight: FontWeight.w700),
                        em: body.copyWith(fontStyle: FontStyle.italic),
                        listBullet: body.copyWith(color: p.brand, fontWeight: FontWeight.w800),
                        a: body.copyWith(color: p.brand, fontWeight: FontWeight.w600),
                        h1: VnText.heading(18, color: p.ink),
                        h2: VnText.heading(17, weight: FontWeight.w700, color: p.ink),
                        h3: VnText.heading(16, weight: FontWeight.w700, color: p.ink),
                      ),
                      onTapLink: (text, href, title) async {
                        final url = href == null ? null : Uri.tryParse(href);
                        if (url != null) {
                          try {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          } catch (_) {}
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (message.widgetType != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _buildCustomWidget(context, message.widgetType!, message.widgetPayload ?? {}),
                ),
              if (message.actions != null && message.actions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.actions!.map((action) => _buildActionWidget(context, action)).toList(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: VnText.body(11, color: p.muted),
                ),
              ),
            ],
          ),
        ),
      ],
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
        final payload = action.payload;
        if (payload.isNotEmpty && payload.startsWith('http')) {
          final url = Uri.tryParse(payload);
          if (url != null) {
            try {
              await launchUrl(url, mode: LaunchMode.externalApplication);
              return;
            } catch (_) {}
          }
        }
        if (!context.mounted) return;
        context.showSnack('Action: ${action.label}');
      },
      icon: Icon(icon, size: 14),
      label: Text(action.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: VnPalette.of(context).brand,
        minimumSize: const Size(44, 44),
        side: BorderSide(color: VnPalette.of(context).brand),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }
}
