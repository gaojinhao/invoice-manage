import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

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

/// 已下载的发票信息
class DownloadedInvoice {
  final String fileName;
  final String localPath;
  final String subject;
  final DateTime date;
  final double? matchedAmount;

  DownloadedInvoice({
    required this.fileName,
    required this.localPath,
    required this.subject,
    required this.date,
    this.matchedAmount,
  });
}

/// 简单 IMAP 客户端（基于 Socket，无外部依赖）
class _ImapClient {
  SecureSocket? _socket;
  String _tag = 'a000';

  /// 连接 IMAP 服务器
  Future<void> connect(String host, int port) async {
    _socket = await SecureSocket.connect(host, port,
      timeout: const Duration(seconds: 15),
    );
    // 读取欢迎信息
    await _readResponse();
  }

  /// 登录
  Future<bool> login(String email, String password) async {
    _tag = _nextTag();
    await _sendCommand('$TAG LOGIN "$email" "$password"');
    final resp = await _readResponse();
    return resp.any((l) => l.startsWith('$TAG OK'));
  }

  /// 选择邮箱
  Future<bool> selectInbox() async {
    _tag = _nextTag();
    await _sendCommand('$TAG SELECT INBOX');
    final resp = await _readResponse();
    return resp.any((l) => l.startsWith('$TAG OK'));
  }

  /// 搜索未读邮件
  Future<List<String>> searchUnseen() async {
    _tag = _nextTag();
    await _sendCommand('$TAG SEARCH UNSEEN');
    final resp = await _readResponse();
    // 返回格式: * SEARCH 1 2 3
    for (final line in resp) {
      if (line.startsWith('* SEARCH')) {
        return line.replaceFirst('* SEARCH', '').trim().split(' ').where((s) => s.isNotEmpty).toList();
      }
    }
    return [];
  }

  /// 搜索指定日期后的邮件
  Future<List<String>> searchSince(DateTime since) async {
    final dateStr = '${since.day.toString().padLeft(2, '0')}-${_monthAbbr(since.month)}-${since.year}';
    _tag = _nextTag();
    await _sendCommand('$TAG SEARCH SINCE "$dateStr"');
    final resp = await _readResponse();
    for (final line in resp) {
      if (line.startsWith('* SEARCH')) {
        return line.replaceFirst('* SEARCH', '').trim().split(' ').where((s) => s.isNotEmpty).toList();
      }
    }
    return [];
  }

  /// 获取邮件主题和日期
  Future<Map<String, String>> fetchEnvelope(int seq) async {
    _tag = _nextTag();
    await _sendCommand('$TAG FETCH $seq (ENVELOPE INTERNALDATE)');
    final resp = await _readResponse();
    final result = <String, String>{};
    for (final line in resp) {
      if (line.contains('INTERNALDATE')) {
        final m = RegExp(r'"(\d{1,2}-[A-Za-z]{3}-\d{4}\s+\d{2}:\d{2}:\d{2}\s+[+\-]\d{4})"')
            .firstMatch(line);
        if (m != null) result['date'] = m.group(1)!;
      }
      if (line.contains('ENVELOPE')) {
        // Subject is the 2nd field in ENVELOPE
        final m = RegExp(r'ENVELOPE\s*\([^)]*"([^"]*)"\s*\(')
            .firstMatch(line);
        if (m != null) {
          result['subject'] = _decodeMimeHeader(m.group(1)!);
        } else {
          // Try to extract subject from raw ENVELOPE
          final m2 = RegExp(r'\?\s*"([^"]*)"\s*\(').firstMatch(line);
          if (m2 != null) {
            result['subject'] = _decodeMimeHeader(m2.group(1)!);
          }
        }
      }
    }
    return result;
  }

