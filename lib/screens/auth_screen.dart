import 'package:flutter/material.dart';

import '../storage.dart';
import '../utils.dart'; // <-- ДОБАВЛЕН ИМПОРТ

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
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final storage = AppStorage.instance;
    final err = _isLogin
        ? await storage.login(_loginCtrl.text.trim(), _passCtrl.text)
        : await storage.register(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    const Text('🎓', textAlign: TextAlign.center, style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 10),
                    Text(
                      'Экзаменационное тестирование',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Проверка знаний по экзаменационным билетам',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),

                    // переключатель Вход / Регистрация
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
                    const SizedBox(height: 18),

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
                            onSubmitted: (_) => _submit(),
                          ),
                        ],
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                      ),
                    ],

                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                          : Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
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

                    // ВЫВОД ВЕРСИИ И ДАТЫ
                    const SizedBox(height: 30),
                    const Divider(color: Color(0xFFE6E9EF)),
                    const SizedBox(height: 10),
                    Text(
                      'Версия: $kAppVersion\n'
                          'Дата релиза: $kReleaseDate\n'
                          'Демо-версия: до $kMaxDemoUsers пользователей',
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
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
        ),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          autocorrect: false,
          decoration: InputDecoration(hintText: hint),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Заполните поле' : null,
        ),
      ],
    );
  }
}

class _SegButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _SegButton({required this.text, required this.active, required this.onTap});

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
                ? [const BoxShadow(color: Color(0x1F0F172A), blurRadius: 4, offset: Offset(0, 1))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? Theme.of(context).colorScheme.primary : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}