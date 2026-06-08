import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

/// 文件管理服务
class FileService {
  /// 获取记录的文件目录：{base}/records/YYYY-MM/YYYY-MM-DD_商户名/
  Future<Directory> getRecordDir(DateTime date, String merchant) async {
    final base = await getApplicationDocumentsDirectory();
    final month = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
    final day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final safeMerchant = merchant.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dir = Directory('${base.path}/records/$month/${day}_$safeMerchant');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 保存结账单照片
  Future<String> saveReceiptImage(File source, DateTime date, String merchant) async {
    final dir = await getRecordDir(date, merchant);
    final target = '${dir.path}/结账单.jpg';
    await source.copy(target);
    return target;
  }

  /// 保存支付记录截图
  Future<String> savePaymentImage(File source, DateTime date, String merchant) async {
    final dir = await getRecordDir(date, merchant);
    final target = '${dir.path}/支付记录.jpg';
    await source.copy(target);
    return target;
  }

  /// 保存发票 PDF
  Future<String> saveInvoicePdf(File source, DateTime date, String merchant) async {
    final dir = await getRecordDir(date, merchant);
    final target = '${dir.path}/发票.pdf';
    await source.copy(target);
    return target;
  }

  /// 获取某月的所有记录目录
  Future<List<Directory>> getMonthRecordDirs(int year, int month) async {
    final base = await getApplicationDocumentsDirectory();
    final monthStr = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final monthDir = Directory('${base.path}/records/$monthStr');
    if (!await monthDir.exists()) return [];
    return monthDir.list().whereType<Directory>().toList();
  }

  /// 打包某月的完整记录为 ZIP
  Future<String?> zipMonthRecords(int year, int month) async {
    final base = await getApplicationDocumentsDirectory();
    final monthStr = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final monthDir = Directory('${base.path}/records/$monthStr');

    if (!await monthDir.exists()) return null;

    final encoder = ZipEncoder();
    final archive = Archive();

    await for (final entity in monthDir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = entity.path.replaceFirst('${monthDir.path}/', '');
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }
    }

    final zipBytes = encoder.encode(archive);
    if (zipBytes == null) return null;

    final zipDir = await getApplicationDocumentsDirectory();
    final zipPath = '${zipDir.path}/records/${monthStr}_报销文件.zip';
    await File(zipPath).writeAsBytes(zipBytes);
    return zipPath;
  }

  /// 删除单个记录的文件
  Future<void> deleteRecordFiles(DateTime date, String merchant) async {
    final dir = await getRecordDir(date, merchant);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
