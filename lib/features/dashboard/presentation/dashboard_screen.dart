import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/models/subject.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/text_styles.dart';
import '../../profile/data/user_repository.dart';
import '../../progress/data/progress_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final userProfile = ref.watch(currentUserProfileProvider).value;
    final dailyStats = ref.watch(dailyStatsProvider).value;
    final subjectProgress = ref.watch(subjectProgressProvider).value;

    final String todayDate = DateFormat('EEEE, d MMMM').format(DateTime.now());
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good Morning'
        : (hour < 17 ? 'Good Afternoon' : 'Good Evening');
    final String greeting =
        '$timeGreeting, ${userProfile?.displayName?.split(' ').first ?? 'Student'} 👋';
    final int streak = userProfile?.currentStreak ?? 0;

    // Compute overall progress
    int overallProgress = 0;
    if (subjectProgress != null && subjectProgress.isNotEmpty) {
      double totalAccuracy = 0;
      for (var sp in subjectProgress) {
        totalAccuracy += (sp['accuracy'] as num?)?.toDouble() ?? 0;
      }
      overallProgress = (totalAccuracy / subjectProgress.length).round();
    }

    final int completedMins = dailyStats?['minutesStudied'] as int? ?? 0;
    final int totalMins = userProfile?.dailyStudyGoalMinutes ?? 30;
    final double goalProgress = (completedMins / totalMins).clamp(0.0, 1.0);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todayDate,
                          style: AppTextStyles.bodySecondary(
                            context,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          greeting,
                          style: AppTextStyles.displayBold(
                            context,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (userProfile?.displayName != null &&
                              userProfile!.displayName!.isNotEmpty)
                          ? userProfile.displayName![0].toUpperCase()
                          : 'S',
                      style: AppTextStyles.displayBold(
                        context,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Overview Card
              CustomCard(
                child: Row(
                  children: [
                    ProgressRing(
                      value: overallProgress.toDouble(),
                      size: 68,
                      child: Text(
                        '$overallProgress%',
                        style: AppTextStyles.monoBold(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 1,
                      height: 50,
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.flame,
                            color: AppColors.accentAmber,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$streak',
                                style: AppTextStyles.monoBold(
                                  context,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                'day streak',
                                style: AppTextStyles.bodySecondary(
                                  context,
                                  fontSize: 12,
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
              const SizedBox(height: 14),

              // Target Exam Countdown Banner
              if (userProfile?.targetExam != null &&
                  userProfile!.targetExam!.isNotEmpty) ...[
                CustomCard(
                  onTap: () => context.push('/planner'),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.target,
                          color: AppColors.accentAmber,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userProfile.targetExam!,
                              style: AppTextStyles.body(
                                context,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              userProfile.examDate != null
                                  ? '${userProfile.examDate!.difference(DateTime.now()).inDays.clamp(0, 999)} days remaining (${DateFormat('dd MMM yyyy').format(userProfile.examDate!)})'
                                  : 'Target Exam Active • Tap to plan timetable',
                              style: AppTextStyles.bodySecondary(
                                context,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Today's Goal
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today\'s Goal',
                          style: AppTextStyles.body(
                            context,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$completedMins / $totalMins mins',
                          style: AppTextStyles.monoBold(context, fontSize: 13)
                              .copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: goalProgress,
                      backgroundColor: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accentTeal,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Subjects
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Your subjects',
                    style: AppTextStyles.displayBold(context, fontSize: 15),
                  ),
                  Text(
                    '${userProfile?.enrolledSubjectIds.length ?? 0} enrolled',
                    style: AppTextStyles.bodySecondary(context, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: Builder(
                  builder: (context) {
                    final enrolledIds = userProfile?.enrolledSubjectIds ?? [];
                    if (enrolledIds.isEmpty) {
                      return const Center(
                        child: Text('No subjects enrolled yet.'),
                      );
                    }
                    final enrolledSubjects = AppSubjects.availableSubjects
                        .where((s) => enrolledIds.contains(s.id))
                        .toList();

                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: enrolledSubjects.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final subject = enrolledSubjects[index];
                        // Find progress for this subject
                        double progress = 0;
                        if (subjectProgress != null) {
                          final sp = subjectProgress
                              .where((s) => s['id'] == subject.id)
                              .firstOrNull;
                          if (sp != null) {
                            progress =
                                (sp['accuracy'] as num?)?.toDouble() ?? 0;
                          }
                        }
                        return InkWell(
                          onTap: () => context.go(
                            '/practice',
                            extra: {'subjectId': subject.id},
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 116,
                            padding: const EdgeInsets.only(
                              left: 18,
                              top: 14,
                              right: 14,
                              bottom: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightSurface,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Spiral Edge simulation
                                Positioned(
                                  left: -14, // Relative to padding
                                  top: 0,
                                  bottom: 0,
                                  width: 3,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      color: subject.color.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ProgressRing(
                                      value: progress,
                                      size: 38,
                                      strokeWidth: 4,
                                      color: subject.color,
                                      child: Text(
                                        '${progress.toInt()}',
                                        style: AppTextStyles.monoBold(
                                          context,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      subject.shortName,
                                      style: AppTextStyles.body(
                                        context,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // Quick Actions
              Text(
                'Quick actions',
                style: AppTextStyles.displayBold(context, fontSize: 15),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: [
                  _QuickActionCard(
                    label: 'Ask AI',
                    icon: LucideIcons.messageCircle,
                    onTap: () => context.go('/chat'),
                  ),
                  _QuickActionCard(
                    label: 'Study Planner',
                    icon: LucideIcons.calendar,
                    onTap: () => context.push('/planner'),
                  ),
                  _QuickActionCard(
                    label: 'Generate MCQs',
                    icon: LucideIcons.listChecks,
                    onTap: () => context.go('/practice'),
                  ),
                  _QuickActionCard(
                    label: 'Summarize',
                    icon: LucideIcons.fileText,
                    onTap: () => context.push('/summary'),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Recommendation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Personalized Focus',
                    style: AppTextStyles.displayBold(context, fontSize: 15),
                  ),
                  TextButton(
                    onPressed: () => context.push('/recommendations'),
                    child: Text(
                      'View all',
                      style: AppTextStyles.body(
                        context,
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  if (subjectProgress == null || subjectProgress.isEmpty) {
                    return CustomCard(
                      backgroundColor: AppColors.primary,
                      customBorder: BorderSide.none,
                      onTap: () => context.push('/recommendations'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.sparkles,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'AI STUDY ROADMAP',
                                style: AppTextStyles.body(
                                  context,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ).copyWith(letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Explore personalized recommendations',
                            style: AppTextStyles.body(
                              context,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'View tailored study advice, practice sets, and timetable suggestions.',
                            style: AppTextStyles.body(
                              context,
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Find weakest subject
                  var weakestSubjectId = '';
                  double lowestAccuracy = 101.0;

                  for (var sp in subjectProgress) {
                    final acc = (sp['accuracy'] as num?)?.toDouble() ?? 0.0;
                    if (acc < lowestAccuracy) {
                      lowestAccuracy = acc;
                      weakestSubjectId = sp['id'] as String;
                    }
                  }

                  final weakestSubObj = AppSubjects.getById(weakestSubjectId);
                  final subjectName = weakestSubObj?.name ?? 'Key Subject';

                  return CustomCard(
                    backgroundColor: AppColors.primary,
                    customBorder: BorderSide.none,
                    onTap: () {
                      context.go(
                        '/practice',
                        extra: {'subjectId': weakestSubjectId},
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.info,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'RECOMMENDED FOR YOU',
                              style: AppTextStyles.body(
                                context,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ).copyWith(letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Review $subjectName topics today',
                          style: AppTextStyles.body(
                            context,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your weakest subject at ${lowestAccuracy.toInt()}% — a focused push here moves the needle fastest.',
                          style: AppTextStyles.body(
                            context,
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Start practice',
                              style: AppTextStyles.body(
                                context,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              LucideIcons.chevronRight,
                              size: 15,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
