import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/services/ai_service.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/custom_chip.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/text_styles.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/user_repository.dart';
import '../data/chat_repository.dart';

final activeThreadIdProvider = StateProvider<String?>((ref) => null);
final selectedChatSubjectProvider = StateProvider<String>((ref) => 'general');
final activeExplanationModeProvider = StateProvider<ExplanationMode>((ref) {
  final profile = ref.watch(currentUserProfileProvider).value;
  if (profile != null) {
    return ExplanationMode.fromId(profile.preferredAiMode);
  }
  return ExplanationMode.student;
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isSpeechAvailable = false;
  bool _isListening = false;
  bool _isTyping = false;
  String _currentStreamedResponse = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _isSpeechAvailable = await _speech.initialize(
        onError: (val) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
      );
    } catch (_) {
      _isSpeechAvailable = false;
    }
  }

  void _toggleListening() async {
    if (!_isSpeechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Speech recognition is initializing or unavailable on this device.',
          ),
        ),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          if (mounted) {
            setState(() {
              _inputController.text = val.recognizedWords;
            });
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isTyping) return;

    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    _inputController.clear();
    setState(() => _isTyping = true);

    final threadRepo = ref.read(chatRepositoryProvider);
    var activeThreadId = ref.read(activeThreadIdProvider);
    final subjectId = ref.read(selectedChatSubjectProvider);
    final mode = ref.read(activeExplanationModeProvider);

    if (activeThreadId == null) {
      activeThreadId = await threadRepo.createThread(
        user.uid,
        subjectId,
        query.length > 30 ? '${query.substring(0, 30)}...' : query,
        mode: mode,
      );
      ref.read(activeThreadIdProvider.notifier).state = activeThreadId;
    }

    await threadRepo.addMessage(
      user.uid,
      activeThreadId,
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'user',
        text: query,
        timestamp: DateTime.now(),
      ),
    );

    final currentMessages =
        ref.read(threadMessagesProvider(activeThreadId)).value ?? [];
    final aiService = ref.read(aiServiceProvider);
    final responseBuffer = StringBuffer();

    try {
      final stream = aiService.streamChat(
        prompt: query,
        mode: mode,
        history: currentMessages,
        subjectContext: AppSubjects.getById(subjectId)?.name,
      );

      await for (final chunk in stream) {
        responseBuffer.write(chunk);
      }

      await threadRepo.addMessage(
        user.uid,
        activeThreadId,
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'model',
          text: responseBuffer.toString().isNotEmpty
              ? responseBuffer.toString()
              : 'I am here to help you study! Please feel free to ask any question.',
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      await threadRepo.addMessage(
        user.uid,
        activeThreadId,
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'model',
          text:
              'Unable to generate AI response. Please verify your connection or try a shorter prompt.',
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _scrollToBottom();
      }
    }
  }

  void _handleQuickAction(String action, List<ChatMessage> messages) async {
    if (messages.isEmpty || _isTyping) return;
    final lastModelMessage = messages.lastWhere(
      (m) => m.role == 'model',
      orElse: () => messages.last,
    );

    final snippet = lastModelMessage.text.length > 150
        ? '${lastModelMessage.text.substring(0, 150)}...'
        : lastModelMessage.text;

    switch (action) {
      case 'Explain Simpler':
        _sendMessage(
          'Can you explain this previous concept in much simpler, intuitive terms with an everyday analogy? Focus: "$snippet"',
        );
        break;
      case 'Give Example':
        _sendMessage(
          'Please provide a concrete practical code or numerical calculation example illustrating this: "$snippet"',
        );
        break;
      case 'Exam Tips':
        _sendMessage(
          'What are the most probable viva questions and high-weightage exam questions for this concept?',
        );
        break;
      case 'Generate MCQs':
        context.push('/practice');
        break;
      case 'Summarize':
        context.push('/summary');
        break;
    }
  }

  void _startNewConversation() {
    ref.read(activeThreadIdProvider.notifier).state = null;
    setState(() {
      _currentStreamedResponse = '';
      _isTyping = false;
    });
  }

  void _showThreadHistorySheet() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final threadsAsync = ref.watch(userChatThreadsProvider);
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chat History',
                      style: AppTextStyles.displayBold(context, fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.plusCircle,
                        color: AppColors.primary,
                      ),
                      tooltip: 'New Conversation',
                      onPressed: () {
                        Navigator.pop(context);
                        _startNewConversation();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: threadsAsync.when(
                    data: (threads) {
                      if (threads.isEmpty) {
                        return Center(
                          child: Text(
                            'No previous conversations.',
                            style: AppTextStyles.bodySecondary(context),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: threads.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final thread = threads[index];
                          final isActive =
                              thread.id == ref.watch(activeThreadIdProvider);

                          return CustomCard(
                            padding: const EdgeInsets.all(12),
                            onTap: () {
                              ref.read(activeThreadIdProvider.notifier).state =
                                  thread.id;
                              ref
                                  .read(activeExplanationModeProvider.notifier)
                                  .state = thread
                                  .mode;
                              Navigator.pop(context);
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppColors.primary
                                        : (isDark
                                              ? AppColors.darkBorder
                                              : AppColors.lightBorder),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    LucideIcons.messageSquare,
                                    size: 16,
                                    color: isActive
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        thread.title,
                                        style: AppTextStyles.body(
                                          context,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (thread.lastMessagePreview != null)
                                        Text(
                                          thread.lastMessagePreview!,
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
                                  onPressed: () async {
                                    await ref
                                        .read(chatRepositoryProvider)
                                        .deleteThread(user.uid, thread.id);
                                    if (isActive) {
                                      ref
                                              .read(
                                                activeThreadIdProvider.notifier,
                                              )
                                              .state =
                                          null;
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Center(child: Text('Error loading history: $e')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showModeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                'Explanation Mode',
                style: AppTextStyles.displayBold(context, fontSize: 17),
              ),
              const SizedBox(height: 4),
              Text(
                'Customize how deep and formal the AI tutor explanations are.',
                style: AppTextStyles.bodySecondary(context),
              ),
              const SizedBox(height: 16),
              ...ExplanationMode.values.map((mode) {
                final isSelected =
                    ref.watch(activeExplanationModeProvider) == mode;
                return InkWell(
                  onTap: () {
                    ref.read(activeExplanationModeProvider.notifier).state =
                        mode;
                    final activeThread = ref.read(activeThreadIdProvider);
                    final user = ref.read(authRepositoryProvider).currentUser;
                    if (activeThread != null && user != null) {
                      ref
                          .read(chatRepositoryProvider)
                          .updateThreadMode(user.uid, activeThread, mode);
                    }
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.primary.withOpacity(0.2)
                                : AppColors.primaryLight)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            mode.icon,
                            size: 18,
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode.label,
                                style: AppTextStyles.body(
                                  context,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                mode.desc,
                                style: AppTextStyles.bodySecondary(
                                  context,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            LucideIcons.check,
                            color: AppColors.primary,
                            size: 20,
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final mode = ref.watch(activeExplanationModeProvider);
    final activeThreadId = ref.watch(activeThreadIdProvider);

    final messagesAsync = activeThreadId != null
        ? ref.watch(threadMessagesProvider(activeThreadId))
        : null;

    final messages = messagesAsync?.value ?? [];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Row(
                children: [
                  Expanded(
                    child: ScreenHeader(
                      title: 'AI Tutor',
                      onBack: () => context.go('/'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.history, size: 20),
                    tooltip: 'History',
                    onPressed: _showThreadHistorySheet,
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.plusCircle,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    tooltip: 'New Chat',
                    onPressed: _startNewConversation,
                  ),
                ],
              ),
            ),

            // Mode and Subject selection chips
            Padding(
              padding: const EdgeInsets.only(
                left: 18.0,
                right: 18.0,
                bottom: 8.0,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: _showModeSheet,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(mode.icon, size: 13, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${mode.label} mode',
                            style: AppTextStyles.body(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            LucideIcons.chevronDown,
                            size: 13,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isListening)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.mic,
                            size: 13,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Listening...',
                            style: AppTextStyles.body(
                              context,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: messages.isEmpty && _currentStreamedResponse.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      itemCount: messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && _isTyping) {
                          return _buildMessageBubble(
                            ChatMessage(
                              id: 'temp',
                              role: 'model',
                              text: _currentStreamedResponse.isEmpty
                                  ? 'Analyzing study concepts...'
                                  : _currentStreamedResponse,
                              timestamp: DateTime.now(),
                            ),
                            isDark,
                          );
                        }

                        final msg = messages[index];
                        final isLastModel =
                            msg.role == 'model' &&
                            index == messages.length - 1 &&
                            !_isTyping;

                        return Column(
                          children: [
                            _buildMessageBubble(msg, isDark),
                            if (isLastModel) _buildQuickActions(messages),
                          ],
                        );
                      },
                    ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      onSubmitted: (val) => _sendMessage(val),
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? 'Listening to your voice...'
                            : 'Ask about any topic, doubt, or code...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                      ),
                      style: AppTextStyles.body(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isListening
                            ? AppColors.error
                            : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                      ),
                      color: _isListening
                          ? AppColors.error.withOpacity(0.2)
                          : (isDark
                                ? AppColors.darkSurface
                                : AppColors.lightSurface),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isListening ? LucideIcons.micOff : LucideIcons.mic,
                        size: 18,
                        color: _isListening
                            ? AppColors.error
                            : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                      ),
                      onPressed: _toggleListening,
                      tooltip: 'Voice Input',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: IconButton(
                      icon: const Icon(LucideIcons.send, size: 17),
                      color: Colors.white,
                      onPressed: () => _sendMessage(_inputController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.sparkles,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'How can I help you study today?',
              style: AppTextStyles.displayBold(context, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask a conceptual doubt, request an exam breakdown, or tap an idea below:',
              style: AppTextStyles.bodySecondary(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildPromptCard(
              'Explain Deadlock Prevention vs Avoidance',
              isDark,
            ),
            const SizedBox(height: 8),
            _buildPromptCard(
              'How does Dijkstra\'s Algorithm find the shortest path?',
              isDark,
            ),
            const SizedBox(height: 8),
            _buildPromptCard(
              'Give a real-world example of 3NF Database Normalization',
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard(String prompt, bool isDark) {
    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: () => _sendMessage(prompt),
      child: Row(
        children: [
          const Icon(
            LucideIcons.helpCircle,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              prompt,
              style: AppTextStyles.body(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            LucideIcons.arrowRight,
            size: 14,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.sparkles,
                size: 14,
                color: Colors.white,
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                border: isUser
                    ? null
                    : Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Text(
                msg.text,
                style: AppTextStyles.body(
                  context,
                  color: isUser
                      ? Colors.white
                      : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                ).copyWith(height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(List<ChatMessage> messages) {
    return Padding(
      padding: const EdgeInsets.only(left: 36.0, bottom: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              [
                    'Explain Simpler',
                    'Give Example',
                    'Real-world Analogy',
                    'Generate MCQs',
                    'Summarize',
                  ]
                  .map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: CustomChip(
                        label: action,
                        onTap: () => _handleQuickAction(action, messages),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}
