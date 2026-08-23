import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/custom_chip.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/models/summary_model.dart';
import '../../../shared/models/quiz_model.dart';
import '../../auth/data/auth_repository.dart';
import '../data/summary_repository.dart';
import '../../practice/presentation/mcq_setup_screen.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  final _textController = TextEditingController();
  bool _isGenerating = false;
  bool _isUploadingPdf = false;
  String? _pickedFileName;
  Uint8List? _pickedFileBytes;
  String? _pickedFileMimeType;
  GeneratedSummary? _result;
  String _activeSourceText = '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcessPdf() async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (files == null || files.isEmpty) return;

      final file = files.first;
      final maxMb = ref.read(firebaseServiceProvider).maxPdfSizeMb;

      if (file.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access selected file path.'),
            ),
          );
        }
        return;
      }

      final f = File(file.path!);
      if (!await f.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected file does not exist on disk.'),
            ),
          );
        }
        return;
      }

      final fileSize = await f.length();
      if (fileSize > maxMb * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File size (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB) exceeds the ${maxMb}MB limit.',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _isUploadingPdf = true;
        _pickedFileName = file.name;
      });

      final extension = file.name.split('.').last.toLowerCase();
      if (extension == 'pdf') {
        final bytes = await f.readAsBytes();
        if (bytes.isEmpty) {
          throw Exception('The selected PDF document is empty.');
        }
        _pickedFileBytes = bytes;
        _pickedFileMimeType = 'application/pdf';
        _textController.text =
            '[PDF Document: ${file.name} (${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB) - Ready for AI summarization & quiz generation]';
      } else if (extension == 'txt') {
        final text = await f.readAsString();
        if (text.trim().isEmpty) {
          throw Exception('The text file is empty.');
        }
        _pickedFileBytes = null;
        _pickedFileMimeType = null;
        _textController.text = text;
      } else {
        throw Exception(
          'Unsupported file format. Please upload a PDF or TXT file.',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Loaded ${file.name} successfully! Ready to summarize.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to read document: ${e.toString().replaceAll('Exception:', '').trim()}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPdf = false);
      }
    }
  }

  Future<void> _generateSummary() async {
    final hasBytes = _pickedFileBytes != null && _pickedFileBytes!.isNotEmpty;
    final text = _textController.text.trim();

    if (!hasBytes && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste some text notes or upload a document.'),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _activeSourceText = text;
    });

    try {
      final aiService = ref.read(aiServiceProvider);
      GeneratedSummary summary;

      if (hasBytes) {
        summary = await aiService.generateSummaryFromDocument(
          documentBytes: _pickedFileBytes,
          mimeType: _pickedFileMimeType ?? 'application/pdf',
        );
      } else {
        summary = await aiService.generateSummary(text: text);
      }

      if (mounted) {
        setState(() {
          _result = summary;
        });
      }

      final authUser = ref.read(authRepositoryProvider).currentUser;
      if (authUser != null) {
        final title =
            _pickedFileName ??
            (text.length > 30 ? '${text.substring(0, 30)}...' : text);
        final doc = SummaryDocument(
          id: 'summary_${DateTime.now().millisecondsSinceEpoch}',
          userId: authUser.uid,
          title: title,
          sourceText: hasBytes
              ? 'Uploaded PDF: $_pickedFileName'
              : (text.length > 1000 ? '${text.substring(0, 1000)}...' : text),
          summary: summary,
          createdAt: DateTime.now(),
        );
        await ref.read(summaryRepositoryProvider).saveSummary(doc);
        ref
            .read(firebaseServiceProvider)
            .logSummaryGenerated(_pickedFileName != null ? 'pdf' : 'text');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate summary: ${e.toString().replaceAll('Exception:', '').trim()}',
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

  Future<void> _generateQuizFromCurrentSummary() async {
    final hasBytes = _pickedFileBytes != null && _pickedFileBytes!.isNotEmpty;
    if (!hasBytes && _activeSourceText.isEmpty && _result == null) return;

    final userProfile = ref.read(currentUserProfileProvider).value;
    final enrolled =
        userProfile?.enrolledSubjectIds ?? ['os', 'py', 'db', 'net'];

    String selectedSubjectId = enrolled.isNotEmpty ? enrolled.first : 'general';
    String selectedDifficulty = 'Medium';
    int selectedCount = 10;
    final maxAllowedCount = ref.read(firebaseServiceProvider).maxMcqCount;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Generate Practice Quiz from Document',
                style: AppTextStyles.displayBold(context, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Associated Subject',
                style: AppTextStyles.body(
                  context,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...enrolled.map((id) {
                    final subj = AppSubjects.getById(id);
                    final isSelected = selectedSubjectId == id;
                    return ChoiceChip(
                      label: Text(subj?.name ?? id),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setModalState(() => selectedSubjectId = id);
                      },
                    );
                  }),
                  ChoiceChip(
                    label: const Text('General Document Practice'),
                    selected: selectedSubjectId == 'general',
                    onSelected: (val) {
                      if (val)
                        setModalState(() => selectedSubjectId = 'general');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Difficulty Level',
                style: AppTextStyles.body(
                  context,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['Easy', 'Medium', 'Hard'].map((diff) {
                  final isSelected = selectedDifficulty == diff;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Center(child: Text(diff)),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val)
                            setModalState(() => selectedDifficulty = diff);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Questions: $selectedCount',
                    style: AppTextStyles.body(
                      context,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Max: $maxAllowedCount',
                    style: AppTextStyles.bodySecondary(context, fontSize: 12),
                  ),
                ],
              ),
              Slider(
                value: selectedCount.toDouble().clamp(
                  3.0,
                  maxAllowedCount.toDouble(),
                ),
                min: 3.0,
                max: maxAllowedCount.toDouble(),
                divisions: (maxAllowedCount - 3).clamp(1, 20),
                label: '$selectedCount questions',
                onChanged: (val) =>
                    setModalState(() => selectedCount = val.round()),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Generate & Start Quiz',
                onPressed: () {
                  Navigator.pop(ctx);
                  _startConfiguredQuiz(
                    subjectId: selectedSubjectId,
                    difficulty: selectedDifficulty,
                    count: selectedCount,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startConfiguredQuiz({
    required String subjectId,
    required String difficulty,
    required int count,
  }) async {
    final hasBytes = _pickedFileBytes != null && _pickedFileBytes!.isNotEmpty;
    setState(() => _isGenerating = true);
    final user = ref.read(authRepositoryProvider).currentUser;

    try {
      final aiService = ref.read(aiServiceProvider);
      List<QuizQuestion> questions;

      if (hasBytes) {
        questions = await aiService.generateQuizFromDocument(
          documentBytes: _pickedFileBytes,
          mimeType: _pickedFileMimeType ?? 'application/pdf',
          difficulty: difficulty,
          count: count,
        );
      } else {
        final contextText = _activeSourceText.isNotEmpty
            ? _activeSourceText
            : '${_result!.quickSummary}\n${_result!.importantPoints.join("\n")}';
        questions = await aiService.generateQuizFromText(
          content: contextText,
          difficulty: difficulty,
          count: count,
        );
      }

      final session = QuizSession(
        id: 'quiz_sum_${DateTime.now().millisecondsSinceEpoch}',
        userId: user?.uid ?? '',
        subjectId: subjectId,
        topic: _pickedFileName ?? 'Document Practice',
        difficulty: difficulty,
        totalQuestions: questions.length,
        score: 0,
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        questions: questions,
      );

      ref.read(currentQuizProvider.notifier).state = session;
      ref.read(activeQuizQuestionsProvider.notifier).state = questions;
      if (mounted) {
        context.push('/quiz');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not generate quiz questions right now. Please try again.',
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

  void _showHistorySheet() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final summariesAsync = ref.watch(userSummariesProvider);
          final bool isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text(
                  'Saved Summaries',
                  style: AppTextStyles.displayBold(context, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: summariesAsync.when(
                    data: (summaries) {
                      if (summaries.isEmpty) {
                        return Center(
                          child: Text(
                            'No saved summaries yet.',
                            style: AppTextStyles.bodySecondary(context),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: summaries.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = summaries[index];
                          return CustomCard(
                            padding: const EdgeInsets.all(12),
                            onTap: () {
                              setState(() {
                                _result = item.summary;
                                _activeSourceText = item.sourceText;
                                _pickedFileName = item.title;
                              });
                              Navigator.pop(context);
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.fileText,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: AppTextStyles.body(
                                          context,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        item.summary.quickSummary,
                                        style: AppTextStyles.bodySecondary(
                                          context,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.trash2,
                                    size: 16,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () => ref
                                      .read(summaryRepositoryProvider)
                                      .deleteSummary(user.uid, item.id),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _reset() {
    setState(() {
      _result = null;
      _pickedFileName = null;
      _textController.clear();
      _activeSourceText = '';
    });
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
              Row(
                children: [
                  Expanded(
                    child: ScreenHeader(
                      title: 'AI Summary',
                      onBack: () => context.go('/'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.history, size: 20),
                    tooltip: 'Saved Summaries',
                    onPressed: _showHistorySheet,
                  ),
                ],
              ),

              if (_result == null) ...[
                TextField(
                  controller: _textController,
                  maxLines: 7,
                  decoration: InputDecoration(
                    hintText:
                        'Paste lecture transcripts, textbook pages, or technical notes here...',
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
                  ),
                  style: AppTextStyles.body(context),
                ),
                const SizedBox(height: 12),

                // PDF Upload Card
                InkWell(
                  onTap: _isUploadingPdf ? null : _pickAndProcessPdf,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isUploadingPdf
                              ? LucideIcons.loader2
                              : LucideIcons.uploadCloud,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _pickedFileName != null
                              ? 'Document: $_pickedFileName (Tap to change)'
                              : (_isUploadingPdf
                                    ? 'Reading Document...'
                                    : 'Upload PDF or Document'),
                          style: AppTextStyles.body(
                            context,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                CustomButton(
                  text: _isGenerating
                      ? 'Generating Structured Summary...'
                      : 'Generate AI Summary',
                  icon: LucideIcons.sparkles,
                  isFullWidth: true,
                  onPressed: _isGenerating ? null : _generateSummary,
                ),
              ] else ...[
                if (_pickedFileName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Source: $_pickedFileName',
                      style: AppTextStyles.bodySecondary(context, fontSize: 12),
                    ),
                  ),
                _buildSection(
                  '📝 Quick Summary',
                  _result!.quickSummary,
                  isDark,
                ),
                _buildListSection(
                  '✅ Important Points',
                  _result!.importantPoints,
                  isDark,
                ),
                _buildChipsSection(
                  '🔑 Key Terms & Concepts',
                  _result!.keyTerms,
                  isDark,
                ),
                _buildListSection(
                  '🎯 Exam Focus & High-Weightage Areas',
                  _result!.examFocus,
                  isDark,
                  icon: LucideIcons.target,
                  iconColor: AppColors.primary,
                ),
                _buildRevisionQuestions(
                  '❓ Revision & Viva Questions',
                  _result!.revisionQuestions,
                  isDark,
                ),

                const SizedBox(height: 12),
                CustomButton(
                  text: 'Generate Quiz from this Summary',
                  icon: LucideIcons.listChecks,
                  isFullWidth: true,
                  onPressed: _isGenerating
                      ? null
                      : _generateQuizFromCurrentSummary,
                ),
                const SizedBox(height: 10),
                CustomButton(
                  text: 'Summarize Another Document',
                  variant: ButtonVariant.ghost,
                  icon: LucideIcons.plus,
                  isFullWidth: true,
                  onPressed: _reset,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: AppTextStyles.bodySecondary(context).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(
    String title,
    List<String> points,
    bool isDark, {
    IconData icon = LucideIcons.check,
    Color iconColor = AppColors.success,
  }) {
    if (points.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3.0),
                    child: Icon(icon, size: 14, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p, style: AppTextStyles.bodySecondary(context)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsSection(String title, List<String> terms, bool isDark) {
    if (terms.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: terms
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withOpacity(0.2)
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      t,
                      style: AppTextStyles.body(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionQuestions(
    String title,
    List<String> questions,
    bool isDark,
  ) {
    if (questions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...questions.map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: CustomCard(
                padding: const EdgeInsets.all(12),
                onTap: () => context.go('/practice'),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        q,
                        style: AppTextStyles.body(context, fontSize: 13),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 15,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
