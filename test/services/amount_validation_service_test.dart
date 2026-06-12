import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/services/amount_validation_service.dart';

void main() {
  group('AmountValidationService', () {
    test('金额一致时不提示 mismatch', () async {
      final service = AmountValidationService(
        imageAmountReader: (_) async => 215.00,
      );

      final result = await service.validateFileAmount(
        file: File('/tmp/payment.jpg'),
        expectedAmount: 215.00,
      );

      expect(result.isMismatch, false);
    });

    test('金额不一致时返回 mismatch', () async {
      final service = AmountValidationService(
        imageAmountReader: (_) async => 193.00,
      );

      final result = await service.validateFileAmount(
        file: File('/tmp/payment.jpg'),
        expectedAmount: 215.00,
      );

      expect(result.isMismatch, true);
    });

    test('无法识别金额时不提示 mismatch', () async {
      final service = AmountValidationService(
        imageAmountReader: (_) async => null,
      );

      final result = await service.validateFileAmount(
        file: File('/tmp/payment.jpg'),
        expectedAmount: 215.00,
      );

      expect(result.detectedAmount, isNull);
      expect(result.isMismatch, false);
    });

    test('PDF 文本中可提取金额', () async {
      final dir = await Directory.systemTemp.createTemp('amount_validation_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/invoice.pdf');
      await file.writeAsString('电子发票\n价税合计 193.00');

      final result = await const AmountValidationService().validateFileAmount(
        file: file,
        expectedAmount: 215.00,
      );

      expect(result.detectedAmount, 193.00);
      expect(result.isMismatch, true);
    });
  });
}
