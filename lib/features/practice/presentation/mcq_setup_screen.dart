import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/custom_chip.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/models/quiz_model.dart';
import '../../auth/data/auth_repository.dart';

final currentQuizProvider = StateProvider<QuizSession?>((ref) => null);

class McqSetupScreen extends ConsumerStatefulWidget {
  final String? initialSubjectId;
  final String? initialTopic;
  final int? initialCount;
  final bool? isMock;

  const McqSetupScreen({
    super.key,
    this.initialSubjectId,
    this.initialTopic,
    this.initialCount,
    this.isMock,
  });

  @override
  ConsumerState<McqSetupScreen> createState() => _McqSetupScreenState();
}

class _McqSetupScreenState extends ConsumerState<McqSetupScreen> {
  late String _selectedSubject;
  late final TextEditingController _topicController;
  String _difficulty = 'Medium';
  late int _count;
  bool _isGenerating = false;
  late bool _isMockTest;

  @override
  void initState() {
    super.initState();
    _selectedSubject =
        (widget.initialSubjectId != null &&
            AppSubjects.getById(widget.initialSubjectId!) != null)
        ? widget.initialSubjectId!
        : AppSubjects.availableSubjects.first.id;
    _topicController = TextEditingController(
      text: widget.initialTopic ?? 'Process Scheduling & Synchronization',
    );
    _count = widget.initialCount ?? 5;
    _isMockTest = widget.isMock ?? false;
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateMcqs() async {
    setState(() => _isGenerating = true);
    final user = ref.read(authRepositoryProvider).currentUser;

    try {
      final subjectName = _isMockTest
          ? 'Comprehensive Engineering Syllabus (${AppSubjects.availableSubjects.map((s) => s.shortName).join(', ')})'
          : AppSubjects.getByIdOrDefault(_selectedSubject).name;

      final topic = _isMockTest
          ? 'Full Exam Mixed Question Paper across Operating Systems, Python, DBMS, and Networks'
          : _topicController.text.trim();

      final aiService = ref.read(aiServiceProvider);
      final questions = await aiService.generateQuiz(
        subject: subjectName,
        topic: topic.isNotEmpty ? topic : 'Core Syllabus',
        difficulty: _difficulty,
        count: _count,
      );

      final session = QuizSession(
        id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
        userId: user?.uid ?? '',
        subjectId: _isMockTest ? 'mixed' : _selectedSubject,
        topic: topic,
        difficulty: _difficulty,
        totalQuestions: questions.length,
        score: 0,
        isMockTest: _isMockTest,
        isCompleted: false,
        startTime: DateTime.now(),
        endTime: DateTime.now().add(
          Duration(
            minutes: _isMockTest
                ? MockTestConfig.getDurationMinutes(_count)
                : 10,
          ),
        ),
        questions: questions,
      );

      ref.read(currentQuizProvider.notifier).state = session;
      ref
          .read(firebaseServiceProvider)
          .logQuizGenerated(
            _isMockTest ? 'Mock Test' : _selectedSubject,
            questions.length,
            _isMockTest,
          );

      if (mounted) {
        context.push('/quiz');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate MCQs: ${e.toString().replaceAll('Exception:', '').trim()}',
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: _isMockTest ? 'Mock Exam Setup' : 'Practice MCQs',
                onBack: () => context.go('/'),
              ),

              CustomCard(
                padding: const EdgeInsets.all(14),
                child: SwitchListTile(
                  title: Text(
                    'Mock Test Mode',
                    style: AppTextStyles.body(
                      context,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Full-length timed exam across all syllabus subjects (${MockTestConfig.getDurationMinutes(_count)} min)',
                    style: AppTextStyles.bodySecondary(context, fontSize: 12),
                  ),
                  value: _isMockTest,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setState(() {
                      _isMockTest = val;
                      if (val) {
                        _count = MockTestConfig.defaultQuestionCount;
                      } else {
                        _count = 5;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              if (!_isMockTest) ...[
                Text(
                  'Subject',
                  style: AppTextStyles.body(
                    context,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: AppSubjects.availableSubjects.map((s) {
                      final isActive = _selectedSubject == s.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: CustomChip(
                          label: s.shortName,
                          isActive: isActive,
                          activeColor: s.color,
                          onTap: () => setState(() => _selectedSubject = s.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  'Specific Topic / Chapter',
                  style: AppTextStyles.body(
                    context,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    hintText:
                        'e.g. Memory Management, SQL Joins, TCP Handshake',
                  ),
                  style: AppTextStyles.body(context),
                ),
                const SizedBox(height: 18),
              ] else ...[
                CustomCard(
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.timer,
                        color: AppColors.accentAmber,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mock Exam Timer: ${MockTestConfig.getDurationMinutes(_count)} Minutes',
                              style: AppTextStyles.body(
                                context,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Test will automatically submit when the countdown ends (${MockTestConfig.minutesPerQuestion}m/question).',
                              style: AppTextStyles.bodySecondary(
                                context,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              Text(
                'Difficulty Level',
                style: AppTextStyles.body(context, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: ['Easy', 'Medium', 'Hard'].map((d) {
                    final isActive = _difficulty == d;
                    return Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _difficulty = d),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            d,
                            style: AppTextStyles.body(
                              context,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? Colors.white
                                  : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Number of Questions',
                style: AppTextStyles.body(context, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              CustomCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => setState(
                        () => _count = (_count > 3)
                            ? _count - (_isMockTest ? 5 : 1)
                            : 3,
                      ),
                      icon: const Icon(LucideIcons.minus, size: 16),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '$_count Questions',
                      style: AppTextStyles.monoBold(context, fontSize: 18),
                    ),
                    IconButton(
                      onPressed: () => setState(
                        () => _count = (_count < 20)
                            ? _count + (_isMockTest ? 5 : 1)
                            : 20,
                      ),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              CustomButton(
                text: _isGenerating
                    ? 'Generating Question Paper...'
                    : (_isMockTest ? 'Start Mock Exam' : 'Generate MCQs'),
                icon: LucideIcons.sparkles,
                isFullWidth: true,
                onPressed: _isGenerating ? null : _generateMcqs,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
