import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../../shared/models/chat_model.dart';
import '../../shared/models/quiz_model.dart';
import '../../shared/models/summary_model.dart';
import '../../shared/models/study_plan_model.dart';
import 'firebase_service.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return FirebaseAiService(firebaseService);
});

abstract interface class AiService {
  Stream<String> streamChat({
    required String prompt,
    required ExplanationMode mode,
    required List<ChatMessage> history,
    String? subjectContext,
  });

  Future<List<QuizQuestion>> generateQuiz({
    required String subject,
    required String topic,
    required String difficulty,
    required int count,
  });

  Future<List<QuizQuestion>> generateQuizFromText({
    required String content,
    required String difficulty,
    required int count,
  });

  Future<GeneratedSummary> generateSummary({
    required String text,
    String? subjectContext,
  });

  Future<GeneratedSummary> generateSummaryFromDocument({
    Uint8List? documentBytes,
    String? mimeType,
    String? plainText,
    String? subjectContext,
  });

  Future<List<QuizQuestion>> generateQuizFromDocument({
    Uint8List? documentBytes,
    String? mimeType,
    String? plainText,
    required String difficulty,
    required int count,
    String? subjectContext,
  });

  Future<StudyPlan> generateStudyPlan({
    required String userId,
    required String targetExam,
    required int dailyGoalMinutes,
    required List<String> enrolledSubjects,
    required List<String> weakSubjects,
  });

  Future<String> simplifyExplanation(String previousAnswer);

  Future<String> giveExample(String contextText, {bool realWorld = false});
}

class FirebaseAiService implements AiService {
  final AppFirebaseService _firebaseService;
  GenerativeModel? _chatModel;
  GenerativeModel? _jsonModel;
  String _cachedModelName = '';

  FirebaseAiService(this._firebaseService);

  void _ensureModelsInitialized() {
    final currentModelName = _firebaseService.aiModelName;
    if (_chatModel == null || _cachedModelName != currentModelName) {
      _cachedModelName = currentModelName.isNotEmpty ? currentModelName : 'gemini-2.5-flash';
      
      try {
        _chatModel = FirebaseAI.googleAI().generativeModel(
          model: _cachedModelName,
        );
        _jsonModel = FirebaseAI.googleAI().generativeModel(
          model: _cachedModelName,
          generationConfig: GenerationConfig(responseMimeType: 'application/json'),
        );
      } catch (_) {
        // Fallback to Agent Platform if configured for that backend
        _chatModel = FirebaseAI.agentPlatform().generativeModel(
          model: _cachedModelName,
        );
        _jsonModel = FirebaseAI.agentPlatform().generativeModel(
          model: _cachedModelName,
          generationConfig: GenerationConfig(responseMimeType: 'application/json'),
        );
      }
    }
  }

  @override
  Stream<String> streamChat({
    required String prompt,
    required ExplanationMode mode,
    required List<ChatMessage> history,
    String? subjectContext,
  }) {
    _ensureModelsInitialized();

    final systemInstruction = StringBuffer();
    systemInstruction.writeln('You are an expert AI Tutor for StudyMate AI.');
    if (subjectContext != null && subjectContext.isNotEmpty) {
      systemInstruction.writeln('Subject Focus: $subjectContext');
    }
    systemInstruction.writeln('Explanation Mode: ${mode.label}');
    systemInstruction.writeln('Mode Directive: ${mode.systemPrompt}');
    systemInstruction.writeln('Formatting instructions: Use clean Markdown with bold keywords, bullet points where helpful, and concise equations or code blocks where applicable.');

    // Limit context history to Remote Config limit
    final maxHistory = _firebaseService.maxChatContextMessages;
    final trimmedHistory = history.length > maxHistory
        ? history.sublist(history.length - maxHistory)
        : history;

    // Convert domain ChatMessage objects into Firebase AI Content
    final contentHistory = trimmedHistory.map((m) {
      if (m.role == 'user') {
        return Content.text(m.text);
      } else {
        return Content.model([TextPart(m.text)]);
      }
    }).toList();

    final chat = _chatModel!.startChat(history: contentHistory);

    return chat.sendMessageStream(
      Content.text('${systemInstruction.toString()}\n\nUser Question: $prompt'),
    ).map((response) => response.text ?? '');
  }