  /// 获取邮件 BODYSTRUCTURE 并下载附件
  Future<List<Map<String, dynamic>>> fetchAttachments(int seq, String saveDir) async {
    final attachments = <Map<String, dynamic>>[];

    // 先获取 BODYSTRUCTURE 了解附件信息
    _tag = _nextTag();
    await _sendCommand('$TAG FETCH $seq (BODYSTRUCTURE)');
    final bodyResp = await _readResponse();

    // 解析附件部分编号（如 1, 2, 1.1, 1.2 等）
    final bodyText = bodyResp.join('\n');
    final attachmentParts = <int>[];
    // 简单解析：找 "("name" "filename.pdf")" 这种模式
    final nameRegex = RegExp(r'"([^"]+\.(?:pdf|jpg|jpeg|png|gif|bmp))"', caseSensitive: false);
    final nameMatches = nameRegex.allMatches(bodyText);

    if (nameMatches.isEmpty) return attachments;

    // 为每个附件名尝试下载
    for (final match in nameMatches) {
      final fileName = match.group(1)!;
      // 从 BODYSTRUCTURE 往前找附件编号
      final beforeMatch = bodyText.substring(0, match.start);
      final partRegex = RegExp(r'(\d+)\s*\[\s*\(?\s*"name"\s*"');
      final partMatch = partRegex.allMatches(beforeMatch);
      if (partMatch.isNotEmpty) {
        final last = partMatch.last;
        final partNum = last.group(1);
        if (partNum != null) {
          attachments.add({
            'part': partNum,
            'fileName': fileName,
          });
        }
      }
    }

    // 下载每个附件
    final downloaded = <Map<String, dynamic>>[];
    for (final att in attachments) {
      final part = att['part'] as String;
      final fileName = att['fileName'] as String;

      _tag = _nextTag();
      await _sendCommand('$TAG FETCH $seq (BODY[$part])');

      // 读取二进制附件数据
      final data = await _readBinaryResponse();
      if (data != null && data.isNotEmpty) {
        final savePath = '$saveDir/$fileName';
        await File(savePath).writeAsBytes(data);
        downloaded.add({
          'fileName': fileName,
          'localPath': savePath,
        });
      }
    }

    return downloaded;
  }

  /// 标记邮件为已读
  Future<void> markSeen(int seq) async {
    _tag = _nextTag();
    await _sendCommand('$TAG STORE $seq +FLAGS (\\SEEN)');
    await _readResponse();
  }

  /// 登出
  Future<void> logout() async {
    _tag = _nextTag();
    await _sendCommand('$TAG LOGOUT');
    await _readResponse();
    await _socket?.close();
    _socket = null;
  }

  // ========== 内部方法 ==========

  String get TAG => _tag;

  String _nextTag() => 'a${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  Future<void> _sendCommand(String cmd) async {
    _socket?.write('$cmd\r\n');
    await _socket?.flush();
  }

  Future<List<String>> _readResponse() async {
    final lines = <String>[];
    while (true) {
      final line = await _readLine();
      if (line == null) break;
      lines.add(line);
      if (line.startsWith(_tag) || line.startsWith('$TAG OK') || line.startsWith('$TAG NO') || line.startsWith('$TAG BAD')) {
        break;
      }
      // 处理多行响应 (FETCH 等)
      if (line.startsWith('* ') && line.contains('FETCH')) {
        // FETCH 响应可能跨多行，继续读取
        if (!line.endsWith(')')) {
          while (true) {
            final inner = await _readLine();
            if (inner == null) break;
            lines.add(inner);
            if (inner.endsWith(')')) break;
          }
        }
      }
    }
    return lines;
  }

  Future<Uint8List?> _readBinaryResponse() async {
    // 读取到换行
    final header = await _readLine();
    if (header == null) return null;

    // 检查是否有 {size} 格式
    final m = RegExp(r'\{(\d+)\}$').firstMatch(header);
    if (m == null) return null;

    final size = int.parse(m.group(1)!);
    // 读取二进制数据
    final completer = Completer<Uint8List>();
    final bytes = <int>[];
    var remaining = size;

    _socket?.listen(
      (data) {
        bytes.addAll(data);
        remaining -= data.length;
        if (remaining <= 0) {
          completer.complete(Uint8List.fromList(bytes.take(size).toList()));
        }
      },
      onError: (e) => completer.completeError(e),
    );

    // 用超时防止卡死
    final result = await completer.future.timeout(const Duration(seconds: 30));
    // 读取尾部换行和响应
    await _readLine(); // 换行
    await _readLine(); // TAG OK
    return result;
  }

  Future<String?> _readLine() async {
    try {
      final socket = _socket;
      if (socket == null) return null;
      final line = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first;
      return line;
    } catch (_) {
      return null;
    }
  }

  String _decodeMimeHeader(String raw) {
    // 解码 =?UTF-8?B?...?= 格式
    final m = RegExp(r'=\?([^?]+)\?([^?])\?([^?]*)\?=').firstMatch(raw);
    if (m != null) {
      final charset = m.group(1)!;
      final encoding = m.group(2)!;
      final data = m.group(3)!;
      if (encoding == 'B' || encoding == 'b') {
        try {
          return utf8.decode(base64.decode(data));
        } catch (_) {
          return raw;
        }
      }
    }
    return raw;
  }

  String _monthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

