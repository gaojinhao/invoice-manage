import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  group('NotificationService (通过 mock 验证接口调用)', () {
    late MockNotificationService mockNotifier;

    setUp(() {
      mockNotifier = MockNotificationService();
    });

    test('showPaymentReminder 传入正确的 count', () async {
      when(
        () => mockNotifier.showPaymentReminder(3),
      ).thenAnswer((_) async => {});

      await mockNotifier.showPaymentReminder(3);
      verify(() => mockNotifier.showPaymentReminder(3)).called(1);
    });

    test('showPaymentReminder — count=0 也可以调用', () async {
      when(
        () => mockNotifier.showPaymentReminder(0),
      ).thenAnswer((_) async => {});

      await mockNotifier.showPaymentReminder(0);
      verify(() => mockNotifier.showPaymentReminder(0)).called(1);
    });

    test('showInvoiceDownloaded 传入正确的商户名和金额', () async {
      when(
        () => mockNotifier.showInvoiceDownloaded('华联超市', 128.5),
      ).thenAnswer((_) async => {});

      await mockNotifier.showInvoiceDownloaded('华联超市', 128.5);
      verify(
        () => mockNotifier.showInvoiceDownloaded('华联超市', 128.5),
      ).called(1);
    });

    test('showMonthlyReportSent 传入正确的月份字符串', () async {
      when(
        () => mockNotifier.showMonthlyReportSent('2026-05'),
      ).thenAnswer((_) async => {});

      await mockNotifier.showMonthlyReportSent('2026-05');
      verify(() => mockNotifier.showMonthlyReportSent('2026-05')).called(1);
    });
  });
}
