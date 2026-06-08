import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/services/email_service.dart';

void main() {
  group('EmailService — 服务器选择逻辑', () {
    late EmailService service;

    setUp(() => service = EmailService());

    group('getSmtpServer', () {
      test('QQ 邮箱 → smtp.qq.com:465 SSL', () {
        final server = service.getSmtpServer('me@qq.com', 'authcode');
        expect(server.host, 'smtp.qq.com');
        expect(server.port, 465);
        expect(server.username, 'me@qq.com');
        expect(server.password, 'authcode');
      });

      test('163 邮箱 → smtp.163.com:465 SSL', () {
        final server = service.getSmtpServer('me@163.com', 'pwd');
        expect(server.host, 'smtp.163.com');
        expect(server.port, 465);
        expect(server.username, 'me@163.com');
      });

      test('Outlook 邮箱 → smtp.office365.com:587 STARTTLS', () {
        final server = service.getSmtpServer('me@outlook.com', 'pwd');
        expect(server.host, 'smtp.office365.com');
        expect(server.port, 587);
      });

      test('Hotmail 邮箱 → smtp.office365.com:587 STARTTLS', () {
        final server = service.getSmtpServer('me@hotmail.com', 'pwd');
        expect(server.host, 'smtp.office365.com');
      });

      test('Gmail 邮箱 → smtp.gmail.com:587 STARTTLS', () {
        final server = service.getSmtpServer('me@gmail.com', 'pwd');
        expect(server.host, 'smtp.gmail.com');
        expect(server.port, 587);
      });

      test('其他邮箱 → 自动推断', () {
        final server = service.getSmtpServer('me@custom.cn', 'pwd');
        expect(server.host, 'smtp.custom.cn');
        expect(server.port, 465);
      });
    });

    group('getImapServer', () {
      test('QQ 邮箱 → imap.qq.com', () {
        expect(service.getImapServer('me@qq.com'), 'imap.qq.com');
      });

      test('163 邮箱 → imap.163.com', () {
        expect(service.getImapServer('me@163.com'), 'imap.163.com');
      });

      test('Outlook → outlook.office365.com', () {
        expect(
          service.getImapServer('me@outlook.com'),
          'outlook.office365.com',
        );
      });

      test('Hotmail → outlook.office365.com', () {
        expect(
          service.getImapServer('me@hotmail.com'),
          'outlook.office365.com',
        );
      });

      test('Gmail → imap.gmail.com', () {
        expect(service.getImapServer('me@gmail.com'), 'imap.gmail.com');
      });

      test('其他邮箱 → 自动推断', () {
        expect(service.getImapServer('me@custom.cn'), 'imap.custom.cn');
      });
    });

    group('getImapPort', () {
      test('始终返回 993（SSL）', () {
        expect(service.getImapPort('any@email.com'), 993);
      });
    });
  });
}
