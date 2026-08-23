import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/models/quiz_model.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(FirebaseFirestore.instance);
});

final dailyStatsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null)
    return Stream.value({'minutesStudied': 0, 'goalMet': false});
  return ref.watch(progressRepositoryProvider).streamDailyStats(user.uid);
});

final subjectProgressProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(progressRepositoryProvider).streamSubjectProgress(user.uid);
});

final allTimeAggregatesProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value({});
  return ref
      .watch(progressRepositoryProvider)
      .streamAllTimeAggregates(user.uid);
});

final allDailyStatsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(progressRepositoryProvider).streamAllDailyStats(user.uid);
});

class ProgressRepository {
  final FirebaseFirestore _firestore;

  ProgressRepository(this._firestore);

  String _getTodayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Genuinely atomic, single-transaction quiz completion.
  /// Guarantees that saving the quiz attempt, updating subject progress,
  /// updating daily stats, recording activity, updating streak, and updating
  /// all-time durable aggregates happen in ONE single ACID transaction.
  /// If the quiz was already finalized, returns immediately without double-counting.
  Future<bool> finalizeQuizAtomic(QuizSession session) async {
    final userRef = _firestore.collection('users').doc(session.userId);
    final quizRef = userRef.collection('quizzes').doc(session.id);
    final todayKey = _getTodayKey();
    final dailyStatsRef = userRef.collection('dailyStats').doc(todayKey);
    final activityRef = userRef.collection('activities').doc(session.id);
    final aggregateRef = userRef.collection('aggregates').doc('quizStats');

    return await _firestore.runTransaction<bool>((transaction) async {
      // 1. Check idempotency: if quiz already exists and completed, abort safely
      final quizDoc = await transaction.get(quizRef);
      if (quizDoc.exists) {
        return false; // Already finalized idempotently
      }

      // 2. Read User profile
      final userDoc = await transaction.get(userRef);
      int currentStreak = 0;
      int longestStreak = 0;
      String? lastStudyDateStr;
      int dailyGoal = 30;

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        currentStreak = (userData['currentStreak'] as num?)?.toInt() ?? 0;
        longestStreak = (userData['longestStreak'] as num?)?.toInt() ?? 0;
        lastStudyDateStr = userData['lastStudyDate'] as String?;
        dailyGoal = (userData['dailyStudyGoalMinutes'] as num?)?.toInt() ?? 30;
      }

      // 3. Read Daily Stats
      final dailyDoc = await transaction.get(dailyStatsRef);
      int todayMinutes = session.durationMinutes;
      int todayQuizzes = 1;
      if (dailyDoc.exists && dailyDoc.data() != null) {
        todayMinutes +=
            (dailyDoc.data()!['minutesStudied'] as num?)?.toInt() ?? 0;
        todayQuizzes +=
            (dailyDoc.data()!['quizzesCompleted'] as num?)?.toInt() ?? 0;
      }
      bool goalMet = todayMinutes >= dailyGoal;

      // 4. Read Subject Progress (if not mock test)
      DocumentReference<Map<String, dynamic>>? subjectProgressRef;
      DocumentSnapshot<Map<String, dynamic>>? subjectDoc;
      final isRealSubject =
          !session.isMockTest && AppSubjects.getById(session.subjectId) != null;
      if (isRealSubject) {
        subjectProgressRef = userRef
            .collection('subjectProgress')
            .doc(session.subjectId);
        subjectDoc = await transaction.get(subjectProgressRef);
      }

      // 5. Read Durable Aggregates (All-Time)
      final aggDoc = await transaction.get(aggregateRef);
      int aggTotalQuizzes = 0;
      int aggTotalQuestions = 0;
      int aggCorrectAnswers = 0;
      int aggTotalMinutes = 0;

      if (aggDoc.exists && aggDoc.data() != null) {
        final d = aggDoc.data()!;
        aggTotalQuizzes = (d['totalQuizzes'] as num?)?.toInt() ?? 0;
        aggTotalQuestions = (d['totalQuestions'] as num?)?.toInt() ?? 0;
        aggCorrectAnswers = (d['correctAnswers'] as num?)?.toInt() ?? 0;
        aggTotalMinutes = (d['totalMinutesStudied'] as num?)?.toInt() ?? 0;
      }

      aggTotalQuizzes += 1;
      aggTotalQuestions += session.totalQuestions;
      aggCorrectAnswers += session.score;
      aggTotalMinutes += session.durationMinutes;
      final aggAccuracy = aggTotalQuestions > 0
          ? (aggCorrectAnswers / aggTotalQuestions) * 100.0
          : 0.0;

      // 6. Calculate Streak
      DateTime today = DateTime.parse(todayKey);
      if (lastStudyDateStr != null) {
        DateTime lastStudyDate = DateTime.tryParse(lastStudyDateStr) ?? today;
        final difference = today.difference(lastStudyDate).inDays;

        if (difference == 1) {
          currentStreak++;
        } else if (difference > 1) {
          currentStreak = 1;
        }
      } else {
        currentStreak = 1;
      }

      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }

      // --- WRITES ---

      // Write Quiz Document
      transaction.set(quizRef, session.toJson());

      // Write Daily Stats
      transaction.set(dailyStatsRef, {
        'minutesStudied': todayMinutes,
        'quizzesCompleted': todayQuizzes,
        'goalMet': goalMet,
        'date': todayKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Write Activity Log
      transaction.set(activityRef, {
        'subjectId': session.subjectId,
        'durationMinutes': session.durationMinutes,
        'score': session.score,
        'totalQuestions': session.totalQuestions,
        'accuracy': session.accuracy,
        'isMockTest': session.isMockTest,
        'timestamp': FieldValue.serverTimestamp(),
        'date': todayKey,
      });

      // Write Subject Progress
      if (isRealSubject && subjectProgressRef != null) {
        int subQuizzes = 1;
        int subScore = session.score;
        int subTotalQuestions = session.totalQuestions;

        if (subjectDoc != null &&
            subjectDoc.exists &&
            subjectDoc.data() != null) {
          final subData = subjectDoc.data()!;
          subQuizzes += (subData['totalQuizzes'] as num?)?.toInt() ?? 0;
          subScore += (subData['correctAnswers'] as num?)?.toInt() ?? 0;
          subTotalQuestions +=
              (subData['totalQuestions'] as num?)?.toInt() ?? 0;
        }

        final subAccuracy = subTotalQuestions > 0
            ? (subScore / subTotalQuestions) * 100.0
            : 0.0;

        transaction.set(subjectProgressRef, {
          'totalQuizzes': subQuizzes,
          'correctAnswers': subScore,
          'totalQuestions': subTotalQuestions,
          'accuracy': subAccuracy,
          'lastStudiedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Write Durable All-Time Aggregates
      transaction.set(aggregateRef, {
        'totalQuizzes': aggTotalQuizzes,
        'totalQuestions': aggTotalQuestions,
        'correctAnswers': aggCorrectAnswers,
        'totalMinutesStudied': aggTotalMinutes,
        'accuracy': aggAccuracy,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update User streak
      if (userDoc.exists) {
        transaction.update(userRef, {
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
          'lastStudyDate': todayKey,
          'lastActiveAt': FieldValue.serverTimestamp(),
        });
      }

      return true;
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
        .map(
          (doc) => doc.exists
              ? doc.data()!
              : {'minutesStudied': 0, 'goalMet': false},
        );
  }

  Stream<Map<String, dynamic>> streamAllTimeAggregates(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('aggregates')
        .doc('quizStats')
        .snapshots()
        .map(
          (doc) => doc.exists
              ? doc.data()!
              : {
                  'totalQuizzes': 0,
                  'totalQuestions': 0,
                  'correctAnswers': 0,
                  'totalMinutesStudied': 0,
                  'accuracy': 0.0,
                },
        );
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

  /// Scalable period analytics query: fetches quizzes bounded strictly by date range
  /// rather than relying on a small fixed limit(50), guaranteeing accurate Week/Month stats
  /// even when a student completes >50 attempts within a reporting period.
  Future<List<QuizSession>> getQuizzesInDateRange(
    String uid,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = await _firestore
        .collection('users')
        .doc(uid)
        .collection('quizzes')
        .where('endTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('endTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('endTime', descending: true)
        .get();

    return query.docs
        .map((doc) => QuizSession.fromJson(doc.data(), doc.id))
        .toList();
  }

  Stream<List<QuizSession>> streamQuizzesInDateRange(
    String uid,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('quizzes')
        .where('endTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('endTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('endTime', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => QuizSession.fromJson(d.data(), d.id))
              .toList(),
        );
  }
}
