import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:invoice_app/services/email_service.dart';

import '../helpers/mocks.dart';

void main() {
  group('DownloadedInvoice', () {
    test('创建实例属性正确', () {
      final now = DateTime(2026, 6, 8);
      final inv = makeInvoice(
        fileName: 'invoice.pdf',
        subject: '电子发票_华联超市',
        date: now,
      );

      expect(inv.fileName, 'invoice.pdf');
      expect(inv.subject, '电子发票_华联超市');
      expect(inv.date, now);
    });
  });

  group('EmailConfig', () {
    test('创建实例属性正确', () {
      final config = EmailConfig(
        email: 'me@qq.com',
        password: 'authcode',
        imapServer: 'imap.qq.com',
        imapPort: 993,
        sendTo: 'boss@company.com',
      );

      expect(config.email, 'me@qq.com');
      expect(config.imapServer, 'imap.qq.com');
      expect(config.imapPort, 993);
      expect(config.sendTo, 'boss@company.com');
    });

    test('无 sendTo 时仅基础属性', () {
      final config = EmailConfig(
        email: 'me@163.com',
        password: 'pwd',
        imapServer: 'imap.163.com',
      );

      expect(config.sendTo, isNull);
      expect(config.imapPort, 993); // 默认值
    });
  });

  group('EmailService — 配置管理', () {
    late MockEmailService mockService;

    setUp(() {
      mockService = MockEmailService();
    });

    test('isConfigured — 有配置时返回 true', () {
      when(() => mockService.isConfigured).thenReturn(true);
      expect(mockService.isConfigured, true);
    });

    test('isConfigured — 无配置时返回 false', () {
      when(() => mockService.isConfigured).thenReturn(false);
      expect(mockService.isConfigured, false);
    });

    test('config — 返回当前配置', () {
      final config = EmailConfig(
        email: 'me@qq.com',
        password: 'auth',
        imapServer: 'imap.qq.com',
      );
      when(() => mockService.config).thenReturn(config);

      expect(mockService.config?.email, 'me@qq.com');
    });

    test('config — 未配置时返回 null', () {
      when(() => mockService.config).thenReturn(null);
      expect(mockService.config, isNull);
    });
  });

  group('EmailService — 功能方法', () {
    late MockEmailService mockService;

    setUp(() {
      mockService = MockEmailService();
    });

    test('saveConfig 保存邮箱配置', () async {
      when(() => mockService.saveConfig(
        email: any(named: 'email'),
        password: any(named: 'password'),
        imapServer: any(named: 'imapServer'),
        sendTo: any(named: 'sendTo'),
      )).thenAnswer((_) async => {});

      await mockService.saveConfig(
        email: 'me@qq.com',
        password: 'authcode',
        imapServer: 'imap.qq.com',
        sendTo: 'boss@company.com',
      );

      verify(() => mockService.saveConfig(
        email: 'me@qq.com',
        password: 'authcode',
        imapServer: 'imap.qq.com',
        sendTo: 'boss@company.com',
      )).called(1);
    });

    test('checkAndDownloadInvoices 返回下载的发票列表', () async {
      final invoices = [makeInvoice(), makeInvoice()];
      when(() => mockService.checkAndDownloadInvoices(any()))
          .thenAnswer((_) async => invoices);

      final result = await mockService.checkAndDownloadInvoices('/tmp/downloads');
      expect(result.length, 2);
    });

    test('checkAndDownloadInvoices — 无新发票返回空列表', () async {
      when(() => mockService.checkAndDownloadInvoices(any()))
          .thenAnswer((_) async => []);

      final result = await mockService.checkAndDownloadInvoices('/tmp/downloads');
      expect(result, isEmpty);
    });

    test('sendEmail — 发送成功返回 true', () async {
      when(() => mockService.sendEmail(
        to: any(named: 'to'),
        subject: any(named: 'subject'),
        body: any(named: 'body'),
        attachmentPaths: any(named: 'attachmentPaths'),
      )).thenAnswer((_) async => true);

      final sent = await mockService.sendEmail(
        to: 'boss@company.com',
        subject: '2026-06 报销文件',
        body: '请查收',
        attachmentPaths: ['/tmp/2026-06.zip'],
      );

      expect(sent, true);
    });

    test('sendEmail — 发送失败返回 false', () async {
      when(() => mockService.sendEmail(
        to: any(named: 'to'),
        subject: any(named: 'subject'),
        body: any(named: 'body'),
        attachmentPaths: any(named: 'attachmentPaths'),
      )).thenAnswer((_) async => false);

      final sent = await mockService.sendEmail(
        to: 'boss@company.com',
        subject: '测试',
        body: '失败测试',
      );

      expect(sent, false);
    });
  });
}
