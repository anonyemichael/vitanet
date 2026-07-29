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

  AuthNotifier() : super(AuthState(status: AuthStatus.initial)) {
    _init();
  }

  void _init() {
    try {
      if (Firebase.apps.isNotEmpty) {
        _auth = FirebaseAuth.instance;
        _auth!.authStateChanges().listen((User? user) {
          if (user == null) {
            state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
          } else {
            state = state.copyWith(
              status: user.isAnonymous
                  ? AuthStatus.anonymous
                  : AuthStatus.authenticated,
              user: user,
            );
          }
        });
      } else {
        // Firebase not initialized
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Firebase not configured',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Auth init error: $e',
      );
    }
  }

  Future<void> signInAnonymously() async {
    if (_auth == null) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Firebase not configured.');
      return;
    }
    try {
      state = state.copyWith(status: AuthStatus.loading);
      await _auth!.signInAnonymously();
      state = state.copyWith(
        status: AuthStatus.anonymous,
        user: _auth!.currentUser,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message ?? 'Failed to sign in anonymously',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    if (_auth == null) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Firebase not configured.');
      return;
    }
    try {
      state = state.copyWith(status: AuthStatus.loading);
      await _auth!.createUserWithEmailAndPassword(email: email, password: password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: _auth!.currentUser,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message ?? 'Failed to sign up',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    if (_auth == null) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Firebase not configured.');
      return;
    }
    try {
      state = state.copyWith(status: AuthStatus.loading);
      await _auth!.signInWithEmailAndPassword(email: email, password: password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: _auth!.currentUser,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message ?? 'Failed to sign in',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> linkGoogleAccount() async {
    if (_auth == null) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Firebase not configured.');
      return;
    }
    try {
      state = state.copyWith(status: AuthStatus.loading);

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        if (_auth!.currentUser != null && _auth!.currentUser!.isAnonymous) {
          await _auth!.currentUser!.linkWithPopup(googleProvider);
        } else {
          await _auth!.signInWithPopup(googleProvider);
        }
      } else {
        // Trigger the authentication flow for mobile
        // Do not pass a dummy client ID, as it breaks Android authentication.
        // The plugin will read the correct ID from google-services.json / GoogleService-Info.plist
        _googleSignIn ??= GoogleSignIn();
        final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
        if (googleUser == null) {
          // The user canceled the sign-in
          state = state.copyWith(
            status: _auth!.currentUser?.isAnonymous == true
                ? AuthStatus.anonymous
                : (_auth!.currentUser != null ? AuthStatus.authenticated : AuthStatus.initial),
          );
          return;
        }

        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Link credential to the current anonymous user, or just sign in
        if (_auth!.currentUser != null && _auth!.currentUser!.isAnonymous) {
          await _auth!.currentUser!.linkWithCredential(credential);
        } else {
          await _auth!.signInWithCredential(credential);
        }
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: _auth!.currentUser,
      );

    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message ?? 'Failed to sign in with Google',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    if (_auth == null) return;
    try {
      state = state.copyWith(status: AuthStatus.loading);
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
      await _auth!.signOut();
      // This will trigger authStateChanges, which will then sign in anonymously again
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
