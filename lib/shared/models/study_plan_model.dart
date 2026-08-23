import 'package:cloud_firestore/cloud_firestore.dart';

class StudyPlanTask {
  final String id;
  final String timeSlot; // 'Morning', 'Afternoon', 'Evening'
  final String subjectId;
  final String subjectName;
  final String topic;
  final int durationMinutes;
  final String taskType; // 'review', 'practice', 'summary', 'mock_test'
  final bool isCompleted;

  StudyPlanTask({
    required this.id,
    required this.timeSlot,
    required this.subjectId,
    required this.subjectName,
    required this.topic,
    required this.durationMinutes,
    this.taskType = 'review',
    this.isCompleted = false,
  });

  factory StudyPlanTask.fromJson(Map<String, dynamic> json) {
    return StudyPlanTask(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      timeSlot: json['timeSlot'] as String? ?? 'Morning',
      subjectId: json['subjectId'] as String? ?? 'os',
      subjectName: json['subjectName'] as String? ?? 'Operating Systems',
      topic: json['topic'] as String? ?? 'Core Concept Review',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      taskType: json['taskType'] as String? ?? 'review',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timeSlot': timeSlot,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'topic': topic,
      'durationMinutes': durationMinutes,
      'taskType': taskType,
      'isCompleted': isCompleted,
    };
  }

  StudyPlanTask copyWith({
    bool? isCompleted,
    String? topic,
    int? durationMinutes,
  }) {
    return StudyPlanTask(
      id: id,
      timeSlot: timeSlot,
      subjectId: subjectId,
      subjectName: subjectName,
      topic: topic ?? this.topic,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      taskType: taskType,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class StudyPlanDay {
  final String dayName;
  final String focus;
  final List<StudyPlanTask> tasks;

  StudyPlanDay({
    required this.dayName,
    required this.focus,
    required this.tasks,
  });

  factory StudyPlanDay.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'] as List<dynamic>?;
    final parsedTasks =
        rawTasks
            ?.map((t) => StudyPlanTask.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];

    return StudyPlanDay(
      dayName: json['dayName'] as String? ?? 'Study Day',
      focus: json['focus'] as String? ?? 'General Practice',
      tasks: parsedTasks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayName': dayName,
      'focus': focus,
      'tasks': tasks.map((t) => t.toJson()).toList(),
    };
  }

  StudyPlanDay copyWith({List<StudyPlanTask>? tasks, String? focus}) {
    return StudyPlanDay(
      dayName: dayName,
      focus: focus ?? this.focus,
      tasks: tasks ?? this.tasks,
    );
  }
}

class StudyPlan {
  final String id;
  final String userId;
  final String targetExam;
  final int dailyGoalMinutes;
  final String overview;
  final List<StudyPlanDay> days;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyPlan({
    required this.id,
    required this.userId,
    required this.targetExam,
    required this.dailyGoalMinutes,
    required this.overview,
    required this.days,
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalTasks => days.fold(0, (acc, day) => acc + day.tasks.length);
  int get completedTasks => days.fold(
    0,
    (acc, day) => acc + day.tasks.where((t) => t.isCompleted).length,
  );
  double get completionPercentage =>
      totalTasks > 0 ? (completedTasks / totalTasks) * 100.0 : 0.0;

  factory StudyPlan.fromJson(Map<String, dynamic> json, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    final rawDays = json['days'] as List<dynamic>?;
    final parsedDays =
        rawDays
            ?.map((d) => StudyPlanDay.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];

    return StudyPlan(
      id: documentId,
      userId: json['userId'] as String? ?? '',
      targetExam: json['targetExam'] as String? ?? 'General Exams',
      dailyGoalMinutes: (json['dailyGoalMinutes'] as num?)?.toInt() ?? 30,
      overview:
          json['overview'] as String? ?? 'Personalized AI Weekly Study Plan',
      days: parsedDays,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'targetExam': targetExam,
      'dailyGoalMinutes': dailyGoalMinutes,
      'overview': overview,
      'days': days.map((d) => d.toJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  StudyPlan copyWith({
    List<StudyPlanDay>? days,
    String? overview,
    DateTime? updatedAt,
  }) {
    return StudyPlan(
      id: id,
      userId: userId,
      targetExam: targetExam,
      dailyGoalMinutes: dailyGoalMinutes,
      overview: overview ?? this.overview,
      days: days ?? this.days,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
