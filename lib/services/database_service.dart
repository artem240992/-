import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models.dart';

/// Локальная SQLite-база приложения.
/// Таблицы: students, tickets, results.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  DatabaseService._init();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'exam_app.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE students (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            "group" TEXT,
            login TEXT,
            password TEXT,
            role TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE tickets (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            questions_json TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE results (
            id TEXT PRIMARY KEY,
            student_id TEXT NOT NULL,
            ticket_id TEXT NOT NULL,
            score INTEGER,
            total INTEGER,
            percent INTEGER,
            passed INTEGER,
            date TEXT,
            answers_json TEXT
          )
        ''');
      },
    );
  }

  // ---------- STUDENTS ----------

  /// Записывает список студентов, обновляя существующих по id.
  Future<void> upsertStudents(List<Student> students) async {
    final db = await database;
    final batch = db.batch();
    for (final s in students) {
      batch.insert(
        'students',
        {
          'id': s.id,
          'name': s.name,
          'group': s.group,
          'login': s.login,
          'password': s.password,
          'role': s.role,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Student>> loadStudents() async {
    final db = await database;
    final rows = await db.query('students');
    return rows
        .map((r) => Student(
              id: r['id'] as String,
              name: r['name'] as String,
              group: (r['group'] as String?) ?? '',
              login: (r['login'] as String?) ?? '',
              password: (r['password'] as String?) ?? '',
              role: (r['role'] as String?) ?? 'student',
            ))
        .toList();
  }

  // ---------- TICKETS ----------

  Future<void> saveTicket(Ticket t) async {
    final db = await database;
    await db.insert(
      'tickets',
      {
        'id': t.id,
        'title': t.title,
        'questions_json': jsonEncode(t.questions
            .map((q) => {
                  'text': q.text,
                  'options': q.options,
                  'correct': q.correct,
                  'hint': q.hint,
                })
            .toList()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Ticket>> loadTickets() async {
    final db = await database;
    final rows = await db.query('tickets');
    return rows.map((r) {
      final qs = (jsonDecode(r['questions_json'] as String) as List)
          .map((m) => Question(
                text: m['text'],
                options: List<String>.from(m['options']),
                correct: m['correct'],
                hint: m['hint'],
              ))
          .toList();
      return Ticket(
        id: r['id'] as String,
        title: r['title'] as String,
        questions: qs,
      );
    }).toList();
  }
}
