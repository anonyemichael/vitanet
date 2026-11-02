import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/features/triage_result/widgets/referral_status_card.dart';

/// Shows the open (new or accepted) hospital referral at the top of Home;
/// renders nothing otherwise.
class ActiveReferralSection extends ConsumerWidget {
  final Widget? trailingGap;
  const ActiveReferralSection({super.key, this.trailingGap = const SizedBox(height: 22)});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeReferralProvider);
    if (active == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReferralStatusCard(referral: active),
        ?trailingGap,
      ],
    );
  }
}
