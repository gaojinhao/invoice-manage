import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:invoice_app/database/tables.dart';
import 'package:invoice_app/services/check_pack_service.dart';
import 'package:invoice_app/services/email_service.dart';

import '../helpers/mocks.dart';

void main() {
  registerFallbackValue(File(''));
  group('DailyCheckService', () {
    late MockAppDatabase mockDb;
    late MockEmailService mockEmail;
    late MockNotificationService mockNotifier;
    late MockFileService mockFileService;
    late DailyCheckService service;

    setUp(() {
      mockDb = MockAppDatabase();
      mockEmail = MockEmailService();
      mockNotifier = MockNotificationService();
      mockFileService = MockFileService();
      service = DailyCheckService(
        db: mockDb,
        emailService: mockEmail,
        notifier: mockNotifier,
        fileService: mockFileService,
      );
    });

    test('run — 有缺支付记录的发送通知', () async {
      when(() => mockDb.getRecordsNeedingPayment())
          .thenAnswer((_) async => [
            makeRecord(id: 'r1', status: RecordStatus.pendingPayment),
            makeRecord(id: 'r2', status: RecordStatus.pendingPayment),
          ]);
      when(() => mockEmail.isConfigured).thenReturn(false);
      when(() => mockNotifier.showPaymentReminder(2))
          .thenAnswer((_) async => {});

      final (missing, invoices) = await service.run();

      expect(missing, 2);
      expect(invoices, 0);
      verify(() => mockNotifier.showPaymentReminder(2)).called(1);
    });

    test('run — 无缺支付记录时不发通知', () async {
      when(() => mockDb.getRecordsNeedingPayment())
          .thenAnswer((_) async => []);
      when(() => mockEmail.isConfigured).thenReturn(false);

      final (missing, invoices) = await service.run();

      expect(missing, 0);
      expect(invoices, 0);
      verifyNever(() => mockNotifier.showPaymentReminder(any()));
    });

    test('run — 邮箱未配置则跳过发票检查', () async {
      when(() => mockDb.getRecordsNeedingPayment())
          .thenAnswer((_) async => []);
      when(() => mockEmail.isConfigured).thenReturn(false);

      final (_, invoices) = await service.run();

      expect(invoices, 0);
      verifyNever(() => mockEmail.checkAndDownloadInvoices(any()));
    });

    test('run — 邮箱已配置时执行发票下载', () async {
      when(() => mockDb.getRecordsNeedingPayment())
          .thenAnswer((_) async => []);
      when(() => mockEmail.isConfigured).thenReturn(true);
      when(() => mockEmail.checkAndDownloadInvoices(any()))
          .thenAnswer((_) async => [makeInvoice()]);

      // InvoiceMatcherService internally uses mockDb/mockFileService/mockNotifier
      // 但这里创建的是独立的 Matcher，需要额外 mock
      when(() => mockDb.getRecordsNeedingInvoice())
          .thenAnswer((_) async => []);
      when(() => mockFileService.saveInvoicePdf(any(), any(), any()))
          .thenAnswer((_) async => '/saved/invoice.pdf');
      when(() => mockNotifier.showInvoiceDownloaded(any(), any()))
          .thenAnswer((_) async => {});

      final (_, invoices) = await service.run();

      // 即使发票下载成功，无待匹配记录 → matched=0
      expect(invoices, 0);
      verify(() => mockEmail.checkAndDownloadInvoices(any())).called(1);
    });

    test('run — 邮箱检查异常时优雅降级', () async {
      when(() => mockDb.getRecordsNeedingPayment())
          .thenAnswer((_) async => []);
      when(() => mockEmail.isConfigured).thenReturn(true);
      when(() => mockEmail.checkAndDownloadInvoices(any()))
          .thenThrow(Exception('IMAP connection failed'));

      final (_, invoices) = await service.run();

      expect(invoices, 0);
    });
  });

  group('MonthlyPackService', () {
    late MockAppDatabase mockDb;
    late MockEmailService mockEmail;
    late MockNotificationService mockNotifier;
    late MockFileService mockFileService;
    late MonthlyPackService service;

    setUp(() {
      mockDb = MockAppDatabase();
      mockEmail = MockEmailService();
      mockNotifier = MockNotificationService();
      mockFileService = MockFileService();
      service = MonthlyPackService(
        db: mockDb,
        emailService: mockEmail,
        notifier: mockNotifier,
        fileService: mockFileService,
      );
    });

    test('run — 无完整记录返回 0', () async {
      when(() => mockDb.getCompleteRecords())
          .thenAnswer((_) async => []);

      final result = await service.run();
      expect(result, 0);
    });

    test('run — 完整记录打包发送成功', () async {
      // 当前月份 2026-06，上个月是 2026-05
      final lastMonthRecords = [
        makeRecord(
          id: 'r1',
          date: DateTime(2026, 5, 15),
          merchant: '超市A',
          amount: 100,
          status: RecordStatus.complete,
          month: '2026-05',
        ),
      ];

      when(() => mockDb.getCompleteRecords())
          .thenAnswer((_) async => lastMonthRecords);
      when(() => mockFileService.zipMonthRecords(2026, 5))
          .thenAnswer((_) async => '/tmp/2026-05_报销文件.zip');
      when(() => mockEmail.config)
          .thenReturn(EmailConfig(
            email: 'me@qq.com',
            password: 'xxx',
            imapServer: 'imap.qq.com',
            sendTo: 'boss@company.com',
          ));
      when(() => mockEmail.sendEmail(
        to: any(named: 'to'),
        subject: any(named: 'subject'),
        body: any(named: 'body'),
        attachmentPaths: any(named: 'attachmentPaths'),
      )).thenAnswer((_) async => true);
      when(() => mockDb.markArchived('r1'))
          .thenAnswer((_) async => {});
      when(() => mockNotifier.showMonthlyReportSent(any()))
          .thenAnswer((_) async => {});

      final result = await service.run();

      expect(result, 1);
      verify(() => mockNotifier.showMonthlyReportSent('2026-05')).called(1);
      verify(() => mockDb.markArchived('r1')).called(1);
    });

    test('run — ZIP 打包失败返回 0', () async {
      final lastMonthRecords = [
        makeRecord(
          id: 'r1',
          date: DateTime(2026, 5, 15),
          status: RecordStatus.complete,
          month: '2026-05',
        ),
      ];

      when(() => mockDb.getCompleteRecords())
          .thenAnswer((_) async => lastMonthRecords);
      when(() => mockFileService.zipMonthRecords(2026, 5))
          .thenAnswer((_) async => null); // ZIP 打包失败

      final result = await service.run();
      expect(result, 0);
      // 不应该尝试发邮件
      verifyNever(() => mockEmail.sendEmail(
        to: any(named: 'to'),
        subject: any(named: 'subject'),
        body: any(named: 'body'),
        attachmentPaths: any(named: 'attachmentPaths'),
      ));
    });
  });
}
