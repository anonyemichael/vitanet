import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final personalRegisterProvider = NotifierProvider<
    PersonalRegisterNotifier, PersonalRegisterState>(
  PersonalRegisterNotifier.new,
);

@immutable
class PersonalRegisterState {
  final bool isLoading;
  final bool obscurePassword;
  final DateTime? dateOfBirth;
  final String? gender;

  const PersonalRegisterState({
    this.isLoading = false,
    this.obscurePassword = true,
    this.dateOfBirth,
    this.gender,
  });

  PersonalRegisterState copyWith({
    bool? isLoading,
    bool? obscurePassword,
    DateTime? dateOfBirth,
    String? gender,
  }) {
    return PersonalRegisterState(
      isLoading: isLoading ?? this.isLoading,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
    );
  }
}

class PersonalRegisterNotifier extends Notifier<PersonalRegisterState> {
  final formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  PersonalRegisterState build() {
    ref.onDispose(() {
      fullNameController.dispose();
      emailController.dispose();
      passwordController.dispose();
    });

    return const PersonalRegisterState();
  }

  //=========================
  // State
  //=========================

  void togglePasswordVisibility() {
    state = state.copyWith(
      obscurePassword: !state.obscurePassword,
    );
  }

  void setGender(String? gender) {
    state = state.copyWith(gender: gender);
  }

  void setDateOfBirth(DateTime date) {
    state = state.copyWith(dateOfBirth: date);
  }

  //=========================
  // Validators
  //=========================

  String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Full name is required";
    }

    if (value.trim().length < 3) {
      return "Please enter your full name";
    }

    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Email address is required";
    }

    final emailRegex = RegExp(
      r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return "Enter a valid email address";
    }

    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Password is required";
    }

    if (value.length < 8) {
      return "Password must be at least 8 characters";
    }

    return null;
  }

  //=========================
  // Registration
  //=========================

  Future<void> register() async {
    if (!formKey.currentState!.validate()) return;

    if (state.dateOfBirth == null) {
      throw Exception("Please select your date of birth.");
    }

    state = state.copyWith(isLoading: true);

    try {
      /// TODO:
      /// Firebase Auth / API Registration
      ///
      /// Example:
      ///
      /// await authRepository.register(...);

      await Future.delayed(
        const Duration(seconds: 2),
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  //=========================
  // Google Sign In
  //=========================

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true);

    try {
      /// TODO:
      /// Google Sign In
      ///
      /// await authRepository.signInWithGoogle();

      await Future.delayed(
        const Duration(seconds: 2),
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}