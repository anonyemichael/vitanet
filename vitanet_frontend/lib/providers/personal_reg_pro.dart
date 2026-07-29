import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Gender is optional, so `null` means "prefer not to say / unanswered".
enum Gender { male, female, other }

extension GenderLabel on Gender {
  String get label => switch (this) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Other',
      };
}

enum RegistrationStatus { idle, submitting, success, error }

/// Holds the parts of the "Create Your Account" form that aren't plain
/// text (so they don't need a TextEditingController): date of birth,
/// gender, password visibility, and submission status.
///
/// Full Name / Email-Phone / Password text stays in local
/// TextEditingControllers on the screen for performance — only the
/// values needed elsewhere (e.g. validation, submission) flow through
/// here.
class PersonalRegistrationState {
  const PersonalRegistrationState({
    this.dateOfBirth,
    this.gender,
    this.obscurePassword = true,
    this.status = RegistrationStatus.idle,
    this.errorMessage,
  });

  final DateTime? dateOfBirth;
  final Gender? gender;
  final bool obscurePassword;
  final RegistrationStatus status;
  final String? errorMessage;

  PersonalRegistrationState copyWith({
    DateTime? dateOfBirth,
    Gender? gender,
    bool? obscurePassword,
    RegistrationStatus? status,
    String? errorMessage,
    bool clearGender = false,
    bool clearError = false,
  }) {
    return PersonalRegistrationState(
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: clearGender ? null : (gender ?? this.gender),
      obscurePassword: obscurePassword ?? this.obscurePassword,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PersonalRegistrationNotifier
    extends StateNotifier<PersonalRegistrationState> {
  PersonalRegistrationNotifier() : super(const PersonalRegistrationState());

  void setDateOfBirth(DateTime date) {
    state = state.copyWith(dateOfBirth: date);
  }

  void setGender(Gender? gender) {
    state = gender == null
        ? state.copyWith(clearGender: true)
        : state.copyWith(gender: gender);
  }

  void toggleObscurePassword() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  /// Submits the personal-account form. Text field values are passed in
  /// from the screen's controllers since they aren't stored here.
  Future<void> submit({
    required String fullName,
    required String emailOrPhone,
    required String password,
  }) async {
    if (state.dateOfBirth == null) {
      state = state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: 'Please select your date of birth.',
      );
      return;
    }

    state = state.copyWith(status: RegistrationStatus.submitting, clearError: true);

    try {
      // TODO: wire up to the real VitaNet signup API.
      await Future.delayed(const Duration(milliseconds: 900));
      state = state.copyWith(status: RegistrationStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: RegistrationStatus.submitting, clearError: true);
    try {
      // TODO: wire up google_sign_in / Firebase Auth.
      await Future.delayed(const Duration(milliseconds: 900));
      state = state.copyWith(status: RegistrationStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: 'Google sign-in failed. Please try again.',
      );
    }
  }

  void reset() => state = const PersonalRegistrationState();
}

final personalRegistrationProvider = StateNotifierProvider<
    PersonalRegistrationNotifier, PersonalRegistrationState>(
  (ref) => PersonalRegistrationNotifier(),
);