import 'package:flutter/material.dart';
import 'package:yandex_auth/yandex_auth.dart';
import '../services/token_storage.dart';

class YandexAuthScreen extends StatefulWidget {
  const YandexAuthScreen({super.key});

  @override
  State<YandexAuthScreen> createState() => _YandexAuthScreenState();
}

class _YandexAuthScreenState extends State<YandexAuthScreen> {
  final _yandexAuth = YandexAuth();
  bool _isLoading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await _yandexAuth.signIn();
      if (result != null) {
        await TokenStorage.saveToken(result.token);
        if (mounted) Navigator.pop(context, true); // Успешный вход
      } else {
        setState(() => _error = 'Авторизация отменена');
      }
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход в Яндекс')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud, size: 80, color: Color(0xFF1976D2)),
            const SizedBox(height: 20),
            const Text(
              'Для сохранения результатов на Яндекс.Диск необходимо войти в аккаунт Яндекса.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              FilledButton.icon(
                onPressed: _signIn,
                icon: const Icon(Icons.login),
                label: const Text('Войти через Яндекс'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00), // Жёлтый Яндекса
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}