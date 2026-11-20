import 'package:flutter/material.dart';

import '../storage.dart';
import '../utils.dart';
import '../services/sync_settings.dart';
import '../services/public_sync_service.dart';
import 'settings_screen.dart';
import 'register_teacher_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();

  bool _isLogin = true;
  // Подрежим вкладки «Регистрация»: студент или преподаватель.
  String _regTab = 'student';
  bool _busy = false;
  bool _syncing = false;
  String? _error;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncFromDisk() async {
    final saved = await SyncSettings.getUrl();
    final initial = saved ?? PublicSyncService.encodedDefault;

    final url = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: initial);
        return AlertDialog(
          title: const Text('Источник данных'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Вставьте ссылку на публичную папку Яндекс Диска '
                    '(или код доступа):',
                style: TextStyle(fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autocorrect: false,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'https://disk.yandex.ru/d/...',
                ),
              ),
            ],
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
              child: const Text('Подключиться'),
            ),
          ],
        );
      },
    );

    if (url == null || url.isEmpty || !mounted) return;

    setState(() => _syncing = true);
    try {
      final stats = await PublicSyncService.syncFromPublicUrl(url);
      if (url != PublicSyncService.encodedDefault) {
        await SyncSettings.setUrl(url);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Обновлено: билетов — ${stats.tickets}, студентов — ${stats.students}',
          ),
          backgroundColor:
          (stats.tickets + stats.students) > 0 ? Colors.green : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка синхронизации: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final storage = AppStorage.instance;
    final err = await storage.register(
      name: _nameCtrl.text.trim(),
      group: _groupCtrl.text.trim(),
      login: _loginCtrl.text.trim(),
      password: _passCtrl.text,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  void _switch(bool login) {
    setState(() {
      _isLogin = login;
      _error = null;
    });
  }

  void _switchRegTab(String tab) {
    setState(() {
      _regTab = tab;
      _error = null;
    });
  }

  void _openTeacherRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterTeacherScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTeacherTab = !_isLogin && _regTab == 'teacher';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF2FF), Color(0xFFF4F5F7), Color(0xFFECFEFF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('🎓',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 10),
                    Text(
                      'Экзаменационное тестирование',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Проверка знаний по экзаменационным билетам',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),

                    // Переключатель Вход / Регистрация.
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EDF3),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          _SegButton(
                            text: 'Вход',
                            active: _isLogin,
                            onTap: () => _switch(true),
                          ),
                          _SegButton(
                            text: 'Регистрация',
                            active: !_isLogin,
                            onTap: () => _switch(false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Вкладки внутри «Регистрации»: студент / преподаватель.
                    // Видны только в режиме регистрации.
                    if (!_isLogin) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F4F8),
                          borderRadius: BorderRadius.circular(13),
                          border:
                          Border.all(color: const Color(0xFFE6E9EF)),
                        ),
                        child: Row(
                          children: [
                            _SegButton(
                              text: 'Регистрация студента',
                              active: _regTab == 'student',
                              onTap: () => _switchRegTab('student'),
                            ),
                            _SegButton(
                              text: 'Регистрация преподавателя',
                              active: _regTab == 'teacher',
                              onTap: () => _switchRegTab('teacher'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Содержимое вкладок.
                    if (isTeacherTab) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE6E9EF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Регистрация преподавателя по коду',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Введите код, выданный администратором. '
                                  'Код одноразовый: после успешной регистрации '
                                  'он помечается использованным и удаляется '
                                  'из публичной папки.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _openTeacherRegistration,
                        child: const Text('Зарегистрировать преподавателя'),
                      ),
                    ] else ...[
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_isLogin) ...[
                              _field(_nameCtrl, 'ФИО', 'Петров Пётр Петрович'),
                              const SizedBox(height: 12),
                              _field(_groupCtrl, 'Группа', 'ИС-21'),
                              const SizedBox(height: 12),
                            ],
                            _field(
                              _loginCtrl,
                              'Логин',
                              _isLogin ? 'student' : 'petrov',
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            _field(
                              _passCtrl,
                              'Пароль',
                              '••••',
                              obscure: true,
                              onSubmitted: (_) {
                                if (_isLogin || _regTab == 'student') {
                                  _submit();
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                              color: theme.colorScheme.error, fontSize: 13),
                        ),
                      ],

                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                            : Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
                      ),
                    ],

                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _syncing ? null : _syncFromDisk,
                      icon: _syncing
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.cloud_download_outlined),
                      label:
                      Text(_syncing ? 'Обновление...' : 'Обновить данные'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: const Color(0xFF1976D2),
                        side: const BorderSide(color: Color(0xFF1976D2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE6E9EF)),
                      ),
                      child: Text(
                        'Демо-доступ\n'
                            'Студент: student / 1234\n'
                            'Преподаватель: admin / admin',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),
                    const Divider(color: Color(0xFFE6E9EF)),
                    const SizedBox(height: 10),
                    Text(
                      'Версия: $kAppVersion\n'
                          'Дата релиза: $kReleaseDate\n',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
      TextEditingController ctrl,
      String label,
      String hint, {
        bool obscure = false,
        TextInputAction textInputAction = TextInputAction.next,
        ValueChanged<String>? onSubmitted,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569)),
          ),
        ),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          autocorrect: false,
          decoration: InputDecoration(hintText: hint),
          validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Заполните поле' : null,
        ),
      ],
    );
  }
}

class _SegButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _SegButton(
      {required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
              const BoxShadow(
                  color: Color(0x1F0F172A),
                  blurRadius: 4,
                  offset: Offset(0, 1))
            ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}
