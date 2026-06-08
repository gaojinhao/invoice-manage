import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../database/tables.dart';
import '../services/file_service.dart';

/// 消费记录详情页
class RecordDetailScreen extends StatefulWidget {
  final ConsumptionRecord record;

  const RecordDetailScreen({super.key, required this.record});

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  late ConsumptionRecord _record;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _record = widget.record;
  }

  Future<void> _uploadPaymentImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2048);
    if (file == null) return;

    final db = context.read<AppDatabase>();
    final fileService = FileService();

    try {
      final savedPath = await fileService.savePaymentImage(
        File(file.path),
        _record.date,
        _record.merchant,
      );
      await db.updatePaymentImage(_record.id, savedPath);
      _record = (await db.getRecordsByMonth(_record.date.year, _record.date.month))
          .firstWhere((r) => r.id == _record.id);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支付记录已上传 ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条消费记录吗？关联的文件也会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );

    if (confirmed == true) {
      final db = context.read<AppDatabase>();
      final fileService = FileService();
      await fileService.deleteRecordFiles(_record.date, _record.merchant);
      await db.deleteRecord(_record.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabels = {
      RecordStatus.pendingPayment: '待补支付记录',
      RecordStatus.pendingInvoice: '待开发票',
      RecordStatus.complete: '三证齐全',
      RecordStatus.archived: '已归档',
    };
    final statusColors = {
      RecordStatus.pendingPayment: Colors.orange,
      RecordStatus.pendingInvoice: Colors.blue,
      RecordStatus.complete: Colors.green,
      RecordStatus.archived: Colors.grey,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_record.merchant),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteRecord,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 基本信息卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _record.merchant,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      Chip(
                        label: Text(
                          statusLabels[_record.status] ?? '未知',
                          style: TextStyle(color: statusColors[_record.status]),
                        ),
                        backgroundColor: statusColors[_record.status]?.withAlpha(20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow(Icons.calendar_today, '日期', DateFormat('yyyy-MM-dd').format(_record.date)),
                  _infoRow(Icons.monetization_on, '金额', '¥${_record.amount.toStringAsFixed(2)}'),
                  if (_record.notes != null && _record.notes!.isNotEmpty)
                    _infoRow(Icons.notes, '备注', _record.notes!),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 文件状态
          Text('文件清单', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),

          _fileStatusCard(
            '结账单',
            _record.receiptImg != null,
            _record.receiptImg,
            Icons.receipt_long,
            Colors.indigo,
            '拍照上传',
            null, // 不可再上传
          ),
          const SizedBox(height: 8),

          _fileStatusCard(
            '支付记录截图',
            _record.paymentImg != null,
            _record.paymentImg,
            Icons.payment,
            Colors.orange,
            '从相册选择',
            _record.status == RecordStatus.pendingPayment ? _uploadPaymentImage : null,
          ),
          const SizedBox(height: 8),

          _fileStatusCard(
            '发票',
            _record.invoicePdf != null,
            _record.invoicePdf,
            Icons.description,
            Colors.green,
            '自动从邮箱下载',
            null, // 自动处理
          ),

          if (_record.status == RecordStatus.pendingPayment) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _uploadPaymentImage,
              icon: const Icon(Icons.upload),
              label: const Text('上传支付记录截图'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _fileStatusCard(
    String label,
    bool exists,
    String? path,
    IconData icon,
    Color color,
    String actionLabel,
    VoidCallback? onAction,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: exists ? color : Colors.grey),
        title: Text(label),
        subtitle: Text(exists ? '已上传 ✓' : '待上传'),
        trailing: exists
            ? IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: path != null ? () => _viewFile(path) : null,
              )
            : null,
      ),
    );
  }

  void _viewFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件不存在')),
      );
      return;
    }
    // 打开文件（需 open_file 包）
    // OpenFile.open(path);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('文件路径: $path')),
    );
  }
}
