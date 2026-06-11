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

  group('EmailConnectionResult', () {
    test('success 返回成功消息', () {
      const result = EmailConnectionResult.success();

      expect(result.isSuccess, true);
      expect(result.message, contains('连接成功'));
    });

    test('failure 返回失败消息', () {
      const result = EmailConnectionResult.failure('登录失败');

      expect(result.isSuccess, false);
      expect(result.message, '登录失败');
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
      when(
        () => mockService.saveConfig(
          email: any(named: 'email'),
          password: any(named: 'password'),
          imapServer: any(named: 'imapServer'),
          sendTo: any(named: 'sendTo'),
        ),
      ).thenAnswer((_) async => {});

      await mockService.saveConfig(
        email: 'me@qq.com',
        password: 'authcode',
        imapServer: 'imap.qq.com',
        sendTo: 'boss@company.com',
      );

      verify(
        () => mockService.saveConfig(
          email: 'me@qq.com',
          password: 'authcode',
          imapServer: 'imap.qq.com',
          sendTo: 'boss@company.com',
        ),
      ).called(1);
    });

    test('checkAndDownloadInvoices 返回下载的发票列表', () async {
      final invoices = [makeInvoice(), makeInvoice()];
      when(
        () => mockService.checkAndDownloadInvoices(any()),
      ).thenAnswer((_) async => invoices);

      final result = await mockService.checkAndDownloadInvoices(
        '/tmp/downloads',
      );
      expect(result.length, 2);
    });

    test('checkAndDownloadInvoices — 无新发票返回空列表', () async {
      when(
        () => mockService.checkAndDownloadInvoices(any()),
      ).thenAnswer((_) async => []);

      final result = await mockService.checkAndDownloadInvoices(
        '/tmp/downloads',
      );
      expect(result, isEmpty);
    });

    test('sendEmail — 发送成功返回 true', () async {
      when(
        () => mockService.sendEmail(
          to: any(named: 'to'),
          subject: any(named: 'subject'),
          body: any(named: 'body'),
          attachmentPaths: any(named: 'attachmentPaths'),
        ),
      ).thenAnswer((_) async => true);

      final sent = await mockService.sendEmail(
        to: 'boss@company.com',
        subject: '2026-06 报销文件',
        body: '请查收',
        attachmentPaths: ['/tmp/2026-06.zip'],
      );

      expect(sent, true);
    });

    test('sendEmail — 发送失败返回 false', () async {
      when(
        () => mockService.sendEmail(
          to: any(named: 'to'),
          subject: any(named: 'subject'),
          body: any(named: 'body'),
          attachmentPaths: any(named: 'attachmentPaths'),
        ),
      ).thenAnswer((_) async => false);

      final sent = await mockService.sendEmail(
        to: 'boss@company.com',
        subject: '测试',
        body: '失败测试',
      );

      expect(sent, false);
    });
  });

  group('EmailService — verifyConnectionDetailed 纯逻辑验证', () {
    late EmailService emailService;

    setUp(() {
      emailService = EmailService();
    });

    test('邮箱格式不正确 — 缺少 @ 符号', () async {
      final result = await emailService.verifyConnectionDetailed(
        'notanemail',
        'password123',
        'imap.qq.com',
        993,
      );

      expect(result.isSuccess, false);
      expect(result.message, '邮箱格式不正确');
    });

    test('邮箱格式不正确 — @ 后域名为空', () async {
      final result = await emailService.verifyConnectionDetailed(
        'user@',
        'password123',
        'imap.qq.com',
        993,
      );

      expect(result.isSuccess, false);
      expect(result.message, '邮箱格式不正确');
    });

    test('授权码为空时返回失败', () async {
      final result = await emailService.verifyConnectionDetailed(
        'user@qq.com',
        '',
        'imap.qq.com',
        993,
      );

      expect(result.isSuccess, false);
      expect(result.message, '授权码不能为空');
    });

    test('邮箱仅含 @ 时也判定格式不正确', () async {
      final result = await emailService.verifyConnectionDetailed(
        '@',
        'password123',
        'imap.qq.com',
        993,
      );

      expect(result.isSuccess, false);
      // @ 前为空不算格式错误？split('@').last gives empty string
      expect(result.message, '邮箱格式不正确');
    });

    test('不可达服务器返回 SocketException 提示', () async {
      final result = await emailService.verifyConnectionDetailed(
        'user@qq.com',
        'password123',
        'invalid.server.example.invalid',
        993,
      );

      expect(result.isSuccess, false);
      // 可能是 SocketException 或 TimeoutException，取决于网络
      expect(
        result.message,
        anyOf(
          contains('无法连接 IMAP 服务器'),
          contains('连接超时'),
        ),
      );
    });
  });

  // T11: saveConfig 真实逻辑
  group('EmailService — saveConfig 真实逻辑 (T11)', () {
    late EmailService emailService;

    setUp(() {
      emailService = EmailService();
    });

    test('saveConfig 后 isConfigured 返回 true', () async {
      await emailService.saveConfig(
        email: 'me@qq.com',
        password: 'authcode',
        imapServer: 'imap.qq.com',
        sendTo: 'boss@company.com',
      );

      expect(emailService.isConfigured, true);
    });

    test('saveConfig 后 config 返回正确值', () async {
      await emailService.saveConfig(
        email: 'me@163.com',
        password: 'pwd123',
        imapServer: 'imap.163.com',
      );

      final config = emailService.config;
      expect(config, isNotNull);
      expect(config!.email, 'me@163.com');
      expect(config.imapServer, 'imap.163.com');
      expect(config.sendTo, isNull); // 未传 sendTo
    });

    test('未 saveConfig 时 isConfigured 返回 false', () {
      expect(emailService.isConfigured, false);
      expect(emailService.config, isNull);
    });
  });

  // T9: isInvoiceSubject 静态方法
  group('EmailService.isInvoiceSubject (T9)', () {
    test('"发票" 关键词返回 true', () {
      expect(EmailService.isInvoiceSubject('电子发票_华联超市'), true);
      expect(EmailService.isInvoiceSubject('您的发票已开具'), true);
    });

    test('"invoice" 关键词（英文）返回 true', () {
      expect(EmailService.isInvoiceSubject('Your invoice is ready'), true);
      expect(EmailService.isInvoiceSubject('Invoice #12345'), true);
    });

    test('"电子票据" 关键词返回 true', () {
      expect(EmailService.isInvoiceSubject('电子票据通知'), true);
    });

    test('"开票" 关键词返回 true', () {
      expect(EmailService.isInvoiceSubject('开票成功通知'), true);
    });

    test('无关主题返回 false', () {
      expect(EmailService.isInvoiceSubject('会议通知'), false);
      expect(EmailService.isInvoiceSubject('日报周报'), false);
      expect(EmailService.isInvoiceSubject(''), false);
    });
  });

  // T10: sendEmail 未配置时返回 false
  group('EmailService — sendEmail 边界 (T10)', () {
    late EmailService emailService;

    setUp(() {
      emailService = EmailService();
    });

    test('未配置时 sendEmail 返回 false', () async {
      // 无配置 → 缺少 SMTP 信息，应返回 false
      final result = await emailService.sendEmail(
        to: 'someone@example.com',
        subject: 'test',
        body: 'test body',
      );
      expect(result, false);
    });
  });
}
