import 'package:flutter/material.dart';

class Subject {
  final String id;
  final String name;
  final String shortName;
  final Color color;

  const Subject({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['shortName'] as String,
      color: Color(int.parse(json['color'].toString().replaceAll('#', '0xFF'))),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    };
  }
}

class AppSubjects {
  static const List<Subject> availableSubjects = [
    Subject(id: 'os', name: 'Operating Systems', shortName: 'OS', color: Color(0xFFFF6B6B)),
    Subject(id: 'py', name: 'Python Programming', shortName: 'Python', color: Color(0xFF2DD4BF)),
    Subject(id: 'db', name: 'DBMS', shortName: 'DBMS', color: Color(0xFFFFB443)),
    Subject(id: 'net', name: 'Computer Networks', shortName: 'Networks', color: Color(0xFF5B8DEF)),
    Subject(id: 'asp', name: 'ASP.NET', shortName: 'ASP.NET', color: Color(0xFFF783AC)),
  ];

  static Subject? getById(String id) {
    for (final s in availableSubjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  static Subject getByIdOrDefault(String id, {Subject? fallback}) {
    return getById(id) ?? fallback ?? availableSubjects.first;
  }
}
