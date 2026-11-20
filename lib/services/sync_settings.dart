import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Хранит ссылку на опубликованную папку Яндекс.Диска с данными.
/// Ссылка по умолчанию зашита в код в обфусцированном виде (XOR + Base64),
/// чтобы её нельзя было найти простым поиском по файлам APK.
class SyncSettings {
  static const _key = 'sync_public_url';

  /// Ключ обфускации. Можно изменить — тогда перегенерируйте строку ниже.
  static const String _secret = 'ExamApp2026SecretKey';

  /// Ссылка по умолчанию: https://disk.yandex.ru/d/K9CFsHyZcfww9g
  /// в виде XOR+_secret, закодированной в Base64.
  static const String _defaultEncrypted =
      'LQwVHTJKXx1TXlkmAU0fBB0nSwswVxEYIxwZUR9dDj4QTBkjADxRFjMsOA==';

  static String _decrypt(String enc) {
    final k = utf8.encode(_secret);
    final xored = base64.decode(enc);
    final bytes = List<int>.generate(
      xored.length,
      (i) => xored[i] ^ k[i % k.length],
    );
    return utf8.decode(bytes);
  }

  /// Сохранённая ссылка, а если пользователь не задал свою — ссылка по умолчанию.
  static Future<String?> getUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_key);
    if (url == null || url.isEmpty) return _decrypt(_defaultEncrypted);
    return url;
  }

  static Future<void> setUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_url', url);
  }

  /// Задаёт пользовательскую ссылку. Чтобы вернуть ссылку по умолчанию —
  /// вызовите clearUrl() (или оставьте в настройках пустое поле).
  static Future<void> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url.trim());
  }

  static Future<void> clearUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
