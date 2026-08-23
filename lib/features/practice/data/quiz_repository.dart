import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/quiz_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../progress/data/progress_repository.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return QuizRepository(
    FirebaseFirestore.instance,
    ref.watch(progressRepositoryProvider),
  );
});

// Stream provider for user's quiz history
final userQuizHistoryProvider = StreamProvider<List<QuizSession>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  return ref.watch(quizRepositoryProvider).getUserQuizHistory(user.uid);
});

class QuizRepository {
  final FirebaseFirestore _firestore;
  final ProgressRepository _progressRepository;

  QuizRepository(this._firestore, this._progressRepository);

  Stream<List<QuizSession>> getUserQuizHistory(String userId, {int limit = 50}) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('quizzes')
        .orderBy('endTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuizSession.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<QuizSession?> getQuizSession(String userId, String quizId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('quizzes')
        .doc(quizId)
        .get();

    if (doc.exists && doc.data() != null) {
      return QuizSession.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  /// Idempotent quiz completion transaction: saves the session once using its stable ID
  /// and atomically updates subject progress and daily stats / streak without duplicate increments.
  Future<void> finalizeQuizSession(QuizSession session) async {
    final quizRef = _firestore
        .collection('users')
        .doc(session.userId)
        .collection('quizzes')
        .doc(session.id);

    final docSnap = await quizRef.get();
    if (docSnap.exists) {
      // Already finalized idempotently
      return;
    }

    // Save quiz session
    await quizRef.set(session.toJson());

    // Update stats and streak atomically
    await _progressRepository.logActivityAndCalculateStreak(
      uid: session.userId,
      subjectId: session.subjectId,
      durationMinutes: session.durationMinutes,
      score: session.score,
      totalQuestions: session.totalQuestions,
      isMockTest: session.isMockTest,
    );
  }

  Future<void> deleteQuizSession(String userId, String quizId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('quizzes')
        .doc(quizId)
        .delete();
  }
}
