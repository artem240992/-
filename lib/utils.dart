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
const String kAppVersion = '1.2.8';
const String kReleaseDate = '05.12.2026';
