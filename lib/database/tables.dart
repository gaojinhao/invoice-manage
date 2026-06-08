import 'package:drift/drift.dart';

/// 消费记录状态枚举
enum RecordStatus {
  /// 已创建结账单，待补支付记录
  pendingPayment,

  /// 已补支付记录，待开发票
  pendingInvoice,

  /// 三证齐全（结账单 + 支付记录 + 发票）
  complete,

  /// 已归档（月初已打包发送）
  archived,
}

/// 消费记录表
class ConsumptionRecords extends Table {
  TextColumn get id => text().clientDefault(() => _uuid())();

  DateTimeColumn get date => dateTime()();

  TextColumn get merchant => text()();

  RealColumn get amount => real()();

  TextColumn get status => textEnum<RecordStatus>()();

  /// 月份索引，格式 YYYY-MM
  TextColumn get month => text()();

  /// 结账单照片本地路径
  TextColumn? get receiptImg => text().nullable()();

  /// 支付记录截图本地路径
  TextColumn? get paymentImg => text().nullable()();

  /// 发票 PDF 本地路径
  TextColumn? get invoicePdf => text().nullable()();

  TextColumn? get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {date, merchant, amount},
  ];
}

String _uuid() {
  // 简单 UUID v4 生成（无外部依赖）
  final now = DateTime.now().millisecondsSinceEpoch;
  final r = (now ^ (now << 21) ^ (now >> 15)) & 0xFFFFFFFFFFFFFFFF;
  return '${r.toRadixString(16).padLeft(16, '0')}';
}
