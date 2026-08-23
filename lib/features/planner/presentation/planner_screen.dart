import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/models/study_plan_model.dart';
import '../../../shared/models/subject.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/user_repository.dart';
import '../../progress/data/progress_repository.dart';
import '../data/study_plan_repository.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  bool _isGenerating = false;

  Future<void> _generatePlan() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    final profile = ref.read(currentUserProfileProvider).value;
    final subjectProgress = ref.read(subjectProgressProvider).value;

    setState(() => _isGenerating = true);

    try {
      final enrolled =
          (profile?.enrolledSubjectIds != null &&
              profile!.enrolledSubjectIds.isNotEmpty)
          ? profile.enrolledSubjectIds
          : AppSubjects.availableSubjects.map((s) => s.id).toList();
      final targetExam = profile?.targetExam ?? 'Semester Finals';
      final dailyGoal = profile?.dailyStudyGoalMinutes ?? 30;

      // Find weak subjects (< 65% accuracy)
      final weakSubjects = <String>[];
      if (subjectProgress != null) {
        for (final sp in subjectProgress) {
          final acc = (sp['accuracy'] as num?)?.toDouble() ?? 0.0;
          if (acc < 65.0) {
            weakSubjects.add(sp['id'] as String);
          }
        }
      }

      final aiService = ref.read(aiServiceProvider);
      final plan = await aiService.generateStudyPlan(
        userId: user.uid,
        targetExam: targetExam,
        dailyGoalMinutes: dailyGoal,
        enrolledSubjects: enrolled,
        weakSubjects: weakSubjects,
        examDate: profile?.examDate,
      );

      await ref.read(studyPlanRepositoryProvider).savePlan(plan);
      ref.read(firebaseServiceProvider).logStudyPlanGenerated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personalized weekly study plan generated!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate plan: ${e.toString().replaceAll('Exception:', '').trim()}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _toggleTask(StudyPlan plan, String dayName, StudyPlanTask task) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    final newStatus = !task.isCompleted;
    await ref
        .read(studyPlanRepositoryProvider)
        .toggleTaskCompletion(user.uid, plan.id, dayName, task.id, newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(activeStudyPlanProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: 'Study Planner',
                onBack: () => context.go('/'),
              ),

              planAsync.when(
                data: (plan) {
                  if (plan == null) {
                    return CustomCard(
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primary.withOpacity(0.2)
                                  : AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.calendar,
                              size: 32,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No active study plan.',
                            style: AppTextStyles.displayBold(
                              context,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Let AI construct a balanced 7-day study timetable customized to your enrolled subjects, weak topics, and daily goal.',
                            style: AppTextStyles.bodySecondary(context),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          CustomButton(
                            text: _isGenerating
                                ? 'Generating Weekly Plan...'
                                : 'Generate 7-Day Plan',
                            icon: LucideIcons.sparkles,
                            isFullWidth: true,
                            onPressed: _isGenerating ? null : _generatePlan,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress Overview
                      CustomCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        plan.targetExam,
                                        style: AppTextStyles.displayBold(
                                          context,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        plan.overview,
                                        style: AppTextStyles.bodySecondary(
                                          context,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.primary.withOpacity(0.2)
                                        : AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${plan.completedTasks}/${plan.totalTasks} Done',
                                    style: AppTextStyles.monoBold(
                                      context,
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: plan.totalTasks > 0
                                  ? (plan.completedTasks / plan.totalTasks)
                                  : 0,
                              backgroundColor: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Days list
                      ...plan.days.map((day) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 4.0,
                                  bottom: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      day.dayName,
                                      style: AppTextStyles.displayBold(
                                        context,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${day.focus}',
                                      style: AppTextStyles.bodySecondary(
                                        context,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...day.tasks.map((task) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: CustomCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () => _toggleTask(
                                            plan,
                                            day.dayName,
                                            task,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              color: task.isCompleted
                                                  ? AppColors.success
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: task.isCompleted
                                                    ? AppColors.success
                                                    : (isDark
                                                          ? AppColors.darkBorder
                                                          : AppColors
                                                                .lightBorder),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: task.isCompleted
                                                ? const Icon(
                                                    LucideIcons.check,
                                                    size: 14,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                task.topic,
                                                style:
                                                    AppTextStyles.body(
                                                      context,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                    ).copyWith(
                                                      decoration:
                                                          task.isCompleted
                                                          ? TextDecoration
                                                                .lineThrough
                                                          : null,
                                                      color: task.isCompleted
                                                          ? (isDark
                                                                ? AppColors
                                                                      .darkTextSecondary
                                                                : AppColors
                                                                      .lightTextSecondary)
                                                          : null,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Text(
                                                    '${task.timeSlot} • ${task.subjectName} • ${task.durationMinutes}m',
                                                    style:
                                                        AppTextStyles.bodySecondary(
                                                          context,
                                                          fontSize: 11,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                      CustomButton(
                        text: _isGenerating
                            ? 'Regenerating Plan...'
                            : 'Regenerate Weekly Plan',
                        variant: ButtonVariant.ghost,
                        icon: LucideIcons.refreshCw,
                        isFullWidth: true,
                        onPressed: _isGenerating ? null : _generatePlan,
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Center(child: Text('Error loading plan: $e')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
