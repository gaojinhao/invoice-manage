import 'dart:convert';
import 'dart:io';

import 'ocr_service.dart';

class AmountValidationResult {
  final double expectedAmount;
  final double? detectedAmount;
  final double tolerance;

  const AmountValidationResult({
    required this.expectedAmount,
    required this.detectedAmount,
    this.tolerance = 0.01,
  });

  bool get isMismatch {
    final amount = detectedAmount;
    if (amount == null) return false;
    return (amount - expectedAmount).abs() > tolerance;
  }
}

class AmountValidationService {
  final Future<double?> Function(File file)? imageAmountReader;

  const AmountValidationService({this.imageAmountReader});

  Future<AmountValidationResult> validateFileAmount({
    required File file,
    required double expectedAmount,
  }) async {
    final detectedAmount = await _detectAmount(file);
    return AmountValidationResult(
      expectedAmount: expectedAmount,
      detectedAmount: detectedAmount,
    );
  }

  Future<double?> _detectAmount(File file) async {
    try {
      if (_isPdf(file.path)) {
        return await _detectPdfAmount(file);
      }
      return await _detectImageAmount(file);
    } catch (_) {
      return null;
    }
  }

  Future<double?> _detectImageAmount(File file) async {
    final reader = imageAmountReader;
    if (reader != null) return reader(file);

    final ocr = OcrService();
    try {
      final result = await ocr.recognizeImage(file);
      return result.amount;
    } finally {
      ocr.dispose();
    }
  }

  Future<double?> _detectPdfAmount(File file) async {
    final ocr = OcrService();
    final bytes = await file.readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: true);
    final fileName =
        file.uri.pathSegments.isEmpty ? '' : file.uri.pathSegments.last;
    return ocr.extractAmount('$fileName\n$text');
  }

  bool _isPdf(String path) => path.toLowerCase().endsWith('.pdf');
}
