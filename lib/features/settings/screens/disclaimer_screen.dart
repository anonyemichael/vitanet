import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);

    Widget point(IconData icon, Color color, String title, String body) => VnCard(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: p.tintFg(color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: VnText.body(14, weight: FontWeight.w700, color: p.ink)),
                    const SizedBox(height: 3),
                    Text(body, style: VnText.body(13, color: p.inkSoft, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                const VnTopBar(title: 'Medical disclaimer'),
                const SizedBox(height: 18),
                Material(
                  color: p.isDark ? const Color(0xFF3B1414) : const Color(0xFFFEF2F2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: p.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => LaunchHelpers.dialOrSnack(context, '112'),
                    child: Semantics(
                      button: true,
                      label: 'In an emergency, call 112',
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFB91C1C),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.call_outlined, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('In an emergency, call 112',
                                      style: VnText.body(15,
                                          weight: FontWeight.w800,
                                          color: p.isDark
                                              ? const Color(0xFFFCA5A5)
                                              : const Color(0xFF991B1B))),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Chest pain, trouble breathing, heavy bleeding or loss of consciousness need emergency services, not an app.',
                                    style: VnText.body(13,
                                        color: p.isDark
                                            ? const Color(0xFFFECACA)
                                            : const Color(0xFF7F1D1D),
                                        height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                point(Icons.check_rounded, const Color(0xFF047857), 'VitaNet can',
                    'Suggest how urgently to seek care, explain results in plain language and help you prepare for appointments.'),
                const SizedBox(height: 12),
                point(Icons.close_rounded, const Color(0xFFB91C1C), 'VitaNet cannot',
                    'Diagnose conditions, prescribe medicines, or replace an examination by a qualified clinician.'),
                const SizedBox(height: 18),
                Text(
                  'The information in this app is for general guidance only. AI responses may be incomplete or wrong, and vitals from consumer devices are not medical-grade. Always follow the advice of your doctor or pharmacist, and never delay seeking care because of something you read here.',
                  style: VnText.body(14, color: p.inkSoft, height: 1.7),
                ),
                const SizedBox(height: 18),
                Text(
                  'Medicine information is sourced from FDA labelling and may differ from what is approved in your country. Check with a pharmacist before starting or stopping any medicine.',
                  style: VnText.body(14, color: p.inkSoft, height: 1.7),
                ),
                const SizedBox(height: 28),
                VnButton(
                  label: 'I understand',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
