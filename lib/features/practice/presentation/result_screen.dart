import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/text_styles.dart';
import 'mcq_setup_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentQuizProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (session == null || session.questions.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No quiz result found.'),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Go to Dashboard',
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      );
    }

    final questions = session.questions;
    final score = session.score;
    final pct = session.accuracy.round();
    final isSuccess = pct >= 70;
    final durationMins = session.durationMinutes;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: session.isMockTest
                    ? 'Mock Exam Results'
                    : 'Quiz Results',
                onBack: () => context.go('/'),
              ),

              // Score Overview Card
              CustomCard(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    ProgressRing(
                      value: pct.toDouble(),
                      size: 116,
                      strokeWidth: 10,
                      color: isSuccess
                          ? AppColors.success
                          : (pct >= 40 ? AppColors.warning : AppColors.error),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$score/${questions.length}',
                            style: AppTextStyles.monoBold(
                              context,
                              fontSize: 26,
                            ),
                          ),
                          Text(
                            '$pct% Score',
                            style: AppTextStyles.bodySecondary(
                              context,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      pct >= 80
                          ? 'Outstanding! You have strong mastery over this topic.'
                          : pct >= 60
                          ? 'Solid performance! A quick revision will reinforce the weak areas.'
                          : 'Keep practicing! Review the detailed explanations below to master these concepts.',
                      style: AppTextStyles.body(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Stat Grid: Correct, Incorrect, Duration
              Row(
                children: [
                  Expanded(
                    child: CustomCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$score',
                            style: AppTextStyles.monoBold(
                              context,
                              fontSize: 20,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Correct',
                            style: AppTextStyles.bodySecondary(
                              context,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${questions.length - score}',
                            style: AppTextStyles.monoBold(
                              context,
                              fontSize: 20,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Incorrect',
                            style: AppTextStyles.bodySecondary(
                              context,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$durationMins m',
                            style: AppTextStyles.monoBold(
                              context,
                              fontSize: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Duration',
                            style: AppTextStyles.bodySecondary(
                              context,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Text(
                'Detailed Question Review',
                style: AppTextStyles.displayBold(context, fontSize: 16),
              ),
              const SizedBox(height: 10),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final q = questions[i];
                  final isAnswered =
                      q.selectedIndex != null && q.selectedIndex! >= 0;
                  final isCorrect =
                      isAnswered && q.selectedIndex == q.correctIndex;
                  final isOpen = _expandedIndex == i;

                  return CustomCard(
                    onTap: () =>
                        setState(() => _expandedIndex = isOpen ? null : i),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: !isAnswered
                                    ? Colors.grey
                                    : (isCorrect
                                          ? AppColors.success
                                          : AppColors.error),
                              ),
                              child: Icon(
                                !isAnswered
                                    ? LucideIcons.minus
                                    : (isCorrect
                                          ? LucideIcons.check
                                          : LucideIcons.x),
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${i + 1}. ${q.question}',
                                style: AppTextStyles.body(
                                  context,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              isOpen
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ],
                        ),
                        if (isOpen) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(left: 36),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isAnswered)
                                  Text.rich(
                                    TextSpan(
                                      text: 'Your choice: ',
                                      style: AppTextStyles.bodySecondary(
                                        context,
                                        fontSize: 13,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: q.options[q.selectedIndex!],
                                          style: AppTextStyles.body(
                                            context,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isCorrect
                                                ? AppColors.success
                                                : AppColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Text(
                                    'Unanswered',
                                    style: AppTextStyles.body(
                                      context,
                                      fontSize: 13,
                                      color: Colors.orange,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                if (!isCorrect)
                                  Text.rich(
                                    TextSpan(
                                      text: 'Correct answer: ',
                                      style: AppTextStyles.bodySecondary(
                                        context,
                                        fontSize: 13,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: q.options[q.correctIndex],
                                          style: AppTextStyles.body(
                                            context,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkBackground
                                        : AppColors.lightBackground,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '💡 ${q.explanation}',
                                    style: AppTextStyles.bodySecondary(
                                      context,
                                      fontSize: 12,
                                    ).copyWith(height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              if (score < questions.length) ...[
                const SizedBox(height: 16),
                CustomCard(
                  onTap: () {
                    final wrongQuestions = questions
                        .where((q) => q.selectedIndex != q.correctIndex)
                        .toList();
                    final sample = wrongQuestions.isNotEmpty
                        ? wrongQuestions.first
                        : questions.first;
                    context.go(
                      '/chat',
                      extra: {
                        'initialPrompt':
                            'Can you explain why the answer to this question is "${sample.options[sample.correctIndex]}":\n\n"${sample.question}"',
                        'subjectId': session.subjectId,
                      },
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.bot,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Clarify Doubts with AI Tutor',
                              style: AppTextStyles.body(
                                context,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Get instant step-by-step explanations for missed questions.',
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
              ],
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Practice Again',
                      variant: ButtonVariant.ghost,
                      icon: LucideIcons.refreshCw,
                      onPressed: () => context.go('/practice'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomButton(
                      text: 'Dashboard',
                      icon: LucideIcons.home,
                      onPressed: () => context.go('/'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
