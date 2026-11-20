import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:yandex_disk/yandex_disk.dart';
import '../models.dart';
import '../storage.dart';
import 'token_storage.dart';

class YandexDiskService {
  static const String _baseUrl = 'https://cloud-api.yandex.net';

  /// Папка результатов внутри опубликованной папки exam_data.
  /// PublicSyncService._walk обходит дерево рекурсивно и подхватывает
  /// result_*.json оттуда при синхронизации.
  static const String resultsFolder = '/exam_data/exam_results';

  /// Папка кодов преподавателей внутри exam_data: файлы вида
  /// TCH_XXXX_XXXX.ecod.
  static const String codesFolder = '/exam_data/code';

  Future<void> uploadResult({
    required ExamResult result,
    required Ticket ticket,
    required Student student,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null) throw Exception('Требуется авторизация в Яндексе');

    await _ensureFolderExists(token, resultsFolder);

    final api = YandexDiskApi(_baseUrl, token);
    final report = _buildReport(result, ticket, student);
    final jsonString = const JsonEncoder.withIndent('  ').convert(report);
    final bytes = utf8.encode(jsonString);

    final fileName = 'result_${student.name.replaceAll(' ', '_')}_'
        '${ticket.id}_${DateTime.now().millisecondsSinceEpoch}.json';
    final path = '$resultsFolder/$fileName';

    try {
      await api.uploadDiskResource(
        path: path,
        binaryData: bytes,
        overwrite: true,
      );
      print('DISK UPLOAD OK: $path');
    } on DioError catch (e) {
      print('DISK STATUS: ${e.response?.statusCode}');
      print('DISK BODY: ${e.response?.data}');
      rethrow;
    }
  }

  /// Выгружает регистрационный код преподавателя в /exam_data/code
  /// файлом вида TCH_XXXX_XXXX.ecod. Содержимое — зашифрованный
  /// (XOR + Base64) JSON кода, тем же способом, что и ссылка на папку.
  Future<void> uploadTeacherCode(TeacherCode code) async {
    final token = await TokenStorage.getToken();
    if (token == null) throw Exception('Требуется авторизация в Яндексе');

    await _ensureFolderExists(token, codesFolder);

    final api = YandexDiskApi(_baseUrl, token);
    final content = AppStorage.encodeCode(jsonEncode(code.toJson()));
    final bytes = utf8.encode(content);

    final fileName =
        '${code.code.replaceAll(RegExp(r'[^A-Z0-9]', caseSensitive: false), '_')}.ecod';
    final path = '$codesFolder/$fileName';

    try {
      await api.uploadDiskResource(
        path: path,
        binaryData: bytes,
        overwrite: true,
      );
      print('DISK CODE UPLOAD OK: $path');
    } on DioError catch (e) {
      print('DISK CODE STATUS: ${e.response?.statusCode}');
      print('DISK CODE BODY: ${e.response?.data}');
      rethrow;
    }
  }

  /// Удаляет файл кода с Диска (при регистрации по коду и при удалении
  /// неиспользованного кода админом).
  Future<void> deleteTeacherCode(String code) async {
    final token = await TokenStorage.getToken();
    if (token == null) return; // нет токена — нет удаления, тихо

    final fileName =
        '${code.replaceAll(RegExp(r'[^A-Z0-9]', caseSensitive: false), '_')}.ecod';
    final path = '$codesFolder/$fileName';

    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {'Authorization': 'OAuth $token'},
    ));
    try {
      await dio.delete('/v1/disk/resources', queryParameters: {
        'path': path,
        'permanently': 'true',
      });
      print('DISK CODE DELETE OK: $path');
    } on DioError catch (e) {
      if (e.response?.statusCode == 404) return;
      print('DISK CODE DELETE ERROR: '
          '${e.response?.statusCode} ${e.response?.data}');
      rethrow;
    }
  }

  /// Создаёт папку на Диске, если её ещё нет. 409 = уже существует —
  /// не ошибка.
  Future<void> _ensureFolderExists(String token, String folder) async {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {'Authorization': 'OAuth $token'},
    ));
    try {
      await dio.put('/v1/disk/resources', queryParameters: {'path': folder});
      print('DISK FOLDER CREATED: $folder');
    } on DioError catch (e) {
      if (e.response?.statusCode != 409) {
        print(
            'DISK FOLDER ERROR: ${e.response?.statusCode} ${e.response?.data}');
        rethrow;
      }
    }
  }

  Map<String, dynamic> _buildReport(
      ExamResult result, Ticket ticket, Student student) {
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
        'login': student.login
      },
      'ticket': {'id': ticket.id, 'title': ticket.title},
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
}
