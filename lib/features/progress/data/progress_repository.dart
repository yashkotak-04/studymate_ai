import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/models/subject.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(FirebaseFirestore.instance);
});

final dailyStatsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value({'minutesStudied': 0, 'goalMet': false});
  return ref.watch(progressRepositoryProvider).streamDailyStats(user.uid);
});

final subjectProgressProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(progressRepositoryProvider).streamSubjectProgress(user.uid);
});

class ProgressRepository {
  final FirebaseFirestore _firestore;

  ProgressRepository(this._firestore);

  String _getTodayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Log activity and update streak and daily goal transactionally
  Future<void> logActivityAndCalculateStreak({
    required String uid,
    required String subjectId,
    required int durationMinutes,
    required int score,
    required int totalQuestions,
    bool isMockTest = false,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final todayKey = _getTodayKey();
    final dailyStatsRef = userRef.collection('dailyStats').doc(todayKey);
    final activityRef = userRef.collection('activities').doc();

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      int currentStreak = (userData['currentStreak'] as num?)?.toInt() ?? 0;
      int longestStreak = (userData['longestStreak'] as num?)?.toInt() ?? 0;
      String? lastStudyDateStr = userData['lastStudyDate'] as String?;
      int dailyGoal = (userData['dailyStudyGoalMinutes'] as num?)?.toInt() ?? 30;

      DateTime today = DateTime.parse(todayKey);

      if (lastStudyDateStr != null) {
        DateTime lastStudyDate = DateTime.parse(lastStudyDateStr);
        final difference = today.difference(lastStudyDate).inDays;

        if (difference == 1) {
          // Consecutive day
          currentStreak++;
        } else if (difference > 1) {
          // Streak broken
          currentStreak = 1;
        }
        // difference == 0: already studied today, keep streak
      } else {
        // First study session
        currentStreak = 1;
      }

      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }

      // Update daily stats
      final dailyDoc = await transaction.get(dailyStatsRef);
      int todayMinutes = durationMinutes;
      int todayQuizzes = 1;
      if (dailyDoc.exists) {
        todayMinutes += (dailyDoc.data()!['minutesStudied'] as num?)?.toInt() ?? 0;
        todayQuizzes += (dailyDoc.data()!['quizzesCompleted'] as num?)?.toInt() ?? 0;
      }
      bool goalMet = todayMinutes >= dailyGoal;

      transaction.set(dailyStatsRef, {
        'minutesStudied': todayMinutes,
        'quizzesCompleted': todayQuizzes,
        'goalMet': goalMet,
        'date': todayKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Record Activity Log
      transaction.set(activityRef, {
        'subjectId': subjectId,
        'durationMinutes': durationMinutes,
        'score': score,
        'totalQuestions': totalQuestions,
        'isMockTest': isMockTest,
        'timestamp': FieldValue.serverTimestamp(),
        'date': todayKey,
      });

      // Update Subject Progress ONLY for legitimate subjects, not mock_test
      if (!isMockTest && AppSubjects.getById(subjectId) != null) {
        final subjectProgressRef = userRef.collection('subjectProgress').doc(subjectId);
        final subjectDoc = await transaction.get(subjectProgressRef);
        int totalQuizzes = 1;
        int subjectScore = score;
        int subjectTotalQuestions = totalQuestions;

        if (subjectDoc.exists) {
          final subData = subjectDoc.data()!;
          totalQuizzes += (subData['totalQuizzes'] as num?)?.toInt() ?? 0;
          subjectScore += (subData['correctAnswers'] as num?)?.toInt() ?? 0;
          subjectTotalQuestions += (subData['totalQuestions'] as num?)?.toInt() ?? 0;
        }

        transaction.set(subjectProgressRef, {
          'totalQuizzes': totalQuizzes,
          'correctAnswers': subjectScore,
          'totalQuestions': subjectTotalQuestions,
          'accuracy': subjectTotalQuestions > 0 ? (subjectScore / subjectTotalQuestions) * 100 : 0,
          'lastStudiedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Update User Streak
      transaction.update(userRef, {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastStudyDate': todayKey,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<Map<String, dynamic>> streamDailyStats(String uid) {
    final todayKey = _getTodayKey();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyStats')
        .doc(todayKey)
        .snapshots()
        .map((doc) => doc.exists ? doc.data()! : {'minutesStudied': 0, 'goalMet': false});
  }

  Stream<List<Map<String, dynamic>>> streamSubjectProgress(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('subjectProgress')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> streamAllDailyStats(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyStats')
        .orderBy('date', descending: true)
        .limit(90)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }
}
