import 'package:flutter/material.dart';

import '../models.dart';
import '../utils.dart';
import '../storage.dart';
import '../services/yandex_disk_service.dart';
import '../services/token_storage.dart'; // <-- Добавлено для проверки токена
import 'yandex_auth_screen.dart'; // <-- Добавлено для перехода на экран авторизации

class ResultScreen extends StatefulWidget {
  final ExamResult result;
  final Ticket ticket;

  const ResultScreen({super.key, required this.result, required this.ticket});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isUploading = false;
  final _diskService = YandexDiskService();

  Future<void> _uploadToDisk() async {
    // 1. Проверяем, есть ли сохраненный токен (безопасное хранилище)
    final hasToken = await TokenStorage.hasToken();

    // 2. Если токена нет, предлагаем авторизоваться через Яндекс
    if (!hasToken) {
      if (!mounted) return;
      final authenticated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const YandexAuthScreen()),
      );

      // Если пользователь закрыл экран или отменил вход — прерываем процесс
      if (authenticated != true) return;
    }

    final user = AppStorage.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      // 3. Загружаем результат (Сервис сам достанет токен из хранилища)
      await _diskService.uploadResult(
        result: widget.result,
        ticket: widget.ticket,
        student: user,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Результат успешно сохранён на Яндекс.Диск!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при выгрузке: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Локальные переменные для удобства чтения
    final result = widget.result;
    final ticket = widget.ticket;

    final passed = result.passed;
    final accent = passed ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результат'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          // ==================== ГЛАВНАЯ КАРТОЧКА РЕЗУЛЬТАТА ====================
          Container(
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: passed ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 158,
                  height: 158,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 158,
                        height: 158,
                        child: CircularProgressIndicator(
                          value: result.percent / 100,
                          strokeWidth: 13,
                          backgroundColor: const Color(0xFFE9EDF3),
                          valueColor: AlwaysStoppedAnimation(accent),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${result.score}/${result.total}',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${result.percent}%',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  passed ? '✅  Экзамен сдан' : '❌  Экзамен не сдан',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: accent),
                ),
                const SizedBox(height: 6),
                Text(
                  ticket.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Проходной балл — $kPassPercent%',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          // ==================== РАЗБОР ОТВЕТОВ ====================
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'РАЗБОР ОТВЕТОВ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.6),
            ),
          ),
          ...List.generate(ticket.questions.length, (i) {
            final q = ticket.questions[i];
            final given = i < result.answers.length ? result.answers[i] : null;
            final ok = given == q.correct;
            final givenText = (given == null) ? 'нет ответа' : q.options[given];

            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  left: BorderSide(color: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626), width: 4),
                  top: const BorderSide(color: Color(0xFFE6E9EF)),
                  right: const BorderSide(color: Color(0xFFE6E9EF)),
                  bottom: const BorderSide(color: Color(0xFFE6E9EF)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ${q.text}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ваш ответ: $givenText',
                    style: TextStyle(
                      fontSize: 13,
                      color: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                  if (!ok) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Правильный ответ: ${q.options[q.correct]}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF16A34A)),
                    ),
                  ],
                  if (q.hint != null && q.hint!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Подсказка: ${q.hint}',
                      style: const TextStyle(fontSize: 12.5, color: Colors.orange),
                    ),
                  ],
                ],
              ),
            );
          }),

          // ==================== КНОПКИ ДЕЙСТВИЙ ====================
          const SizedBox(height: 14),

          // Кнопка выгрузки на Яндекс.Диск
          OutlinedButton.icon(
            onPressed: _isUploading ? null : _uploadToDisk,
            icon: _isUploading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_isUploading ? 'Отправка...' : 'Выгрузить на Яндекс.Диск'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: const Color(0xFF1976D2), // Синий цвет Яндекса
              side: const BorderSide(color: Color(0xFF1976D2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 10),

          // Кнопка возврата
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('К списку билетов'),
          ),
        ],
      ),
    );
  }
}