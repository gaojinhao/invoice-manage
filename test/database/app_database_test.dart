import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/database/app_database.dart';
import 'package:invoice_app/database/tables.dart';

import '../helpers/mocks.dart';

/// Helper: create a record and return it
Future<ConsumptionRecord> _create(
  AppDatabase db, {
  DateTime? date,
  String merchant = '测试超市',
  double amount = 42.5,
  String? receiptImg,
  String? notes,
}) async {
  return db.createRecord(
    date: date ?? DateTime(2026, 6, 8),
    merchant: merchant,
    amount: amount,
    receiptImg: receiptImg,
    notes: notes,
  );
}

void main() {
  // ============================================================
  // Static method tests (no DB needed)
  // ============================================================
  group('AppDatabase — 状态推导 (static)', () {
    test('三证齐全时推导为 complete', () {
      final status = AppDatabase.statusForFiles(
        receiptImg: '/path/receipt.jpg',
        paymentImg: '/path/payment.jpg',
        invoicePdf: '/path/invoice.pdf',
      );
      expect(status, RecordStatus.complete);
    });

    test('只有发票没有支付记录时仍为 pendingPayment', () {
      final status = AppDatabase.statusForFiles(
        receiptImg: '/path/receipt.jpg',
        paymentImg: null,
        invoicePdf: '/path/invoice.pdf',
      );
      expect(status, RecordStatus.pendingPayment);
    });

    test('有支付记录但缺发票时为 pendingInvoice', () {
      final status = AppDatabase.statusForFiles(
        receiptImg: '/path/receipt.jpg',
        paymentImg: '/path/payment.jpg',
        invoicePdf: null,
      );
      expect(status, RecordStatus.pendingInvoice);
    });

    test('已归档记录保持 archived', () {
      final status = AppDatabase.effectiveStatusForRecord(
        makeRecord(
          status: RecordStatus.archived,
          receiptImg: '/path/receipt.jpg',
          paymentImg: '/path/payment.jpg',
          invoicePdf: '/path/invoice.pdf',
        ),
      );
      expect(status, RecordStatus.archived);
    });

    test('全为空时推导为 pendingPayment', () {
      final status = AppDatabase.statusForFiles(
        receiptImg: null,
        paymentImg: null,
        invoicePdf: null,
      );
      expect(status, RecordStatus.pendingPayment);
    });

    test('仅结账单推导为 pendingPayment（无支付记录）', () {
      final status = AppDatabase.statusForFiles(
        receiptImg: '/receipt.jpg',
        paymentImg: null,
        invoicePdf: null,
      );
      expect(status, RecordStatus.pendingPayment);
    });
  });

  // ============================================================
  // In-memory database tests (T3)
  // ============================================================
  group('AppDatabase — in-memory (createRecord)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.test();
    });

    tearDown(() async {
      await db.close();
    });

    test('创建记录返回正确数据', () async {
      final record = await _create(db, merchant: '华联超市', amount: 128.5);
      expect(record.merchant, '华联超市');
      expect(record.amount, 128.5);
      expect(record.status, RecordStatus.pendingPayment);
      expect(record.month, '2026-06');
      expect(record.id, isNotEmpty);
    });

    test('自动生成 month 字段（跨月）', () async {
      final r1 = await _create(db, date: DateTime(2026, 1, 15), merchant: '店A');
      final r2 = await _create(db, date: DateTime(2026, 12, 31), merchant: '店B');
      expect(r1.month, '2026-01');
      expect(r2.month, '2026-12');
    });

    test('可保存 receiptImg 和 notes', () async {
      final record = await _create(
        db,
        merchant: '测试店',
        receiptImg: '/path/photo.jpg',
        notes: '备注内容',
      );
      expect(record.receiptImg, '/path/photo.jpg');
      expect(record.notes, '备注内容');
    });
  });

  group('AppDatabase — in-memory (查询方法)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.test();
    });

    tearDown(() async {
      await db.close();
    });

    // --- getRecordsByMonth ---
    test('getRecordsByMonth 返回指定月份数据，按日期倒序', () async {
      await _create(db, date: DateTime(2026, 6, 1), merchant: '店A');
      await _create(db, date: DateTime(2026, 6, 15), merchant: '店B');
      await _create(db, date: DateTime(2026, 5, 20), merchant: '店C');

      final june = await db.getRecordsByMonth(2026, 6);
      expect(june.length, 2);
      // 按日期倒序：15 日在前
      expect(june[0].merchant, '店B');
      expect(june[1].merchant, '店A');
    });

    test('getRecordsByMonth 无数据返回空列表', () async {
      final result = await db.getRecordsByMonth(2026, 9);
      expect(result, isEmpty);
    });

    // --- getMonthlyTotal ---
    test('getMonthlyTotal 计算正确总额', () async {
      await _create(db, date: DateTime(2026, 6, 1), amount: 100);
      await _create(db, date: DateTime(2026, 6, 15), amount: 200);
      await _create(db, date: DateTime(2026, 5, 1), amount: 50);

      final total = await db.getMonthlyTotal(2026, 6);
      expect(total, 300.0);
    });

    test('getMonthlyTotal 无记录时返回 0.0', () async {
      final total = await db.getMonthlyTotal(2026, 9);
      expect(total, 0.0);
    });

    // --- getStatusCounts ---
    test('getStatusCounts 返回全局状态分布', () async {
      await _create(db, merchant: '店A'); // pendingPayment (default)
      await _create(db, merchant: '店B'); // pendingPayment
      final counts = await db.getStatusCounts();
      expect(counts[RecordStatus.pendingPayment], 2);
      expect(counts[RecordStatus.complete], 0);
    });

    // --- getStatusCountsByMonth ---
    test('getStatusCountsByMonth 仅统计指定月份', () async {
      await _create(db, date: DateTime(2026, 6, 1), merchant: '六月店');
      await _create(db, date: DateTime(2026, 5, 1), merchant: '五月店');

      final juneCounts = await db.getStatusCountsByMonth(2026, 6);
      final mayCounts = await db.getStatusCountsByMonth(2026, 5);
      expect(juneCounts[RecordStatus.pendingPayment], 1);
      expect(mayCounts[RecordStatus.pendingPayment], 1);
    });

    // --- getAllRecords ---
    test('getAllRecords 返回所有记录按日期倒序', () async {
      await _create(db, date: DateTime(2026, 6, 1), merchant: '早');
      await _create(db, date: DateTime(2026, 6, 15), merchant: '晚');
      await _create(db, date: DateTime(2026, 5, 20), merchant: '更早');

      final all = await db.getAllRecords();
      expect(all.length, 3);
      expect(all[0].merchant, '晚');   // 2026-06-15
      expect(all[1].merchant, '早');   // 2026-06-01
      expect(all[2].merchant, '更早'); // 2026-05-20
    });

    // --- getMonthlyTrend ---
    test('getMonthlyTrend 返回近 N 个月的趋势', () async {
      await _create(db, date: DateTime(2026, 6, 1), amount: 100);
      await _create(db, date: DateTime(2026, 5, 1), amount: 200);

      final trend = await db.getMonthlyTrend(3);
      expect(trend.length, 3);
      // 最后一项是当前月
      expect(trend.last.month, DateTime.now().month);
    });

    test('getMonthlyTrend monthsBack=0 返回空', () async {
      final trend = await db.getMonthlyTrend(0);
      expect(trend, isEmpty);
    });

    // --- searchRecords ---
    test('searchRecords 按商户名搜索', () async {
      await _create(db, merchant: '华联超市');
      await _create(db, merchant: '永辉超市');
      await _create(db, merchant: '华联便利店');

      final results = await db.searchRecords('华联');
      expect(results.length, 2);
    });

    test('searchRecords 按金额搜索', () async {
      await _create(db, merchant: '店A', amount: 128);
      await _create(db, merchant: '店B', amount: 256);

      final results = await db.searchRecords('128');
      expect(results.length, 1);
      expect(results.first.amount, 128);
    });

    test('searchRecords 按备注搜索', () async {
      await _create(db, merchant: '店A', notes: '商务午餐');
      await _create(db, merchant: '店B', notes: '个人消费');

      final results = await db.searchRecords('商务');
      expect(results.length, 1);
      expect(results.first.notes, '商务午餐');
    });

    test('searchRecords 空关键词返回空列表', () async {
      await _create(db, merchant: '店A');
      final results = await db.searchRecords('');
      expect(results, isEmpty);
    });

    test('searchRecords 无匹配返回空列表', () async {
      await _create(db, merchant: '店A');
      final results = await db.searchRecords('不存在的商户');
      expect(results, isEmpty);
    });

    // --- getRecordsNeedingPayment ---
    test('getRecordsNeedingPayment 只返回 paymentImg==null 的非归档记录', () async {
      final r = await _create(db, merchant: '缺支付');
      // 默认 paymentImg=null, status=pendingPayment
      final needs = await db.getRecordsNeedingPayment();
      expect(needs.any((x) => x.id == r.id), true);
    });

    // --- getRecordsNeedingInvoice ---
    test('getRecordsNeedingInvoice 返回有支付但缺发票的记录', () async {
      final r = await _create(db, merchant: '缺发票');
      await db.updatePaymentImage(r.id, '/pay.jpg');
      final needs = await db.getRecordsNeedingInvoice();
      expect(needs.any((x) => x.id == r.id), true);
    });

    // --- getCompleteRecords ---
    test('getCompleteRecords 只返回三证齐全的非归档记录', () async {
      final r = await _create(db, merchant: '齐全店', receiptImg: '/rec.jpg');
      await db.updatePaymentImage(r.id, '/pay.jpg');
      await db.updateInvoicePdf(r.id, '/inv.pdf');

      final complete = await db.getCompleteRecords();
      expect(complete.any((x) => x.id == r.id), true);
    });
  });

  // ============================================================
  // Mutation methods (real DB) — covers T1, T2, T8
  // ============================================================
  group('AppDatabase — in-memory (状态更新)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.test();
    });

    tearDown(() async {
      await db.close();
    });

    // --- updatePaymentImage ---
    test('updatePaymentImage 更新截图并重新计算状态', () async {
      final r = await _create(db, merchant: '测试店');
      expect(r.status, RecordStatus.pendingPayment);

      await db.updatePaymentImage(r.id, '/pay.jpg');
      final updated = await db.getRecordsByMonth(2026, 6);
      final record = updated.firstWhere((x) => x.id == r.id);
      expect(record.paymentImg, '/pay.jpg');
      // 有 receiptImg? null, paymentImg: yes, invoicePdf: null → pendingInvoice
      expect(record.status, RecordStatus.pendingInvoice);
    });

    test('updatePaymentImage — 记录不存在时不抛异常', () async {
      // Should not throw
      await db.updatePaymentImage('nonexistent', '/pay.jpg');
    });

    // --- updateReceiptImage (T1) ---
    test('updateReceiptImage 更新结账单并重新计算状态', () async {
      final r = await _create(db, merchant: '测试店');
      // 初始：receiptImg=null → pendingPayment
      expect(r.status, RecordStatus.pendingPayment);

      await db.updateReceiptImage(r.id, '/new_receipt.jpg');
      final updated = await db.getRecordsByMonth(2026, 6);
      final record = updated.firstWhere((x) => x.id == r.id);
      expect(record.receiptImg, '/new_receipt.jpg');
      // 仍为 pendingPayment（因为 paymentImg 仍为 null）
      expect(record.status, RecordStatus.pendingPayment);
    });

    test('updateReceiptImage — 三证齐全后变 complete', () async {
      final r = await _create(db, merchant: '测试店', receiptImg: '/old.jpg');
      // 先加支付记录 → pendingInvoice
      await db.updatePaymentImage(r.id, '/pay.jpg');
      // 再加发票 → complete
      await db.updateInvoicePdf(r.id, '/inv.pdf');
      // 替换 receiptImg
      await db.updateReceiptImage(r.id, '/new_receipt.jpg');

      final updated = await db.getRecordsByMonth(2026, 6);
      final record = updated.firstWhere((x) => x.id == r.id);
      expect(record.receiptImg, '/new_receipt.jpg');
      expect(record.status, RecordStatus.complete);
    });

    test('updateReceiptImage — 记录不存在时不抛异常', () async {
      await db.updateReceiptImage('nonexistent', '/rec.jpg');
    });

    // --- updateInvoicePdf ---
    test('updateInvoicePdf 更新发票并重新计算状态', () async {
      final r = await _create(db, merchant: '测试店', receiptImg: '/rec.jpg');
      await db.updatePaymentImage(r.id, '/pay.jpg'); // → pendingInvoice
      await db.updateInvoicePdf(r.id, '/inv.pdf');   // → complete

      final updated = await db.getRecordsByMonth(2026, 6);
      final record = updated.firstWhere((x) => x.id == r.id);
      expect(record.invoicePdf, '/inv.pdf');
      expect(record.status, RecordStatus.complete);
    });

    test('updateInvoicePdf — 记录不存在时不抛异常', () async {
      await db.updateInvoicePdf('nonexistent', '/inv.pdf');
    });

    // --- markArchived ---
    test('markArchived 标记为已归档', () async {
      final r = await _create(db, merchant: '待归档');
      await db.markArchived(r.id);

      final updated = await db.getRecordsByMonth(2026, 6);
      final record = updated.firstWhere((x) => x.id == r.id);
      expect(record.status, RecordStatus.archived);
    });

    // --- deleteRecord ---
    test('deleteRecord 删除指定记录', () async {
      final r = await _create(db, merchant: '待删除');
      await _create(db, merchant: '保留');

      await db.deleteRecord(r.id);
      final remaining = await db.getAllRecords();
      expect(remaining.length, 1);
      expect(remaining.first.merchant, '保留');
    });

    // --- deleteAllRecords (T2) ---
    test('deleteAllRecords 删除所有记录', () async {
      await _create(db, merchant: '店A');
      await _create(db, merchant: '店B');

      await db.deleteAllRecords();
      final all = await db.getAllRecords();
      expect(all, isEmpty);
    });
  });

  group('AppDatabase — in-memory (complete 流转)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.test();
    });

    tearDown(() async {
      await db.close();
    });

    test('完整三证补齐流程: pendingPayment → pendingInvoice → complete', () async {
      // Step 1: create with receipt only → pendingPayment
      final r = await _create(db, merchant: '流程测试', receiptImg: '/rec.jpg');
      expect(r.status, RecordStatus.pendingPayment);

      // Step 2: add payment → pendingInvoice
      await db.updatePaymentImage(r.id, '/pay.jpg');
      var cur = (await db.getAllRecords()).firstWhere((x) => x.id == r.id);
      expect(cur.status, RecordStatus.pendingInvoice);

      // Step 3: add invoice → complete
      await db.updateInvoicePdf(r.id, '/inv.pdf');
      cur = (await db.getAllRecords()).firstWhere((x) => x.id == r.id);
      expect(cur.status, RecordStatus.complete);

      // Step 4: archive
      await db.markArchived(r.id);
      cur = (await db.getAllRecords()).firstWhere((x) => x.id == r.id);
      expect(cur.status, RecordStatus.archived);
    });

    test('已归档记录不会在三证补齐后变回 complete', () async {
      final r = await _create(db, merchant: '归档测试', receiptImg: '/rec.jpg');
      await db.updatePaymentImage(r.id, '/pay.jpg');
      await db.updateInvoicePdf(r.id, '/inv.pdf');
      await db.markArchived(r.id);

      // 尝试再更新文件 → 仍保持 archived
      await db.updateReceiptImage(r.id, '/new_rec.jpg');
      var cur = (await db.getAllRecords()).firstWhere((x) => x.id == r.id);
      expect(cur.status, RecordStatus.archived);
    });
  });

  // T20: 边界值 + 组合查询
  group('AppDatabase — in-memory (T20 边界值/组合)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.test();
    });

    tearDown(() async {
      await db.close();
    });

    test('searchRecords — 金额字符串匹配时同时搜索商户名（OR逻辑）', () async {
      await _create(db, merchant: '华联超市', amount: 128.0);
      await _create(db, merchant: '永辉超市', amount: 256.0);

      // "128" 作为数字匹配 amount=128，也作为字符串匹配 merchant 包含"128"的
      final results = await db.searchRecords('128');
      expect(results.length, 1);
      expect(results.first.amount, 128.0);
    });

    test('searchRecords — 关键词同时匹配商户名和备注', () async {
      await _create(db, merchant: '华联超市', notes: '华联购物');
      await _create(db, merchant: '永辉超市', notes: '日用品');

      final results = await db.searchRecords('华联');
      expect(results.length, 1);
      expect(results.first.merchant, '华联超市');
    });

    test('getRecordsByMonth — 验证按日期倒序排列', () async {
      await _create(db, date: DateTime(2026, 6, 1), merchant: '最早');
      await _create(db, date: DateTime(2026, 6, 30), merchant: '最晚');
      await _create(db, date: DateTime(2026, 6, 15), merchant: '中间');

      final results = await db.getRecordsByMonth(2026, 6);
      expect(results.length, 3);
      expect(results[0].merchant, '最晚');
      expect(results[1].merchant, '中间');
      expect(results[2].merchant, '最早');
    });

    test('getMonthlyTotal — 单条记录即为自身金额', () async {
      await _create(db, amount: 42.5);
      final total = await db.getMonthlyTotal(2026, 6);
      expect(total, 42.5);
    });

    test('getMonthlyTrend — monthsBack=1 仅返回当前月', () async {
      await _create(db, amount: 100);
      final trend = await db.getMonthlyTrend(1);
      expect(trend.length, 1);
      expect(trend.first.total, 100);
    });
  });
}
