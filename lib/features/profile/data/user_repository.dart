import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user_profile.dart';
import '../../auth/data/auth_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});

// Stream provider to listen to the current user's profile
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.streamUserProfile(user.uid);
});

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  Stream<UserProfile?> streamUserProfile(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserProfile.fromJson(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserProfile.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> createUserProfile(User user) async {
    final docRef = _users.doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      final profile = UserProfile(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName ?? (user.email?.split('@').first ?? 'Student'),
        createdAt: DateTime.now(),
      );
      await docRef.set(profile.toJson(), SetOptions(merge: true));
    }
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await _users.doc(profile.uid).update(profile.toJson());
  }

  Future<void> updateOnboarding(String uid, {
    required String displayName,
    required String academicProgram,
    required String targetExam,
    required List<String> enrolledSubjectIds,
    required int dailyGoal,
    String preferredAiMode = 'Student',
  }) async {
    await _users.doc(uid).set({
      'displayName': displayName,
      'academicProgram': academicProgram,
      'targetExam': targetExam,
      'enrolledSubjectIds': enrolledSubjectIds,
      'dailyStudyGoalMinutes': dailyGoal,
      'preferredAiMode': preferredAiMode,
      'onboardingComplete': true,
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updatePreferredAiMode(String uid, String mode) async {
    await _users.doc(uid).update({
      'preferredAiMode': mode,
    });
  }

  Future<void> updateDailyGoal(String uid, int minutes) async {
    await _users.doc(uid).update({
      'dailyStudyGoalMinutes': minutes,
    });
  }

  Future<void> enrollSubject(String uid, String subjectId) async {
    await _users.doc(uid).update({
      'enrolledSubjectIds': FieldValue.arrayUnion([subjectId])
    });
  }

  Future<void> unenrollSubject(String uid, String subjectId) async {
    await _users.doc(uid).update({
      'enrolledSubjectIds': FieldValue.arrayRemove([subjectId])
    });
  }

  /// Permanently purges all user data across all subcollections and the user profile document.
  Future<void> deleteEntireUserData(String uid) async {
    final userRef = _users.doc(uid);

    final subcollections = [
      'quizzes',
      'summaries',
      'subjectProgress',
      'dailyStats',
      'activities',
      'studyPlans',
      'recommendations',
      'aggregates',
      'settings',
    ];

    for (final col in subcollections) {
      try {
        final snap = await userRef.collection(col).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
    }

    // Delete chat threads and their nested messages
    try {
      final threads = await userRef.collection('chatThreads').get();
      for (final t in threads.docs) {
        final msgs = await t.reference.collection('messages').get();
        for (final m in msgs.docs) {
          await m.reference.delete();
        }
        await t.reference.delete();
      }
    } catch (_) {}

    // Delete user profile document
    await userRef.delete();
  }
}
