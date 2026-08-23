import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/data/user_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    FirebaseAuth.instance,
    ref.watch(userRepositoryProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final UserRepository _userRepository;

  AuthRepository(this._firebaseAuth, this._userRepository);

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signIn(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw getFriendlyAuthErrorMessage(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please check your connection and try again.';
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        // Create user profile in Firestore
        await _userRepository.createUserProfile(credential.user!);
        // Send email verification if possible
        try {
          await credential.user!.sendEmailVerification();
        } catch (_) {}
      }
    } on FirebaseAuthException catch (e) {
      throw getFriendlyAuthErrorMessage(e);
    } catch (e) {
      throw 'Unable to create account. Please check your connection and try again.';
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw getFriendlyAuthErrorMessage(e);
    } catch (e) {
      throw 'Failed to send password reset email. Please try again.';
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw 'No user is currently signed in.';
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw getFriendlyAuthErrorMessage(e);
    } catch (e) {
      throw 'Failed to update password: $e';
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> deleteAccount({String? passwordForReauth}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return;

      if (passwordForReauth != null &&
          passwordForReauth.isNotEmpty &&
          user.email != null) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: passwordForReauth,
        );
        await user.reauthenticateWithCredential(cred);
      }

      // 1. Permanently delete all Firestore user data FIRST
      await _userRepository.deleteEntireUserData(user.uid);

      // 2. Permanently delete Auth identity
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw getFriendlyAuthErrorMessage(e);
    } catch (e) {
      throw 'Failed to delete account: $e';
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  static String getFriendlyAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please verify and try again.';
      case 'email-already-in-use':
        return 'An account with this email address already exists. Please sign in.';
      case 'invalid-email':
        return 'The email address format is invalid. Please check for typos.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters with mixed letters/numbers.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many unsuccessful attempts. Please wait a few minutes before trying again.';
      case 'network-request-failed':
        return 'Network connection issue. Please check your internet connection.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
