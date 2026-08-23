import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/models/recommendation_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/user_repository.dart';
import '../../progress/data/progress_repository.dart';

final recommendationsProvider = Provider<List<Recommendation>>((ref) {
  final subjectProgress = ref.watch(subjectProgressProvider).value ?? [];
  final userProfile = ref.watch(currentUserProfileProvider).value;
  final user = ref.watch(authStateProvider).value;

  final recommendations = <Recommendation>[];
  final uid = user?.uid ?? '';

  // 1. Check for Weakest Subject (< 65% accuracy)
  if (subjectProgress.isNotEmpty) {
    for (final sp in subjectProgress) {
      final acc = (sp['accuracy'] as num?)?.toDouble() ?? 0.0;
      final subId = sp['id'] as String;
      final subObj = AppSubjects.getById(subId);

      if (subObj != null && acc < 65.0) {
        recommendations.add(Recommendation(
          id: 'rec_weak_$subId',
          userId: uid,
          subjectId: subId,
          subjectName: subObj.name,
          topic: 'Targeted Practice: ${subObj.name}',
          title: 'Strengthen ${subObj.shortName} Foundation',
          reason: 'Your accuracy is currently ${acc.toInt()}%. A focused 10-question MCQ set will rapidly close the gap.',
          actionType: 'practice',
          actionRoute: '/practice',
          accuracy: acc,
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  // 2. Add AI Tutor Doubt Solving Recommendation
  recommendations.add(Recommendation(
    id: 'rec_chat_tutor',
    userId: uid,
    subjectId: 'general',
    subjectName: 'AI Tutor',
    topic: 'Concept Clarification',
    title: 'Ask AI Tutor tricky questions',
    reason: 'Stuck on complex definitions or formulas? Switch to Student or Exam mode in AI Tutor for instant clarity.',
    actionType: 'chat',
    actionRoute: '/chat',
    createdAt: DateTime.now(),
  ));

  // 3. Add Exam Summary Recommendation
  recommendations.add(Recommendation(
    id: 'rec_summary_notes',
    userId: uid,
    subjectId: 'summary',
    subjectName: 'Smart Notes',
    topic: 'Exam Revision',
    title: 'Generate Exam-Focus Revision Summaries',
    reason: 'Upload your semester syllabus or lecture slides to extract key terms, formulas, and high-weightage viva questions.',
    actionType: 'summary',
    actionRoute: '/summary',
    createdAt: DateTime.now(),
  ));

  // 4. Add Weekly Study Planner Recommendation
  recommendations.add(Recommendation(
    id: 'rec_planner_schedule',
    userId: uid,
    subjectId: 'planner',
    subjectName: 'Study Schedule',
    topic: 'Time Management',
    title: 'Organize your weekly study calendar',
    reason: 'Balance your ${userProfile?.enrolledSubjectIds.length ?? 4} enrolled subjects with an AI timetable.',
    actionType: 'planner',
    actionRoute: '/planner',
    createdAt: DateTime.now(),
  ));

  return recommendations;
});

class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(recommendationsProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: 'AI Recommendations',
                onBack: () => context.go('/'),
              ),
              Text(
                'Personalized action items derived from your quiz performance, weak areas, and exam timeline.',
                style: AppTextStyles.bodySecondary(context, fontSize: 13),
              ),
              const SizedBox(height: 20),

              ...recommendations.map((rec) {
                IconData getIcon() {
                  switch (rec.actionType) {
                    case 'practice':
                      return LucideIcons.listChecks;
                    case 'chat':
                      return LucideIcons.messageCircle;
                    case 'summary':
                      return LucideIcons.fileText;
                    case 'planner':
                      return LucideIcons.calendar;
                    default:
                      return LucideIcons.sparkles;
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(getIcon(), color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rec.title, style: AppTextStyles.displayBold(context, fontSize: 15)),
                                  Text(rec.subjectName, style: AppTextStyles.bodySecondary(context, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          rec.reason,
                          style: AppTextStyles.body(context, fontSize: 13).copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        CustomButton(
                          text: 'Take Action Now',
                          icon: LucideIcons.arrowRight,
                          onPressed: () {
                            if (rec.actionRoute == '/practice' || rec.actionRoute == '/chat') {
                              context.go(rec.actionRoute);
                            } else {
                              context.push(rec.actionRoute);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
