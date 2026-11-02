import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/data/services/referral_service.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Shows where a hospital referral stands, in plain language, with
/// directions / call / cancel actions. Refreshes every 30 s while visible.
class ReferralStatusCard extends ConsumerStatefulWidget {
  final Referral referral;

  /// Hospital details (coords/phone) if already known; otherwise looked up
  /// from the nearby facilities list.
  final Facility? facility;

  /// Shown as "Find another hospital" when the referral was declined.
  final VoidCallback? onFindAnother;

  /// Poll interval; null disables auto-refresh.
  final Duration? refreshEvery;

  const ReferralStatusCard({
    super.key,
    required this.referral,
    this.facility,
    this.onFindAnother,
    this.refreshEvery = const Duration(seconds: 30),
  });

  static String hospitalLabel(Referral r) =>
      (r.hospitalName?.trim().isNotEmpty ?? false) ? r.hospitalName!.trim() : 'the hospital';

  /// Main status line for [r].
  static String headline(Referral r) {
    final h = hospitalLabel(r);
    switch (r.status) {
      case ReferralStatus.newRef:
        return 'Sent — waiting for $h to respond';
      case ReferralStatus.accepted:
        final c = r.caseInfo;
        final b = StringBuffer('Accepted — go to $h Emergency');
        final who = c?.assigneeName?.trim();
        if (who != null && who.isNotEmpty) b.write('; ask for $who');
        final where = [
          if (c?.wardName?.trim().isNotEmpty ?? false) c!.wardName!.trim(),
          if (c?.bed?.trim().isNotEmpty ?? false) 'bed ${c!.bed!.trim()}',
        ];
        if (where.isNotEmpty) b.write(' (${where.join(', ')})');
        return b.toString();
      case ReferralStatus.declined:
        return '$h could not take this referral';
      case ReferralStatus.arrived:
        return 'Visit completed';
      case ReferralStatus.cancelled:
        return 'Referral cancelled';
      default:
        return 'Status: ${r.status}';
    }
  }

  @override
  ConsumerState<ReferralStatusCard> createState() => _ReferralStatusCardState();
}

class _ReferralStatusCardState extends ConsumerState<ReferralStatusCard> {
  Timer? _timer;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant ReferralStatusCard old) {
    super.didUpdateWidget(old);
    if (old.refreshEvery != widget.refreshEvery || old.referral.isOpen != widget.referral.isOpen) {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final every = widget.refreshEvery;
    // Only poll while the hospital may still change the status.
    if (every == null || !widget.referral.isOpen) return;
    _timer = Timer.periodic(every, (_) {
      if (mounted) ref.invalidate(myReferralsProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Facility? _facility() {
    if (widget.facility != null) return widget.facility;
    final list = ref.watch(nearbyFacilitiesProvider).valueOrNull;
    if (list == null) return null;
    for (final f in list) {
      if (f.id == widget.referral.hospitalId) return f;
    }
    return null;
  }

  void _directions(Facility? f) {
    final r = widget.referral;
    final url = (f?.latitude != null && f?.longitude != null)
        ? 'https://www.google.com/maps/dir/?api=1&destination=${f!.latitude},${f.longitude}'
        : 'https://www.google.com/maps/search/?api=1&query='
            '${Uri.encodeComponent('${f?.name ?? r.hospitalName ?? 'hospital'} emergency')}';
    LaunchHelpers.openUrlOrSnack(context, url);
  }

  Future<void> _cancel() async {
    final h = ReferralStatusCard.hospitalLabel(widget.referral);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel referral?'),
        content: Text('$h will no longer see your summary as an incoming referral.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel referral')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(referralServiceProvider).cancel(widget.referral.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral cancelled')));
    } on ReferralException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
        ref.invalidate(myReferralsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final r = widget.referral;
    final f = _facility();
    final phone = f?.phoneNumber?.trim();

    final (Color bg, Color fg, IconData icon) = switch (r.status) {
      ReferralStatus.accepted => (const Color(0xFFD1FAE5), const Color(0xFF047857), Icons.check_circle_outline),
      ReferralStatus.declined => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C), Icons.cancel_outlined),
      ReferralStatus.arrived => (const Color(0xFFCCFBF1), const Color(0xFF0F766E), Icons.task_alt_rounded),
      ReferralStatus.cancelled => (p.surfaceAlt, p.muted, Icons.block_outlined),
      _ => (const Color(0xFFFEF3C7), const Color(0xFFB45309), Icons.schedule_rounded),
    };

    final eta = r.etaMinutes ?? f?.etaMinutes;

    return VnCard(
      padding: const EdgeInsets.all(18),
      semanticLabel: 'Hospital referral. ${ReferralStatusCard.headline(r)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VnIconTile(icon: icon, bg: bg, fg: fg, size: 44, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOSPITAL REFERRAL',
                        style: VnText.body(11, weight: FontWeight.w800, letterSpacing: 0.6, color: p.muted)),
                    const SizedBox(height: 4),
                    Text(ReferralStatusCard.headline(r),
                        style: VnText.body(15, weight: FontWeight.w700, color: p.ink, height: 1.35)),
                    if (r.status == ReferralStatus.declined &&
                        (r.declineReason?.trim().isNotEmpty ?? false)) ...[
                      const SizedBox(height: 6),
                      Text('Reason: ${r.declineReason!.trim()}',
                          style: VnText.body(13, color: p.inkSoft, height: 1.4)),
                    ],
                    if (eta != null && r.isOpen) ...[
                      const SizedBox(height: 6),
                      Text('About $eta min away by road',
                          style: VnText.body(13, color: p.muted)),
                    ],
                    if (r.status == ReferralStatus.newRef) ...[
                      const SizedBox(height: 6),
                      Text('If you feel worse, call 112 — don\'t wait for a reply.',
                          style: VnText.body(12, color: p.muted, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (r.isOpen || r.status == ReferralStatus.declined) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (r.isOpen)
                  VnChip(label: 'Directions', icon: Icons.directions_outlined, onTap: () => _directions(f)),
                if (r.isOpen && phone != null && phone.isNotEmpty)
                  VnChip(
                    label: 'Call',
                    icon: Icons.call_outlined,
                    onTap: () => LaunchHelpers.dialOrSnack(context, phone),
                  ),
                if (r.status == ReferralStatus.newRef)
                  VnChip(
                    label: _cancelling ? 'Cancelling…' : 'Cancel',
                    icon: Icons.close_rounded,
                    onTap: _cancelling ? null : _cancel,
                  ),
                if (r.status == ReferralStatus.declined && widget.onFindAnother != null)
                  VnChip(
                    label: 'Find another hospital',
                    icon: Icons.local_hospital_outlined,
                    onTap: widget.onFindAnother,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
