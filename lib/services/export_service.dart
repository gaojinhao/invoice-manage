import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';
import '../database/tables.dart';

/// 数据导出/备份服务
class ExportService {
  final AppDatabase db;

  /// 可注入的基础目录（用于测试），默认使用应用文档目录
  Future<Directory> Function() baseDirectory = getApplicationDocumentsDirectory;

  ExportService(this.db);

  /// 导出消费记录为 CSV
  /// 返回导出的文件路径
  Future<String> exportCsv() async {
    final allRecords = await db.getAllRecords();
    final dir = await baseDirectory();
    final now = DateTime.now();
    final path =
        '${dir.path}/exports/报销记录_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv';

    await Directory('${dir.path}/exports').create(recursive: true);

    final buffer = StringBuffer();
    // BOM 用于 Excel 正确识别 UTF-8 中文
    buffer.write('\uFEFF');
    buffer.writeln('日期,商户名,金额,状态,结账单,支付记录,发票,备注,创建时间');

    for (final r in allRecords) {
      final status = switch (r.status) {
        RecordStatus.pendingPayment => '待补支付',
        RecordStatus.pendingInvoice => '待开发票',
        RecordStatus.complete => '三证齐全',
        RecordStatus.archived => '已归档',
      };
      final date =
          '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
      buffer.writeln(
        '"$date","${_escapeCsv(r.merchant)}","${r.amount}","$status",'
        '"${_escapeCsv(r.receiptImg ?? '')}","${_escapeCsv(r.paymentImg ?? '')}",'
        '"${_escapeCsv(r.invoicePdf ?? '')}","${_escapeCsv(r.notes ?? '')}",'
        '"${r.createdAt}"',
      );
    }

    await File(path).writeAsString(buffer.toString());
    return path;
  }

  /// 备份数据库文件
  /// 返回备份文件路径
  Future<String> backupDatabase() async {
    final dir = await baseDirectory();
    final now = DateTime.now();
    final backupDir = '${dir.path}/backups';
    await Directory(backupDir).create(recursive: true);

    final src = File('${dir.path}/invoice_app.db');
    final dst =
        '$backupDir/invoice_app_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.db';

    if (await src.exists()) {
      await src.copy(dst);
    }
    return dst;
  }

  /// CSV 字段转义：双引号 → 两个双引号
  String _escapeCsv(String value) {
    return value.replaceAll('"', '""');
  }

  /// 分享文件（通过系统分享菜单）
  Future<void> shareFile(String path) async {
    final file = XFile(path);
    await Share.shareXFiles([file], text: '报销文件');
  }
}
