import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two ways a person can use VitaNet.
enum UserType {
  healthcareProfessional,
  personal,
}

extension UserTypeContent on UserType {
  String get title {
    switch (this) {
      case UserType.healthcareProfessional:
        return 'Healthcare Professional';
      case UserType.personal:
        return 'Personal Account';
    }
  }

  String get description {
    switch (this) {
      case UserType.healthcareProfessional:
        return 'Manage patients, records, and hospital operations';
      case UserType.personal:
        return 'Access healthcare services and manage your health';
    }
  }

  List<String> get audience {
    switch (this) {
      case UserType.healthcareProfessional:
        return const ['Doctors', 'Nurses', 'Hospital administrators', 'Healthcare staff'];
      case UserType.personal:
        return const ['Patients', 'Individuals managing their health', 'People looking for healthcare services'];
    }
  }
}

/// Holds which card the user has committed to (tapped), or null if
/// they haven't chosen yet. Kept separate from any hover/press
/// animation state, which is purely visual and lives in the widget.
class UserTypeSelectionNotifier extends Notifier<UserType?> {
  @override
  UserType? build() => null;

  void choose(UserType type) {
    state = type;
  }

  void reset() {
    state = null;
  }
}

final userTypeSelectionProvider =
    NotifierProvider<UserTypeSelectionNotifier, UserType?>(
  UserTypeSelectionNotifier.new,
);