import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models.dart';
import '../services/database_service.dart';
import '../services/yandex_disk_service.dart';
import '../services/sync_settings.dart';
import '../storage.dart';

/// Синхронизация из публичной папки Яндекс Диска.
///
/// Файлы результатов: {student, ticket, result, questions_details}.
/// Файлы кодов преподавателей: *.ecod в корне опубликованной папки —
/// зашифрованный (XOR + Base64) JSON с полями кода. Загрузка кодов на Диск —
/// publishTeacherCode(), через YandexDiskService с общим OAuth-токеном
/// (TokenStorage), как у выгрузки результатов.
/// Использованный код удаляется из публичной папки: при регистрации
/// сразу (deleteTeacherCodeRemote в экране регистрации) и подстраховкой —
/// при синхронизации, если пришёл файл со статусом «использован».
class PublicSyncService {
  static const _base = 'https://cloud-api.yandex.net/v1/disk/public/resources';

  /// Код доступа к папке по умолчанию (зашифрованная ссылка).
  static const _encodedDefault =
      'DQwVHUEKHRkBERIGHElTWAEdGUNARR1SSjNYLnRDek8/GwcaRQlV';

  static String get encodedDefault => _encodedDefault;

  static const _key = 'exam2026';

  /// Расшифровывает код доступа в ссылку. Принимает и зашифрованный код,
  /// и обычную ссылку (на случай отладки).
  static String _decodeLink(String input) {
    if (input.startsWith('http')) return input;
    try {
      final raw = base64Decode(input.replaceAll('\n', ' ').trim());
      return String.fromCharCodes([
        for (var i = 0; i < raw.length; i++)
          raw[i] ^ _key.codeUnitAt(i % _key.length),
      ]);
    } catch (_) {
      return '';
    }
  }