  @override
  Future<List<QuizQuestion>> generateQuiz({
    required String subject,
    required String topic,
    required String difficulty,
    required int count,
  }) async {
    _ensureModelsInitialized();

    final prompt = '''
Generate exactly $count multiple-choice questions for the subject "$subject" on the topic "$topic" at a "$difficulty" difficulty level.
Each question MUST have exactly 4 non-empty options, a valid correctIndex (0, 1, 2, or 3), and a clear, informative explanation.

Return ONLY a valid JSON array matching this exact schema:
[
  {
    "question": "Clear question text?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "explanation": "Why this specific option is correct."
  }
]
''';

    return _generateAndValidateQuestions(prompt, count);
  }

  @override
  Future<List<QuizQuestion>> generateQuizFromText({
    required String content,
    required String difficulty,
    required int count,
  }) async {
    _ensureModelsInitialized();

    final prompt = '''
Analyze the provided study text and generate exactly $count multiple-choice questions at a "$difficulty" difficulty level based directly on the key concepts in the text.
Each question MUST have exactly 4 options, a correctIndex (0, 1, 2, or 3), and an explanation referencing the text.

Study Text:
$content

Return ONLY a valid JSON array matching this schema:
[
  {
    "question": "Question text based on document?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "explanation": "Detailed explanation."
  }
]
''';

    return _generateAndValidateQuestions(prompt, count);
  }

  Future<List<QuizQuestion>> _generateAndValidateQuestions(String prompt, int requestedCount) async {
    try {
      final response = await _jsonModel!.generateContent([Content.text(prompt)]);
      final rawText = response.text ?? '[]';
      final questions = _parseQuestionsJson(rawText);

      if (questions.isNotEmpty) {
        return questions;
      }
    } catch (_) {}

    // One controlled retry attempt
    try {
      final retryResponse = await _jsonModel!.generateContent([
        Content.text('$prompt\n\nCRITICAL: Return strictly valid JSON array of objects with question, options (length 4), correctIndex (0-3), explanation.')
      ]);
      final rawRetry = retryResponse.text ?? '[]';
      final retryQuestions = _parseQuestionsJson(rawRetry);
      if (retryQuestions.isNotEmpty) {
        return retryQuestions;
      }
    } catch (e) {
      throw Exception('Could not generate valid quiz questions from AI: $e');
    }

    throw Exception('AI returned invalid quiz question format. Please try again with a refined topic.');
  }

