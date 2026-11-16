import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../storage.dart';
import '../utils.dart';
import 'ticket_editor.dart';
import 'premium_screen.dart'; // <-- ДОБАВЛЕН ИМПОРТ

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  int _index = 0;

  static const _titles = ['Студенты', 'Билеты', 'Результаты', 'Профиль'];

  // ==================== СТУДЕНТЫ ====================
  Future<void> _addStudent() async {
    final nameCtrl = TextEditingController();
    final groupCtrl = TextEditingController();
    final loginCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Новый студент'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'ФИО'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Введите ФИО' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: groupCtrl,
                    decoration: const InputDecoration(labelText: 'Группа'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Введите группу' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: loginCtrl,
                    decoration: const InputDecoration(labelText: 'Логин'),
                    autocorrect: false,
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Введите логин' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passCtrl,
                    decoration: const InputDecoration(labelText: 'Пароль'),
                    validator: (v) =>
                    (v == null || v.length < 4) ? 'Минимум 4 символа' : null,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!,
                        style: const TextStyle(
                            color: Color(0xFFDC2626), fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final err = await AppStorage.instance.addStudent(
                  name: nameCtrl.text.trim(),
                  group: groupCtrl.text.trim(),
                  login: loginCtrl.text.trim(),
                  password: passCtrl.text,
                );
                if (err != null) {
                  setDialogState(() => error = err);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      nameCtrl.dispose();
      groupCtrl.dispose();
      loginCtrl.dispose();
      passCtrl.dispose();
    });

    if (mounted) setState(() {});
  }

  Future<void> _deleteStudent(Student s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить студента?'),
        content: Text('«${s.name}» и все его результаты будут удалены.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить',
                style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AppStorage.instance.deleteStudent(s.id);
      if (mounted) setState(() {});
    }
  }

  // ==================== ИМПОРТ СТУДЕНТОВ ====================
  Future<void> _importStudentsJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final content = utf8.decode(result.files.single.bytes!);

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );
        }

        final error = await AppStorage.instance.importStudentsFromJson(content);

        if (mounted) Navigator.pop(context); // Закрываем индикатор

        if (error == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Студенты успешно загружены!'),
                  backgroundColor: Colors.green),
            );
            setState(() {}); // Обновляем список
          }
        } else {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Ошибка импорта'),
                content: Text(error),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Ок')),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Не удалось открыть файл: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showStudentJsonTemplate() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Формат JSON (Студенты)'),
        content: const SingleChildScrollView(
          child: Text(
            '[\n'
                '  {\n'
                '    "name": "Иванов Иван",\n'
                '    "group": "ИС-21",\n'
                '    "login": "ivanov",\n'
                '    "password": "1234"\n'
                '  }\n'
                ']',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Понятно')),
        ],
      ),
    );
  }

  // ==================== БИЛЕТЫ ====================
  Future<void> _createTicket() async {
    final ctrl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый билет'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название билета',
            hintText: 'Билет 7. Тема',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isEmpty) return;
              Navigator.pop(ctx, t);
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 300), () => ctrl.dispose());

    if (title == null || !mounted) return;

    final ticket = await AppStorage.instance.createTicket(title);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TicketEditorScreen(ticketId: ticket.id),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _deleteTicket(Ticket t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить билет?'),
        content:
        Text('«${t.title}» и все связанные результаты будут удалены.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить',
                style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AppStorage.instance.deleteTicket(t.id);
    if (mounted) setState(() {});
  }

  Widget _buildTicketsTab() {
    final tickets = AppStorage.instance.db.tickets;

    if (tickets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📚', style: TextStyle(fontSize: 40)),
              SizedBox(height: 10),
              Text(
                'Билетов пока нет.\nНажмите «+ Билет», чтобы создать первый.',
                textAlign: TextAlign.center,
                style:
                TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      itemCount: tickets.length,
      itemBuilder: (context, i) {
        final t = tickets[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TicketEditorScreen(ticketId: t.id),
                ));
                if (mounted) setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6E9EF)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                height: 1.3),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.questions.isEmpty
                                ? 'Нет вопросов'
                                : '${t.questions.length} вопросов',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.questions.isEmpty
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFDC2626), size: 20),
                      onPressed: () => _deleteTicket(t),
                      tooltip: 'Удалить',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _importJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final content = utf8.decode(result.files.single.bytes!);

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );
        }

        final error = await AppStorage.instance.importTicketsFromJson(content);

        if (mounted) Navigator.pop(context);

        if (error == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Билеты успешно загружены!'),
                  backgroundColor: Colors.green),
            );
          }
        } else {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Ошибка импорта'),
                content: Text(error),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Ок')),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Не удалось открыть файл: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showJsonTemplate() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Формат JSON (Билеты)'),
        content: const SingleChildScrollView(
          child: Text(
            '[\n'
                '  {\n'
                '    "title": "Билет 7. Тема",\n'
                '    "questions": [\n'
                '      {\n'
                '        "text": "Текст вопроса?",\n'
                '        "options": ["А", "Б", "В", "Г"],\n'
                '        "correct": 0,\n'
                '        "hint": "Необязательная подсказка"\n'
                '      }\n'
                '    ]\n'
                '  }\n'
                ']',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Понятно')),
        ],
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final user = AppStorage.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_index]),
            const Text(
              'Панель преподавателя',
              style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          if (_index == 0) ...[
            IconButton(
              icon: const Icon(Icons.help_outline, color: Color(0xFF64748B)),
              onPressed: _showStudentJsonTemplate,
              tooltip: 'Формат JSON',
            ),
            IconButton(
              icon: const Icon(Icons.upload_file, color: Color(0xFF4F46E5)),
              onPressed: _importStudentsJson,
              tooltip: 'Загрузить из JSON',
            ),
            const SizedBox(width: 8),
          ],
          if (_index == 1) ...[
            IconButton(
              icon: const Icon(Icons.help_outline, color: Color(0xFF64748B)),
              onPressed: _showJsonTemplate,
              tooltip: 'Формат JSON',
            ),
            IconButton(
              icon: const Icon(Icons.upload_file, color: Color(0xFF4F46E5)),
              onPressed: _importJson,
              tooltip: 'Загрузить из JSON',
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      floatingActionButton: switch (_index) {
        0 => FloatingActionButton.extended(
          onPressed: _addStudent,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Студент'),
        ),
        1 => FloatingActionButton.extended(
          onPressed: _createTicket,
          icon: const Icon(Icons.add),
          label: const Text('Билет'),
        ),
        _ => null,
      },
      body: IndexedStack(
        index: _index,
        children: [
          _StudentsTab(onDelete: _deleteStudent),
          _buildTicketsTab(),
          const _TeacherResultsTab(),
          _TeacherProfileTab(user: user),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Студенты'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Билеты'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Результаты'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Профиль'),
        ],
      ),
    );
  }
}

