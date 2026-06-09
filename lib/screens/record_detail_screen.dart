import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../database/tables.dart';
import '../services/file_service.dart';
import 'camera_screen.dart';

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
      await _refreshRecord();
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

  Future<void> _uploadInvoiceFromFile() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2048);
    if (file == null) return;

    final db = context.read<AppDatabase>();
    final fileService = FileService();

    try {
      final savedPath = await fileService.saveInvoicePdf(
        File(file.path),
        _record.date,
        _record.merchant,
      );
      await db.updateInvoicePdf(_record.id, savedPath);
      await _refreshRecord();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发票已上传 ✓')),
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

  Future<void> _refreshRecord() async {
    final db = context.read<AppDatabase>();
    final records = await db.getRecordsByMonth(_record.date.year, _record.date.month);
    final updated = records.where((r) => r.id == _record.id).firstOrNull;
    if (updated != null) {
      setState(() => _record = updated);
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

          const SizedBox(height: 24),

          // 文件三证状态
          Text('文件清单', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildFileCard(
            '结账单',
            _record.receiptImg,
            Icons.receipt_long,
            Colors.indigo,
            '拍照上传结账单',
            () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CameraScreen()),
              );
              if (created == true) await _refreshRecord();
            },
          ),
          const SizedBox(height: 8),

          _buildFileCard(
            '支付记录截图',
            _record.paymentImg,
            Icons.payment,
            Colors.orange,
            '从相册选择支付截图',
            _uploadPaymentImage,
          ),
          const SizedBox(height: 8),

          _buildFileCard(
            '发票',
            _record.invoicePdf,
            Icons.description,
            Colors.green,
            '上传发票照片/PDF',
            _uploadInvoiceFromFile,
          ),

          const SizedBox(height: 24),

          // 说明文字
          Card(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '三证齐全后记录状态自动变为"三证齐全"，月初可打包发送到邮箱。',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(
    String label,
    String? filePath,
    IconData icon,
    Color color,
    String uploadHint,
    VoidCallback? onUpload,
  ) {
    final exists = filePath != null;
    final statusColor = exists ? Colors.green : Colors.red;
    final statusIcon = exists ? Icons.check_circle : Icons.cancel;
    final statusText = exists ? '已上传 ✓' : '未上传 ✗';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withAlpha(80),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: exists
            ? () => _viewFile(filePath)
            : onUpload,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 状态图标
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: exists ? color : Colors.grey, size: 24),
              ),
              const SizedBox(width: 16),

              // 标签 + 状态
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 操作按钮
              if (exists)
                IconButton(
                  icon: const Icon(Icons.visibility, size: 20),
                  tooltip: '查看文件',
                  onPressed: () => _viewFile(filePath),
                )
              else
                IconButton(
                  icon: const Icon(Icons.upload_file, size: 20),
                  tooltip: uploadHint,
                  onPressed: onUpload,
                  color: statusColor,
                ),
            ],
          ),
        ),
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

  void _viewFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件不存在')),
      );
      return;
    }
    OpenFile.open(path);
  }
}
