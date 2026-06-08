import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../database/tables.dart';
import '../services/file_service.dart';
import '../services/notification_service.dart';
import 'camera_screen.dart';
import 'record_detail_screen.dart';
import 'email_config_screen.dart';

/// 首页 — 仪表盘 + 消费记录列表
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _currentMonth;
  List<ConsumptionRecord> _records = [];
  double _monthlyTotal = 0;
  Map<RecordStatus, int> _statusCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = context.read<AppDatabase>();
    final records = await db.getRecordsByMonth(_currentMonth.year, _currentMonth.month);
    final total = await db.getMonthlyTotal(_currentMonth.year, _currentMonth.month);
    final counts = await db.getStatusCounts();

    setState(() {
      _records = records;
      _monthlyTotal = total;
      _statusCounts = counts;
      _loading = false;
    });
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _loading = true;
    });
    _loadData();
  }

  void _nextMonth() {
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1);
    if (!next.isAfter(DateTime.now())) {
      setState(() {
        _currentMonth = next;
        _loading = true;
      });
      _loadData();
    }
  }

  Future<void> _dailyCheck() async {
    final db = context.read<AppDatabase>();
    final pending = await db.getRecordsNeedingPayment();
    if (pending.isNotEmpty) {
      await NotificationService().showPaymentReminder(pending.length);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('有 ${pending.length} 条记录缺少支付记录截图')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所有记录已齐全 ✓')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('报销文件管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _dailyCheck,
            tooltip: '每日检查',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmailConfigScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CameraScreen()),
          );
          if (created == true) _loadData();
        },
        icon: const Icon(Icons.camera_alt),
        label: const Text('拍照上传'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // 月份切换 + 总额
                  SliverToBoxAdapter(child: _buildHeader(theme)),
                  // 状态统计卡片
                  SliverToBoxAdapter(child: _buildStatusCards(theme)),
                  // 记录列表标题
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        '消费记录',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // 记录列表
                  if (_records.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('暂无消费记录', style: TextStyle(color: Colors.grey)),
                            SizedBox(height: 8),
                            Text('点击下方按钮拍照上传结账单', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildRecordCard(_records[index]),
                        childCount: _records.length,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final fmt = DateFormat('yyyy年M月');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousMonth,
              ),
              Text(
                fmt.format(_currentMonth),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '¥ ${_monthlyTotal.toStringAsFixed(2)}',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          Text('本月消费总额', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildStatusCards(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statusCard('待补支付', _statusCounts[RecordStatus.pendingPayment] ?? 0, Colors.orange, theme),
          _statusCard('待开发票', _statusCounts[RecordStatus.pendingInvoice] ?? 0, Colors.blue, theme),
          _statusCard('三证齐全', _statusCounts[RecordStatus.complete] ?? 0, Colors.green, theme),
          _statusCard('已归档', _statusCounts[RecordStatus.archived] ?? 0, Colors.grey, theme),
        ],
      ),
    );
  }

  Widget _statusCard(String label, int count, Color color, ThemeData theme) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                '$count',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(ConsumptionRecord record) {
    final statusColors = {
      RecordStatus.pendingPayment: Colors.orange,
      RecordStatus.pendingInvoice: Colors.blue,
      RecordStatus.complete: Colors.green,
      RecordStatus.archived: Colors.grey,
    };
    final statusLabels = {
      RecordStatus.pendingPayment: '待补支付',
      RecordStatus.pendingInvoice: '待开发票',
      RecordStatus.complete: '三证齐全',
      RecordStatus.archived: '已归档',
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColors[record.status]?.withAlpha(30),
          child: Icon(Icons.receipt, color: statusColors[record.status]),
        ),
        title: Text(record.merchant),
        subtitle: Text(
          '${DateFormat('MM-dd').format(record.date)}  ¥${record.amount.toStringAsFixed(2)}',
        ),
        trailing: Chip(
          label: Text(
            statusLabels[record.status] ?? '未知',
            style: TextStyle(
              fontSize: 12,
              color: statusColors[record.status],
            ),
          ),
          backgroundColor: statusColors[record.status]?.withAlpha(20),
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecordDetailScreen(record: record),
            ),
          );
          _loadData();
        },
      ),
    );
  }
}
