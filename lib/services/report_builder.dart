import 'dart:convert';
import '../models.dart';

/// Собирает отчёт о результате экзамена.
/// Используется для выгрузки на Яндекс Диск и сохранения на телефон.
Map<String, dynamic> buildReport({
  required ExamResult result,
  required Ticket ticket,
  required Student student,
}) {
  final questionsDetails = <Map<String, dynamic>>[];
  for (var i = 0; i < ticket.questions.length; i++) {
    final q = ticket.questions[i];
    final given = i < result.answers.length ? result.answers[i] : null;
    questionsDetails.add({
      'question': q.text,
      'options': q.options,
      'correct_answer': q.correct,
      'student_answer': given,
      'is_correct': given == q.correct,
      'hint': q.hint,
    });
  }

  return {
    'student': {
      'name': student.name,
      'group': student.group,
      'login': student.login,
    },
    'ticket': {
      'id': ticket.id,
      'title': ticket.title,
    },
    'result': {
      'score': result.score,
      'total': result.total,
      'percent': result.percent,
      'passed': result.passed,
      'date': result.date.toIso8601String(),
    },
    'questions_details': questionsDetails,
  };
}

String reportToJson(Map<String, dynamic> report) =>
    const JsonEncoder.withIndent('  ').convert(report);

/// Имя файла отчёта.
String reportFileName(Student student, Ticket ticket) =>
    'result_${student.name.replaceAll(' ', '_')}_'
        '${ticket.id}_${DateTime.now().millisecondsSinceEpoch}.json';