  static Map<String, dynamic>? _asMap(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static int _asInt(Object? v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  /// «t1» → 1, «ticket_01» → 1, «Билет №1» → 1. Пусто, если цифр нет.
  static String _digits(String s) {
    final d = s.replaceAll(RegExp(r'\D'), '');
    return d.isEmpty ? '' : int.tryParse(d).toString();
  }

  /// Текущая публичная ссылка: сохранённая в настройках или дефолтная.
  static Future<String> currentPublicKey() async {
    final saved = await SyncSettings.getUrl();
    return _decodeLink((saved ?? encodedDefault).trim());
  }

  /// Точка входа: расшифровывает ссылку и запускает синхронизацию,
  /// превращая сетевые сбои в понятные сообщения.
  static Future<SyncStats> syncFromPublicUrl(String input) async {
    final url = _decodeLink(input.trim());
    if (url.isEmpty || !url.startsWith('http')) {
      throw Exception('Неверный код доступа');
    }
    try {
      return await _syncAll(url);
    } on SocketException {
      debugPrint('YandexSync: SocketException — нет сети');
      throw Exception('Отсутствует подключение к интернету');
    } on TimeoutException {
      debugPrint('YandexSync: TimeoutException — нет сети или медленно');
      throw Exception('Отсутствует подключение к интернету');
    } on HttpException {
      debugPrint('YandexSync: HttpException — нет сети');
      throw Exception('Отсутствует подключение к интернету');
    }
  }

  /// Основная логика синхронизации. Все сетевые вызовы здесь падают
  /// с SocketException/TimeoutException при отсутствии интернета,
  /// наверх их перехватывает syncFromPublicUrl.
  static Future<SyncStats> _syncAll(String url) async {
    var tickets = 0;
    var students = 0;
    var results = 0;
    var codes = 0;
    final newStudents = <Student>[];
    final newTickets = <Ticket>[];
    final pendingResults = <_PendingResult>[];

    final files = <_RemoteFile>[];
    await _walk(url, '', files, 0);
    debugPrint('YandexSync: found ${files.length} json files');

    for (final f in files) {
      final lowerName = f.name.toLowerCase();

      // --- Файлы кодов преподавателей (.ecod) ---
      if (lowerName.endsWith('.ecod')) {
        final body = await _downloadFile(url, f.path);
        if (body == null) continue;
        final decoded = AppStorage.decodeCode(body);
        if (decoded.isEmpty) {
          debugPrint('YandexSync: bad ecod "${f.name}"');
          continue;
        }
        try {
          final obj = jsonDecode(decoded);
          if (obj is Map<String, dynamic>) {
            final code = TeacherCode.fromJson(obj);
            await AppStorage.instance.mergeRemoteTeacherCode(code);
            codes++;
            debugPrint('YandexSync: teacher code ok "${f.name}"');

            // Код уже использован — удаляем файл из публичной папки,
            // чтобы новые устройства его больше не видели. Сбой удаления
            // (нет сети, нет токена) не ломает синхронизацию: файл уберёт
            // следующая синхронизация или регистрация на другом устройстве.
            if (code.used) {
              try {
                await deleteTeacherCodeRemote(code.code);
                debugPrint(
                    'YandexSync: used code "${code.code}" removed from public folder');
              } catch (e) {
                debugPrint(
                    'YandexSync: used code delete failed "${code.code}": $e');
              }
            }
          }
        } catch (e) {
          debugPrint('YandexSync: ecod parse error "${f.name}": $e');
        }
        continue;
      }

      // --- Обычные JSON-файлы ---
      final body = await _downloadFile(url, f.path);
      if (body == null) continue;

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('YandexSync: bad json in "${f.name}": $e');
        continue;
      }

      if (json.containsKey('questions')) {
        try {
          final t = _ticketFromJson(json);
          await DatabaseService.instance.saveTicket(t);
          newTickets.add(t);
          tickets++;
          debugPrint('YandexSync: ticket ok "${f.name}"');
        } catch (e) {
          debugPrint('YandexSync: ticket parse error "${f.name}": $e');
        }
      } else if (json['students'] is List) {
        for (final s in (json['students'] as List)) {
          if (s is Map<String, dynamic>) {
            newStudents.add(_studentFromJson(s));
            students++;
          }
        }
        debugPrint('YandexSync: students list ok "${f.name}"');
      } else if (json['login'] != null) {
        newStudents.add(_studentFromJson(json));
        students++;
        debugPrint('YandexSync: single student ok "${f.name}"');
      } else if (json['result'] is Map) {
        final r = _parseResultFile(json);
        if (r != null) {
          pendingResults.add(r);
          results++;
          debugPrint('YandexSync: result ok "${f.name}"');
        } else {
          debugPrint('YandexSync: result incomplete "${f.name}"');
        }
      } else {
        debugPrint(
            'YandexSync: unknown format "${f.name}", keys: ${json.keys.toList()}');
      }
    }

    if (newStudents.isNotEmpty) {
      await DatabaseService.instance.upsertStudents(newStudents);
      await AppStorage.instance.applySyncStudents(newStudents);
    }
    if (newTickets.isNotEmpty) {
      await AppStorage.instance.applySyncTickets(newTickets);
    }

    // Привязка результатов к локальным студентам и билетам.
    if (pendingResults.isNotEmpty) {
      final studentsDb = AppStorage.instance.db.students;
      final ticketsDb = AppStorage.instance.db.tickets;
      final resolved = <ExamResult>[];
      for (final p in pendingResults) {
        // Студент: по id, логину (без учёта регистра) или имени.
        Student? s;
        for (final st in studentsDb) {
          if (st.id == p.studentLogin ||
              st.login.toLowerCase() == p.studentLogin.toLowerCase()) {
            s = st;
            break;
          }
        }
        s ??= _findByName(studentsDb, p.studentName);
        if (s == null) {
          debugPrint(
              'YandexSync: result skipped, student "${p.studentLogin}" not found');
          continue;
        }

        // Билет: по id, названию или номеру («t1» ↔ «ticket_01» ↔ «Билет 1»).
        final keyDigits = _digits(p.ticketKey);
        Ticket? t;
        for (final tk in ticketsDb) {
          if (tk.id == p.ticketKey ||
              tk.title == p.ticketKey ||
              (keyDigits.isNotEmpty &&
                  (_digits(tk.id) == keyDigits ||
                      _digits(tk.title) == keyDigits))) {
            t = tk;
            break;
          }
        }
        if (t == null) {
          debugPrint(
              'YandexSync: result skipped, ticket "${p.ticketKey}" not found');
          continue;
        }

        resolved.add(ExamResult(
          id: p.id,
          studentId: s.id,
          ticketId: t.id,
          score: p.score,
          total: p.total,
          percent: p.percent ??
              (p.total > 0 ? (p.score * 100 / p.total).round() : 0),
          passed: p.passed ?? (p.total > 0 && p.score * 100 / p.total >= 60),
          answers: const [],
          date: p.date,
        ));
      }
      if (resolved.isNotEmpty) {
        await AppStorage.instance.applySyncResults(resolved);
        debugPrint('YandexSync: applied ${resolved.length} results');
      }
    }

    return SyncStats(
        tickets: tickets, students: students, results: results, codes: codes);
  }

  /// Загружает файл кода преподавателя на Диск через общий сервис
  /// (тот же токен, что и у выгрузки результатов). Файл ложится
  /// в /exam_results/TCH_XXXX_XXXX.ecod.
  static Future<void> publishTeacherCode(TeacherCode c) async {
    await YandexDiskService().uploadTeacherCode(c);
  }

  /// Удаляет файл кода с Диска (при регистрации по коду и при удалении
  /// неиспользованного кода админом). Без токена тихо ничего не делает.
  static Future<void> deleteTeacherCodeRemote(String code) async {
    await YandexDiskService().deleteTeacherCode(code);
  }

  /// Запасной поиск студента по ФИО — если логин в файле не совпал.
  static Student? _findByName(List<Student> list, String name) {
    final n = name.toLowerCase().trim();
    if (n.isEmpty) return null;
    for (final st in list) {
      if (st.name.toLowerCase().trim() == n) return st;
    }
    return null;
  }

  /// Разбирает файл результата: {student, ticket, result, questions_details}.
  static _PendingResult? _parseResultFile(Map<String, dynamic> data) {
    final student = _asMap(data['student']);
    final ticket = _asMap(data['ticket']);
    final result = _asMap(data['result']);
    if (student == null || result == null) return null;

    final login = (student['login'] ?? student['id'] ?? '').toString().trim();
    final name = (student['name'] ?? student['fio'] ?? '').toString().trim();
    if (login.isEmpty && name.isEmpty) return null;

    final ticketKey =
    (ticket?['id'] ?? ticket?['title'] ?? '').toString().trim();

    final score = _asInt(result['score']);
    final total = _asInt(result['total'] ?? result['maxScore'] ?? 0);
    final dateRaw = (result['date'] ??
        result['finishedAt'] ??
        result['finished_at'] ??
        result['timestamp'] ??
        '')
        .toString();
    final date = DateTime.tryParse(dateRaw) ?? DateTime.now();

    final id = (result['id'] ??
        'sync_${login}_${ticketKey}_${date.millisecondsSinceEpoch}')
        .toString();

    final percentRaw = result['percent'];
    final percent =
    percentRaw is num ? percentRaw.toInt() : int.tryParse('$percentRaw');

    final passedRaw = result['passed'];
    final passed = passedRaw is bool
        ? passedRaw
        : (passedRaw is num ? passedRaw != 0 : null);

    return _PendingResult(
      studentLogin: login,
      studentName: name,
      ticketKey: ticketKey,
      score: score,
      total: total,
      percent: percent,
      passed: passed,
      date: date,
      id: id,
    );
  }

  /// Рекурсивный обход публичной папки. Подхватывает файлы из подпапок,
  /// так что *.ecod, оставшиеся в старой подпапке «code», тоже читаются.
  static Future<void> _walk(
      String publicKey, String path, List<_RemoteFile> out, int depth) async {
    if (depth > 5) return;

    final uri = Uri.parse(_base).replace(queryParameters: {
      'public_key': publicKey,
      if (path.isNotEmpty) 'path': path,
      'limit': '1000',
    });

    final resp = await http.get(uri, headers: {
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 20));
    debugPrint('YandexSync: list "$path" HTTP ${resp.statusCode}');

    if (resp.statusCode != 200) {
      throw Exception('Папка недоступна (HTTP ${resp.statusCode}). '
          'Проверьте, что это ссылка на публичную папку Диска: $publicKey');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final embedded = data['_embedded'];
    if (embedded is! Map || embedded['items'] is! List) return;

    for (final item in (embedded['items'] as List)) {
      if (item is! Map) continue;
      final type = (item['type'] as String?) ?? '';
      final name = (item['name'] as String?) ?? '';
      final itemPath = (item['path'] as String?) ?? '';

      if (type == 'dir') {
        await _walk(publicKey, itemPath, out, depth + 1);
      } else if (name.toLowerCase().endsWith('.json') ||
          name.toLowerCase().endsWith('.ecod')) {
        out.add(_RemoteFile(name: name, path: itemPath));
      }
    }
  }

  /// Скачивание файла из публичной папки.
  static Future<String?> _downloadFile(String publicKey, String path) async {
    try {
      final uri = Uri.parse('$_base/download').replace(queryParameters: {
        'public_key': publicKey,
        'path': path,
      });
      final resp = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) {
        debugPrint(
            'YandexSync: get-download-href "$path" HTTP ${resp.statusCode}');
        return null;
      }

      final href = (jsonDecode(resp.body) as Map<String, dynamic>)['href'];
      if (href is! String) return null;

      final fileResp =
      await http.get(Uri.parse(href)).timeout(const Duration(seconds: 30));
      debugPrint('YandexSync: download "$path" HTTP ${fileResp.statusCode}');
      return fileResp.statusCode == 200
          ? utf8.decode(fileResp.bodyBytes)
          : null;
    } catch (e) {
      debugPrint('YandexSync: download error "$path": $e');
      rethrow;
    }
  }

  static Student _studentFromJson(Map<String, dynamic> s) => Student(
    id: (s['id'] ?? s['login'] ?? DateTime.now().microsecondsSinceEpoch)
        .toString(),
    name: s['name'] as String? ?? 'Без имени',
    group: (s['group'] as String?) ?? '',
    login: (s['login'] as String?) ?? '',
    password: (s['password'] as String?) ?? '',
    role: (s['role'] as String?) ?? 'student',
  );

  static Ticket _ticketFromJson(Map<String, dynamic> data) {
    final questions = (data['questions'] as List)
        .map((q) => Question(
      text: q['text'] as String,
      options: List<String>.from(q['options'] as List),
      correct: q['correct'] as int,
      hint: q['hint'] as String?,
    ))
        .toList();
    return Ticket(
      id: (data['id'] ??
          data['title'] ??
          'ticket_${DateTime.now().millisecondsSinceEpoch}')
          .toString(),
      title: data['title'] as String? ?? 'Билет',
      questions: questions,
    );
  }
}

class _RemoteFile {
  final String name;
  final String path;
  const _RemoteFile({required this.name, required this.path});
}

/// Результат попытки из файла до привязки к локальным студенту и билету.
class _PendingResult {
  final String studentLogin;
  final String studentName;
  final String ticketKey;
  final int score;
  final int total;
  final int? percent;
  final bool? passed;
  final DateTime date;
  final String id;
  const _PendingResult({
    required this.studentLogin,
    required this.studentName,
    required this.ticketKey,
    required this.score,
    required this.total,
    this.percent,
    this.passed,
    required this.date,
    required this.id,
  });
}

class SyncStats {
  final int tickets;
  final int students;
  final int results;
  final int codes;
  const SyncStats({
    required this.tickets,
    required this.students,
    this.results = 0,
    this.codes = 0,
  });
}