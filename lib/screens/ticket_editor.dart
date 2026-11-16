import 'package:flutter/material.dart';

import '../models.dart';
import '../storage.dart';
import '../utils.dart';

// ==================== РЕДАКТОР БИЛЕТА ====================
class TicketEditorScreen extends StatefulWidget {
  final String ticketId;
  const TicketEditorScreen({super.key, required this.ticketId});

  @override
  State<TicketEditorScreen> createState() => _TicketEditorScreenState();
}

class _TicketEditorScreenState extends State<TicketEditorScreen> {
  late TextEditingController _titleCtrl;
  late List<Question> _questions;

  @override
  void initState() {
    super.initState();
    final t = AppStorage.instance.ticketById(widget.ticketId);
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _questions = List<Question>.from(t?.questions ?? const []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final orig = AppStorage.instance.ticketById(widget.ticketId);
    if (orig == null) return;
    await AppStorage.instance.updateTicket(Ticket(
      id: orig.id,
      title: _titleCtrl.text.trim().isEmpty ? orig.title : _titleCtrl.text.trim(),
      questions: _questions,
    ));
  }

  Future<void> _addQuestion() async {
    final q = await Navigator.of(context).push<Question>(
      MaterialPageRoute(builder: (_) => const QuestionEditorScreen()),
    );
    if (q == null) return;
    setState(() => _questions.add(q));
    await _save();
  }

  Future<void> _editQuestion(int idx) async {
    final q = await Navigator.of(context).push<Question>(
      MaterialPageRoute(
          builder: (_) => QuestionEditorScreen(initial: _questions[idx])),
    );
    if (q == null) return;
    setState(() => _questions[idx] = q);
    await _save();
  }

  Future<void> _deleteQuestion(int idx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить вопрос?'),
        content: const Text('Вопрос будет удалён из билета.'),
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
    setState(() => _questions.removeAt(idx));
    await _save();
  }

  Future<void> _onBack() async {
    await _save();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Редактирование билета'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBack,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          children: [
            const _Label('НАЗВАНИЕ'),
            TextFormField(
              controller: _titleCtrl,
              decoration:
              const InputDecoration(hintText: 'Например: Билет 7. Тема'),
            ),
            const SizedBox(height: 20),
            _Label('ВОПРОСЫ · ${_questions.length}'),
            if (_questions.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE6E9EF)),
                ),
                child: const Column(
                  children: [
                    Text('📝', style: TextStyle(fontSize: 28)),
                    SizedBox(height: 8),
                    Text(
                      'В билете пока нет вопросов.\nДобавьте первый вопрос кнопкой ниже.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.5),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_questions.length, (i) {
                final q = _questions[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _editQuestion(i),
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE6E9EF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'ВОПРОС ${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => _deleteQuestion(i),
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: Color(0xFFDC2626)),
                                  tooltip: 'Удалить',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              q.text,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Вариантов: ${q.options.length} · правильный: '
                                  '${kLetters[q.correct]}',
                              style: const TextStyle(
                                  fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _addQuestion,
              icon: const Icon(Icons.add),
              label: const Text('Добавить вопрос'),
              style:
              FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ==================== РЕДАКТОР ВОПРОСА ====================
class QuestionEditorScreen extends StatefulWidget {
  final Question? initial;
  const QuestionEditorScreen({super.key, this.initial});

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  late final TextEditingController _textCtrl;
  late final TextEditingController _hintCtrl;
  late final List<TextEditingController> _opts;
  late int _correct;
  String? _error;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.initial?.text ?? '');
    _hintCtrl = TextEditingController(text: widget.initial?.hint ?? '');
    final initOpts = widget.initial?.options ?? const ['', '', '', ''];
    _opts = initOpts.map((o) => TextEditingController(text: o)).toList();
    _correct = widget.initial?.correct ?? 0;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _hintCtrl.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_opts.length >= 6) return;
    setState(() => _opts.add(TextEditingController()));
  }

  void _removeOption(int i) {
    if (_opts.length <= 2) return;
    setState(() {
      _opts.removeAt(i).dispose();
      if (_correct == i) {
        _correct = 0;
      } else if (_correct > i) {
        _correct--;
      }
    });
  }

  void _save() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Введите текст вопроса');
      return;
    }
    final opts = _opts.map((c) => c.text.trim()).toList();
    if (opts.any((o) => o.isEmpty)) {
      setState(() => _error = 'Заполните все варианты ответа');
      return;
    }
    if (opts.toSet().length != opts.length) {
      setState(() => _error = 'Варианты не должны повторяться');
      return;
    }

    final hintText = _hintCtrl.text.trim();

    Navigator.of(context).pop(Question(
      text: text,
      options: opts,
      correct: _correct,
      hint: hintText.isEmpty ? null : hintText,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.initial == null ? 'Новый вопрос' : 'Редактирование вопроса'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
        children: [
          const _Label('ТЕКСТ ВОПРОСА'),
          TextFormField(
            controller: _textCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Введите вопрос...'),
          ),
          const SizedBox(height: 20),
          const _Label('ПОДСКАЗКА (НЕОБЯЗАТЕЛЬНО)'),
          TextFormField(
            controller: _hintCtrl,
            decoration: const InputDecoration(
                hintText: 'Помощь студенту при ответе...'),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                const Text(
                  'ВАРИАНТЫ ОТВЕТА',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                Text(
                  'Нажмите на букву — правильный',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(_opts.length, (i) {
            final isCorrect = _correct == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _correct = i),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        kLetters[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isCorrect
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _opts[i],
                      decoration:
                      InputDecoration(hintText: 'Вариант ${kLetters[i]}'),
                    ),
                  ),
                  if (_opts.length > 2)
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () => _removeOption(i),
                      tooltip: 'Удалить вариант',
                    ),
                ],
              ),
            );
          }),
          if (_opts.length < 6)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить вариант'),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style:
                const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: const Text('Сохранить вопрос'),
          ),
        ],
      ),
    );
  }
}