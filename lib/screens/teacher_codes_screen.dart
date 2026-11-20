import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../storage.dart';
import '../utils.dart';
import '../services/public_sync_service.dart';
import '../services/token_storage.dart';
import 'yandex_auth_screen.dart';

/// Экран администратора: генерация и управление кодами регистрации
/// преподавателей. Коды выгружаются на Диск в подпапку «code» файлами
/// вида TCH_XXXX_XXXX.ecod (зашифрованный JSON) и подхватываются
/// остальными устройствами при синхронизации. Авторизация — та же,
/// что и при выгрузке результатов (YandexAuthScreen + TokenStorage).
class TeacherCodesScreen extends StatefulWidget {
  const TeacherCodesScreen({super.key});

  @override
  State<TeacherCodesScreen> createState() => _TeacherCodesScreenState();
}

class _TeacherCodesScreenState extends State<TeacherCodesScreen> {
  bool _busy = false;
  bool _hasToken = false;
  String? _justGenerated; // свежесозданный код подсвечиваем

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final has = await TokenStorage.hasToken();
    if (!mounted) return;
    setState(() => _hasToken = has);
  }

  /// Гарантирует наличие токена: при отсутствии открывает экран
  /// авторизации Яндекса — ровно как при выгрузке результатов.
  Future<bool> _ensureAuthorized() async {
    if (await TokenStorage.hasToken()) return true;
    if (!mounted) return false;
    final authenticated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const YandexAuthScreen()),
    );
    final ok = authenticated == true;
    setState(() => _hasToken = ok);
    return ok;
  }

  Future<void> _generate() async {
    if (!await _ensureAuthorized()) return;

    setState(() => _busy = true);
    final code = await AppStorage.instance.generateTeacherCode();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _justGenerated = code;
    });

    // Выгрузка на Диск в подпапку «code».
    String? uploadError;
    try {
      await PublicSyncService.publishTeacherCode(
        AppStorage.instance.teacherCodes.firstWhere((t) => t.code == code),
      );
    } catch (e) {
      uploadError = '$e';
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(uploadError == null
            ? 'Код создан и выгружен на Диск'
            : 'Код создан локально, но на Диск не выгружен: $uploadError'),
        backgroundColor: uploadError == null ? Colors.green : Colors.orange,
      ),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Код создан'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Передайте этот код преподавателю. Код одноразовый:',
                style: TextStyle(fontSize: 13.5, height: 1.4)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Код скопирован')),
              );
            },
            child: const Text('Копировать'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCode(TeacherCode c) async {
    await AppStorage.instance.deleteTeacherCode(c.code);
    // Тихая попытка удалить файл и с Диска (если токен есть).
    await PublicSyncService.deleteTeacherCodeRemote(c.code);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Коды преподавателей'),
      ),
      body: AnimatedBuilder(
        animation: AppStorage.instance,
        builder: (context, _) {
          final codes = AppStorage.instance.teacherCodes;
          if (codes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎟️', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      'Кодов пока нет.\nПри создании код будет выгружен '
                          'на Диск в папку «code».',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: codes.length,
            itemBuilder: (context, i) {
              final c = codes[i];
              final fresh = c.code == _justGenerated;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: fresh ? const Color(0xFFEEF2FF) : null,
                child: ListTile(
                  title: Text(
                    c.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  subtitle: Text(
                    c.used
                        ? 'Использован: ${c.usedBy}, ${fmtDate(c.createdAt)}'
                        : 'Создан: ${fmtDate(c.createdAt)}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.used)
                        const Chip(
                          label: Text('Использован',
                              style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                        )
                      else ...[
                        IconButton(
                          tooltip: 'Копировать',
                          icon: const Icon(Icons.copy_outlined, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: c.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Код скопирован')),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Удалить',
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Color(0xFFEF4444)),
                          onPressed: () => _deleteCode(c),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _generate,
        icon: _busy
            ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: const Text('Создать код'),
      ),
    );
  }
}
