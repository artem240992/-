import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import '../storage.dart';
import '../utils.dart';

class ExamScreen extends StatefulWidget {
  final Ticket ticket;
  const ExamScreen({super.key, required this.ticket});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  late final List<int?> _answers;
  int _current = 0;
  int _remaining = kTimeLimit;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _answers = List<int?>.filled(widget.ticket.questions.length, null);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) _finish();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _select(int index) {
    setState(() => _answers[_current] = index);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();

    final questions = widget.ticket.questions;
    var score = 0;
    for (var i = 0; i < questions.length; i++) {
      if (_answers[i] == questions[i].correct) score++;
    }
    final total = questions.length;
    final percent = total == 0 ? 0 : ((score / total) * 100).round();

    final result = ExamResult(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      studentId: AppStorage.instance.currentUser!.id,
      ticketId: widget.ticket.id,
      score: score,
      total: total,
      percent: percent,
      passed: percent >= kPassPercent,
      date: DateTime.now(),
      answers: List<int?>.from(_answers),
    );

    Navigator.of(context).pop(result);
  }

  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Прервать экзамен?'),
        content: const Text('Результат не будет сохранён.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Продолжить')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Прервать', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (exit == true && mounted) {
      _finished = true;
      _timer?.cancel();
      Navigator.of(context).pop();
    }
  }

  Future<void> _finishWithConfirm() async {
    final unanswered = _answers.where((a) => a == null).length;
    if (unanswered > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Завершить тест?'),
          content: Text('Без ответа осталось вопросов: $unanswered.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Вернуться')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Завершить')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.ticket.questions;
    if (questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('В билете нет вопросов')));
    }

    final q = questions[_current];
    final answered = _answers.where((a) => a != null).length;
    final isLast = _current == questions.length - 1;
    final warn = _remaining <= 60;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop && !_finished) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmExit,
          ),
          title: Text(
            widget.ticket.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: warn ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    fmtTime(_remaining),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: warn ? const Color(0xFFDC2626) : const Color(0xFF334155),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: answered / questions.length,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE9EDF3),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: questions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (context, i) {
                        final isCur = i == _current;
                        final isDone = _answers[i] != null;
                        return GestureDetector(
                          onTap: () => setState(() => _current = i),
                          child: Container(
                            width: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isCur
                                  ? Theme.of(context).colorScheme.primary
                                  : isDone
                                  ? const Color(0xFFDCFCE7)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCur
                                    ? Theme.of(context).colorScheme.primary
                                    : isDone
                                    ? const Color(0xFFBBF7D0)
                                    : const Color(0xFFE6E9EF),
                              ),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isCur
                                    ? Colors.white
                                    : isDone
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                children: [
                  Text(
                    'Вопрос ${_current + 1} из ${questions.length}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.text,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
                  ),

                  // Блок подсказки
                  if (q.hint != null && q.hint!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.lightbulb_outline, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('Подсказка'),
                                ],
                              ),
                              content: Text(q.hint!),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Понятно'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.lightbulb, size: 18, color: Colors.orange),
                        label: const Text(
                            'Показать подсказку',
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  ...List.generate(q.options.length, (i) {
                    final selected = _answers[_current] == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Material(
                        color: selected ? const Color(0xFFEEF2FF) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () => _select(i),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : const Color(0xFFE6E9EF),
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 29,
                                  height: 29,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    kLetters[i],
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: selected ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    q.options[i],
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      height: 1.35,
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE6E9EF))),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _current == 0 ? null : () => setState(() => _current--),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: isLast
                            ? _finishWithConfirm
                            : () => setState(() => _current++),
                        child: Text(isLast ? 'Завершить тест' : 'Далее'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}