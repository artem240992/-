import 'package:flutter/material.dart';

import '../models.dart';
import '../storage.dart';
import '../utils.dart';
import 'exam_screen.dart';
import 'result_screen.dart';
import 'premium_screen.dart'; // <-- ДОБАВЛЕН ИМПОРТ

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _index = 0;

  static const _titles = ['Экзаменационные билеты', 'История попыток', 'Профиль'];

  Future<void> _startExam(Ticket ticket) async {
    final result = await Navigator.of(context).push<ExamResult>(
      MaterialPageRoute(builder: (_) => ExamScreen(ticket: ticket)),
    );
    if (result == null || !mounted) return;

    await AppStorage.instance.addResult(result);
    if (!mounted) return;

    setState(() {});

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: result, ticket: ticket),
        fullscreenDialog: true,
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = AppStorage.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_index]),
            Text(
              '${user.name} · ${user.group}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          _TicketsTab(onStart: _startExam),
          const _HistoryTab(),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Билеты'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'История'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}

// ==================== БИЛЕТЫ ====================
class _TicketsTab extends StatelessWidget {
  final void Function(Ticket) onStart;

  const _TicketsTab({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final storage = AppStorage.instance;
    final user = storage.currentUser!;
    final tickets = storage.db.tickets;
    final results = storage.resultsFor(user.id);
    final best = storage.bestResultsFor(user.id);

    final passedCount = tickets.where((t) => best[t.id]?.passed == true).length;
    final avg = results.isEmpty
        ? 0
        : (results.map((r) => r.percent).reduce((a, b) => a + b) / results.length).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Row(
          children: [
            _StatCard(value: '$passedCount/${tickets.length}', label: 'Сдано'),
            const SizedBox(width: 9),
            _StatCard(value: '${results.length}', label: 'Попыток'),
            const SizedBox(width: 9),
            _StatCard(value: '$avg%', label: 'Средний'),
          ],
        ),
        const _SectionTitle('Выберите билет'),
        ...List.generate(tickets.length, (i) {
          final t = tickets[i];
          final b = best[t.id];
          return _TicketTile(
            number: i + 1,
            ticket: t,
            bestResult: b,
            onTap: () => onStart(t),
          );
        }),
      ],
    );
  }
}

class _TicketTile extends StatelessWidget {
  final int number;
  final Ticket ticket;
  final ExamResult? bestResult;
  final VoidCallback onTap;

  const _TicketTile({
    required this.number,
    required this.ticket,
    required this.bestResult,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final b = bestResult;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: ticket.questions.isEmpty ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
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
                    '$number',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.title,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.3),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ticket.questions.isEmpty
                            ? 'Нет вопросов — обратитесь к преподавателю'
                            : '${ticket.questions.length} вопросов · ${kTimeLimit ~/ 60} мин'
                            '${b != null ? ' · лучший: ${b.percent}%' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ticket.questions.isEmpty
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(result: b),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ExamResult? result;

  const _StatusBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;

    if (result == null) {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
      text = 'Не начат';
    } else if (result!.passed) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
      text = 'Сдан';
    } else {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      text = 'Не сдан';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE6E9EF)),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        text.toUpperCase(),
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

// ==================== ИСТОРИЯ ====================
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final storage = AppStorage.instance;
    final results = storage.resultsFor(storage.currentUser!.id)
      ..sort((a, b) => b.date.compareTo(a.date));

    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📭', style: TextStyle(fontSize: 40)),
              SizedBox(height: 10),
              Text(
                'Вы ещё не проходили ни одного билета',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final r = results[i];
        final ticket = storage.ticketById(r.ticketId);
        final passed = r.passed;

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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: passed ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${r.percent}%',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: passed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket?.title ?? 'Билет удалён',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${r.score} из ${r.total} · ${fmtDate(r.date)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(result: r),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== ПРОФИЛЬ ====================
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final storage = AppStorage.instance;
    final user = storage.currentUser!;
    final results = storage.resultsFor(user.id);
    final avg = results.isEmpty
        ? 0
        : (results.map((r) => r.percent).reduce((a, b) => a + b) / results.length).round();

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
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  if (user.isPro) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: Colors.amber, size: 20),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Студент · группа ${user.group}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                'Логин: ${user.login}',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(value: '${results.length}', label: 'Попыток'),
            const SizedBox(width: 9),
            _StatCard(value: '${results.where((r) => r.passed).length}', label: 'Сдано'),
            const SizedBox(width: 9),
            _StatCard(value: '$avg%', label: 'Средний'),
          ],
        ),
        const _SectionTitle('О приложении'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6E9EF)),
          ),
          child: const Text(
            'Тестирование по экзаменационным билетам.\n'
                'Проходной балл — 60%, время на билет — 15 минут.\n'
                'Результаты сохраняются на устройстве.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.6),
          ),
        ),

        if (!user.isPro) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Снять ограничения (Premium)'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
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
                Text('Premium активен', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: storage.logout,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Выйти из аккаунта'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: const Color(0xFFDC2626),
            side: const BorderSide(color: Color(0xFFFECACA)),
            backgroundColor: const Color(0xFFFEF2F2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}