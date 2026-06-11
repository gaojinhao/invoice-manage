import 'dart:io';

import '../database/app_database.dart';
import 'email_service.dart';
import 'file_service.dart';
import 'notification_service.dart';
import 'invoice_matcher_service.dart';

/// 每日检查服务
/// 1. 检查缺支付记录 → 通知
/// 2. 检查邮箱下载发票 → 匹配
class DailyCheckService {
  final AppDatabase db;
  final EmailService emailService;
  final NotificationService notifier;
  final FileService fileService;

  DailyCheckService({
    required this.db,
    required this.emailService,
    required this.notifier,
    required this.fileService,
  });

  /// 执行每日检查
  /// 返回 (需要提醒的记录数, 新匹配的发票数)
  Future<(int, int)> run() async {
    // 任务1: 检查缺支付记录
    final missingCount = await _checkPendingPayment();

    // 任务2: 检查邮箱下载发票
    final invoiceCount = await _checkEmailInvoices();

    return (missingCount, invoiceCount);
  }

  /// 检查所有待补支付记录的消费
  Future<int> _checkPendingPayment() async {
    final pending = await db.getRecordsNeedingPayment();
    if (pending.isNotEmpty) {
      await notifier.showPaymentReminder(pending.length);
    }
    return pending.length;
  }

  /// 检查邮箱并匹配发票
  Future<int> _checkEmailInvoices() async {
    if (!emailService.isConfigured) return 0;

    try {
      // 创建临时下载目录
      final tempDir = Directory.systemTemp.createTempSync('invoices_');
      final downloadDir = tempDir.path;

      // 从邮箱下载发票
      final invoices = await emailService.checkAndDownloadInvoices(downloadDir);

      if (invoices.isEmpty) return 0;

      // 自动匹配到消费记录
      final matcher = InvoiceMatcherService(db, fileService, notifier);
      final matched = await matcher.runMatching(invoices);

      // 清理临时文件（保留已匹配的）
      for (final inv in invoices) {
        final file = File(inv.localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await tempDir.delete();

      return matched;
    } catch (_) {
      return 0;
    }
  }
}

/// 月初打包服务
/// 上月三证齐全的记录 → ZIP → 发邮件
class MonthlyPackService {
  final AppDatabase db;
  final EmailService emailService;
  final FileService fileService;
  final NotificationService notifier;

  MonthlyPackService({
    required this.db,
    required this.emailService,
    required this.notifier,
    required this.fileService,
  });

  /// 执行打包发送
  /// 返回打包的记录数
  Future<int> run() async {
    final now = DateTime.now();
    // 上个月
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final year = lastMonth.year;
    final month = lastMonth.month;
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';

    // 获取上个月"三证齐全"的记录
    final completeRecords = await db.getCompleteRecords();
    final recordsToPack =
        completeRecords.where((r) => r.month == monthStr).toList();

    if (recordsToPack.isEmpty) return 0;

    // ZIP 打包：只包含筛选出的三证齐全记录
    final zipPath = await fileService.zipRecords(year, month, recordsToPack);
    if (zipPath == null) return 0;

    // 发送邮件
    final targetEmail =
        emailService.config?.sendTo ?? emailService.config?.email ?? '';
    if (targetEmail.isEmpty) return 0;

    final sent = await emailService.sendEmail(
      to: targetEmail,
      subject: '$monthStr 报销文件',
      body:
          '您好，\n\n$year年$month月的报销文件已打包，共 ${recordsToPack.length} 条记录，请查收附件。\n\n---\n本邮件由报销文件管理 App 自动发送',
      attachmentPaths: [zipPath],
    );

    if (sent) {
      // 标记所有记录为已归档
      for (final record in recordsToPack) {
        await db.markArchived(record.id);
      }

      // 发送通知
      await notifier.showMonthlyReportSent(monthStr);
    }

    return recordsToPack.length;
  }
}
