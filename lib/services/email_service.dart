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
    _socket = await SecureSocket.connect(
      host,
      port,
      timeout: const Duration(seconds: 15),
    );
    // 读取欢迎信息
    await _readResponse();
  }

  /// 登录
  Future<bool> login(String email, String password) async {
    _tag = _nextTag();
    await _sendCommand('$tag LOGIN "$email" "$password"');
    final resp = await _readResponse();
    return resp.any((l) => l.startsWith('$tag OK'));
  }

  /// 选择邮箱
  Future<bool> selectInbox() async {
    _tag = _nextTag();
    await _sendCommand('$tag SELECT INBOX');
    final resp = await _readResponse();
    return resp.any((l) => l.startsWith('$tag OK'));
  }

  /// 搜索未读邮件
  Future<List<String>> searchUnseen() async {
    _tag = _nextTag();
    await _sendCommand('$tag SEARCH UNSEEN');
    final resp = await _readResponse();
    // 返回格式: * SEARCH 1 2 3
    for (final line in resp) {
      if (line.startsWith('* SEARCH')) {
        return line
            .replaceFirst('* SEARCH', '')
            .trim()
            .split(' ')
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  /// 搜索指定日期后的邮件
  Future<List<String>> searchSince(DateTime since) async {
    final dateStr =
        '${since.day.toString().padLeft(2, '0')}-${_monthAbbr(since.month)}-${since.year}';
    _tag = _nextTag();
    await _sendCommand('$tag SEARCH SINCE "$dateStr"');
    final resp = await _readResponse();
    for (final line in resp) {
      if (line.startsWith('* SEARCH')) {
        return line
            .replaceFirst('* SEARCH', '')
            .trim()
            .split(' ')
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  /// 获取邮件主题和日期
  Future<Map<String, String>> fetchEnvelope(int seq) async {
    _tag = _nextTag();
    await _sendCommand('$tag FETCH $seq (ENVELOPE INTERNALDATE)');
    final resp = await _readResponse();
    final result = <String, String>{};
    for (final line in resp) {
      if (line.contains('INTERNALDATE')) {
        final m = RegExp(
          r'"(\d{1,2}-[A-Za-z]{3}-\d{4}\s+\d{2}:\d{2}:\d{2}\s+[+\-]\d{4})"',
        ).firstMatch(line);
        if (m != null) result['date'] = m.group(1)!;
      }
      if (line.contains('ENVELOPE')) {
        // Subject is the 2nd field in ENVELOPE
        final m = RegExp(r'ENVELOPE\s*\([^)]*"([^"]*)"\s*\(').firstMatch(line);
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
  Future<List<Map<String, dynamic>>> fetchAttachments(
    int seq,
    String saveDir,
  ) async {
    final attachments = <Map<String, dynamic>>[];

    // 先获取 BODYSTRUCTURE 了解附件信息
    _tag = _nextTag();
    await _sendCommand('$tag FETCH $seq (BODYSTRUCTURE)');
    final bodyResp = await _readResponse();

    // 解析附件部分编号（如 1, 2, 1.1, 1.2 等）
    final bodyText = bodyResp.join('\n');
    // 简单解析：找 "("name" "filename.pdf")" 这种模式
    final nameRegex = RegExp(
      r'"([^"]+\.(?:pdf|jpg|jpeg|png|gif|bmp))"',
      caseSensitive: false,
    );
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
          attachments.add({'part': partNum, 'fileName': fileName});
        }
      }
    }

    // 下载每个附件
    final downloaded = <Map<String, dynamic>>[];
    for (final att in attachments) {
      final part = att['part'] as String;
      final fileName = att['fileName'] as String;

      _tag = _nextTag();
      await _sendCommand('$tag FETCH $seq (BODY[$part])');

      // 读取二进制附件数据
      final data = await _readBinaryResponse();
      if (data != null && data.isNotEmpty) {
        final savePath = '$saveDir/$fileName';
        await File(savePath).writeAsBytes(data);
        downloaded.add({'fileName': fileName, 'localPath': savePath});
      }
    }

    return downloaded;
  }

  /// 标记邮件为已读
  Future<void> markSeen(int seq) async {
    _tag = _nextTag();
    await _sendCommand('$tag STORE $seq +FLAGS (\\SEEN)');
    await _readResponse();
  }

  /// 登出
  Future<void> logout() async {
    _tag = _nextTag();
    await _sendCommand('$tag LOGOUT');
    await _readResponse();
    await _socket?.close();
    _socket = null;
  }

  // ========== 内部方法 ==========

  String get tag => _tag;

  String _nextTag() =>
      'a${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

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
      if (line.startsWith(_tag) ||
          line.startsWith('$tag OK') ||
          line.startsWith('$tag NO') ||
          line.startsWith('$tag BAD')) {
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

    _socket?.listen((data) {
      bytes.addAll(data);
      remaining -= data.length;
      if (remaining <= 0) {
        completer.complete(Uint8List.fromList(bytes.take(size).toList()));
      }
    }, onError: (e) => completer.completeError(e));

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
          .first
          .timeout(const Duration(seconds: 15));
      return line;
    } catch (_) {
      return null;
    }
  }

  String _decodeMimeHeader(String raw) {
    // 解码 =?UTF-8?B?...?= 格式
    final m = RegExp(r'=\?([^?]+)\?([^?])\?([^?]*)\?=').firstMatch(raw);
    if (m != null) {
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
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

/// 邮箱连接验证结果
class EmailConnectionResult {
  final bool isSuccess;
  final String message;

  const EmailConnectionResult._({
    required this.isSuccess,
    required this.message,
  });

  const EmailConnectionResult.success()
    : this._(isSuccess: true, message: '连接成功，邮箱配置正确');

  const EmailConnectionResult.failure(String message)
    : this._(isSuccess: false, message: message);
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
    configure(
      EmailConfig(
        email: email,
        password: password,
        imapServer: imapServer,
        sendTo: sendTo,
      ),
    );
  }

  /// 验证邮箱连接（通过 IMAP）
  Future<bool> verifyConnection(
    String email,
    String password,
    String imapServer,
    int imapPort,
  ) async {
    final result = await verifyConnectionDetailed(
      email,
      password,
      imapServer,
      imapPort,
    );
    return result.isSuccess;
  }

  /// 验证邮箱连接并返回具体失败原因
  Future<EmailConnectionResult> verifyConnectionDetailed(
    String email,
    String password,
    String imapServer,
    int imapPort,
  ) async {
    if (!email.contains('@') || email.split('@').last.isEmpty) {
      return const EmailConnectionResult.failure('邮箱格式不正确');
    }
    if (password.isEmpty) {
      return const EmailConnectionResult.failure('授权码不能为空');
    }

    final imap = _ImapClient();
    var connected = false;
    try {
      await imap.connect(imapServer, imapPort);
      connected = true;

      final loggedIn = await imap.login(email, password);
      if (!loggedIn) {
        return const EmailConnectionResult.failure(
          '登录失败，请检查授权码是否正确，或确认 IMAP 服务已开启',
        );
      }

      final inboxReady = await imap.selectInbox();
      if (!inboxReady) {
        return const EmailConnectionResult.failure(
          '已登录邮箱，但无法打开收件箱，请确认 IMAP 权限可用',
        );
      }

      return const EmailConnectionResult.success();
    } on SocketException {
      return const EmailConnectionResult.failure(
        '无法连接 IMAP 服务器，请检查服务器地址、端口和网络',
      );
    } on HandshakeException {
      return const EmailConnectionResult.failure(
        'IMAP SSL 连接失败，请确认端口为 993 且邮箱支持 SSL',
      );
    } on TimeoutException {
      return const EmailConnectionResult.failure('连接超时，请检查网络或邮箱 IMAP 服务是否开启');
    } catch (e) {
      return EmailConnectionResult.failure('连接异常: $e');
    } finally {
      if (connected) {
        try {
          await imap.logout().timeout(const Duration(seconds: 5));
        } catch (_) {
          // 验证结束时关闭失败不影响结果。
        }
      }
    }
  }

  /// 检查邮箱并下载发票
  /// 返回新下载的附件列表
  Future<List<DownloadedInvoice>> checkAndDownloadInvoices(
    String downloadDir,
  ) async {
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

        // 判断是否可能包含发票（主题含"发票"、"invoice"等关键字）
        final isInvoice =
            subject.contains('发票') ||
            subject.contains('invoice') ||
            subject.contains('Invoice') ||
            subject.contains('电子票据') ||
            subject.contains('开票');

        if (!isInvoice) continue;

        // 下载附件
        final attachments = await imap.fetchAttachments(seqNum, downloadDir);
        for (final att in attachments) {
          invoices.add(
            DownloadedInvoice(
              fileName: att['fileName'] as String,
              localPath: att['localPath'] as String,
              subject: subject,
              date: DateTime.now(), // 简化处理
            ),
          );
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
      return SmtpServer(
        'smtp.qq.com',
        username: email,
        password: password,
        port: 465,
        ssl: true,
      );
    }
    if (email.contains('163.com')) {
      return SmtpServer(
        'smtp.163.com',
        username: email,
        password: password,
        port: 465,
        ssl: true,
      );
    }
    if (email.contains('outlook.com') || email.contains('hotmail.com')) {
      return SmtpServer(
        'smtp.office365.com',
        username: email,
        password: password,
        port: 587,
        ssl: false,
      );
    }
    if (email.contains('gmail.com')) {
      return SmtpServer(
        'smtp.gmail.com',
        username: email,
        password: password,
        port: 587,
        ssl: false,
      );
    }
    return SmtpServer(
      'smtp.${email.split('@').last}',
      username: email,
      password: password,
      port: 465,
      ssl: true,
    );
  }

  /// 获取 IMAP 服务器地址
  String getImapServer(String email) {
    if (email.contains('qq.com')) return 'imap.qq.com';
    if (email.contains('163.com')) return 'imap.163.com';
    if (email.contains('outlook.com') || email.contains('hotmail.com')) {
      return 'outlook.office365.com';
    }
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
      final message =
          Message()
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
