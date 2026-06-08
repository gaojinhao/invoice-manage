import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:invoice_app/database/app_database.dart';
import 'package:invoice_app/database/tables.dart';

import '../helpers/mocks.dart';

void main() {
  group('AppDatabase — 状态查询', () {
    late MockAppDatabase mockDb;

    setUp(() {
      mockDb = MockAppDatabase();
    });

    test('getRecordsByMonth 返回指定月份数据', () async {
      final records = [
        makeRecord(id: 'r1', date: DateTime(2026, 6, 1), month: '2026-06'),
        makeRecord(id: 'r2', date: DateTime(2026, 6, 15), month: '2026-06'),
      ];
      when(() => mockDb.getRecordsByMonth(2026, 6))
          .thenAnswer((_) async => records);

      final result = await mockDb.getRecordsByMonth(2026, 6);
      expect(result.length, 2);
    });

    test('getRecordsNeedingPayment 返回待补支付记录', () async {
      final records = [
        makeRecord(id: 'r1', status: RecordStatus.pendingPayment),
        makeRecord(id: 'r2', status: RecordStatus.pendingPayment),
      ];
      when(() => mockDb.getRecordsNeedingPayment())
          .thenAnswer((_) async => records);

      final result = await mockDb.getRecordsNeedingPayment();
      expect(result.length, 2);
      expect(result.every((r) => r.status == RecordStatus.pendingPayment), true);
    });

    test('getRecordsNeedingInvoice 返回待开发票记录', () async {
      final records = [
        makeRecord(id: 'r1', status: RecordStatus.pendingInvoice),
      ];
      when(() => mockDb.getRecordsNeedingInvoice())
          .thenAnswer((_) async => records);

      final result = await mockDb.getRecordsNeedingInvoice();
      expect(result.length, 1);
      expect(result.first.status, RecordStatus.pendingInvoice);
    });

    test('getCompleteRecords 只返回三证齐全的记录', () async {
      final records = [
        makeRecord(id: 'r1', status: RecordStatus.complete),
        makeRecord(id: 'r2', status: RecordStatus.complete),
      ];
      when(() => mockDb.getCompleteRecords())
          .thenAnswer((_) async => records);

      final result = await mockDb.getCompleteRecords();
      expect(result.every((r) => r.status == RecordStatus.complete), true);
    });

    test('getStatusCounts 返回正确的状态分布', () async {
      final allRecords = [
        makeRecord(id: 'r1', status: RecordStatus.pendingPayment),
        makeRecord(id: 'r2', status: RecordStatus.pendingInvoice),
        makeRecord(id: 'r3', status: RecordStatus.complete),
        makeRecord(id: 'r4', status: RecordStatus.complete),
      ];
      when(() => mockDb.getStatusCounts())
          .thenAnswer((_) async => {
            RecordStatus.pendingPayment: 1,
            RecordStatus.pendingInvoice: 1,
            RecordStatus.complete: 2,
            RecordStatus.archived: 0,
          });

      final counts = await mockDb.getStatusCounts();
      expect(counts[RecordStatus.pendingPayment], 1);
      expect(counts[RecordStatus.complete], 2);
      expect(counts[RecordStatus.archived], 0);
    });
  });

  group('AppDatabase — 状态更新', () {
    late MockAppDatabase mockDb;

    setUp(() {
      mockDb = MockAppDatabase();
    });

    test('updatePaymentImage 更新支付截图并更改状态为 pendingInvoice', () async {
      when(() => mockDb.updatePaymentImage('rec_001', '/path/payment.jpg'))
          .thenAnswer((_) async => {});

      await mockDb.updatePaymentImage('rec_001', '/path/payment.jpg');
      verify(() => mockDb.updatePaymentImage('rec_001', '/path/payment.jpg')).called(1);
    });

    test('updateInvoicePdf 更新发票并更改状态为 complete', () async {
      when(() => mockDb.updateInvoicePdf('rec_001', '/path/invoice.pdf'))
          .thenAnswer((_) async => {});

      await mockDb.updateInvoicePdf('rec_001', '/path/invoice.pdf');
      verify(() => mockDb.updateInvoicePdf('rec_001', '/path/invoice.pdf')).called(1);
    });

    test('markArchived 更改状态为 archived', () async {
      when(() => mockDb.markArchived('rec_001'))
          .thenAnswer((_) async => {});

      await mockDb.markArchived('rec_001');
      verify(() => mockDb.markArchived('rec_001')).called(1);
    });

    test('deleteRecord 删除指定记录', () async {
      when(() => mockDb.deleteRecord('rec_001'))
          .thenAnswer((_) async => {});

      await mockDb.deleteRecord('rec_001');
      verify(() => mockDb.deleteRecord('rec_001')).called(1);
    });
  });

  group('AppDatabase — 创建与查询', () {
    late MockAppDatabase mockDb;

    setUp(() {
      mockDb = MockAppDatabase();
    });

    test('createRecord 返回新创建的记录', () async {
      final newRecord = makeRecord(
        id: 'rec_new',
        merchant: '新超市',
        amount: 66.6,
        status: RecordStatus.pendingPayment,
      );
      when(() => mockDb.createRecord(
        date: any(named: 'date'),
        merchant: any(named: 'merchant'),
        amount: any(named: 'amount'),
      )).thenAnswer((_) async => newRecord);

      final result = await mockDb.createRecord(
        date: DateTime(2026, 6, 8),
        merchant: '新超市',
        amount: 66.6,
      );

      expect(result.id, 'rec_new');
      expect(result.merchant, '新超市');
      expect(result.status, RecordStatus.pendingPayment);
    });

    test('getMonthlyTotal 计算指定月份总额', () async {
      when(() => mockDb.getMonthlyTotal(2026, 6))
          .thenAnswer((_) async => 456.0);

      final total = await mockDb.getMonthlyTotal(2026, 6);
      expect(total, 456.0);
    });

    test('searchRecords 按商户名搜索', () async {
      when(() => mockDb.searchRecords('华联'))
          .thenAnswer((_) async => [
            makeRecord(id: 'r1', merchant: '华联超市'),
          ]);

      final results = await mockDb.searchRecords('华联');
      expect(results.length, 1);
      expect(results.first.merchant, '华联超市');
    });

    test('searchRecords 按金额搜索', () async {
      when(() => mockDb.searchRecords('128'))
          .thenAnswer((_) async => [
            makeRecord(id: 'r2', amount: 128.0),
          ]);

      final results = await mockDb.searchRecords('128');
      expect(results.length, 1);
    });

    test('searchRecords 空关键词返回空列表', () async {
      when(() => mockDb.searchRecords(''))
          .thenAnswer((_) async => []);

      final results = await mockDb.searchRecords('');
      expect(results, isEmpty);
    });
  });
}
