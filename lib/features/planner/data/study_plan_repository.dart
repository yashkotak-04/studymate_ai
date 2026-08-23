import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/study_plan_model.dart';
import '../../auth/data/auth_repository.dart';

final studyPlanRepositoryProvider = Provider<StudyPlanRepository>((ref) {
  return StudyPlanRepository(FirebaseFirestore.instance);
});

final activeStudyPlanProvider = StreamProvider<StudyPlan?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(studyPlanRepositoryProvider).streamActivePlan(user.uid);
});

class StudyPlanRepository {
  final FirebaseFirestore _firestore;

  StudyPlanRepository(this._firestore);

  Stream<StudyPlan?> streamActivePlan(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('studyPlans')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return StudyPlan.fromJson(
              snapshot.docs.first.data(),
              snapshot.docs.first.id,
            );
          }
          return null;
        });
  }

  Future<void> savePlan(StudyPlan plan) async {
    final docRef = _firestore
        .collection('users')
        .doc(plan.userId)
        .collection('studyPlans')
        .doc(plan.id.isNotEmpty ? plan.id : null);

    await docRef.set(plan.toJson(), SetOptions(merge: true));
  }

  Future<void> toggleTaskCompletion(
    String userId,
    String planId,
    String dayName,
    String taskId,
    bool isCompleted,
  ) async {
    final planRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('studyPlans')
        .doc(planId);

    final docSnap = await planRef.get();
    if (!docSnap.exists || docSnap.data() == null) return;

    final plan = StudyPlan.fromJson(docSnap.data()!, docSnap.id);
    final updatedDays = plan.days.map((day) {
      if (day.dayName == dayName) {
        final updatedTasks = day.tasks.map((task) {
          if (task.id == taskId) {
            return task.copyWith(isCompleted: isCompleted);
          }
          return task;
        }).toList();
        return day.copyWith(tasks: updatedTasks);
      }
      return day;
    }).toList();

    final updatedPlan = plan.copyWith(
      days: updatedDays,
      updatedAt: DateTime.now(),
    );

    await planRef.set(updatedPlan.toJson(), SetOptions(merge: true));
  }

  Future<void> deletePlan(String userId, String planId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('studyPlans')
        .doc(planId)
        .delete();
  }
}
