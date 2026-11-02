import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/data/services/referral_service.dart';
import 'package:vitanet/features/triage_result/widgets/referral_status_card.dart';
import 'package:vitanet/features/triage_result/widgets/send_referral_sheet.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Triage-result block: either "Send my summary to a hospital" or the status
/// of the referral already sent.
class ReferralSection extends ConsumerWidget {
  final TriageResult result;
  const ReferralSection({super.key, required this.result});

  Future<void> _open(BuildContext context) async {
    final outcome = await showSendReferralSheet(context, result);
    if (outcome == null || !context.mounted) return;
    final h = ReferralStatusCard.hospitalLabel(outcome.referral);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(outcome.alreadyOpen
          ? 'You already have an open referral with $h — showing it below.'
          : 'Sent to $h. Their reply will appear here.'),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionId = ref.watch(sessionReferralIdProvider);
    final list = ref.watch(myReferralsProvider).valueOrNull ?? const <Referral>[];
    Referral? shown;
    if (sessionId != null) {
      for (final r in list) {
        if (r.id == sessionId) shown = r;
      }
    }
    shown ??= ref.watch(activeReferralProvider);

    if (shown != null && shown.status != ReferralStatus.cancelled) {
      return ReferralStatusCard(
        referral: shown,
        onFindAnother: shown.status == ReferralStatus.declined ? () => _open(context) : null,
      );
    }

    final p = VnPalette.of(context);
    return VnCard(
      onTap: () => _open(context),
      semanticLabel: 'Send my summary to a hospital',
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          VnIconTile(
            icon: Icons.send_to_mobile_outlined,
            bg: p.brandTint,
            fg: p.brandDeep,
            size: 46,
            radius: 14,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Send my summary to a hospital',
                    style: VnText.body(15, weight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 2),
                Text('They can get ready before you arrive. You choose what to share.',
                    style: VnText.body(13, color: p.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.faint),
        ],
      ),
    );
  }
}
