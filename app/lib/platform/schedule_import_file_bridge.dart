import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/roster_grid_import.dart';

class ImportedCalendarFile {
  const ImportedCalendarFile({
    required this.name,
    this.bytes,
    this.extractedText,
    this.ocrTokens = const [],
  });

  final String name;
  final Uint8List? bytes;
  final String? extractedText;
  final List<OcrTextToken> ocrTokens;
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
    final encodedTokens = selected['tokens'];
    if (name is! String || text is! String || text.trim().isEmpty) {
      throw const FormatException('No readable schedule text was found.');
    }
    return ImportedCalendarFile(
      name: name,
      extractedText: text,
      ocrTokens: _decodeOcrTokens(encodedTokens),
    );
  }

  List<OcrTextToken> _decodeOcrTokens(Object? encoded) {
    if (encoded is! String || encoded.isEmpty) return const [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('The document layout could not be reviewed.');
    }
    final result = <OcrTextToken>[];
    for (final value in decoded) {
      if (value is! Map) continue;
      final text = value['text'];
      final left = value['left'];
      final top = value['top'];
      final right = value['right'];
      final bottom = value['bottom'];
      final page = value['page'];
      if (text is! String ||
          left is! num ||
          top is! num ||
          right is! num ||
          bottom is! num ||
          page is! int ||
          page < 0 ||
          page >= 12 ||
          [
            left,
            top,
            right,
            bottom,
          ].any((number) => !number.isFinite || number < 0 || number > 1) ||
          left > right ||
          top > bottom) {
        continue;
      }
      result.add(
        OcrTextToken(
          text: text,
          left: left.toDouble(),
          top: top.toDouble(),
          right: right.toDouble(),
          bottom: bottom.toDouble(),
          page: page,
        ),
      );
    }
    return List.unmodifiable(result);
  }
}
