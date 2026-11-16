/// Проходной балл, %
const int kPassPercent = 60;

/// Время на билет, секунды
const int kTimeLimit = 15 * 60;

class Question {
  final String text;
  final List<String> options;
  final int correct;
  final String? hint;

  const Question({
    required this.text,
    required this.options,
    required this.correct,
    this.hint,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'options': options,
    'correct': correct,
    if (hint != null && hint!.isNotEmpty) 'hint': hint,
  };

  factory Question.fromJson(Map<String, dynamic> j) => Question(
    text: j['text'] as String,
    options: List<String>.from(j['options'] as List),
    correct: j['correct'] as int,
    hint: j['hint'] as String?,
  );
}

class Ticket {
  final String id;
  final String title;
  final List<Question> questions;

  const Ticket({required this.id, required this.title, required this.questions});

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
    id: j['id'] as String,
    title: j['title'] as String,
    questions: (j['questions'] as List)
        .map((e) => Question.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

class Student {
  final String id;
  final String login;
  final String password;
  final String name;
  final String group;
  final String role;
  final bool isPro; // <--- НОВОЕ ПОЛЕ

  const Student({
    required this.id,
    required this.login,
    required this.password,
    required this.name,
    required this.group,
    required this.role,
    this.isPro = false,
  });

  bool get isTeacher => role == 'teacher';

  Map<String, dynamic> toJson() => {
    'id': id,
    'login': login,
    'password': password,
    'name': name,
    'group': group,
    'role': role,
    'isPro': isPro,
  };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
    id: j['id'] as String,
    login: j['login'] as String,
    password: j['password'] as String,
    name: j['name'] as String,
    group: j['group'] as String,
    role: j['role'] as String,
    isPro: j['isPro'] as bool? ?? false,
  );
}

class ExamResult {
  final String id;
  final String studentId;
  final String ticketId;
  final int score;
  final int total;
  final int percent;
  final bool passed;
  final DateTime date;
  final List<int?> answers;

  const ExamResult({
    required this.id,
    required this.studentId,
    required this.ticketId,
    required this.score,
    required this.total,
    required this.percent,
    required this.passed,
    required this.date,
    required this.answers,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'ticketId': ticketId,
    'score': score,
    'total': total,
    'percent': percent,
    'passed': passed,
    'date': date.toIso8601String(),
    'answers': answers,
  };

  factory ExamResult.fromJson(Map<String, dynamic> j) => ExamResult(
    id: j['id'] as String,
    studentId: j['studentId'] as String,
    ticketId: j['ticketId'] as String,
    score: j['score'] as int,
    total: j['total'] as int,
    percent: j['percent'] as int,
    passed: j['passed'] as bool,
    date: DateTime.parse(j['date'] as String),
    answers: (j['answers'] as List).map((e) => e as int?).toList(),
  );
}

class AppDatabase {
  List<Student> students;
  List<Ticket> tickets;
  List<ExamResult> results;

  AppDatabase({
    required this.students,
    required this.tickets,
    required this.results,
  });

  Map<String, dynamic> toJson() => {
    'students': students.map((s) => s.toJson()).toList(),
    'tickets': tickets.map((t) => t.toJson()).toList(),
    'results': results.map((r) => r.toJson()).toList(),
  };

  factory AppDatabase.fromJson(Map<String, dynamic> j) => AppDatabase(
    students: (j['students'] as List)
        .map((e) => Student.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    tickets: (j['tickets'] as List)
        .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    results: (j['results'] as List)
        .map((e) => ExamResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  factory AppDatabase.seed() => AppDatabase(
    students: [
      const Student(
        id: 'teacher',
        login: 'admin',
        password: 'admin',
        name: 'Преподаватель',
        group: '—',
        role: 'teacher',
      ),
      const Student(
        id: 's-demo',
        login: 'student',
        password: '1234',
        name: 'Иванов Иван Иванович',
        group: 'ИС-21',
        role: 'student',
      ),
    ],
    tickets: [
      const Ticket(id: 't1', title: 'Билет 1. Основы информатики', questions: [
        Question(text: 'Сколько бит содержится в одном байте?', options: ['4', '8', '16', '1024'], correct: 1, hint: '1 байт = 8 бит.'),
        Question(text: 'Какое устройство является устройством ввода?', options: ['Монитор', 'Принтер', 'Клавиатура', 'Колонки'], correct: 2),
        Question(text: 'Что такое файл?', options: ['Программа для работы с текстом', 'Поименованная область на носителе', 'Устройство хранения', 'Раздел оперативной памяти'], correct: 1),
      ]),
    ],
    results: [],
  );
}