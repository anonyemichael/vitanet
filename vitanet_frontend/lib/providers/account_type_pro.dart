import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The two account types a new VitaNet user can choose between.
enum AccountType { personal, healthcareProfessional }

extension AccountTypeCopy on AccountType {
  String get title => switch (this) {
        AccountType.personal => 'Personal Account',
        AccountType.healthcareProfessional => 'Healthcare Professional',
      };

  String get description => switch (this) {
        AccountType.personal =>
          'Access healthcare services and manage your health',
        AccountType.healthcareProfessional =>
          'Manage patients, records, and hospital operations',
      };

  /// Short "For:" bullet list shown under the description on the
  /// Welcome screen so each option is easy to self-identify with.
  List<String> get forWhom => switch (this) {
        AccountType.personal => const [
            'Patients',
            'Individuals managing their health',
            'People looking for healthcare services',
          ],
        AccountType.healthcareProfessional => const [
            'Doctors',
            'Nurses',
            'Hospital administrators',
            'Healthcare staff',
          ],
      };
}

/// Tracks which account type the user has tapped, and exposes an action to
/// confirm the selection (e.g. to trigger navigation). Screens should only
/// read this provider and call [selectAccountType] — no business logic
/// belongs in the widget layer.
class AccountTypeSelectionNotifier extends StateNotifier<AccountType?> {
  AccountTypeSelectionNotifier() : super(null);

  void select(AccountType type) => state = type;

  void clear() => state = null;
}

final accountTypeSelectionProvider =
    StateNotifierProvider<AccountTypeSelectionNotifier, AccountType?>(
  (ref) => AccountTypeSelectionNotifier(),
);