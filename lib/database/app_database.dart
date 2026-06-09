import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' hide Table;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// 数据库定义
@DriftDatabase(tables: [ConsumptionRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
  );

  /// 创建一条消费记录
  Future<ConsumptionRecord> createRecord({
    required DateTime date,
    required String merchant,
    required double amount,
    String? receiptImg,
    String? notes,
  }) async {
    final now = DateTime.now();
    final month = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
    final record = ConsumptionRecordsCompanion.insert(
      date: date,
      merchant: merchant,
      amount: amount,
      status: RecordStatus.pendingPayment,
      month: month,
      receiptImg: Value(receiptImg),
      notes: Value(notes),
      createdAt: now,
      updatedAt: now,
    );
    await into(consumptionRecords).insert(record);
    // 返回刚创建的记录（按时间最近的一条匹配）
    return (select(consumptionRecords)
      ..where((t) => t.merchant.equals(merchant))
      ..where((t) => t.date.equals(date))
      ..where((t) => t.amount.equals(amount))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
      ..limit(1)
    ).getSingle();
  }

  /// 查询某月的消费记录
  Future<List<ConsumptionRecord>> getRecordsByMonth(int year, int month) async {
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    return (select(consumptionRecords)
      ..where((t) => t.month.equals(monthStr))
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
    ).get();
  }

  /// 查询某月的消费总额
  Future<double> getMonthlyTotal(int year, int month) async {
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final records = await (select(consumptionRecords)
      ..where((t) => t.month.equals(monthStr))
    ).get();
    return records.fold<double>(0.0, (sum, r) => sum + r.amount);
  }

  /// 查询各状态的数量统计
  Future<Map<RecordStatus, int>> getStatusCounts() async {
    final all = await select(consumptionRecords).get();
    final counts = <RecordStatus, int>{};
    for (final status in RecordStatus.values) {
      counts[status] = all.where((r) => r.status == status).length;
    }
    return counts;
  }

  /// 获取所有"待补支付记录"的记录
  Future<List<ConsumptionRecord>> getRecordsNeedingPayment() async {
    return (select(consumptionRecords)
      ..where((t) => t.status.equals(RecordStatus.pendingPayment.name))
    ).get();
  }

  /// 获取所有"待开发票"的记录
  Future<List<ConsumptionRecord>> getRecordsNeedingInvoice() async {
    return (select(consumptionRecords)
      ..where((t) => t.status.equals(RecordStatus.pendingInvoice.name))
    ).get();
  }

  /// 获取所有"三证齐全"的记录
  Future<List<ConsumptionRecord>> getCompleteRecords() async {
    return (select(consumptionRecords)
      ..where((t) => t.status.equals(RecordStatus.complete.name))
    ).get();
  }

  /// 更新支付记录截图
  Future<void> updatePaymentImage(String id, String imagePath) async {
    final now = DateTime.now();
    await (update(consumptionRecords)..where((t) => t.id.equals(id))).write(
      ConsumptionRecordsCompanion(
        paymentImg: Value(imagePath),
        status: Value(RecordStatus.pendingInvoice),
        updatedAt: Value(now),
      ),
    );
  }

  /// 更新结账单照片
  Future<void> updateReceiptImage(String id, String imagePath) async {
    final now = DateTime.now();
    await (update(consumptionRecords)..where((t) => t.id.equals(id))).write(
      ConsumptionRecordsCompanion(
        receiptImg: Value(imagePath),
        updatedAt: Value(now),
      ),
    );
  }

  /// 更新发票文件
  Future<void> updateInvoicePdf(String id, String pdfPath) async {
    final now = DateTime.now();
    await (update(consumptionRecords)..where((t) => t.id.equals(id))).write(
      ConsumptionRecordsCompanion(
        invoicePdf: Value(pdfPath),
        status: Value(RecordStatus.complete),
        updatedAt: Value(now),
      ),
    );
  }

  /// 标记为已归档
  Future<void> markArchived(String id) async {
    final now = DateTime.now();
    await (update(consumptionRecords)..where((t) => t.id.equals(id))).write(
      ConsumptionRecordsCompanion(
        status: Value(RecordStatus.archived),
        updatedAt: Value(now),
      ),
    );
  }

  /// 删除记录
  Future<void> deleteRecord(String id) async {
    await (delete(consumptionRecords)..where((t) => t.id.equals(id))).go();
  }

  /// 获取所有记录（按日期倒序）
  Future<List<ConsumptionRecord>> getAllRecords() async {
    return (select(consumptionRecords)
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
    ).get();
  }

  /// 获取近 N 个月的月度总额趋势
  Future<List<({int year, int month, double total})>> getMonthlyTrend(
      int monthsBack) async {
    final now = DateTime.now();
    final results = <({int year, int month, double total})>[];
    for (var i = monthsBack - 1; i >= 0; i--) {
      final target = DateTime(now.year, now.month - i, 1);
      final total = await getMonthlyTotal(target.year, target.month);
      results.add((year: target.year, month: target.month, total: total));
    }
    return results;
  }

  /// 搜索消费记录（按商户名、金额、备注）
  Future<List<ConsumptionRecord>> searchRecords(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    // 尝试解析数字
    final amount = double.tryParse(q);
    return (select(consumptionRecords)
      ..where((t) {
        final conditions = <Expression<bool>>[
          t.merchant.contains(q),
          t.notes.contains(q),
        ];
        if (amount != null) {
          conditions.add(t.amount.equals(amount));
        }
        return conditions.reduce((a, b) => a | b);
      })
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
    ).get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    await Directory(dir.path).create(recursive: true);
    final file = File('${dir.path}/invoice_app.db');
    return NativeDatabase(file);
  });
}

/// Provider 包装，方便在 Widget 树中使用
class DatabaseProvider extends StatelessWidget {
  final Widget child;

  const DatabaseProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Provider<AppDatabase>(
      create: (_) => AppDatabase(),
      dispose: (_, db) => db.close(),
      child: child,
    );
  }
}
