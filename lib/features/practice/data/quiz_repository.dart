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

  /// Idempotent, single-transaction quiz completion.
  Future<bool> finalizeQuizSession(QuizSession session) async {
    return await _progressRepository.finalizeQuizAtomic(session);
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
