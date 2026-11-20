import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/public_sync_service.dart';
import '../storage.dart';

/// Регистрация преподавателя по одноразовому коду, выданному администратором.
/// Коды генерируются на экране «Коды преподавателей» (для admin) и выгружаются
/// на Диск файлами *.ecod; при синхронизации они подхватываются на других
/// устройствах. Использованный код повторно не принимается.
class RegisterTeacherScreen extends StatefulWidget {
  const RegisterTeacherScreen({super.key});

  @override
  State<RegisterTeacherScreen> createState() => _RegisterTeacherScreenState();
}

class _RegisterTeacherScreenState extends State<RegisterTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final storage = AppStorage.instance;

    // 1. Код должен существовать и быть неиспользованным.
    if (!storage.isTeacherCodeValid(_code.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный или уже использованный код')),
      );
      return;
    }

    setState(() => _busy = true);
    final ok = await storage.registerTeacher(
      name: _name.text,
      login: _login.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Этот логин уже занят')),
      );
      return;
    }

    // 2. Расходуем код за логином нового преподавателя.
    final codeText = _code.text.trim().toUpperCase();
    await storage.consumeTeacherCode(codeText,
        _login.text.trim().toLowerCase());

    // 3. Если на устройстве есть OAuth-токен — обновляем файл кода на Диске,
    // чтобы статус «использован» разошёлся и на другие устройства.
    try {
      final consumed = storage.teacherCodes
          .firstWhere((t) => t.code == codeText);
      await PublicSyncService.publishTeacherCode(consumed);
    } catch (e) {
      debugPrint('RegisterTeacher: не удалось обновить код на Диске: $e');
    }

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Преподаватель зарегистрирован. Теперь войдите.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация преподавателя')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('👩‍🏫',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(
                      'Создание учётной записи преподавателя',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 18),

                    _field(
                      ctrl: _name,
                      label: 'ФИО',
                      hint: 'Иванова Анна Петровна',
                    ),
                    const SizedBox(height: 12),
                    _field(
                      ctrl: _login,
                      label: 'Логин',
                      hint: 'ivanova_a',
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Минимум 3 символа'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      ctrl: _password,
                      label: 'Пароль',
                      hint: '••••',
                      obscure: true,
                      validator: (v) => (v == null || v.length < 4)
                          ? 'Минимум 4 символа'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      ctrl: _confirm,
                      label: 'Повторите пароль',
                      hint: '••••',
                      obscure: true,
                      validator: (v) =>
                      v != _password.text ? 'Пароли не совпадают' : null,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      ctrl: _code,
                      label: 'Код преподавателя',
                      hint: 'TCH-XXXX-XXXX',
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Введите код' : null,
                    ),

                    if (_busy) ...[
                      const SizedBox(height: 18),
                      const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: const Text('Зарегистрироваться'),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'Код выдаёт администратор. Он одноразовый: '
                          'повторно зарегистрироваться по нему не выйдет.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFF64748B)),
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

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    bool obscure = false,
    String? Function(String?)? validator,
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
              color: Color(0xFF475569),
            ),
          ),
        ),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          autocorrect: false,
          decoration: InputDecoration(hintText: hint),
          validator: validator ??
                  (v) => (v == null || v.trim().isEmpty) ? 'Заполните поле' : null,
        ),
      ],
    );
  }
}