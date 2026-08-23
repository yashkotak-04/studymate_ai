import 'package:cloud_firestore/cloud_firestore.dart';

class Recommendation {
  final String id;
  final String userId;
  final String subjectId;
  final String subjectName;
  final String topic;
  final String title;
  final String reason;
  final String? evidence;
  final String actionLabel;
  final String actionType; // 'practice', 'chat', 'summary', 'mock_test'
  final String actionRoute;
  final double? accuracy;
  final bool isPersonalized;
  final bool isCompleted;
  final DateTime createdAt;

  Recommendation({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.subjectName,
    required this.topic,
    required this.title,
    required this.reason,
    this.evidence,
    this.actionLabel = 'Start Practice',
    this.actionType = 'practice',
    this.actionRoute = '/practice',
    this.accuracy,
    this.isPersonalized = true,
    this.isCompleted = false,
    required this.createdAt,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return Recommendation(
      id: documentId,
      userId: json['userId'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? 'os',
      subjectName: json['subjectName'] as String? ?? 'Operating Systems',
      topic: json['topic'] as String? ?? 'Concept Mastery',
      title: json['title'] as String? ?? 'Focus Practice Recommended',
      reason: json['reason'] as String? ?? 'Based on recent performance and study pace.',
      evidence: json['evidence'] as String?,
      actionLabel: json['actionLabel'] as String? ?? 'Start Practice',
      actionType: json['actionType'] as String? ?? 'practice',
      actionRoute: json['actionRoute'] as String? ?? '/practice',
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      isPersonalized: json['isPersonalized'] as bool? ?? true,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'topic': topic,
      'title': title,
      'reason': reason,
      if (evidence != null) 'evidence': evidence,
      'actionLabel': actionLabel,
      'actionType': actionType,
      'actionRoute': actionRoute,
      if (accuracy != null) 'accuracy': accuracy,
      'isPersonalized': isPersonalized,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
