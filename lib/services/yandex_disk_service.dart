import 'dart:convert';
import 'package:yandex_disk/yandex_disk.dart';
import '../models.dart';
import 'token_storage.dart';

class YandexDiskService {
  static const String _baseUrl = 'https://cloud-api.yandex.net';

  Future<void> uploadResult({
    required ExamResult result,
    required Ticket ticket,
    required Student student,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null) throw Exception('Требуется авторизация в Яндексе');

    final api = YandexDiskApi(_baseUrl, token);
    final report = _buildReport(result, ticket, student);
    final jsonString = const JsonEncoder.withIndent('  ').convert(report);
    final bytes = utf8.encode(jsonString);

    final fileName = 'result_${student.name.replaceAll(' ', '_')}_'
        '${ticket.id}_${DateTime.now().millisecondsSinceEpoch}.json';
    final path = '/exam_results/$fileName';

    await api.uploadDiskResource(
      path: path,
      binaryData: bytes,
      overwrite: true,
    );
  }

  Map<String, dynamic> _buildReport(ExamResult result, Ticket ticket, Student student) {
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
      'student': {'name': student.name, 'group': student.group, 'login': student.login},
      'ticket': {'id': ticket.id, 'title': ticket.title},
      'result': {
        'score': result.score, 'total': result.total, 'percent': result.percent,
        'passed': result.passed, 'date': result.date.toIso8601String(),
      },
      'questions_details': questionsDetails,
    };
  }
}