import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final bool onboardingComplete;
  final String? academicProgram;
  final String? targetExam;
  final DateTime? examDate;
  final List<String> enrolledSubjectIds;
  final int dailyStudyGoalMinutes;
  final String preferredAiMode; // 'Beginner', 'Student', 'Exam', 'Viva'
  final int currentStreak;
  final int longestStreak;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  UserProfile({
    required this.uid,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.onboardingComplete = false,
    this.academicProgram,
    this.targetExam,
    this.examDate,
    this.enrolledSubjectIds = const [],
    this.dailyStudyGoalMinutes = 30,
    this.preferredAiMode = 'Student',
    this.currentStreak = 0,
    this.longestStreak = 0,
    required this.createdAt,
    this.lastActiveAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json, [String? documentId]) {
    return UserProfile(
      uid: documentId ?? json['uid'] as String? ?? json['userId'] as String? ?? '',
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      academicProgram: json['academicProgram'] as String?,
      targetExam: json['targetExam'] as String?,
      examDate: (json['examDate'] as Timestamp?)?.toDate(),
      enrolledSubjectIds: List<String>.from(json['enrolledSubjectIds'] ?? []),
      dailyStudyGoalMinutes: json['dailyStudyGoalMinutes'] as int? ?? 30,
      preferredAiMode: json['preferredAiMode'] as String? ?? 'Student',
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (json['lastActiveAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'onboardingComplete': onboardingComplete,
      'academicProgram': academicProgram,
      'targetExam': targetExam,
      'examDate': examDate != null ? Timestamp.fromDate(examDate!) : null,
      'enrolledSubjectIds': enrolledSubjectIds,
      'dailyStudyGoalMinutes': dailyStudyGoalMinutes,
      'preferredAiMode': preferredAiMode,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': lastActiveAt != null
          ? Timestamp.fromDate(lastActiveAt!)
          : null,
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    bool? onboardingComplete,
    String? academicProgram,
    String? targetExam,
    DateTime? examDate,
    List<String>? enrolledSubjectIds,
    int? dailyStudyGoalMinutes,
    String? preferredAiMode,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActiveAt,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      academicProgram: academicProgram ?? this.academicProgram,
      targetExam: targetExam ?? this.targetExam,
      examDate: examDate ?? this.examDate,
      enrolledSubjectIds: enrolledSubjectIds ?? this.enrolledSubjectIds,
      dailyStudyGoalMinutes:
          dailyStudyGoalMinutes ?? this.dailyStudyGoalMinutes,
      preferredAiMode: preferredAiMode ?? this.preferredAiMode,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}
