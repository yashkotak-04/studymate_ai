import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_ai/shared/models/study_plan_model.dart';

void main() {
  group('StudyPlan Model Tests', () {
    test(
      'Calculates total tasks, completed tasks, and completion percentage',
      () {
        final task1 = StudyPlanTask(
          id: 't1',
          timeSlot: 'Morning',
          subjectId: 'os',
          subjectName: 'Operating Systems',
          topic: 'Process Sync',
          durationMinutes: 30,
          isCompleted: true,
        );

        final task2 = StudyPlanTask(
          id: 't2',
          timeSlot: 'Evening',
          subjectId: 'py',
          subjectName: 'Python',
          topic: 'Decorators',
          durationMinutes: 30,
          isCompleted: false,
        );

        final day1 = StudyPlanDay(
          dayName: 'Monday',
          focus: 'OS & Python',
          tasks: [task1, task2],
        );

        final plan = StudyPlan(
          id: 'plan_1',
          userId: 'u1',
          targetExam: 'Finals',
          dailyGoalMinutes: 60,
          overview: 'Weekly Plan',
          days: [day1],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(plan.totalTasks, equals(2));
        expect(plan.completedTasks, equals(1));
        expect(plan.completionPercentage, equals(50.0));
      },
    );
  });
}