  List<QuizQuestion> _parseQuestionsJson(String rawJson) {
    try {
      final cleanText = rawJson
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleanText);
      if (decoded is List) {
        final parsed = decoded
            .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
            .where((q) => q.isValid)
            .toList();
        return parsed;
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<GeneratedSummary> generateSummary({
    required String text,
    String? subjectContext,
  }) async {
    _ensureModelsInitialized();

    final maxInput = _firebaseService.maxSummaryInput;
    final processedText = text.length > maxInput ? text.substring(0, maxInput) : text;

    final prompt = '''
Summarize the following study material comprehensively for an engineering/diploma student.
${subjectContext != null ? 'Subject Context: $subjectContext' : ''}

Return ONLY valid JSON matching this exact structure:
{
  "quickSummary": "High-impact 2-3 sentence overview covering core premise.",
  "importantPoints": [
    "Key takeaway point 1",
    "Key takeaway point 2",
    "Key takeaway point 3"
  ],
  "keyTerms": [
    "Term 1: Definition",
    "Term 2: Definition",
    "Term 3: Definition"
  ],
  "examFocus": [
    "High-probability exam question area 1",
    "Critical formula or concept to remember for exams"
  ],
  "revisionQuestions": [
    "Conceptual review question 1?",
    "Conceptual review question 2?"
  ]
}

Study Material:
$processedText
''';

    try {
      final response = await _jsonModel!.generateContent([Content.text(prompt)]);
      final rawText = response.text ?? '{}';
      final cleanText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleanText) as Map<String, dynamic>;
      return GeneratedSummary.fromJson(decoded);
    } catch (e) {
      // Retry once with strict prompt
      try {
        final retry = await _jsonModel!.generateContent([
          Content.text('$prompt\n\nEnsure valid JSON object with quickSummary, importantPoints, keyTerms, examFocus, revisionQuestions.')
        ]);
        final cleanRetry = (retry.text ?? '{}').replaceAll('```json', '').replaceAll('```', '').trim();
        final decoded = jsonDecode(cleanRetry) as Map<String, dynamic>;
        return GeneratedSummary.fromJson(decoded);
      } catch (retryError) {
        throw Exception('Failed to generate structured summary: $retryError');
      }
    }
  }

  @override
  Future<GeneratedSummary> generateSummaryFromDocument({
    Uint8List? documentBytes,
    String? mimeType,
    String? plainText,
    String? subjectContext,
  }) async {
    _ensureModelsInitialized();

    final prompt = '''
Summarize the following study material document comprehensively for an engineering/diploma student.
${subjectContext != null && subjectContext.isNotEmpty ? 'Subject Context: $subjectContext' : ''}

Return ONLY valid JSON matching this exact structure:
{
  "quickSummary": "High-impact 2-3 sentence overview covering core premise.",
  "importantPoints": [
    "Key takeaway point 1",
    "Key takeaway point 2",
    "Key takeaway point 3"
  ],
  "keyTerms": [
    "Term 1: Definition",
    "Term 2: Definition",
    "Term 3: Definition"
  ],
  "examFocus": [
    "High-probability exam question area 1",
    "Critical formula or concept to remember for exams"
  ],
  "revisionQuestions": [
    "Conceptual review question 1?",
    "Conceptual review question 2?"
  ]
}
''';

    Content content;
    if (documentBytes != null && documentBytes.isNotEmpty && mimeType != null && mimeType.isNotEmpty) {
      content = Content.multi([
        TextPart(prompt),
        InlineDataPart(mimeType, documentBytes),
      ]);
    } else if (plainText != null && plainText.isNotEmpty) {
      final maxInput = _firebaseService.maxSummaryInput;
      final processed = plainText.length > maxInput ? plainText.substring(0, maxInput) : plainText;
      content = Content.text('$prompt\n\nStudy Material:\n$processed');
    } else {
      throw ArgumentError('Either documentBytes with mimeType or plainText must be provided.');
    }

    try {
      final response = await _jsonModel!.generateContent([content]);
      final rawText = response.text ?? '{}';
      final cleanText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleanText) as Map<String, dynamic>;
      return GeneratedSummary.fromJson(decoded);
    } catch (e) {
      throw Exception('Failed to generate structured summary from document: $e');
    }
  }

  @override
  Future<List<QuizQuestion>> generateQuizFromDocument({
    Uint8List? documentBytes,
    String? mimeType,
    String? plainText,
    required String difficulty,
    required int count,
    String? subjectContext,
  }) async {
    _ensureModelsInitialized();

    final prompt = '''
Generate exactly $count multiple-choice questions (MCQs) for an engineering/diploma student based on the provided document.
Difficulty level: $difficulty.
${subjectContext != null && subjectContext.isNotEmpty ? 'Subject Focus: $subjectContext' : ''}

Each question MUST have:
1. "question": clear question text
2. "options": array of exactly 4 plausible option strings
3. "correctIndex": integer index (0-3) indicating the correct option
4. "explanation": 1-2 sentence explanation of why the correct answer is right

Return ONLY a valid JSON array of objects.
''';

    Content content;
    if (documentBytes != null && documentBytes.isNotEmpty && mimeType != null && mimeType.isNotEmpty) {
      content = Content.multi([
        TextPart(prompt),
        InlineDataPart(mimeType, documentBytes),
      ]);
    } else if (plainText != null && plainText.isNotEmpty) {
      final maxInput = _firebaseService.maxSummaryInput;
      final processed = plainText.length > maxInput ? plainText.substring(0, maxInput) : plainText;
      content = Content.text('$prompt\n\nSource Material:\n$processed');
    } else {
      throw ArgumentError('Either documentBytes with mimeType or plainText must be provided.');
    }

    try {
      final response = await _jsonModel!.generateContent([content]);
      final rawJson = response.text ?? '[]';
      final questions = _parseQuestionsJson(rawJson);
      if (questions.isNotEmpty) {
        return questions;
      }
    } catch (e) {
      throw Exception('Could not generate valid quiz questions from document: $e');
    }

    throw Exception('AI returned invalid quiz question format from document. Please try again.');
  }

