import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/models/quiz_model.dart';
import '../../auth/data/auth_repository.dart';
import '../data/quiz_repository.dart';
import 'mcq_setup_screen.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _currentIndex = 0;
  late Map<int, int> _userAnswers; // questionIndex -> selectedOptionIndex
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _userAnswers = {};

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(currentQuizProvider);
      if (session != null && session.isMockTest) {
        final totalSeconds = MockTestConfig.getDurationSeconds(
          session.totalQuestions,
        );
        setState(() {
          _secondsRemaining = totalSeconds;
        });
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _finalizeQuiz(isTimeout: true);
      } else {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _finalizeQuiz({bool isTimeout = false}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    _countdownTimer?.cancel();

    final session = ref.read(currentQuizProvider);
    final user = ref.read(authRepositoryProvider).currentUser;

    if (session == null || user == null) {
      if (mounted) context.go('/');
      return;
    }

    // Build completed questions with selected answers
    int score = 0;
    final updatedQuestions = <QuizQuestion>[];
    final answerList = <int>[];

    for (int i = 0; i < session.questions.length; i++) {
      final q = session.questions[i];
      final selected = _userAnswers[i];
      if (selected != null) {
        answerList.add(selected);
        if (selected == q.correctIndex) {
          score++;
        }
      } else {
        answerList.add(-1); // Unanswered
      }

      updatedQuestions.add(q.copyWith(selectedIndex: selected));
    }

    final completedSession = session.copyWith(
      userId: user.uid,
      score: score,
      isCompleted: true,
      endTime: DateTime.now(),
      questions: updatedQuestions,
      userAnswers: answerList,
    );

    // Save finalized session atomically and idempotently
    try {
      await ref
          .read(quizRepositoryProvider)
          .finalizeQuizSession(completedSession);
      ref.read(currentQuizProvider.notifier).state = completedSession;
      if (mounted) {
        context.pushReplacement('/result');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving quiz: $e')));
        context.pushReplacement('/result');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSubmitConfirmation(QuizSession session) {
    final unansweredCount = session.questions.length - _userAnswers.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Quiz?'),
        content: Text(
          unansweredCount > 0
              ? 'You have $unansweredCount unanswered question${unansweredCount > 1 ? 's' : ''}. Are you sure you want to submit?'
              : 'Are you ready to submit and calculate your final score?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Review Answers'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finalizeQuiz();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Submit Now',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

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
              const Text('No quiz active.'),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Go to Practice',
                onPressed: () => context.go('/practice'),
              ),
            ],
          ),
        ),
      );
    }

    final currentQ = session.questions[_currentIndex];
    final selectedAnswer = _userAnswers[_currentIndex];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ScreenHeader(
                      title:
                          'Q ${_currentIndex + 1} of ${session.questions.length}',
                      onBack: () {
                        _showSubmitConfirmation(session);
                      },
                    ),
                  ),
                  if (session.isMockTest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _secondsRemaining < 120
                            ? AppColors.error.withOpacity(0.15)
                            : (isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightSurface),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _secondsRemaining < 120
                              ? AppColors.error
                              : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.timer,
                            size: 15,
                            color: _secondsRemaining < 120
                                ? AppColors.error
                                : AppColors.accentAmber,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatTimer(_secondsRemaining),
                            style: AppTextStyles.monoBold(
                              context,
                              fontSize: 13,
                              color: _secondsRemaining < 120
                                  ? AppColors.error
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Progress Bar
              Row(
                children: List.generate(session.questions.length, (index) {
                  final isAnswered = _userAnswers.containsKey(index);
                  final isCurrent = index == _currentIndex;

                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _currentIndex = index),
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(
                          right: index == session.questions.length - 1 ? 0 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.primary
                              : (isAnswered
                                    ? AppColors.accentTeal
                                    : (isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder)),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Question Text Card
              CustomCard(
                child: Text(
                  currentQ.question,
                  style: AppTextStyles.body(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ).copyWith(height: 1.4),
                ),
              ),
              const SizedBox(height: 16),

              // Options
              Expanded(
                child: ListView.separated(
                  itemCount: currentQ.options.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final isSelected = selectedAnswer == index;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _userAnswers[_currentIndex] = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                    ? AppColors.primary.withOpacity(0.25)
                                    : AppColors.primaryLight)
                              : (isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurface),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder),
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: isSelected
                                  ? const Icon(
                                      LucideIcons.check,
                                      size: 13,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      String.fromCharCode(
                                        65 + index,
                                      ), // A, B, C, D
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                currentQ.options[index],
                                style: AppTextStyles.body(
                                  context,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Navigation Buttons
              Row(
                children: [
                  if (_currentIndex > 0)
                    Expanded(
                      flex: 1,
                      child: CustomButton(
                        text: 'Previous',
                        variant: ButtonVariant.ghost,
                        icon: LucideIcons.arrowLeft,
                        onPressed: () => setState(() => _currentIndex--),
                      ),
                    ),
                  if (_currentIndex > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: CustomButton(
                      text: _currentIndex == session.questions.length - 1
                          ? (_isSubmitting
                                ? 'Calculating Score...'
                                : 'Submit Quiz')
                          : 'Next Question',
                      icon: _currentIndex == session.questions.length - 1
                          ? LucideIcons.checkCircle
                          : LucideIcons.arrowRight,
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              if (_currentIndex ==
                                  session.questions.length - 1) {
                                _showSubmitConfirmation(session);
                              } else {
                                setState(() => _currentIndex++);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
