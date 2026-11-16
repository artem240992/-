import 'package:flutter/material.dart';
// Импорт клиента
import 'package:flutter_rustore_pay/api/flutter_rustore_pay_client.dart';
// Импорт типа покупки (PreferredPurchaseType)
import 'package:flutter_rustore_pay/model/preferred_purchase_type.dart';
// Импорт результата проверки доступности (Available / Unavailable)
import 'package:flutter_rustore_pay/model/purchase_availability.dart';
// Импорт исключений
import 'package:flutter_rustore_pay/model/ru_store_exception.dart';
// Импорт результата покупки (ProductPurchaseResult)
import 'package:flutter_rustore_pay/model/purchase_result.dart';

import '../storage.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isProcessing = false;
  final _client = RuStorePayClient.instance;

  Future<void> _buySubscription() async {
    setState(() => _isProcessing = true);

    try {
      // 1. Проверка доступности
      final availability = await _client.purchaseInteractor.getPurchaseAvailability();

      if (availability case Unavailable unavailable) {
        throw 'Платежи недоступны: ${unavailable.errorMessage}';
      }

      if (availability is! Available) {
        throw 'Не удалось проверить доступность платежей';
      }

      // 2. Инициируем покупку подписки.
      // Метод purchase возвращает ProductPurchaseResult (даже для подписок).
      final result = await _client.purchaseInteractor.purchase(
        'premium_subscription',
        preferredPurchaseType: PreferredPurchaseType.oneStep,
        quantity: 1,
      );

      // 3. Активируем Pro. Так как purchase всегда возвращает ProductPurchaseResult,
      // проверка типа не нужна. Можно дополнительно проверить result.productType,
      // но для активации достаточно самого факта успешного завершения.
      await _activatePro();

    } on RuStoreProductPurchaseException catch (e) {
      _showError('Ошибка покупки: ${e.message}');
    } on RuStorePurchaseCancelledException {
      _showError('Покупка отменена пользователем.');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _activatePro() async {
    final user = AppStorage.instance.currentUser;
    if (user != null) {
      await AppStorage.instance.activatePro(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Premium активирован! Ограничения сняты.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium доступ')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              'Снимите ограничения!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Демо-версия ограничена 2 студентами. '
                  'Оформите Premium, чтобы снять лимит и получить полный доступ.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            if (_isProcessing)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: _buySubscription,
                icon: const Icon(Icons.payment),
                label: const Text('Оформить подписку'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Вернуться назад'),
            ),
          ],
        ),
      ),
    );
  }
}