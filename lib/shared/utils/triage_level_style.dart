import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/core/constants/app_strings.dart';
import 'package:vitanet/data/models/triage_result.dart';

/// Shared visual style for triage levels across Home, History, and Result.
class TriageLevelStyle {
  final Color color;
  final IconData icon;
  final String shortLabel;
  final String fullLabel;

  const TriageLevelStyle({
    required this.color,
    required this.icon,
    required this.shortLabel,
    required this.fullLabel,
  });

  static TriageLevelStyle of(TriageLevel level) {
    switch (level) {
      case TriageLevel.selfCare:
        return const TriageLevelStyle(
          color: AppColors.triageSelfCare,
          icon: Icons.home_rounded,
          shortLabel: 'Self-Care',
          fullLabel: AppStrings.triageSelfCare,
        );
      case TriageLevel.pharmacist:
        return const TriageLevelStyle(
          color: AppColors.triagePharmacist,
          icon: Icons.local_pharmacy_rounded,
          shortLabel: 'Pharmacist',
          fullLabel: AppStrings.triagePharmacist,
        );
      case TriageLevel.doctor:
        return const TriageLevelStyle(
          color: AppColors.triageDoctor,
          icon: Icons.medical_services_rounded,
          shortLabel: 'Doctor',
          fullLabel: 'See a Doctor',
        );
      case TriageLevel.emergency:
        return const TriageLevelStyle(
          color: AppColors.triageUrgent,
          icon: Icons.local_hospital_rounded,
          shortLabel: 'Emergency',
          fullLabel: AppStrings.triageUrgent,
        );
    }
  }
}
