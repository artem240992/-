import 'package:flutter/material.dart';
import '../services/sync_settings.dart';
import '../storage.dart'; // НОВОЕ: доступ к текущему пользователю
import 'teacher_codes_screen.dart'; // НОВОЕ: экран кодов преподавателей

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final url = await SyncSettings.getUrl();
    _urlCtrl.text = url ?? '';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ссылку на папку')),
      );
      return;
    }
    await SyncSettings.saveUrl(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Настройка сохранена'), backgroundColor: Colors.green),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Коды преподавателей видит только преподаватель/admin.
    final isTeacher = AppStorage.instance.currentUser?.isTeacher ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Папка данных на Яндекс.Диске',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Опубликованная (общедоступная) ссылка на папку, где лежат файлы '
                'билетов и студентов в формате JSON. Студенты смогут обновлять '
                'данные по этой ссылке без авторизации.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _urlCtrl,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'https://cloud.mail.ru/public/xxxxxxxx/yyyy',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить'),
          ),

          // НОВОЕ: управление кодами регистрации преподавателей.
          // Видно только преподавателям и админу.
          if (isTeacher) ...[
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFE6E9EF)),
            const SizedBox(height: 8),
            const Text(
              'Преподаватели',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Коды регистрации'),
                subtitle: const Text(
                  'Создание одноразовых кодов для регистрации '
                      'новых преподавателей',
                  style: TextStyle(fontSize: 12.5),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TeacherCodesScreen()),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}