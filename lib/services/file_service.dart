import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

/// 文件管理服务
class FileService {
  /// 获取记录的文件目录：{base}/records/YYYY-MM/YYYY-MM-DD_商户名/
  Future<Directory> getRecordDir(DateTime date, String merchant) async {
    final base = await getApplicationDocumentsDirectory();
    final month =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
    final day =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final safeMerchant = merchant.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dir = Directory('${base.path}/records/$month/${day}_$safeMerchant');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 保存结账单照片
  Future<String> saveReceiptImage(
    File source,
    DateTime date,
    String merchant,
  ) async {
    final dir = await getRecordDir(date, merchant);
    final target = '${dir.path}/结账单.jpg';
    await source.copy(target);
    return target;
  }

  /// 保存支付记录截图
  Future<String> savePaymentImage(
    File source,
    DateTime date,
    String merchant,
  ) async {
    final dir = await getRecordDir(date, merchant);
    final target = '${dir.path}/支付记录.jpg';
    await source.copy(target);
    return target;
  }

  /// 保存发票 PDF
  Future<String> saveInvoicePdf(
    File source,
    DateTime date,
    String merchant,
  ) async {
    return saveInvoiceFile(source, date, merchant, extension: '.pdf');
  }

  /// 保存发票文件（PDF 或图片）
  Future<String> saveInvoiceFile(
    File source,
    DateTime date,
    String merchant, {
    String? extension,
  }) async {
    final dir = await getRecordDir(date, merchant);
    final ext = _normalizeExtension(
      extension ?? _extensionOf(source.path, fallback: '.pdf'),
    );
    final target = '${dir.path}/发票$ext';
    if (source.path != target) {
      await _deleteInvoiceFiles(dir);
      await source.copy(target);
    }
    return target;
  }

  /// 获取某月的所有记录目录
  Future<List<Directory>> getMonthRecordDirs(int year, int month) async {
    final base = await getApplicationDocumentsDirectory();
    final monthStr =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final monthDir = Directory('${base.path}/records/$monthStr');
    if (!await monthDir.exists()) return [];
    final entities = await monthDir.list().toList();
    return entities.whereType<Directory>().toList();
  }

  /// 打包某月的完整记录为 ZIP
  Future<String?> zipMonthRecords(int year, int month) async {
    final base = await getApplicationDocumentsDirectory();
    final monthStr =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final monthDir = Directory('${base.path}/records/$monthStr');

    if (!await monthDir.exists()) return null;

    final encoder = ZipEncoder();
    final archive = Archive();
    var hasFiles = false;

    await for (final entity in monthDir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = entity.path.replaceFirst('${monthDir.path}/', '');
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        hasFiles = true;
      }
    }

    if (!hasFiles) return null;

    final zipBytes = encoder.encode(archive);

    final zipDir = await getApplicationDocumentsDirectory();
    final zipPath = '${zipDir.path}/records/${monthStr}_报销文件.zip';
    await File(zipPath).writeAsBytes(zipBytes);
    return zipPath;
  }

  /// 只打包指定记录中的现有文件。
  Future<String?> zipRecords(
    int year,
    int month,
    List<ConsumptionRecord> records, {
    String? outputName,
  }) async {
    if (records.isEmpty) return null;

    final encoder = ZipEncoder();
    final archive = Archive();
    final folderCounts = <String, int>{};
    var hasFiles = false;

    for (final record in records) {
      final baseFolder = _recordFolderName(record);
      final count = (folderCounts[baseFolder] ?? 0) + 1;
      folderCounts[baseFolder] = count;
      final folder = count == 1 ? baseFolder : '${baseFolder}_$count';

      final files = <({String label, String? path})>[
        (label: '结账单', path: record.receiptImg),
        (label: '支付记录', path: record.paymentImg),
        (label: '发票', path: record.invoicePdf),
      ];

      for (final item in files) {
        final path = item.path;
        if (path == null) continue;
        final file = File(path);
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        final ext = _extensionOf(path, fallback: '');
        archive.addFile(
          ArchiveFile('$folder/${item.label}$ext', bytes.length, bytes),
        );
        hasFiles = true;
      }
    }

    if (!hasFiles) return null;

    final zipBytes = encoder.encode(archive);

    final base = await getApplicationDocumentsDirectory();
    final monthStr =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final zipDir = Directory('${base.path}/records');
    if (!await zipDir.exists()) {
      await zipDir.create(recursive: true);
    }
    final zipPath = '${zipDir.path}/${outputName ?? '${monthStr}_报销文件.zip'}';
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

  /// 删除全部记录文件
  Future<void> deleteAllRecordFiles() async {
    final base = await getApplicationDocumentsDirectory();
    final recordsDir = Directory('${base.path}/records');
    if (await recordsDir.exists()) {
      await recordsDir.delete(recursive: true);
    }
  }

  Future<void> _deleteInvoiceFiles(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('发票.')) {
          await entity.delete();
        }
      }
    }
  }

  String _recordFolderName(ConsumptionRecord record) {
    final day =
        '${record.date.year.toString().padLeft(4, '0')}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}';
    final safeMerchant = record.merchant.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    return '${day}_$safeMerchant';
  }

  String _extensionOf(String path, {required String fallback}) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return fallback;
    return _normalizeExtension(name.substring(dot));
  }

  String _normalizeExtension(String ext) {
    final normalized =
        ext.startsWith('.') ? ext.toLowerCase() : '.${ext.toLowerCase()}';
    return normalized.replaceAll(RegExp(r'[^a-z0-9.]'), '');
  }
}
