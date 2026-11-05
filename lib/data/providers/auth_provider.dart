import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthStatus {
  initial,
  loading,
  unauthenticated,
  anonymous,
  authenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  StreamSubscription<User?>? _authSubscription;

  AuthNotifier() : super(AuthState(status: AuthStatus.initial)) {
    _init();
  }

  FirebaseAuth? get _safeAuth {
    if (_auth != null) return _auth;
    if (Firebase.apps.isNotEmpty) {
      try {
        _auth = FirebaseAuth.instance;
        _listenToAuth();
      } catch (e) {
        debugPrint('FirebaseAuth initialization error: $e');
      }
    }
    return _auth;
  }

  void _init() {
    try {
      if (!kIsWeb) {
        _googleSignIn = GoogleSignIn();
      }
      if (Firebase.apps.isNotEmpty) {
        _auth = FirebaseAuth.instance;
        _listenToAuth();
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      debugPrint('AuthNotifier init error: $e');
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  void _listenToAuth() {
    if (_auth == null) return;
    _authSubscription?.cancel();
    _authSubscription = _auth!.authStateChanges().listen((User? user) {
      if (user == null) {
        if (state.status != AuthStatus.initial && state.status != AuthStatus.loading) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            user: null,
            errorMessage: null,
          );
        }
      } else {
        state = state.copyWith(
          status: user.isAnonymous ? AuthStatus.anonymous : AuthStatus.authenticated,
          user: user,
          errorMessage: null,
        );
      }
    }, onError: (err) {
      debugPrint('Auth state listener error: $err');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: err.toString(),
      );
    });
  }

  void reinitialize() {
    _init();
  }

  Future<void> signInAnonymously() async {
    final auth = _safeAuth;
    if (auth == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Firebase not configured.',
      );
      return;
    }
    try {
      state = state.copyWith(status: AuthStatus.loading);
      final cred = await auth.signInAnonymously();
      state = state.copyWith(
        status: AuthStatus.anonymous,
        user: cred.user ?? auth.currentUser,
        errorMessage: null,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase anonymous sign in error: ${e.code} - ${e.message}');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message ?? 'Failed to sign in anonymously (${e.code})',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    final auth = _safeAuth;
    if (auth == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Firebase not configured.',
      );
      return;
    }
    try {
      state = state.copyWith(status: AuthStatus.loading);
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      try {
        await cred.user?.sendEmailVerification();
      } catch (e) {
        debugPrint('Verification email not sent: $e');
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: cred.user ?? auth.currentUser,
        errorMessage: null,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase sign up error: ${e.code} - ${e.message}');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message ?? 'Failed to sign up (${e.code})',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    final auth = _safeAuth;
    if (auth == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Firebase not configured.',
      );
      return;
    }
    try {
      state = state.copyWith(status: AuthStatus.loading);
      final cred = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: cred.user ?? auth.currentUser,
        errorMessage: null,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase sign in error: ${e.code} - ${e.message}');
      String msg = e.message ?? 'Failed to sign in (${e.code})';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Invalid email or password. Please verify and try again.';
      } else if (e.code == 'user-disabled') {
        msg = 'This account has been disabled. Please contact support.';
      } else if (e.code == 'too-many-requests') {
        msg = 'Too many attempts. Please try again later.';
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> linkGoogleAccount() async {
    final auth = _safeAuth;
    if (auth == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Firebase not configured.',
      );
      return;
    }
    try {
      state = state.copyWith(status: AuthStatus.loading);

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        if (auth.currentUser != null && auth.currentUser!.isAnonymous) {
          try {
            final cred = await auth.currentUser!.linkWithPopup(googleProvider);
            state = state.copyWith(
              status: AuthStatus.authenticated,
              user: cred.user ?? auth.currentUser,
              errorMessage: null,
            );
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use' ||
                e.code == 'account-exists-with-different-credential') {
              final cred = await auth.signInWithPopup(googleProvider);
              state = state.copyWith(
                status: AuthStatus.authenticated,
                user: cred.user ?? auth.currentUser,
                errorMessage: null,
              );
            } else {
              rethrow;
            }
          }
        } else {
          final cred = await auth.signInWithPopup(googleProvider);
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: cred.user ?? auth.currentUser,
            errorMessage: null,
          );
        }
      } else {
        _googleSignIn ??= GoogleSignIn();
        final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
        if (googleUser == null) {
          state = state.copyWith(
            status: auth.currentUser != null
                ? (auth.currentUser!.isAnonymous ? AuthStatus.anonymous : AuthStatus.authenticated)
                : AuthStatus.unauthenticated,
            user: auth.currentUser,
            errorMessage: null,
          );
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        if (auth.currentUser != null && auth.currentUser!.isAnonymous) {
          try {
            final cred = await auth.currentUser!.linkWithCredential(credential);
            state = state.copyWith(
              status: AuthStatus.authenticated,
              user: cred.user ?? auth.currentUser,
              errorMessage: null,
            );
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use' ||
                e.code == 'account-exists-with-different-credential') {
              final cred = await auth.signInWithCredential(credential);
              state = state.copyWith(
                status: AuthStatus.authenticated,
                user: cred.user ?? auth.currentUser,
                errorMessage: null,
              );
            } else {
              rethrow;
            }
          }
        } else {
          final cred = await auth.signInWithCredential(credential);
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: cred.user ?? auth.currentUser,
            errorMessage: null,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Google Auth error: ${e.code} - ${e.message}');
      if (e.code == 'popup-closed-by-user') {
        state = state.copyWith(
          status: auth.currentUser != null
              ? (auth.currentUser!.isAnonymous ? AuthStatus.anonymous : AuthStatus.authenticated)
              : AuthStatus.unauthenticated,
          user: auth.currentUser,
          errorMessage: null,
        );
        return;
      }
      String msg = e.message ?? 'Failed to sign in with Google (${e.code})';
      if (e.code == 'account-exists-with-different-credential' || e.code == 'credential-already-in-use') {
        msg = 'An account already exists with this Google email.';
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
      );
    } catch (e) {
      debugPrint('General error during Google sign-in: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      if (_googleSignIn != null) {
        try {
          await _googleSignIn!.signOut();
        } catch (_) {}
      }
      final auth = _safeAuth;
      if (auth != null) {
        try {
          await auth.signOut();
        } catch (_) {}
      }
    } finally {
      // Build a fresh state: copyWith(user: null) would keep the old user.
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
