import 'package:flutter/material.dart';

import '../models.dart';
import '../utils.dart';

class ResultScreen extends StatelessWidget {
  final ExamResult result;
  final Ticket ticket;

  const ResultScreen({super.key, required this.result, required this.ticket});

  @override
  Widget build(BuildContext context) {
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

          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('К списку билетов'),
          ),
        ],
      ),
    );
  }
}