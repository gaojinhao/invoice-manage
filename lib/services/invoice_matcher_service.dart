import 'dart:io';

import '../database/app_database.dart';
import 'email_service.dart';
import 'file_service.dart';
import 'notification_service.dart';

/// 发票自动匹配服务
/// 将邮箱下载的发票自动匹配到对应的消费记录
class InvoiceMatcherService {
  final AppDatabase _db;
  final FileService _fileService;
  final NotificationService _notifier;

  InvoiceMatcherService(this._db, this._fileService, this._notifier);

  /// 执行一次完整的发票匹配流程
  /// 1. 获取所有"待开发票"的记录
  /// 2. 用文件名/主题尝试匹配
  /// 3. 返回匹配成功数
  Future<int> runMatching(List<DownloadedInvoice> invoices) async {
    if (invoices.isEmpty) return 0;

    final pendingRecords = await _db.getRecordsNeedingInvoice();
    if (pendingRecords.isEmpty) return 0;

    int matched = 0;

    for (final invoice in invoices) {
      // 尝试找到匹配的消费记录
      final record = _findBestMatch(invoice, pendingRecords);

      if (record != null) {
        // 保存发票到对应目录
        final source = File(invoice.localPath);
        final savedPath = await _fileService.saveInvoicePdf(
          source,
          record.date,
          record.merchant,
        );

        // 更新数据库
        await _db.updateInvoicePdf(record.id, savedPath);

        // 发送通知
        await _notifier.showInvoiceDownloaded(record.merchant, record.amount);

        matched++;
      }
    }

    return matched;
  }

  /// 从待匹配的记录中找到最佳匹配
  ConsumptionRecord? _findBestMatch(
    DownloadedInvoice invoice,
    List<ConsumptionRecord> candidates,
  ) {
    if (candidates.isEmpty) return null;

    // 策略1: 用主题中的金额匹配
    final amountInSubject = _extractAmountFromText(invoice.subject);

    // 策略2: 用文件名匹配
    final amountInFileName = _extractAmountFromText(invoice.fileName);
    final merchantInFileName = _extractMerchantFromText(invoice.fileName);

    // 评分候选记录
    final scored = <_MatchScore>[];

    for (final record in candidates) {
      double score = 0;

      // 金额匹配（最高权重）
      if (amountInSubject != null &&
          (record.amount - amountInSubject).abs() < 0.01) {
        score += 100;
      } else if (amountInFileName != null &&
          (record.amount - amountInFileName).abs() < 0.01) {
        score += 80;
      }

      // 商户名匹配
      if (merchantInFileName != null &&
          (record.merchant.contains(merchantInFileName) ||
              merchantInFileName.contains(record.merchant))) {
        score += 50;
      }

      // 日期接近度（发票通常和消费日期相近）
      final dayDiff = invoice.date.difference(record.date).inDays;
      if (dayDiff.abs() <= 3) score += 30;
      if (dayDiff.abs() <= 7) score += 10;

      // 主题包含商户名的关键词
      final merchantKeywords = record.merchant.split('');
      for (final keyword in merchantKeywords.where((k) => k.length >= 2)) {
        if (invoice.subject.contains(keyword)) {
          score += 20;
          break;
        }
      }

      scored.add(_MatchScore(record, score));
    }

    // 按评分排序，取最高分
    scored.sort((a, b) => b.score.compareTo(a.score));

    if (scored.isNotEmpty && scored.first.score >= 30) {
      return scored.first.record;
    }

    return null;
  }

  /// 从文本中提取金额
  double? _extractAmountFromText(String text) {
    final patterns = [
      RegExp(r'(\d+\.\d{2})'),
      RegExp(r'合计[：:\s]*(\d+\.?\d*)'),
      RegExp(r'金额[：:\s]*(\d+\.?\d*)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final val = double.tryParse(match.group(1)!);
        if (val != null && val > 0 && val < 100000) return val;
      }
    }
    return null;
  }

  /// 从文本中提取商户名
  String? _extractMerchantFromText(String text) {
    // 尝试提取文件名中的商户名（常见格式：商户名_日期.pdf）
    final match = RegExp(r'^([^_\d]+)').firstMatch(text);
    if (match != null) {
      final name = match.group(1)!.trim();
      if (name.length >= 2 && name.length <= 20) return name;
    }
    return null;
  }
}

class _MatchScore {
  final ConsumptionRecord record;
  final double score;
  _MatchScore(this.record, this.score);
}
