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

  // 1. Check for Weakest Subject (< 70% accuracy)
  if (subjectProgress.isNotEmpty) {
    for (final sp in subjectProgress) {
      final acc = (sp['accuracy'] as num?)?.toDouble() ?? 0.0;
      final totalQ = (sp['totalQuestions'] as num?)?.toInt() ?? 0;
      final correctQ = (sp['correctAnswers'] as num?)?.toInt() ?? 0;
      final subId = sp['id'] as String;
      final subObj = AppSubjects.getById(subId);

      if (subObj != null && acc < 70.0 && totalQ > 0) {
        final incorrect = totalQ - correctQ;
        recommendations.add(Recommendation(
          id: 'rec_weak_$subId',
          userId: uid,
          subjectId: subId,
          subjectName: subObj.name,
          topic: 'Targeted Practice: ${subObj.name}',
          title: 'Strengthen ${subObj.shortName} Foundation',
          reason: 'Your accuracy is currently ${acc.toInt()}% in ${subObj.name}.',
          evidence: '$incorrect incorrect answers recorded across $totalQ attempted questions.',
          actionLabel: 'Start 10-Question ${subObj.shortName} Quiz',
          actionType: 'practice',
          actionRoute: '/practice',
          accuracy: acc,
          isPersonalized: true,
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  // 2. Check for Enrolled Subjects with 0 Practice
  if (userProfile != null && userProfile.enrolledSubjectIds.isNotEmpty) {
    for (final subId in userProfile.enrolledSubjectIds) {
      final hasProgress = subjectProgress.any((sp) => sp['id'] == subId);
      final subObj = AppSubjects.getById(subId);
      if (!hasProgress && subObj != null) {
        recommendations.add(Recommendation(
          id: 'rec_unstudied_$subId',
          userId: uid,
          subjectId: subId,
          subjectName: subObj.name,
          topic: 'Initial Assessment',
          title: 'Assess Your ${subObj.shortName} Baseline',
          reason: 'You enrolled in ${subObj.name} but haven\'t attempted a quiz yet.',
          evidence: 'Zero quiz attempts logged in ${subObj.name}.',
          actionLabel: 'Take 5-Question Diagnostic',
          actionType: 'practice',
          actionRoute: '/practice',
          isPersonalized: true,
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  // 3. General Helpful StudyMate Suggestions
  recommendations.add(Recommendation(
    id: 'rec_chat_tutor',
    userId: uid,
    subjectId: 'general',
    subjectName: 'AI Tutor',
    topic: 'Concept Clarification',
    title: 'Ask AI Tutor Tricky Viva & Exam Questions',
    reason: 'Stuck on complex definitions or formulas? Switch to Viva or Exam mode in AI Tutor for structured breakdown.',
    evidence: 'Supports Beginner, Student, Exam, and Viva modes with real-world analogies.',
    actionLabel: 'Open AI Tutor',
    actionType: 'chat',
    actionRoute: '/chat',
    isPersonalized: false,
    createdAt: DateTime.now(),
  ));

  recommendations.add(Recommendation(
    id: 'rec_summary_notes',
    userId: uid,
    subjectId: 'summary',
    subjectName: 'Smart Notes',
    topic: 'Exam Revision',
    title: 'Generate Exam-Focus Revision Summaries',
    reason: 'Upload your syllabus notes or PDF chapters to extract key terms, formulas, and high-yield revision questions.',
    evidence: '5-section structured summary with instant quiz generator.',
    actionLabel: 'Summarize Document',
    actionType: 'summary',
    actionRoute: '/summary',
    isPersonalized: false,
    createdAt: DateTime.now(),
  ));

  recommendations.add(Recommendation(
    id: 'rec_planner_schedule',
    userId: uid,
    subjectId: 'planner',
    subjectName: 'Study Schedule',
    topic: 'Time Management',
    title: 'Generate Your Weekly Study Timetable',
    reason: 'Balance your study workload with a 7-day plan tailored to your daily goal.',
    evidence: 'Generates morning/evening tasks with persistent checkboxes.',
    actionLabel: 'View AI Planner',
    actionType: 'planner',
    actionRoute: '/planner',
    isPersonalized: false,
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
                                color: rec.isPersonalized
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : (isDark ? AppColors.darkSurface : AppColors.lightBackground),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(getIcon(), color: rec.isPersonalized ? AppColors.primary : AppColors.accentAmber, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(rec.title, style: AppTextStyles.displayBold(context, fontSize: 15)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: rec.isPersonalized
                                              ? AppColors.accentAmber.withValues(alpha: 0.15)
                                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          rec.isPersonalized ? 'Personalized' : 'Suggestion',
                                          style: AppTextStyles.monoBold(
                                            context,
                                            fontSize: 10,
                                            color: rec.isPersonalized ? AppColors.accentAmber : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(rec.subjectName, style: AppTextStyles.bodySecondary(context, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          rec.reason,
                          style: AppTextStyles.body(context, fontSize: 13).copyWith(height: 1.4),
                        ),
                        if (rec.evidence != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.info, size: 14, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Evidence: ${rec.evidence}',
                                    style: AppTextStyles.bodySecondary(context, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        CustomButton(
                          text: rec.actionLabel,
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
