import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// 邮件配置
class EmailConfig {
  final String email;
  final String password;
  final String imapServer;
  final int imapPort;
  final String? sendTo;

  EmailConfig({
    required this.email,
    required this.password,
    required this.imapServer,
    this.imapPort = 993,
    this.sendTo,
  });
}

/// 邮件服务 — IMAP 收件 + SMTP 发件
class EmailService {
  EmailConfig? _config;

  bool get isConfigured => _config != null;

  void configure(EmailConfig config) {
    _config = config;
  }

  EmailConfig? get config => _config;

  /// 验证邮箱连接
  Future<bool> verifyConnection(String email, String password, String imapServer, int imapPort) async {
    try {
      // 用 SMTP 验证登录
      final smtpServer = getSmtpServer(email, password);
      final connection = SMTPConnection(smtpServer);
      await connection.connect();
      await connection.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 获取 SMTP 服务器配置
  SmtpServer getSmtpServer(String email, String password) {
    if (email.contains('qq.com')) {
      return SMTP(email, password, 'smtp.qq.com', 465, ssl: true);
    } else if (email.contains('163.com')) {
      return SMTP(email, password, 'smtp.163.com', 465, ssl: true);
    } else if (email.contains('outlook.com') || email.contains('hotmail.com')) {
      return SMTP(email, password, 'smtp.office365.com', 587, ssl: false);
    } else if (email.contains('gmail.com')) {
      return SMTP(email, password, 'smtp.gmail.com', 587, ssl: false);
    }
    return SMTP(email, password, 'smtp.${email.split('@').last}', 465, ssl: true);
  }

  /// 获取 IMAP 服务器配置
  String getImapServer(String email) {
    if (email.contains('qq.com')) return 'imap.qq.com';
    if (email.contains('163.com')) return 'imap.163.com';
    if (email.contains('outlook.com') || email.contains('hotmail.com')) return 'outlook.office365.com';
    if (email.contains('gmail.com')) return 'imap.gmail.com';
    return 'imap.${email.split('@').last}';
  }

  int getImapPort(String email) {
    return 993; // 主流邮箱 IMAP over SSL
  }

  /// 发送邮件（带附件）
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    List<String>? attachmentPaths,
  }) async {
    if (_config == null) return false;

    try {
      final smtpServer = getSmtpServer(_config!.email, _config!.password);
      final message = Message()
        ..from = Address(_config!.email)
        ..recipients.add(to)
        ..subject = subject
        ..text = body;

      if (attachmentPaths != null) {
        for (final path in attachmentPaths) {
          message.attachments.add(
            FileAttachment(File(path)),
          );
        }
      }

      await send(message, smtpServer);
      return true;
    } catch (_) {
      return false;
    }
  }
}
