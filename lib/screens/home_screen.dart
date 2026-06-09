import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../database/tables.dart';
import '../services/file_service.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import 'camera_screen.dart';
import 'record_detail_screen.dart';
import 'email_config_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import 'charts_screen.dart';

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
            onPressed: () => showSearch<ConsumptionRecord?>(
              context: context,
              delegate: RecordSearchDelegate(),
            ),
            tooltip: '搜索',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChartsScreen()),
            ),
            tooltip: '统计',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
                  // 操作按钮栏
                  SliverToBoxAdapter(child: _buildActionBar(theme)),
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

  /// 操作按钮栏：打包导出
  Widget _buildActionBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _packAndExport,
              icon: const Icon(Icons.folder_zip, size: 20),
              label: const Text('打包导出当前月所有记录'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 打包当前月记录为 ZIP → 选择下载或发送到邮箱
  Future<void> _packAndExport() async {
    final scaffold = ScaffoldMessenger.of(context);
    final fileService = FileService();

    scaffold.showSnackBar(
      const SnackBar(
        content: Text('正在打包，请稍候...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final zipPath = await fileService.zipMonthRecords(
        _currentMonth.year,
        _currentMonth.month,
      );

      if (zipPath == null) {
        if (mounted) {
          scaffold.showSnackBar(
            const SnackBar(
              content: Text('当前月暂无记录可打包'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // 弹出操作选择
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  DateFormat('yyyy年M月').format(_currentMonth),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('下载 / 分享文件'),
                subtitle: const Text('保存到本地或通过微信/QQ 发送'),
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('发送到邮箱'),
                subtitle: const Text('需要先配置邮箱'),
                onTap: () => Navigator.pop(ctx, 'email'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );

      if (action == null || !mounted) return;

      if (action == 'share') {
        final exportService = ExportService(context.read<AppDatabase>());
        await exportService.shareFile(zipPath);
      } else if (action == 'email') {
        // 检查邮箱是否已配置
        final storage = const FlutterSecureStorage();
        final email = await storage.read(key: 'email_addr');
        if (email == null || email.isEmpty) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('未配置邮箱'),
              content: const Text('请先在设置中配置邮箱，即可将打包文件自动发送。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('去配置'),
                ),
              ],
            ),
          );
          if (confirm == true && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmailConfigScreen()),
            );
          }
        } else {
          // 邮箱已配置，直接发送
          scaffold.showSnackBar(
            const SnackBar(
              content: Text('邮箱发送功能即将实现（当前可通过分享手动发送）'),
              duration: Duration(seconds: 2),
            ),
          );
          // 先分享文件
          final exportService = ExportService(context.read<AppDatabase>());
          await exportService.shareFile(zipPath);
        }
      }
    } catch (e) {
      if (mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('打包失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  /// 计算记录卡片的颜色
  /// 红：支付记录和发票都未上传 → pendingPayment
  /// 橘：上传了支付记录或发票（部分完成）
  /// 绿：三证齐全（结账单+支付记录+发票）
  Color _cardColor(ConsumptionRecord record) {
    if (record.receiptImg != null &&
        record.paymentImg != null &&
        record.invoicePdf != null) {
      return Colors.green;
    }
    if (record.paymentImg != null || record.invoicePdf != null) {
      return Colors.orange;
    }
    return Colors.red;
  }

  String _cardStatusText(ConsumptionRecord record) {
    if (record.receiptImg != null &&
        record.paymentImg != null &&
        record.invoicePdf != null) {
      return '三证齐全';
    }
    if (record.paymentImg != null || record.invoicePdf != null) {
      return '部分完成';
    }
    return '待补充';
  }

  Widget _buildRecordCard(ConsumptionRecord record) {
    final color = _cardColor(record);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withAlpha(80), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecordDetailScreen(record: record),
            ),
          );
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 左侧彩色标记
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),

              // 商户名 + 日期
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.merchant,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('yyyy-MM-dd').format(record.date),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // 金额
              Text(
                '¥${record.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),

              // 状态标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _cardStatusText(record),
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
