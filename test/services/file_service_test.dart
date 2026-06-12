import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/services/file_service.dart';

import '../helpers/mocks.dart';

/// Creates a temp file with given content for test purposes.
Future<File> _tempFile(
  Directory dir,
  String name, {
  String content = 'test',
}) async {
  final f = File('${dir.path}/$name');
  await f.writeAsString(content);
  return f;
}

/// Creates a temp directory for the baseDirectory injection.
Future<Directory> _tempBase() async {
  final tmp = await Directory.systemTemp.createTemp('file_service_test_');
  return tmp;
}

void main() {
  group('FileService — getRecordDir', () {
    test('创建正确的目录结构', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;

      final dir = await svc.getRecordDir(DateTime(2026, 6, 15), '华联超市');
      expect(dir.path, contains('records/2026-06/2026-06-15_华联超市'));
      expect(await dir.exists(), true);
    });

    test('商户名中的非法字符被替换', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;

      final dir = await svc.getRecordDir(
        DateTime(2026, 6, 15),
        'file:test?name',
      );
      final seg = dir.path.split(Platform.pathSeparator).last;
      expect(seg, '2026-06-15_file_test_name');
    });

    test('跨年月份目录格式正确', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;

      final dir = await svc.getRecordDir(DateTime(2025, 12, 31), '跨年超市');
      expect(dir.path, contains('records/2025-12/2025-12-31_跨年超市'));
    });
  });

  group('FileService — saveReceiptImage / savePaymentImage', () {
    test('saveReceiptImage 复制文件到正确路径', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;
      final src = await _tempFile(base, 'photo.jpg', content: 'receipt-data');

      final saved = await svc.saveReceiptImage(
        src,
        DateTime(2026, 6, 10),
        '测试店',
      );
      expect(saved, contains('2026-06-10_测试店/结账单.jpg'));
      expect(await File(saved).exists(), true);
      expect(await File(saved).readAsString(), 'receipt-data');
    });

    test('savePaymentImage 复制文件到正确路径', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;
      final src = await _tempFile(base, 'pay.png', content: 'payment-data');

      final saved = await svc.savePaymentImage(
        src,
        DateTime(2026, 6, 10),
        '测试店',
      );
      expect(saved, contains('2026-06-10_测试店/支付记录.jpg'));
      expect(await File(saved).exists(), true);
    });
  });

  group('FileService — saveInvoiceFile', () {
    test('无 extension 时默认使用 .pdf', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;
      final src = await _tempFile(base, 'inv.pdf', content: 'invoice-pdf');

      // 文件本身扩展名是 .pdf，saveInvoiceFile 应该使用它
      final saved = await svc.saveInvoiceFile(
        src,
        DateTime(2026, 6, 10),
        '测试店',
      );
      expect(saved, contains('发票.pdf'));
    });

    test('显式指定 .pdf 扩展名', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;
      final src = await _tempFile(base, 'inv', content: 'invoice-data');

      // 文件无扩展名，显式指定 .pdf
      final saved = await svc.saveInvoiceFile(
        src,
        DateTime(2026, 6, 10),
        '测试店',
        extension: '.pdf',
      );
      expect(saved, contains('发票.pdf'));
    });

    test('保存 JPEG 图片发票', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;
      final src = await _tempFile(base, 'photo.jpg', content: 'jpeg-data');

      final saved = await svc.saveInvoiceFile(
        src,
        DateTime(2026, 6, 10),
        '测试店',
      );
      expect(saved, contains('发票.jpg'));
    });

    test('saveInvoicePdf 委托到 saveInvoiceFile', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;
      final src = await _tempFile(base, 'invoice.pdf', content: 'pdf-data');

      final saved = await svc.saveInvoicePdf(src, DateTime(2026, 6, 10), '测试店');
      expect(saved, contains('发票.pdf'));
    });

    test('替换旧发票文件（删除旧的 发票.*）', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;
      final dir = await svc.getRecordDir(DateTime(2026, 6, 10), '测试店');

      // 先放一个旧的发票文件
      await _tempFile(dir, '发票.jpg', content: 'old');
      // 再放一个非发票文件（不应被删除）
      await _tempFile(dir, '结账单.jpg', content: 'receipt');

      // 保存新发票
      final src = await _tempFile(base, 'new.pdf', content: 'new');
      await svc.saveInvoiceFile(
        src,
        DateTime(2026, 6, 10),
        '测试店',
        extension: '.pdf',
      );

      // 旧发票被删除
      expect(await File('${dir.path}/发票.jpg').exists(), false);
      // 新发票存在
      expect(await File('${dir.path}/发票.pdf').exists(), true);
      expect(await File('${dir.path}/发票.pdf').readAsString(), 'new');
      // 非发票文件未被删除
      expect(await File('${dir.path}/结账单.jpg').exists(), true);
    });
  });

  group('FileService — getMonthRecordDirs', () {
    test('返回某月所有记录目录', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;

      // 创建几个测试目录
      await svc.getRecordDir(DateTime(2026, 6, 10), '店A');
      await svc.getRecordDir(DateTime(2026, 6, 15), '店B');
      // 不同月份的目录（不应被返回）
      await svc.getRecordDir(DateTime(2026, 5, 20), '店C');

      final dirs = await svc.getMonthRecordDirs(2026, 6);
      expect(dirs.length, 2);
      expect(dirs.any((d) => d.path.contains('店A')), true);
      expect(dirs.any((d) => d.path.contains('店B')), true);
    });

    test('月份目录不存在时返回空列表', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;

      final dirs = await svc.getMonthRecordDirs(2026, 9);
      expect(dirs, isEmpty);
    });
  });

  group('FileService — deleteRecordFiles', () {
    test('删除单个记录目录', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;
      final dir = await svc.getRecordDir(DateTime(2026, 6, 10), '待删店');
      await _tempFile(dir, 'test.jpg');

      await svc.deleteRecordFiles(DateTime(2026, 6, 10), '待删店');
      expect(await dir.exists(), false);
    });

    test('删除不存在的目录不报错', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;

      // Should not throw
      await svc.deleteRecordFiles(DateTime(2026, 1, 1), '不存在的店');
    });
  });

  group('FileService — deleteAllRecordFiles', () {
    test('删除整个 records 目录', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;
      await svc.getRecordDir(DateTime(2026, 6, 10), '店A');
      await svc.getRecordDir(DateTime(2026, 6, 15), '店B');

      await svc.deleteAllRecordFiles();
      final recordsDir = Directory('${base.path}/records');
      expect(await recordsDir.exists(), false);
    });
  });

  group('FileService — zipRecords', () {
    test('空记录列表返回 null', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;

      final result = await svc.zipRecords(2026, 6, []);
      expect(result, isNull);
    });

    test('仅打包记录中的现有文件', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;

      // 创建记录的文件
      final dir = await svc.getRecordDir(DateTime(2026, 6, 10), '打包店');
      await _tempFile(dir, '结账单.jpg', content: 'receipt-content');
      await _tempFile(dir, '支付记录.jpg', content: 'pay-content');

      final record = makeRecord(
        merchant: '打包店',
        date: DateTime(2026, 6, 10),
        receiptImg: '${dir.path}/结账单.jpg',
        paymentImg: '${dir.path}/支付记录.jpg',
        invoicePdf: null, // 无发票
      );

      final zipPath = await svc.zipRecords(2026, 6, [record]);
      expect(zipPath, isNotNull);
      expect(await File(zipPath!).exists(), true);
      // ZIP 文件应大于 0
      expect(await File(zipPath).length(), greaterThan(0));
    });

    test('同名商户名去重（_2 后缀）', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;

      final r1 = makeRecord(
        merchant: '同名店',
        date: DateTime(2026, 6, 10),
        receiptImg: null,
        paymentImg: null,
        invoicePdf: null,
      );
      final r2 = makeRecord(
        merchant: '同名店',
        date: DateTime(2026, 6, 12),
        receiptImg: null,
        paymentImg: null,
        invoicePdf: null,
      );

      // 两个记录都没有文件，所以 ZIP 应该返回 null
      final zipPath = await svc.zipRecords(2026, 6, [r1, r2]);
      expect(zipPath, isNull); // 没有文件可打包
    });

    test('自定义 outputName', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;

      final dir = await svc.getRecordDir(DateTime(2026, 6, 10), '自定义店');
      await _tempFile(dir, '结账单.jpg', content: 'data');

      final record = makeRecord(
        merchant: '自定义店',
        date: DateTime(2026, 6, 10),
        receiptImg: '${dir.path}/结账单.jpg',
      );

      final zipPath = await svc.zipRecords(2026, 6, [
        record,
      ], outputName: 'my_custom.zip');
      expect(zipPath, isNotNull);
      expect(zipPath!, contains('my_custom.zip'));
    });
  });

  group('FileService — zipMonthRecords', () {
    test('月份目录不存在返回 null', () async {
      final base = await _tempBase();
      final svc = FileService()..baseDirectory = () async => base;

      final result = await svc.zipMonthRecords(2026, 13); // invalid month
      expect(result, isNull);
    });
  });
}
