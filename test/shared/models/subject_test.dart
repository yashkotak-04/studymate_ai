import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_ai/shared/models/subject.dart';

void main() {
  group('Subject Model Tests', () {
    test('fromJson parses color correctly', () {
      final json = {
        'id': 'os',
        'name': 'Operating Systems',
        'shortName': 'OS',
        'color': '#FF6B6B',
      };

      final subject = Subject.fromJson(json);

      expect(subject.id, 'os');
      expect(subject.name, 'Operating Systems');
      expect(subject.shortName, 'OS');
      expect(subject.color, const Color(0xFFFF6B6B));
    });

    test('toJson encodes color correctly', () {
      const subject = Subject(
        id: 'py',
        name: 'Python',
        shortName: 'Py',
        color: Color(0xFF2DD4BF),
      );

      final json = subject.toJson();

      expect(json['id'], 'py');
      expect(json['name'], 'Python');
      expect(json['shortName'], 'Py');
      expect(json['color'], '#2DD4BF');
    });

    test('AppSubjects.getById returns correct subject', () {
      final subject = AppSubjects.getById('db');
      expect(subject, isNotNull);
      expect(subject?.name, 'DBMS');
      expect(subject?.shortName, 'DBMS');
    });

    test('AppSubjects.getById returns null if not found', () {
      final subject = AppSubjects.getById('non_existent');
      expect(subject, isNull);
    });

    test('AppSubjects.getByIdOrDefault returns fallback or default if not found', () {
      final subject = AppSubjects.getByIdOrDefault('non_existent');
      expect(subject.id, 'os');
    });
  });
}
