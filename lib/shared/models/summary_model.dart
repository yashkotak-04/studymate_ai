import 'package:cloud_firestore/cloud_firestore.dart';

class GeneratedSummary {
  final String quickSummary;
  final List<String> importantPoints;
  final List<String> keyTerms;
  final List<String> examFocus;
  final List<String> revisionQuestions;

  GeneratedSummary({
    required this.quickSummary,
    required this.importantPoints,
    required this.keyTerms,
    required this.examFocus,
    required this.revisionQuestions,
  });

  factory GeneratedSummary.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (raw is String && raw.trim().isNotEmpty) {
        return [raw.trim()];
      }
      return [];
    }

    return GeneratedSummary(
      quickSummary: (json['quickSummary'] as String? ?? '').trim(),
      importantPoints: parseList(json['importantPoints']),
      keyTerms: parseList(json['keyTerms']),
      examFocus: parseList(json['examFocus']),
      revisionQuestions: parseList(json['revisionQuestions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quickSummary': quickSummary,
      'importantPoints': importantPoints,
      'keyTerms': keyTerms,
      'examFocus': examFocus,
      'revisionQuestions': revisionQuestions,
    };
  }
}

class SummaryDocument {
  final String id;
  final String userId;
  final String title;
  final String? subjectId;
  final String sourceText;
  final GeneratedSummary summary;
  final DateTime createdAt;

  SummaryDocument({
    required this.id,
    required this.userId,
    required this.title,
    this.subjectId,
    required this.sourceText,
    required this.summary,
    required this.createdAt,
  });

  factory SummaryDocument.fromJson(
    Map<String, dynamic> json,
    String documentId,
  ) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    final rawContent = json['summary'] ?? json['generatedContent'] ?? {};
    final parsedSummary = rawContent is Map<String, dynamic>
        ? GeneratedSummary.fromJson(rawContent)
        : GeneratedSummary.fromJson({});

    return SummaryDocument(
      id: documentId,
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? 'Study Summary',
      subjectId: json['subjectId'] as String?,
      sourceText: json['sourceText'] as String? ?? '',
      summary: parsedSummary,
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      if (subjectId != null) 'subjectId': subjectId,
      'sourceText': sourceText,
      'summary': summary.toJson(),
      'generatedContent': summary.toJson(), // backwards compatibility
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
