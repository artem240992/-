import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'utils.dart';

/// Регистрационный код преподавателя: одноразовый, выдаётся администратором.
class TeacherCode {
  final String code;
  final bool used;
  final String usedBy;
  final DateTime createdAt;

  const TeacherCode({
    required this.code,
    this.used = false,
    this.usedBy = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'used': used,
    'usedBy': usedBy,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TeacherCode.fromJson(Map<String, dynamic> j) => TeacherCode(
    code: (j['code'] ?? '').toString(),
    used: j['used'] == true,
    usedBy: (j['usedBy'] ?? '').toString(),
    createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
  );
}

class AppStorage extends ChangeNotifier {
  AppStorage._();
  static final AppStorage instance = AppStorage._();

  static const _dbKey = 'exam_app_db_v1';
  static const _sessionKey = 'exam_app_session_v1';
  static const _codesKey = 'exam_app_teacher_codes_v1';

  /// Ключ шифрования регистрационных кодов (по аналогии со ссылкой на Диск).
  static const _codeXorKey = 'exam2026';

  late AppDatabase db;
  Student? currentUser;

  final ValueNotifier<Student?> currentUserNotifier = ValueNotifier(null);

  SharedPreferences? _prefs;

  /// Регистрационные коды преподавателей. Хранятся зашифрованными.
  final List<TeacherCode> _teacherCodes = [];

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

    await _loadCodes();
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

  // ==================== РЕГИСТРАЦИОННЫЕ КОДЫ ПРЕПОДАВАТЕЛЕЙ ====================

  /// Шифрует строку (XOR + Base64) — так же, как ссылка на Диск.
  /// Публичный метод: им пользуется и PublicSyncService для файлов .ecod.
  static String encodeCode(String input) {
    final bytes = utf8.encode(input);
    final out = <int>[
      for (var i = 0; i < bytes.length; i++)
        bytes[i] ^ _codeXorKey.codeUnitAt(i % _codeXorKey.length),
    ];
    return base64Encode(out);
  }

  /// Расшифровывает строку. Возвращает пустую строку при сбое.
  static String decodeCode(String input) {
    try {
      final raw = base64Decode(input.replaceAll('\n', ' ').trim());
      return utf8.decode([
        for (var i = 0; i < raw.length; i++)
          raw[i] ^ _codeXorKey.codeUnitAt(i % _codeXorKey.length),
      ]);
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadCodes() async {
    _teacherCodes.clear();
    final raw = _prefs?.getString(_codesKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        try {
          final obj = jsonDecode(decodeCode(e as String));
          if (obj is Map<String, dynamic>) {
            _teacherCodes.add(TeacherCode.fromJson(obj));
          }
        } catch (_) {
          // повреждённый код пропускаем, остальные остаются рабочими
        }
      }
    } catch (_) {}
  }

  Future<void> _persistCodes() async {
    final encrypted = [
      for (final c in _teacherCodes) encodeCode(jsonEncode(c.toJson())),
    ];
    await _prefs?.setString(_codesKey, jsonEncode(encrypted));
  }

  /// Генерирует новый одноразовый код преподавателя и возвращает его.
  /// Вызывается из админского экрана; код показывается один раз,
  /// дальше его можно только скопировать из списка.
  Future<String> generateTeacherCode() async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // без 0/O и 1/I
    final rnd = Random.secure();
    String group() =>
        List.generate(4, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
    final code = 'TCH-${group()}-${group()}';
    _teacherCodes.add(TeacherCode(code: code, createdAt: DateTime.now()));
    await _persistCodes();
    notifyListeners();
    return code;
  }

  /// Список кодов для админского экрана (в расшифрованном виде).
  List<TeacherCode> get teacherCodes => List.unmodifiable(_teacherCodes);

  /// Проверяет код без расходования: существует и ещё не использован.
  bool isTeacherCodeValid(String input) {
    final c = input.trim().toUpperCase();
    return _teacherCodes.any((t) => t.code == c && !t.used);
  }

  /// Помечает код использованным за логином преподавателя.
  /// Возвращает false, если код не найден или уже израсходован.
  Future<bool> consumeTeacherCode(String input, String login) async {
    final c = input.trim().toUpperCase();
    final idx = _teacherCodes.indexWhere((t) => t.code == c && !t.used);
    if (idx == -1) return false;
    _teacherCodes[idx] = TeacherCode(
      code: c,
      used: true,
      usedBy: login,
      createdAt: _teacherCodes[idx].createdAt,
    );
    await _persistCodes();
    notifyListeners();
    return true;
  }

  /// Удаляет неиспользованный код. Использованные не удаляются —
  /// остаются в списке как история.
  Future<void> deleteTeacherCode(String code) async {
    _teacherCodes.removeWhere((t) => t.code == code && !t.used);
    await _persistCodes();
    notifyListeners();
  }

  /// Добавляет код, пришедший при синхронизации с Диска (.ecod).
  /// Локально уже израсходованный код не переводится обратно в «свободный»:
  /// применяется только вход нового кода или переход в «использован».
  Future<void> mergeRemoteTeacherCode(TeacherCode c) async {
    final idx = _teacherCodes.indexWhere((t) => t.code == c.code);
    if (idx == -1) {
      _teacherCodes.add(c);
      await _persistCodes();
      notifyListeners();
    } else if (c.used && !_teacherCodes[idx].used) {
      _teacherCodes[idx] = c;
      await _persistCodes();
      notifyListeners();
    }
  }

  // ==================== АККАУНТЫ ====================

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

  /// Регистрация студента. Если учётка с таким логином уже существует
  /// (выдана преподавателем через students.json или создана ранее),
  /// а пароль совпадает — просто выполняем вход: человек доказал,
  /// что это его аккаунт. При чужом пароле — понятное сообщение.
  Future<String?> register({
    required String name,
    required String group,
    required String login,
    required String password,
  }) async {
    if (password.length < 4) return 'Пароль должен быть не короче 4 символов';

    final l = login.trim().toLowerCase();
    final existing = db.students
        .where((s) => s.login.toLowerCase() == l)
        .toList();

    if (existing.isNotEmpty) {
      final s = existing.first;
      if (s.password == password) {
        currentUser = s;
        await _prefs?.setString(_sessionKey, s.id);
        currentUserNotifier.value = s;
        notifyListeners();
        return null;
      }
      return 'Такой логин уже занят. Если это ваш логин — войдите '
          'на вкладке «Вход» с выданным паролем, либо выберите другой';
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

  /// Регистрирует преподавателя. Возвращает false, если логин занят
  /// или пароль короче 4 символов. Сам код проверяется и расходуется
  /// на экране регистрации — до и после вызова этого метода.
  Future<bool> registerTeacher({
    required String name,
    required String login,
    required String password,
  }) async {
    final l = login.trim().toLowerCase();
    if (l.isEmpty || password.length < 4) return false;
    if (db.students.any((s) => s.login.toLowerCase() == l || s.id == l)) {
      return false;
    }
    db.students.add(Student(
      id: 'teacher_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      group: '',
      login: l,
      password: password,
      role: 'teacher',
    ));
    await _persist();
    notifyListeners();
    return true;
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

  /// Дописывает студентов из синхронизации во внутреннюю базу.
  /// Совпадение ищется по id, а при непустом логине — ещё и по логину.
  Future<void> applySyncStudents(List<Student> incoming) async {
    var changed = false;
    for (final s in incoming) {
      final idx = db.students.indexWhere((e) =>
      e.id == s.id ||
          (s.login.isNotEmpty &&
              e.login.toLowerCase() == s.login.toLowerCase()));
      if (idx == -1) {
        db.students.add(s);
        changed = true;
      } else if (s.login.isNotEmpty) {
        db.students[idx] = s;
        changed = true;
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  /// Дописывает билеты из синхронизации во внутреннюю базу.
  Future<void> applySyncTickets(List<Ticket> incoming) async {
    var changed = false;
    for (final t in incoming) {
      final idx = db.tickets.indexWhere((e) => e.id == t.id);
      if (idx == -1) {
        db.tickets.add(t);
        changed = true;
      } else {
        db.tickets[idx] = t;
        changed = true;
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  /// Дописывает результаты из синхронизации. Дубликаты отсеиваются:
  /// тот же студент + тот же билет + то же время попытки уже есть — пропускаем.
  Future<void> applySyncResults(List<ExamResult> incoming) async {
    var changed = false;
    for (final r in incoming) {
      final exists = db.results.any((e) =>
      e.studentId == r.studentId &&
          e.ticketId == r.ticketId &&
          e.date.millisecondsSinceEpoch == r.date.millisecondsSinceEpoch);
      if (exists) continue;
      db.results.add(r);
      changed = true;
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
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
