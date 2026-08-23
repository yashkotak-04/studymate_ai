import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_chip.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/text_styles.dart';
import '../../profile/data/user_repository.dart';
import '../data/auth_repository.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/models/chat_model.dart';
import '../../../core/services/firebase_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _programController = TextEditingController();
  final _examController = TextEditingController();

  DateTime? _selectedExamDate;
  final List<String> _selectedSubjectIds = ['os', 'py'];
  ExplanationMode _preferredAiMode = ExplanationMode.student;
  int _dailyGoal = 30;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _nameController.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _programController.dispose();
    _examController.dispose();
    super.dispose();
  }

  void _toggleSubject(String id) {
    setState(() {
      if (_selectedSubjectIds.contains(id)) {
        if (_selectedSubjectIds.length > 1) {
          _selectedSubjectIds.remove(id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please keep at least one enrolled subject.'),
            ),
          );
        }
      } else {
        _selectedSubjectIds.add(id);
      }
    });
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExamDate ?? now.add(const Duration(days: 60)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() => _selectedExamDate = picked);
    }
  }

  Future<void> _completeOnboarding() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full or display name.'),
        ),
      );
      return;
    }

    if (_selectedSubjectIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one study subject.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        await ref
            .read(userRepositoryProvider)
            .updateOnboarding(
              user.uid,
              displayName: name,
              academicProgram: _programController.text.trim().isNotEmpty
                  ? _programController.text.trim()
                  : 'Diploma / Engineering',
              targetExam: _examController.text.trim().isNotEmpty
                  ? _examController.text.trim()
                  : 'Semester Exams',
              examDate: _selectedExamDate,
              enrolledSubjectIds: _selectedSubjectIds,
              dailyGoal: _dailyGoal,
              preferredAiMode: _preferredAiMode.label,
            );

        ref.read(firebaseServiceProvider).logOnboardingCompleted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not complete onboarding. Please try again.'),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'Welcome to StudyMate AI',
                style: AppTextStyles.displayBold(context, fontSize: 26),
              ),
              const SizedBox(height: 8),
              Text(
                'Let\'s personalize your curriculum, AI teaching style, and goals.',
                style: AppTextStyles.bodySecondary(context, fontSize: 14),
              ),
              const SizedBox(height: 28),

              _buildTextField(
                'Your Name *',
                _nameController,
                isDark,
                LucideIcons.user,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                'Academic Program (e.g. Diploma CS, B.Tech)',
                _programController,
                isDark,
                LucideIcons.graduationCap,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                'Target Exam (e.g. MSBTE 6th Sem, Finals)',
                _examController,
                isDark,
                LucideIcons.target,
              ),
              const SizedBox(height: 14),

              InkWell(
                onTap: _pickExamDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.cardBorderDark
                          : AppColors.cardBorderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.calendar,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedExamDate != null
                              ? 'Exam Date: ${_selectedExamDate!.day}/${_selectedExamDate!.month}/${_selectedExamDate!.year}'
                              : 'Optional Target Exam Date (Tap to set)',
                          style: _selectedExamDate != null
                              ? AppTextStyles.body(
                                  context,
                                  fontWeight: FontWeight.w600,
                                )
                              : AppTextStyles.bodySecondary(context),
                        ),
                      ),
                      if (_selectedExamDate != null)
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              setState(() => _selectedExamDate = null),
                        )
                      else
                        const Icon(LucideIcons.chevronRight, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Enrolled Subjects (Select at least 1) *',
                style: AppTextStyles.body(context, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppSubjects.availableSubjects.map((s) {
                  final isSelected = _selectedSubjectIds.contains(s.id);
                  return CustomChip(
                    label: s.name,
                    isActive: isSelected,
                    activeColor: s.color,
                    onTap: () => _toggleSubject(s.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              Text(
                'Preferred AI Explanation Mode',
                style: AppTextStyles.body(context, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how you want the AI Tutor to communicate by default.',
                style: AppTextStyles.bodySecondary(context, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ...ExplanationMode.values.map((mode) {
                final isSelected = _preferredAiMode == mode;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                              ? AppColors.primary.withOpacity(0.2)
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
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    leading: Icon(
                      mode.icon,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white70 : Colors.black54),
                      size: 20,
                    ),
                    title: Text(
                      mode.label,
                      style: AppTextStyles.body(
                        context,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      mode.desc,
                      style: AppTextStyles.bodySecondary(context, fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            LucideIcons.checkCircle2,
                            color: AppColors.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () => setState(() => _preferredAiMode = mode),
                  ),
                );
              }),
              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily Study Goal',
                    style: AppTextStyles.body(
                      context,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$_dailyGoal mins/day',
                    style: AppTextStyles.monoBold(
                      context,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _dailyGoal.toDouble(),
                min: 15,
                max: 180,
                divisions: 11,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _dailyGoal = val.toInt());
                },
              ),
              const SizedBox(height: 36),

              CustomButton(
                text: _isLoading
                    ? 'Personalizing...'
                    : 'Complete Setup & Launch',
                isFullWidth: true,
                onPressed: _isLoading ? null : _completeOnboarding,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller,
    bool isDark,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 19),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      style: AppTextStyles.body(context),
    );
  }
}