  @override
  Future<StudyPlan> generateStudyPlan({
    required String userId,
    required String targetExam,
    required int dailyGoalMinutes,
    required List<String> enrolledSubjects,
    required List<String> weakSubjects,
  }) async {
    _ensureModelsInitialized();

    final prompt = '''
Create a structured 7-day study plan (Monday through Sunday) for a student preparing for "$targetExam".
Daily Study Goal: $dailyGoalMinutes minutes per day.
Enrolled Subjects: ${enrolledSubjects.join(', ')}
Weak Focus Areas / Subjects: ${weakSubjects.isNotEmpty ? weakSubjects.join(', ') : 'All enrolled subjects equally'}

Return ONLY a valid JSON object matching this exact schema:
{
  "overview": "Brief 1-2 sentence motivating summary of this week's strategy",
  "days": [
    {
      "dayName": "Monday",
      "focus": "Operating Systems & Concurrency",
      "tasks": [
        {
          "timeSlot": "Morning",
          "subjectId": "os",
          "subjectName": "Operating Systems",
          "topic": "Process Synchronization & Semaphores",
          "durationMinutes": 30,
          "taskType": "review"
        },
        {
          "timeSlot": "Evening",
          "subjectId": "os",
          "subjectName": "Operating Systems",
          "topic": "Practice 10 Deadlock MCQs",
          "durationMinutes": 20,
          "taskType": "practice"
        }
      ]
    }
  ]
}
''';

    try {
      final response = await _jsonModel!.generateContent([Content.text(prompt)]);
      final rawText = (response.text ?? '{}').replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(rawText) as Map<String, dynamic>;

      final rawDays = decoded['days'] as List<dynamic>? ?? [];
      final days = rawDays.map((d) => StudyPlanDay.fromJson(d as Map<String, dynamic>)).toList();

      return StudyPlan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        targetExam: targetExam,
        dailyGoalMinutes: dailyGoalMinutes,
        overview: decoded['overview'] as String? ?? 'Personalized 7-Day Plan',
        days: days,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to generate AI study plan: $e');
    }
  }

  @override
  Future<String> simplifyExplanation(String previousAnswer) async {
    _ensureModelsInitialized();
    final prompt = '''
The user asked to explain the following concept much simpler with plain language, real-world analogies, and zero unnecessary jargon:

Previous Explanation:
$previousAnswer

Provide a super clear, beginner-friendly simplified explanation:
''';
    final response = await _chatModel!.generateContent([Content.text(prompt)]);
    return response.text ?? 'Could not simplify the explanation.';
  }

  @override
  Future<String> giveExample(String contextText, {bool realWorld = false}) async {
    _ensureModelsInitialized();
    final prompt = realWorld
        ? 'Provide a vivid, relatable real-world analogy and application for this concept:\n\n$contextText'
        : 'Provide a concrete, practical code or mathematical example demonstrating this concept:\n\n$contextText';

    final response = await _chatModel!.generateContent([Content.text(prompt)]);
    return response.text ?? 'Could not generate example.';
  }
}