// ==================== ВКЛАДКА СТУДЕНТОВ ====================
class _StudentsTab extends StatelessWidget {
  final void Function(Student) onDelete;

  const _StudentsTab({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final storage = AppStorage.instance;
    final students = storage.db.students.where((s) => !s.isTeacher).toList();
    final ticketsCount = storage.db.tickets.length;

    if (students.isEmpty) {
      return const Center(
        child: Text('Студентов пока нет',
            style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      itemCount: students.length,
      itemBuilder: (context, i) {
        final s = students[i];
        final results = storage.resultsFor(s.id);
        final best = storage.bestResultsFor(s.id);
        final passed = best.values.where((r) => r.passed).length;
        final avg = results.isEmpty
            ? 0
            : (results.map((r) => r.percent).reduce((a, b) => a + b) /
            results.length)
            .round();

        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6E9EF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials(s.name),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${s.group} · ${s.login}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => onDelete(s),
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFDC2626), size: 20),
                      tooltip: 'Удалить',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MiniStat(label: 'Попыток', value: '${results.length}'),
                    _MiniStat(label: 'Сдано', value: '$passed/$ticketsCount'),
                    _MiniStat(label: 'Средний', value: '$avg%'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          Text(label,
              style:
              const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

// ==================== ВКЛАДКА РЕЗУЛЬТАТОВ ====================
class _TeacherResultsTab extends StatelessWidget {
  const _TeacherResultsTab();

  @override
  Widget build(BuildContext context) {
    final storage = AppStorage.instance;
    final results = [...storage.db.results]
      ..sort((a, b) => b.date.compareTo(a.date));

    if (results.isEmpty) {
      return const Center(
        child: Text('Попыток пока не было',
            style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final r = results[i];
        final student = storage.db.students.firstWhere(
              (s) => s.id == r.studentId,
          orElse: () => const Student(
            id: '',
            login: '',
            password: '',
            name: '—',
            group: '—',
            role: 'student',
          ),
        );
        final ticket = storage.ticketById(r.ticketId);

        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6E9EF)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: r.passed
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${r.percent}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: r.passed
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${ticket?.title ?? '—'} · ${r.score}/${r.total}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      Text(
                        fmtDate(r.date),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== ПРОФИЛЬ ====================
class _TeacherProfileTab extends StatelessWidget {
  final Student user;

  const _TeacherProfileTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final storage = AppStorage.instance;
    final students = storage.db.students.where((s) => !s.isTeacher).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6E9EF)),
          ),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials(user.name),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(user.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  if (user.isPro) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: Colors.amber, size: 20),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              const Text('Преподаватель',
                  style:
                  TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _MiniStat(label: 'Студентов', value: '$students'),
            _MiniStat(label: 'Билетов', value: '${storage.db.tickets.length}'),
            _MiniStat(label: 'Попыток', value: '${storage.db.results.length}'),
          ],
        ),

        if (!user.isPro) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Снять лимит (Premium)'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ] else ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified, color: Colors.green),
                SizedBox(width: 8),
                Text('Лимит снят (Premium)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: storage.logout,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Выйти из аккаунта'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: const Color(0xFFDC2626),
            side: const BorderSide(color: Color(0xFFFECACA)),
            backgroundColor: const Color(0xFFFEF2F2),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}