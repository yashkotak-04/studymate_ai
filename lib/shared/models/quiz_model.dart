import 'package:cloud_firestore/cloud_firestore.dart';

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int? selectedIndex;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.selectedIndex,
  });

  bool get wasCorrect => selectedIndex != null && selectedIndex == correctIndex;

  bool get isValid =>
      question.trim().isNotEmpty &&
      options.length == 4 &&
      options.every((opt) => opt.trim().isNotEmpty) &&
      correctIndex >= 0 &&
      correctIndex < options.length &&
      explanation.trim().isNotEmpty;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    List<String> parsedOptions = [];
    if (rawOptions is List) {
      parsedOptions = rawOptions.map((e) => e.toString().trim()).toList();
    }

    final rawCorrectIndex = json['correctIndex'];
    int parsedCorrect = 0;
    if (rawCorrectIndex is int) {
      parsedCorrect = rawCorrectIndex;
    } else if (rawCorrectIndex is String) {
      parsedCorrect = int.tryParse(rawCorrectIndex) ?? 0;
    }

    return QuizQuestion(
      question: (json['question'] as String? ?? '').trim(),
      options: parsedOptions,
      correctIndex: parsedCorrect.clamp(0, parsedOptions.isNotEmpty ? parsedOptions.length - 1 : 3),
      explanation: (json['explanation'] as String? ?? '').trim(),
      selectedIndex: json['selectedIndex'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
      if (selectedIndex != null) 'selectedIndex': selectedIndex,
      if (selectedIndex != null) 'wasCorrect': wasCorrect,
    };
  }

  QuizQuestion copyWith({
    String? question,
    List<String>? options,
    int? correctIndex,
    String? explanation,
    int? selectedIndex,
  }) {
    return QuizQuestion(
      question: question ?? this.question,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      explanation: explanation ?? this.explanation,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}

class QuizSession {
  final String id;
  final String userId;
  final String subjectId;
  final String topic;
  final String difficulty;
  final int totalQuestions;
  final int score;
  final bool isMockTest;
  final bool isCompleted;
  final DateTime startTime;
  final DateTime endTime;
  final List<QuizQuestion> questions;
  final List<int> userAnswers;

  QuizSession({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.topic,
    required this.difficulty,
    required this.totalQuestions,
    required this.score,
    this.isMockTest = false,
    this.isCompleted = false,
    required this.startTime,
    required this.endTime,
    required this.questions,
    this.userAnswers = const [],
  });

  int get durationMinutes {
    final diff = endTime.difference(startTime).inSeconds;
    final mins = (diff / 60.0).ceil();
    return mins < 1 ? 1 : mins.clamp(1, 180);
  }

  double get accuracy => totalQuestions > 0 ? (score / totalQuestions) * 100.0 : 0.0;

  factory QuizSession.fromJson(Map<String, dynamic> json, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    final rawQuestions = json['questions'] as List<dynamic>?;
    final parsedQuestions = rawQuestions
            ?.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList() ??
        [];

    final rawAnswers = json['userAnswers'] as List<dynamic>?;
    final parsedAnswers = rawAnswers?.map((e) => (e as num).toInt()).toList() ?? [];

    return QuizSession(
      id: documentId,
      userId: json['userId'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? 'general',
      topic: json['topic'] as String? ?? 'Quiz',
      difficulty: json['difficulty'] as String? ?? 'Medium',
      totalQuestions: json['totalQuestions'] as int? ?? parsedQuestions.length,
      score: json['score'] as int? ?? 0,
      isMockTest: json['isMockTest'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? true,
      startTime: parseDate(json['startTime']),
      endTime: parseDate(json['endTime']),
      questions: parsedQuestions,
      userAnswers: parsedAnswers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'subjectId': subjectId,
      'topic': topic,
      'difficulty': difficulty,
      'totalQuestions': totalQuestions,
      'score': score,
      'isMockTest': isMockTest,
      'isCompleted': isCompleted,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'questions': questions.map((q) => q.toJson()).toList(),
      'userAnswers': userAnswers,
      'durationMinutes': durationMinutes,
      'accuracy': accuracy,
    };
  }

  QuizSession copyWith({
    String? id,
    String? userId,
    String? subjectId,
    String? topic,
    String? difficulty,
    int? totalQuestions,
    int? score,
    bool? isMockTest,
    bool? isCompleted,
    DateTime? startTime,
    DateTime? endTime,
    List<QuizQuestion>? questions,
    List<int>? userAnswers,
  }) {
    return QuizSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subjectId: subjectId ?? this.subjectId,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      score: score ?? this.score,
      isMockTest: isMockTest ?? this.isMockTest,
      isCompleted: isCompleted ?? this.isCompleted,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      questions: questions ?? this.questions,
      userAnswers: userAnswers ?? this.userAnswers,
    );
  }
}