/// 邮件服务 — IMAP 收件 + SMTP 发件
class EmailService {
  EmailConfig? _config;

  bool get isConfigured => _config != null;

  void configure(EmailConfig config) {
    _config = config;
  }

  EmailConfig? get config => _config;

  /// 保存邮箱配置（含安全存储）
  /// 供邮箱配置页面调用
  Future<void> saveConfig({
    required String email,
    required String password,
    required String imapServer,
    String? sendTo,
  }) async {
    configure(EmailConfig(
      email: email,
      password: password,
      imapServer: imapServer,
      sendTo: sendTo,
    ));
  }

  /// 验证邮箱连接（通过 SMTP）
  Future<bool> verifyConnection(String email, String password, String imapServer, int imapPort) async {
    try {
      final smtpServer = getSmtpServer(email, password);
      await checkCredentials(smtpServer);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 检查邮箱并下载发票
  /// 返回新下载的附件列表
  Future<List<DownloadedInvoice>> checkAndDownloadInvoices(String downloadDir) async {
    if (_config == null) return [];

    final invoices = <DownloadedInvoice>[];

    try {
      final imap = _ImapClient();
      await imap.connect(_config!.imapServer, _config!.imapPort);
      final loggedIn = await imap.login(_config!.email, _config!.password);
      if (!loggedIn) return invoices;

      await imap.selectInbox();

      // 搜索最近7天的邮件（发票通常近期内到达）
      final since = DateTime.now().subtract(const Duration(days: 7));
      final seqs = await imap.searchSince(since);

      for (final seq in seqs) {
        final seqNum = int.tryParse(seq);
        if (seqNum == null) continue;

        // 获取邮件主题和日期
        final envelope = await imap.fetchEnvelope(seqNum);
        final subject = envelope['subject'] ?? '';
        final dateStr = envelope['date'] ?? '';

        // 判断是否可能包含发票（主题含"发票"、"invoice"等关键字）
        final isInvoice = subject.contains('发票') ||
            subject.contains('invoice') ||
            subject.contains('Invoice') ||
            subject.contains('电子票据') ||
            subject.contains('开票');

        if (!isInvoice) continue;

        // 下载附件
        final attachments = await imap.fetchAttachments(seqNum, downloadDir);
        for (final att in attachments) {
          invoices.add(DownloadedInvoice(
            fileName: att['fileName'] as String,
            localPath: att['localPath'] as String,
            subject: subject,
            date: DateTime.now(), // 简化处理
          ));
        }

        // 标记为已读
        await imap.markSeen(seqNum);
      }

      await imap.logout();
    } catch (_) {
      // IMAP 失败时静默处理，下次再试
    }

    return invoices;
  }

  /// SMTP 服务器配置
  SmtpServer getSmtpServer(String email, String password) {
    if (email.contains('qq.com')) {
      return SmtpServer('smtp.qq.com', username: email, password: password, port: 465, ssl: true);
    }
    if (email.contains('163.com')) {
      return SmtpServer('smtp.163.com', username: email, password: password, port: 465, ssl: true);
    }
    if (email.contains('outlook.com') || email.contains('hotmail.com')) {
      return SmtpServer('smtp.office365.com', username: email, password: password, port: 587, ssl: false);
    }
    if (email.contains('gmail.com')) {
      return SmtpServer('smtp.gmail.com', username: email, password: password, port: 587, ssl: false);
    }
    return SmtpServer('smtp.${email.split('@').last}', username: email, password: password, port: 465, ssl: true);
  }

  /// 获取 IMAP 服务器地址
  String getImapServer(String email) {
    if (email.contains('qq.com')) return 'imap.qq.com';
    if (email.contains('163.com')) return 'imap.163.com';
    if (email.contains('outlook.com') || email.contains('hotmail.com')) return 'outlook.office365.com';
    if (email.contains('gmail.com')) return 'imap.gmail.com';
    return 'imap.${email.split('@').last}';
  }

  int getImapPort(String email) => 993;

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
          message.attachments.add(FileAttachment(File(path)));
        }
      }

      await send(message, smtpServer);
      return true;
    } catch (_) {
      return false;
    }
  }
}


