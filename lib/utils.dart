String two(int n) => n.toString().padLeft(2, '0');

String fmtTime(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${two(s ~/ 60)}:${two(s % 60)}';
}

String fmtDate(DateTime d) =>
    '${two(d.day)}.${two(d.month)}.${two(d.year)} ${two(d.hour)}:${two(d.minute)}';

String initials(String name) => name
    .split(' ')
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w[0].toUpperCase())
    .join();

const List<String> kLetters = ['А', 'Б', 'В', 'Г', 'Д', 'Е'];

// ==================== ИНФОРМАЦИЯ О ПРИЛОЖЕНИИ ====================
const String kAppVersion = '1.1.0 (Demo)';
const String kReleaseDate = '26.11.2026';
const int kMaxDemoUsers = 2; // Максимум студентов в демо-версии