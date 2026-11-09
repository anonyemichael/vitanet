/// Small shared pieces for the staff sign-up screens (the portal itself uses
/// lib/features/portal/ui/clinical_ui.dart).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/features/auth/widgets/staff_ui.dart';
import 'package:vitanet/features/portal/data/hospital_api_service.dart';

/// "just now", "12 min ago", "3 h ago", "2 d ago", else "4 Mar".
String relativeTime(String? iso, {DateTime? now}) {
  if (iso == null || iso.isEmpty) return '';
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final diff = (now ?? DateTime.now()).toUtc().difference(t.toUtc());
  if (diff.inSeconds < 60) return 'just now'; // includes small clock skew
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return DateFormat('d MMM yyyy').format(t.toLocal());
}


class PortalEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  const PortalEmpty({super.key, required this.icon, required this.title, this.message});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, size: 26, color: p.muted),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: staffHeading(16, weight: FontWeight.w700, color: p.ink)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: staffBody(13, color: p.muted, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class PortalError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const PortalError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final t = p.tone(StaffTone.danger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.cloud_off_rounded, size: 26, color: t.strong),
          ),
          const SizedBox(height: 14),
          Text("Couldn't load this", style: staffHeading(16, weight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 6),
          Text(apiErrorMessage(error), textAlign: TextAlign.center, style: staffBody(13, color: p.muted, height: 1.45)),
          const SizedBox(height: 16),
          StaffButton('Retry', icon: Icons.refresh_rounded, expand: false, height: 44, onPressed: onRetry),
        ],
      ),
    );
  }
}

class PortalLoading extends StatelessWidget {
  const PortalLoading({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Semantics(
            label: 'Loading',
            child: CircularProgressIndicator(strokeWidth: 2.6, color: StaffPalette.of(context).accent),
          ),
        ),
      );
}

/// Standard sheet layout: title, scrollable body, action bar.
class PortalSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  const PortalSheet({super.key, required this.title, this.subtitle, required this.children, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: staffHeading(20, color: p.ink))),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: staffBody(13, color: p.muted)),
              ],
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
