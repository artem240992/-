import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models.dart';
import '../services/report_builder.dart';

class LocalFileService {
  /// Открывает системный диалог «Сохранить как» и пишет отчёт в выбранное место.
  /// Возвращает путь, по которому сохранён файл.
  static Future<String> saveResultWithPicker({
    required ExamResult result,
    required Ticket ticket,
    required Student student,
  }) async {
    final jsonString = reportToJson(buildReport(
      result: result,
      ticket: ticket,
      student: student,
    ));
    final fileName = reportFileName(student, ticket);

    final bytes = utf8.encode(jsonString);

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Куда сохранить отчёт',
      fileName: fileName,
      bytes: bytes,
    );


    if (outputPath == null) {
      // Пользователь закрыл диалог, не выбрав место — это не ошибка.
      throw Exception('Сохранение отменено');
    }

    return outputPath;
  }


  /// Старый вариант — без диалога, в папку «Загрузки».
  static Future<String> saveResultToDevice({
    required ExamResult result,
    required Ticket ticket,
    required Student student,
  }) async {
    final jsonString = reportToJson(buildReport(
      result: result,
      ticket: ticket,
      student: student,
    ));
    final fileName = reportFileName(student, ticket);

    final dir = await getDownloadsDirectory();
    if (dir == null) {
      throw Exception('Не удалось получить папку загрузок');
    }

    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonString, encoding: utf8);

    return file.path;
  }
}
