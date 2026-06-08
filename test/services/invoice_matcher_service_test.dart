import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:invoice_app/database/app_database.dart';
import 'package:invoice_app/database/tables.dart';
import 'package:invoice_app/services/email_service.dart';
import 'package:invoice_app/services/file_service.dart';
import 'package:invoice_app/services/invoice_matcher_service.dart';
import 'package:invoice_app/services/notification_service.dart';

import '../helpers/mocks.dart';

void main() {
  late MockAppDatabase mockDb;
  late MockFileService mockFileService;
  late MockNotificationService mockNotifier;
  late InvoiceMatcherService service;

  setUp(() {
    mockDb = MockAppDatabase();
    mockFileService = MockFileService();
    mockNotifier = MockNotificationService();
    service = InvoiceMatcherService(mockDb, mockFileService, mockNotifier);
  });

  group('runMatching — 空输入', () {
    test('空发票列表返回 0', () async {
      final result = await service.runMatching([]);
      expect(result, 0);
    });

    test('无待匹配记录返回 0', () async {
      when(() => mockDb.getRecordsNeedingInvoice())
          .thenAnswer((_) async => []);

      final invoices = [makeInvoice()];
      final result = await service.runMatching(invoices);

      expect(result, 0);
      verify(() => mockDb.getRecordsNeedingInvoice()).called(1);
    });
  });

  group('runMatching — 匹配逻辑', () {
    setUp(() {
      when(() => mockFileService.saveInvoicePdf(
        any(),
        any(),
        any(),
      )).thenAnswer((_) async => '/saved/invoice.pdf');

      when(() => mockNotifier.showInvoiceDownloaded(any(), any()))
          .thenAnswer((_) async => {});
    });

    test('金额完全一致时匹配成功', () async {
      final record = makeRecord(
        id: 'rec_001',
        merchant: '华联超市',
        amount: 128.0,
        status: RecordStatus.pendingInvoice,
      );
      when(() => mockDb.getRecordsNeedingInvoice())
          .thenAnswer((_) async => [record]);
      when(() => mockDb.updateInvoicePdf('rec_001', '/saved/invoice.pdf'))
          .thenAnswer((_) async => {});

      // 主题中包含金额 128.00
      final invoices = [makeInvoice(subject: '电子发票_128.00_华联超市')];
      final result = await service.runMatching(invoices);

      expect(result, 1);
      verify(() => mockDb.updateInvoicePdf('rec_001', '/saved/invoice.pdf')).called(1);
      verify(() => mockNotifier.showInvoiceDownloaded('华联超市', 128.0)).called(1);
    });

    test('金额匹配优先于商户名匹配', () async {
      final recordA = makeRecord(
        id: 'rec_a',
        merchant: '永辉超市',
        amount: 50.0,
        status: RecordStatus.pendingInvoice,
      );
      final recordB = makeRecord(
        id: 'rec_b',
        merchant: '华联超市',
        amount: 128.0,
        status: RecordStatus.pendingInvoice,
      );
      when(() => mockDb.getRecordsNeedingInvoice())
          .thenAnswer((_) async => [recordA, recordB]);
      when(() => mockDb.updateInvoicePdf(any(), any()))
          .thenAnswer((_) async => {});

      // 金额匹配 128.00 → 应匹配到 recordB
      final invoices = [makeInvoice(subject: '电子发票_128.00')];
      final result = await service.runMatching(invoices);

      expect(result, 1);
      verify(() => mockDb.updateInvoicePdf('rec_b', any())).called(1);
    });

    test('日期接近度加分 — 3天内+30分', () async {
      final today = DateTime(2026, 6, 8);
      final record = makeRecord(
        id: 'rec_001',
        date: today,
        merchant: '测试超市',
        amount: 99.0,
        status: RecordStatus.pendingInvoice,
      );
      when(() => mockDb.getRecordsNeedingInvoice())
          .thenAnswer((_) async => [record]);
      when(() => mockDb.updateInvoicePdf(any(), any()))
          .thenAnswer((_) async => {});

      // 发票日期 = 同一天，应有日期匹配加分
      final invoices = [makeInvoice(date: today, subject: '发票_99.00')];
      final result = await service.runMatching(invoices);

      expect(result, 1);
    });

    test('多发票匹配多个记录', () async {
      final records = [
        makeRecord(id: 'rec_a', merchant: '超市A', amount: 50.0, status: RecordStatus.pendingInvoice),
        makeRecord(id: 'rec_b', merchant: '超市B', amount: 80.0, status: RecordStatus.pendingInvoice),
      ];
      when(() => mockDb.getRecordsNeedingInvoice())
          .thenAnswer((_) async => records);
      when(() => mockDb.updateInvoicePdf(any(), any()))
          .thenAnswer((_) async => {});

      final invoices = [
        makeInvoice(subject: '发票_50.00_超市A'),
        makeInvoice(subject: '发票_80.00_超市B'),
      ];

      final result = await service.runMatching(invoices);

      expect(result, 2);
      verify(() => mockDb.updateInvoicePdf('rec_a', any())).called(1);
      verify(() => mockDb.updateInvoicePdf('rec_b', any())).called(1);
    });
  });

  group('runMatching — 阈值过滤', () {
    test('评分 < 30 不匹配', () async {
      final record = makeRecord(
        id: 'rec_001',
        date: DateTime(2026, 1, 1), // 5个月前
        merchant: '不同商户',
        amount: 999.0, // 金额不匹配
        status: RecordStatus.pendingInvoice,
      );
      when(() => mockDb.getRecordsNeedingInvoice())
          .thenAnswer((_) async => [record]);

      final invoices = [makeInvoice(subject: '完全不相关主题')];
      final result = await service.runMatching(invoices);

      expect(result, 0);
      verify(() => mockDb.updateInvoicePdf(any(), any()), never).called(0);
    });
  });
}
