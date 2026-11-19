import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'utils.dart';

class AppStorage extends ChangeNotifier {
  AppStorage._();
  static final AppStorage instance = AppStorage._();

  static const _dbKey = 'exam_app_db_v1';
  static const _sessionKey = 'exam_app_session_v1';

  late AppDatabase db;
  Student? currentUser;

  final ValueNotifier<Student?> currentUserNotifier = ValueNotifier(null);

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    final raw = _prefs!.getString(_dbKey);
    if (raw != null) {
      try {
        db = AppDatabase.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        db = AppDatabase.seed();
        await _persist();
      }
    } else {
      db = AppDatabase.seed();
      await _persist();
    }

    final sessionId = _prefs!.getString(_sessionKey);
    if (sessionId != null) {
      currentUser = _findStudent(sessionId);
      currentUserNotifier.value = currentUser;
    }
  }

  Future<void> _persist() async {
    await _prefs?.setString(_dbKey, jsonEncode(db.toJson()));
  }

  Student? _findStudent(String id) {
    for (final s in db.students) {
      if (s.id == id) return s;
    }
    return null;
  }

  // Активация премиум-доступа
  Future<void> activatePro(String studentId) async {
    final index = db.students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      final old = db.students[index];
      db.students[index] = Student(
        id: old.id,
        login: old.login,
        password: old.password,
        name: old.name,
        group: old.group,
        role: old.role,
        isPro: true, // Снимаем ограничения
      );

      if (currentUser?.id == studentId) {
        currentUser = db.students[index];
        currentUserNotifier.value = currentUser;
      }

      await _persist();
      notifyListeners();
    }
  }

  Future<String?> login(String login, String password) async {
    for (final s in db.students) {
      if (s.login.toLowerCase() == login.toLowerCase() &&
          s.password == password) {
        currentUser = s;
        await _prefs?.setString(_sessionKey, s.id);
        currentUserNotifier.value = s;
        notifyListeners();
        return null;
      }
    }
    return 'Неверный логин или пароль';
  }

  Future<String?> register({
    required String name,
    required String group,
    required String login,
    required String password,
  }) async {
    final hasPro = db.students.any((s) => s.isPro);
    final studentCount = db.students.where((s) => !s.isTeacher).length;

    if (password.length < 4) return 'Пароль должен быть не короче 4 символов';
    if (db.students.any((s) => s.login.toLowerCase() == login.toLowerCase())) {
      return 'Такой логин уже занят';
    }

    final s = Student(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      login: login,
      password: password,
      name: name,
      group: group,
      role: 'student',
    );
    db.students.add(s);
    await _persist();
    currentUser = s;
    await _prefs?.setString(_sessionKey, s.id);
    currentUserNotifier.value = s;
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    currentUser = null;
    currentUserNotifier.value = null;
    await _prefs?.remove(_sessionKey);
    notifyListeners();
  }

  Future<void> addResult(ExamResult r) async {
    db.results.add(r);
    await _persist();
    notifyListeners();
  }

  List<ExamResult> resultsFor(String studentId) =>
      db.results.where((r) => r.studentId == studentId).toList();

  Map<String, ExamResult> bestResultsFor(String studentId) {
    final best = <String, ExamResult>{};
    for (final r in resultsFor(studentId)) {
      final cur = best[r.ticketId];
      if (cur == null || r.percent > cur.percent) best[r.ticketId] = r;
    }
    return best;
  }

  Ticket? ticketById(String id) {
    for (final t in db.tickets) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<String?> addStudent({
    required String name,
    required String group,
    required String login,
    required String password,
  }) async {
    final hasPro = db.students.any((s) => s.isPro);
    final studentCount = db.students.where((s) => !s.isTeacher).length;

    if (db.students.any((s) => s.login.toLowerCase() == login.toLowerCase())) {
      return 'Такой логин уже занят';
    }

    if (password.length < 4) return 'Пароль должен быть не короче 4 символов';

    db.students.add(Student(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      login: login,
      password: password,
      name: name,
      group: group,
      role: 'student',
    ));
    await _persist();
    notifyListeners();
    return null;
  }

  Future<void> deleteStudent(String id) async {
    db.students.removeWhere((s) => s.id == id);
    db.results.removeWhere((r) => r.studentId == id);
    await _persist();
    notifyListeners();
  }

  Future<Ticket> createTicket(String title) async {
    final t = Ticket(
      id: 't${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      questions: const [],
    );
    db.tickets.add(t);
    await _persist();
    notifyListeners();
    return t;
  }

  Future<void> updateTicket(Ticket ticket) async {
    final idx = db.tickets.indexWhere((t) => t.id == ticket.id);
    if (idx == -1) {
      db.tickets.add(ticket);
    } else {
      db.tickets[idx] = ticket;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteTicket(String id) async {
    db.tickets.removeWhere((t) => t.id == id);
    db.results.removeWhere((r) => r.ticketId == id);
    await _persist();
    notifyListeners();
  }

  Future<String?> importTicketsFromJson(String jsonString) async {
    try {
      final dynamic parsed = jsonDecode(jsonString);
      if (parsed is! List) return 'Ожидается массив билетов [...]';

      int importedCount = 0;

      for (var item in parsed) {
        if (item is! Map) continue;

        final title = item['title'] as String? ?? 'Без названия';
        final questionsList = item['questions'] as List<dynamic>? ?? [];

        final questions = questionsList.map((q) {
          return Question(
            text: q['text'] as String,
            options: List<String>.from(q['options'] as List),
            correct: q['correct'] as int,
            hint: q['hint'] as String?,
          );
        }).toList();

        final newTicket = Ticket(
          id: 'import_${DateTime.now().microsecondsSinceEpoch}_$importedCount',
          title: title,
          questions: questions,
        );

        db.tickets.add(newTicket);
        importedCount++;
      }

      if (importedCount == 0) return 'В файле не найдено билетов';

      await _persist();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Ошибка парсинга JSON: $e';
    }
  }

  Future<String?> importStudentsFromJson(String jsonString) async {
    try {
      final dynamic parsed = jsonDecode(jsonString);
      if (parsed is! List) return 'Ожидается массив студентов [...]';

      int importedCount = 0;
      int skippedCount = 0;

      for (var item in parsed) {
        if (item is! Map) continue;

        final login = item['login'] as String?;
        final password = item['password'] as String?;
        final name = item['name'] as String?;
        final group = item['group'] as String?;

        if (login == null ||
            password == null ||
            name == null ||
            group == null) {
          skippedCount++;
          continue;
        }

        if (db.students
            .any((s) => s.login.toLowerCase() == login.toLowerCase())) {
          skippedCount++;
          continue;
        }

        db.students.add(Student(
          id: '${DateTime.now().microsecondsSinceEpoch}_$importedCount',
          login: login,
          password: password,
          name: name,
          group: group,
          role: 'student',
        ));
        importedCount++;
      }

      if (importedCount == 0 && skippedCount > 0) {
        return 'Не удалось импортировать ни одного студента. Возможно, логины уже заняты или формат неверный.';
      }

      if (importedCount == 0) return 'В файле не найдено студентов';

      await _persist();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Ошибка парсинга JSON: $e';
    }
  }
}
