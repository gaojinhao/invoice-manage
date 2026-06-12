import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:invoice_app/database/tables.dart';
import 'package:invoice_app/services/export_service.dart';

import '../helpers/mocks.dart';

/// Creates a temp directory for the baseDirectory injection.
Future<Directory> _tempBase() async {
  final tmp = await Directory.systemTemp.createTemp('export_test_');
  return tmp;
}

void main() {
  group('ExportService — exportCsv', () {
    late MockAppDatabase mockDb;
    late ExportService svc;
    late Directory base;

    setUp(() async {
      mockDb = MockAppDatabase();
      base = await _tempBase();
      svc = ExportService(mockDb)..baseDirectory = () async => base;
    });

    test('空记录时导出仅含表头', () async {
      when(() => mockDb.getAllRecords()).thenAnswer((_) async => []);

      final path = await svc.exportCsv();
      final content = await File(path).readAsString();

      expect(content, contains('日期,商户名,金额,状态,结账单,支付记录,发票,备注,创建时间'));
      // 只有表头行，无数据行
      final lines = content.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines.length, 1);
    });

    test('单条记录导出正确格式', () async {
      when(() => mockDb.getAllRecords()).thenAnswer(
        (_) async => [
          makeRecord(
            id: 'r1',
            date: DateTime(2026, 6, 8),
            merchant: '华联超市',
            amount: 128.5,
            status: RecordStatus.complete,
            receiptImg: '/rec.jpg',
            paymentImg: '/pay.jpg',
            invoicePdf: '/inv.pdf',
            notes: '商务午餐',
            month: '2026-06',
          ),
        ],
      );

      final path = await svc.exportCsv();
      final content = await File(path).readAsString();

      expect(content, contains('2026-06-08'));
      expect(content, contains('华联超市'));
      expect(content, contains('128.5'));
      expect(content, contains('三证齐全'));
      expect(content, contains('商务午餐'));
    });

    test('多条记录导出多行', () async {
      when(() => mockDb.getAllRecords()).thenAnswer(
        (_) async => [
          makeRecord(id: 'r1', merchant: '店A'),
          makeRecord(id: 'r2', merchant: '店B'),
          makeRecord(id: 'r3', merchant: '店C'),
        ],
      );

      final path = await svc.exportCsv();
      final content = await File(path).readAsString();
      final lines = content.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines.length, 4); // 表头 + 3 条记录
    });

    test('商户名含双引号时正确转义', () async {
      when(
        () => mockDb.getAllRecords(),
      ).thenAnswer((_) async => [makeRecord(merchant: '华联"旗舰"超市')]);

      final path = await svc.exportCsv();
      final content = await File(path).readAsString();

      // 双引号应转为两个双引号
      expect(content, contains('华联""旗舰""超市'));
    });

    test('备注含双引号和逗号时正确转义', () async {
      when(() => mockDb.getAllRecords()).thenAnswer(
        (_) async => [makeRecord(merchant: '店A', notes: '备注含"引号",和逗号')],
      );

      final path = await svc.exportCsv();
      final content = await File(path).readAsString();

      // 双引号被转义，逗号在引号字段内不影响
      expect(content, contains('备注含""引号"",和逗号'));
    });

    test('null 字段导出为空字符串', () async {
      when(() => mockDb.getAllRecords()).thenAnswer(
        (_) async => [
          makeRecord(
            id: 'r1',
            merchant: '店',
            receiptImg: null,
            paymentImg: null,
            invoicePdf: null,
            notes: null,
          ),
        ],
      );

      final path = await svc.exportCsv();
      final content = await File(path).readAsString();

      // null 字段位置应有空引号对
      expect(content, contains('""'));
    });

    test('不同状态正确映射为中文', () async {
      when(() => mockDb.getAllRecords()).thenAnswer(
        (_) async => [
          makeRecord(id: 'r1', status: RecordStatus.pendingPayment),
          makeRecord(id: 'r2', status: RecordStatus.pendingInvoice),
          makeRecord(id: 'r3', status: RecordStatus.complete),
          makeRecord(id: 'r4', status: RecordStatus.archived),
        ],
      );

      final path = await svc.exportCsv();
      final content = await File(path).readAsString();

      expect(content, contains('待补支付'));
      expect(content, contains('待开发票'));
      expect(content, contains('三证齐全'));
      expect(content, contains('已归档'));
    });
  });

  group('ExportService — backupDatabase', () {
    late MockAppDatabase mockDb;
    late ExportService svc;
    late Directory base;

    setUp(() async {
      mockDb = MockAppDatabase();
      base = await _tempBase();
      svc = ExportService(mockDb)..baseDirectory = () async => base;
    });

    test('数据库文件存在时创建备份', () async {
      // 先创建假的 invoice_app.db
      final srcFile = File('${base.path}/invoice_app.db');
      await srcFile.writeAsString('fake-db-content');

      final dstPath = await svc.backupDatabase();
      expect(dstPath, contains('backups/invoice_app_'));
      expect(await File(dstPath).exists(), true);
      expect(await File(dstPath).readAsString(), 'fake-db-content');
    });

    test('数据库文件不存在时仍返回目标路径（不抛异常）', () async {
      // 没有 invoice_app.db 文件
      final dstPath = await svc.backupDatabase();
      expect(dstPath, contains('backups/invoice_app_'));
      // 目标文件不应存在（因为源不存在）
      expect(await File(dstPath).exists(), false);
    });
  });
}
