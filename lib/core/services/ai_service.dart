import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../shared/models/chat_model.dart';
import '../../shared/models/quiz_model.dart';
import '../../shared/models/summary_model.dart';
import '../../shared/models/study_plan_model.dart';
import 'firebase_service.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return FirebaseAiService(firebaseService);
});

class AiDisabledException implements Exception {
  final String message;
  const AiDisabledException([
    this.message =
        'AI features are temporarily unavailable. Your saved study content is still accessible.',
  ]);

  @override
  String toString() => message;
}

class AiQuizGenerationException implements Exception {
  final String message;
  const AiQuizGenerationException([
    this.message =
        'Could not generate the requested quiz questions. Please try again.',
  ]);

  @override
  String toString() => message;
}

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
    DateTime? examDate,
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

  void _checkAiEnabled() {
    if (!_firebaseService.aiEnabled) {
      throw const AiDisabledException();
    }
  }

  void _ensureModelsInitialized() {
    _checkAiEnabled();
    final currentModelName = _firebaseService.aiModelName;
    if (_chatModel == null || _cachedModelName != currentModelName) {
      _cachedModelName = currentModelName.isNotEmpty
          ? currentModelName
          : 'gemini-3.7-flash';

      try {
        _chatModel = FirebaseAI.googleAI().generativeModel(
          model: _cachedModelName,
          systemInstruction: Content.system(
            'You are StudyMate AI, an expert, encouraging, and rigorous academic tutor for engineering, diploma, and exam students. '
            'Always explain clearly, use structured Markdown, and provide deep conceptual clarity.',
          ),
        );
        _jsonModel = FirebaseAI.googleAI().generativeModel(
          model: _cachedModelName,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
          systemInstruction: Content.system(
            'You are StudyMate AI JSON Engine. Output strictly valid JSON without any markdown formatting or commentary.',
          ),
        );
      } catch (e, stack) {
        debugPrint(
          'Firebase AI Logic initialization error for $_cachedModelName: $e',
        );
        try {
          if (!kIsWeb) {
            FirebaseCrashlytics.instance.recordError(
              e,
              stack,
              reason: 'AI Model Init Error: $_cachedModelName',
              fatal: false,
            );
          }
        } catch (_) {}
        rethrow;
      }
    }
  }

  int _clampCount(int requested) {
    final maxAllowed = _firebaseService.maxMcqCount;
    if (requested <= 0) return 5;
    if (requested > maxAllowed) return maxAllowed;
    return requested;
  }

  @override
  Stream<String> streamChat({
    required String prompt,
    required ExplanationMode mode,
    required List<ChatMessage> history,
    String? subjectContext,
  }) async* {
    if (!_firebaseService.aiEnabled) {
      yield 'AI features are temporarily unavailable. Your saved study content is still accessible.';
      return;
    }

    _ensureModelsInitialized();

    final systemInstruction = StringBuffer();
    systemInstruction.writeln('Subject Focus: ${subjectContext ?? "General"}');
    systemInstruction.writeln('Explanation Mode: ${mode.label}');
    systemInstruction.writeln('Mode Directive: ${mode.systemPrompt}');

    // Limit context history to Remote Config limit
    final maxHistory = _firebaseService.maxChatContextMessages;
    final trimmedHistory = history.length > maxHistory
        ? history.sublist(history.length - maxHistory)
        : history;

    final contentHistory = trimmedHistory.map((m) {
      if (m.role == 'user') {
        return Content.text(m.text);
      } else {
        return Content.model([TextPart(m.text)]);
      }
    }).toList();

    final chat = _chatModel!.startChat(history: contentHistory);

    final stream = chat.sendMessageStream(
      Content.text(
        '${systemInstruction.toString()}\n\nStudent Question: $prompt',
      ),
    );

    await for (final response in stream) {
      yield response.text ?? '';
    }
  }

  @override
  Future<List<QuizQuestion>> generateQuiz({
    required String subject,
    required String topic,
    required String difficulty,
    required int count,
  }) async {
    _checkAiEnabled();
    _ensureModelsInitialized();
    final targetCount = _clampCount(count);

    final prompt =
        '''
Generate exactly $targetCount multiple-choice questions for the subject "$subject" on the topic "$topic" at a "$difficulty" difficulty level.
Rules:
1. Exactly $targetCount questions in the output array.
2. Every question must be distinct and non-empty.
3. Every question must contain exactly 4 unique non-empty options.
4. correctIndex must be an integer between 0 and 3.
5. Provide a detailed, pedagogical explanation for why the correct option is right.

Return ONLY a valid JSON array matching this schema:
[
  {
    "question": "Question text?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "explanation": "Why this specific option is correct."
  }
]
''';

    return _generateAndValidateQuestions(prompt, targetCount);
  }

  @override
  Future<List<QuizQuestion>> generateQuizFromText({
    required String content,
    required String difficulty,
    required int count,
  }) async {
    _checkAiEnabled();
    _ensureModelsInitialized();
    final targetCount = _clampCount(count);

    final prompt =
        '''
Analyze the provided study text and generate exactly $targetCount multiple-choice questions at a "$difficulty" difficulty level based directly on the key concepts in the text.
Rules:
1. Exactly $targetCount questions in the output array.
2. Every question must contain exactly 4 unique non-empty options.
3. correctIndex must be an integer between 0 and 3.
4. Provide an explanation referencing the text.

Study Text:
$content

Return ONLY a valid JSON array matching this schema:
[
  {
    "question": "Question text based on text?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "explanation": "Detailed explanation."
  }
]
''';

    return _generateAndValidateQuestions(prompt, targetCount);
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
    _checkAiEnabled();
    _ensureModelsInitialized();
    final targetCount = _clampCount(count);

    final prompt =
        '''
Generate exactly $targetCount multiple-choice questions (MCQs) for an engineering/diploma student based on the provided document.
Difficulty level: $difficulty.
${subjectContext != null && subjectContext.isNotEmpty ? 'Subject Focus: $subjectContext' : ''}

Rules:
1. Exactly $targetCount questions in the output array.
2. Every question must have exactly 4 unique non-empty options.
3. correctIndex must be 0, 1, 2, or 3.
4. Clear explanation for each answer.

Return ONLY a valid JSON array of objects.
''';

    if (documentBytes != null &&
        documentBytes.isNotEmpty &&
        mimeType != null &&
        mimeType.isNotEmpty) {
      final content = Content.multi([
        TextPart(prompt),
        InlineDataPart(mimeType, documentBytes),
      ]);

      try {
        final response = await _jsonModel!.generateContent([content]);
        final questions = _parseQuestionsJson(
          response.text ?? '[]',
          targetCount,
        );
        if (questions.length == targetCount) {
          return questions;
        }
      } catch (_) {}

      // Controlled retry with plain prompt
      return _generateAndValidateQuestions(prompt, targetCount);
    } else if (plainText != null && plainText.isNotEmpty) {
      return generateQuizFromText(
        content: plainText,
        difficulty: difficulty,
        count: targetCount,
      );
    } else {
      throw ArgumentError(
        'Either documentBytes or plainText must be provided.',
      );
    }
  }

  Future<List<QuizQuestion>> _generateAndValidateQuestions(
    String prompt,
    int requestedCount,
  ) async {
    try {
      final response = await _jsonModel!.generateContent([
        Content.text(prompt),
      ]);
      final rawText = response.text ?? '[]';
      final questions = _parseQuestionsJson(rawText, requestedCount);

      if (questions.length == requestedCount) {
        return questions;
      }
    } catch (_) {}

    // One controlled retry attempt with explicit count emphasis
    try {
      final retryResponse = await _jsonModel!.generateContent([
        Content.text(
          '$prompt\n\nCRITICAL REQUIREMENT: Output EXACTLY $requestedCount distinct question objects with 4 unique options each and valid correctIndex (0..3).',
        ),
      ]);
      final rawRetry = retryResponse.text ?? '[]';
      final retryQuestions = _parseQuestionsJson(rawRetry, requestedCount);

      if (retryQuestions.length == requestedCount) {
        return retryQuestions;
      } else if (retryQuestions.length > requestedCount) {
        return retryQuestions.sublist(0, requestedCount);
      }
    } catch (e) {
      throw AiQuizGenerationException(
        'Could not generate valid quiz questions from AI: $e',
      );
    }

    throw const AiQuizGenerationException(
      'AI returned an invalid question set. Please try again with a refined topic.',
    );
  }

  List<QuizQuestion> _parseQuestionsJson(String rawJson, int targetCount) {
    try {
      final cleanText = rawJson
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleanText);
      if (decoded is List) {
        final List<QuizQuestion> validList = [];
        final Set<String> seenQuestions = {};

        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final q = QuizQuestion.fromJson(item);
            final normalized = q.question.trim().toLowerCase();
            final uniqueOptions = q.options
                .map((o) => o.trim().toLowerCase())
                .toSet();

            if (q.isValid &&
                !seenQuestions.contains(normalized) &&
                uniqueOptions.length == 4) {
              seenQuestions.add(normalized);
              validList.add(q);
            }
          }
        }
        return validList;
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<GeneratedSummary> generateSummary({
    required String text,
    String? subjectContext,
  }) async {
    _checkAiEnabled();
    _ensureModelsInitialized();

    final maxInput = _firebaseService.maxSummaryInput;

    // Handle chunking if text exceeds single-request limit
    if (text.length > maxInput) {
      return _generateChunkedSummary(text, subjectContext);
    }

    final prompt =
        '''
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
$text
''';

    try {
      final response = await _jsonModel!.generateContent([
        Content.text(prompt),
      ]);
      return _parseSummaryJson(response.text ?? '{}');
    } catch (e) {
      // Retry once
      try {
        final retry = await _jsonModel!.generateContent([
          Content.text(
            '$prompt\n\nEnsure valid JSON object with quickSummary, importantPoints, keyTerms, examFocus, revisionQuestions.',
          ),
        ]);
        return _parseSummaryJson(retry.text ?? '{}');
      } catch (retryError) {
        throw Exception('Failed to generate structured summary: $retryError');
      }
    }
  }

  Future<GeneratedSummary> _generateChunkedSummary(
    String fullText,
    String? subjectContext,
  ) async {
    final chunkSize = _firebaseService.maxSummaryInput ~/ 2;
    final chunks = <String>[];

    for (var i = 0; i < fullText.length; i += chunkSize) {
      final end = (i + chunkSize < fullText.length)
          ? i + chunkSize
          : fullText.length;
      chunks.add(fullText.substring(i, end));
    }

    final intermediatePoints = <String>[];
    for (final chunk in chunks) {
      try {
        final prompt =
            'Extract the top 3 essential key takeaway points from this notes excerpt:\n\n$chunk';
        final res = await _chatModel!.generateContent([Content.text(prompt)]);
        if (res.text != null && res.text!.isNotEmpty) {
          intermediatePoints.add(res.text!);
        }
      } catch (_) {}
    }

    final combinedText = intermediatePoints.join('\n\n');
    return generateSummary(
      text: combinedText.isNotEmpty
          ? combinedText
          : fullText.substring(0, 5000),
      subjectContext: subjectContext,
    );
  }

  GeneratedSummary _parseSummaryJson(String rawJson) {
    final cleanText = rawJson
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final decoded = jsonDecode(cleanText) as Map<String, dynamic>;
    return GeneratedSummary.fromJson(decoded);
  }

  @override
  Future<GeneratedSummary> generateSummaryFromDocument({
    Uint8List? documentBytes,
    String? mimeType,
    String? plainText,
    String? subjectContext,
  }) async {
    _checkAiEnabled();
    _ensureModelsInitialized();

    final prompt =
        '''
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

    if (documentBytes != null &&
        documentBytes.isNotEmpty &&
        mimeType != null &&
        mimeType.isNotEmpty) {
      final content = Content.multi([
        TextPart(prompt),
        InlineDataPart(mimeType, documentBytes),
      ]);

      try {
        final response = await _jsonModel!.generateContent([content]);
        return _parseSummaryJson(response.text ?? '{}');
      } catch (e) {
        throw Exception(
          'Failed to generate structured summary from document: $e',
        );
      }
    } else if (plainText != null && plainText.isNotEmpty) {
      return generateSummary(text: plainText, subjectContext: subjectContext);
    } else {
      throw ArgumentError(
        'Either documentBytes with mimeType or plainText must be provided.',
      );
    }
  }

  @override
  Future<StudyPlan> generateStudyPlan({
    required String userId,
    required String targetExam,
    required int dailyGoalMinutes,
    required List<String> enrolledSubjects,
    required List<String> weakSubjects,
    DateTime? examDate,
  }) async {
    _checkAiEnabled();
    _ensureModelsInitialized();

    final daysRemaining = examDate != null
        ? examDate.difference(DateTime.now()).inDays
        : 30;

    final prompt =
        '''
Create a realistic 7-day study plan for an engineering student preparing for "$targetExam" (Days until exam: $daysRemaining).
Daily Study Goal: $dailyGoalMinutes minutes.
Enrolled Subjects: ${enrolledSubjects.join(', ')}
Weak Focus Areas (prioritize these): ${weakSubjects.join(', ')}

Return ONLY a valid JSON object matching this schema:
{
  "title": "7-Day Strategic Preparation Plan",
  "targetExam": "$targetExam",
  "startDate": "${DateTime.now().toIso8601String()}",
  "endDate": "${DateTime.now().add(const Duration(days: 7)).toIso8601String()}",
  "days": [
    {
      "dayNumber": 1,
      "date": "${DateTime.now().toIso8601String()}",
      "focusSubject": "os",
      "tasks": [
        {
          "id": "task_1_1",
          "subjectId": "os",
          "title": "Master Process Synchronization & Semaphores",
          "targetMinutes": 45,
          "isCompleted": false
        }
      ]
    }
  ]
}
''';

    try {
      final response = await _jsonModel!.generateContent([
        Content.text(prompt),
      ]);
      final cleanText = (response.text ?? '{}')
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleanText) as Map<String, dynamic>;
      return StudyPlan.fromJson(
        decoded,
        'plan_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      throw Exception('Failed to generate AI Study Plan: $e');
    }
  }

  @override
  Future<String> simplifyExplanation(String previousAnswer) async {
    _checkAiEnabled();
    _ensureModelsInitialized();
    final prompt =
        'Explain this concept in much simpler, intuitive terms using a basic real-world analogy suitable for a beginner student:\n\n$previousAnswer';
    final res = await _chatModel!.generateContent([Content.text(prompt)]);
    return res.text ?? previousAnswer;
  }

  @override
  Future<String> giveExample(
    String contextText, {
    bool realWorld = false,
  }) async {
    _checkAiEnabled();
    _ensureModelsInitialized();
    final prompt = realWorld
        ? 'Give a clear real-world industry example illustrating this concept:\n\n$contextText'
        : 'Give a concise code or numerical step-by-step example for this concept:\n\n$contextText';
    final res = await _chatModel!.generateContent([Content.text(prompt)]);
    return res.text ?? contextText;
  }
}
