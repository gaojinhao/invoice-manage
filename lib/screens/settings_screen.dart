import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import 'email_config_screen.dart';

/// 设置页
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _emailConfigured = false;
  int _totalRecords = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final storage = const FlutterSecureStorage();
    final email = await storage.read(key: 'email_addr');
    final db = context.read<AppDatabase>();
    final allRecords = await db.getRecordsNeedingPayment();
    final monthlyTotal = await db.getMonthlyTotal(
      DateTime.now().year,
      DateTime.now().month,
    );

    setState(() {
      _emailConfigured = email != null && email.isNotEmpty;
      _totalRecords = allRecords.length;
    });
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除所有数据'),
        content: const Text('确定要清除所有消费记录和配置吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 实际清除逻辑
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除所有数据（需要在代码中实现）')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 邮箱配置
          _sectionHeader('邮箱', theme),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('邮箱配置'),
            subtitle: Text(_emailConfigured ? '已配置' : '未配置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmailConfigScreen()),
            ),
          ),
          const Divider(),

          // 数据管理
          _sectionHeader('数据管理', theme),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('数据库'),
            subtitle: Text('$_totalRecords 条待处理记录'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('清除所有数据', style: TextStyle(color: Colors.red)),
            onTap: _clearAllData,
          ),
          const Divider(),

          // 省电优化
          _sectionHeader('省电优化', theme),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.battery_charging_full, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      const Text('后台任务说明', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'App 使用 Android WorkManager 在后台运行每日检查和月初打包任务。'
                    '部分手机厂商（华为/小米/OPPO/vivo）的省电策略可能会延迟或阻止后台任务运行，'
                    '建议将本 App 加入省电白名单。',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _showBatteryOptimizationGuide,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('查看白名单设置指南'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),

          // 关于
          _sectionHeader('关于', theme),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('版本'),
            subtitle: Text('v1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('技术栈'),
            subtitle: Text('Flutter · drift · Google ML Kit · WorkManager'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showBatteryOptimizationGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '省电白名单设置指南',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '不同手机厂商的设置路径不同，请根据您的手机品牌选择对应操作：',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),

            _brandGuide('华为 / 鸿蒙',
              '设置 → 应用 → 应用管理 → 报销文件管理 → 耗电详情 → 启动管理\n\n'
              '关闭"自动管理"，将"允许自启动、允许关联启动、允许后台活动"全部打开。'),
            const SizedBox(height: 12),

            _brandGuide('小米（HyperOS）',
              '设置 → 应用设置 → 应用管理 → 报销文件管理 → 省电策略\n\n'
              '选择"无限制"。\n\n'
              '或在：设置 → 省电与电池 → 右上角设置 → 应用智能省电 → 找到本 App → 选择"无限制"。'),
            const SizedBox(height: 12),

            _brandGuide('OPPO / 一加（ColorOS）',
              '设置 → 电池 → 耗电管理 → 报销文件管理\n\n'
              '关闭"自动优化"和"深度睡眠"，开启"允许唤醒前台"。'),
            const SizedBox(height: 12),

            _brandGuide('vivo / iQOO（OriginOS）',
              '设置 → 电池 → 后台耗电管理 → 报销文件管理\n\n'
              '选择"允许后台高耗电"。\n\n'
              '同时：设置 → 应用与权限 → 应用管理 → 报销文件管理 → 自启动 → 开启。'),
            const SizedBox(height: 12),

            _brandGuide('三星（One UI）',
              '设置 → 电池 → 后台使用限制 → 不限制列表 → 添加报销文件管理。'),
            const SizedBox(height: 12),

            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '设置完成后，App 的每日检查和月初打包任务将更准时地运行。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandGuide(String brand, String steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.phone_android, size: 18),
            const SizedBox(width: 8),
            Text(brand, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(steps, style: const TextStyle(fontSize: 13, height: 1.5)),
      ],
    );
  }
}
