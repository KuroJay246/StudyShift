import 'package:flutter/services.dart';

class ImportedCalendarFile {
  const ImportedCalendarFile({
    required this.name,
    this.bytes,
    this.extractedText,
  });

  final String name;
  final Uint8List? bytes;
  final String? extractedText;
}

class ScheduleImportFileBridge {
  const ScheduleImportFileBridge();

  static const _channel = MethodChannel('app.shiftstudy/import');

  Future<ImportedCalendarFile?> openCalendar() async {
    final selected = await _channel.invokeMapMethod<String, Object?>(
      'openCalendar',
    );
    if (selected == null) return null;
    final name = selected['name'];
    final bytes = selected['bytes'];
    if (name is! String || bytes is! Uint8List || bytes.isEmpty) {
      throw const FormatException('The selected calendar file is unavailable.');
    }
    return ImportedCalendarFile(name: name, bytes: bytes);
  }

  Future<ImportedCalendarFile?> openOcrImport() async {
    final selected = await _channel.invokeMapMethod<String, Object?>(
      'openOcrImport',
    );
    if (selected == null) return null;
    final name = selected['name'];
    final text = selected['text'];
    if (name is! String || text is! String || text.trim().isEmpty) {
      throw const FormatException('No readable schedule text was found.');
    }
    return ImportedCalendarFile(name: name, extractedText: text);
  }
}
