import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum ExplanationMode {
  beginner(
    id: 'beginner',
    label: 'Beginner',
    icon: LucideIcons.sparkles,
    desc: 'Plain language, everyday analogies',
    systemPrompt:
        'Explain in clear, intuitive beginner language. Use concrete everyday analogies and avoid overly dense academic jargon unless immediately defined with simple examples.',
  ),
  student(
    id: 'student',
    label: 'Student',
    icon: LucideIcons.bookOpenCheck,
    desc: 'Textbook depth, exam vocabulary',
    systemPrompt:
        'Provide comprehensive, academically rigorous explanations suitable for university/diploma students. Include standard technical definitions, principles, and structured breakdowns.',
  ),
  exam(
    id: 'exam',
    label: 'Exam',
    icon: LucideIcons.target,
    desc: 'Short, scorable, to-the-point',
    systemPrompt:
        'Provide concise, highly scorable, bulleted answers designed for quick memorization and maximum exam marks. Highlight key definitions, formulas, pros/cons, and diagrams/diagram notes where applicable.',
  ),
  viva(
    id: 'viva',
    label: 'Viva',
    icon: LucideIcons.user,
    desc: 'Spoken answers, follow-up ready',
    systemPrompt:
        'Deliver concise, conversational answers tailored for oral exams and viva voce. Give direct 2-3 sentence answers followed by anticipated follow-up questions or counter-examples.',
  );

  final String id;
  final String label;
  final IconData icon;
  final String desc;
  final String systemPrompt;

  const ExplanationMode({
    required this.id,
    required this.label,
    required this.icon,
    required this.desc,
    required this.systemPrompt,
  });

  static ExplanationMode fromId(String? id) {
    for (final mode in ExplanationMode.values) {
      if (mode.id == id || mode.name == id?.toLowerCase()) {
        return mode;
      }
    }
    return ExplanationMode.student;
  }
}

class ChatThread {
  final String id;
  final String userId;
  final String subjectId;
  final String title;
  final ExplanationMode mode;
  final String? lastMessagePreview;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatThread({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.title,
    this.mode = ExplanationMode.student,
    this.lastMessagePreview,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return ChatThread(
      id: documentId,
      userId: json['userId'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? 'general',
      title: json['title'] as String? ?? 'Study Session',
      mode: ExplanationMode.fromId(json['mode'] as String?),
      lastMessagePreview: json['lastMessagePreview'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'subjectId': subjectId,
      'title': title,
      'mode': mode.id,
      if (lastMessagePreview != null) 'lastMessagePreview': lastMessagePreview,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ChatThread copyWith({
    String? title,
    ExplanationMode? mode,
    String? lastMessagePreview,
    DateTime? updatedAt,
  }) {
    return ChatThread(
      id: id,
      userId: userId,
      subjectId: subjectId,
      title: title ?? this.title,
      mode: mode ?? this.mode,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChatMessage {
  final String id;
  final String role; // 'user' or 'model'
  final String text;
  final DateTime timestamp;
  final bool isVoice;

  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isVoice = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return ChatMessage(
      id: documentId,
      role: json['role'] as String? ?? 'user',
      text: json['text'] as String? ?? '',
      timestamp: parseDate(json['timestamp']),
      isVoice: json['isVoice'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isVoice': isVoice,
    };
  }
}
