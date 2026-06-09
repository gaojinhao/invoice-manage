import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../database/tables.dart';
import '../services/file_service.dart';

/// 消费记录详情页 — 三证文件管理
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

  /// 上传/替换结账单
  Future<void> _uploadReceipt() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2048);
    if (file == null) return;

    final db = context.read<AppDatabase>();
    final fileService = FileService();
    try {
      final savedPath = await fileService.saveReceiptImage(
        File(file.path), _record.date, _record.merchant,
      );
      await db.updateReceiptImage(_record.id, savedPath);
      await _refreshRecord();
    } catch (e) {
      _showError('上传失败: $e');
    }
  }

  /// 上传/替换支付记录
  Future<void> _uploadPayment() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2048);
    if (file == null) return;

    final db = context.read<AppDatabase>();
    final fileService = FileService();
    try {
      final savedPath = await fileService.savePaymentImage(
        File(file.path), _record.date, _record.merchant,
      );
      await db.updatePaymentImage(_record.id, savedPath);
      await _refreshRecord();
    } catch (e) {
      _showError('上传失败: $e');
    }
  }

  /// 上传/替换发票
  Future<void> _uploadInvoice() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2048);
    if (file == null) return;

    final db = context.read<AppDatabase>();
    final fileService = FileService();
    try {
      // 用图片方式保存发票（也可用 PDF，但用户拍照最方便）
      final savedPath = await fileService.saveInvoicePdf(
        File(file.path), _record.date, _record.merchant,
      );
      await db.updateInvoicePdf(_record.id, savedPath);
      await _refreshRecord();
    } catch (e) {
      _showError('上传失败: $e');
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

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _record.merchant,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy-MM-dd').format(_record.date),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '¥${_record.amount.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 三证区域
            Text('文件管理', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // 1. 结账单
            _buildFileSection(
              '结账单',
              _record.receiptImg,
              Icons.receipt_long,
              Colors.indigo,
              _uploadReceipt,
            ),
            const SizedBox(height: 12),

            // 2. 支付记录
            _buildFileSection(
              '支付记录',
              _record.paymentImg,
              Icons.payment,
              Colors.orange,
              _uploadPayment,
            ),
            const SizedBox(height: 12),

            // 3. 发票
            _buildFileSection(
              '发票',
              _record.invoicePdf,
              Icons.description,
              Colors.green,
              _uploadInvoice,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSection(
    String label,
    String? filePath,
    IconData icon,
    Color color,
    VoidCallback onUpload,
  ) {
    final exists = filePath != null;
    final file = exists ? File(filePath) : null;
    final isImage = exists && _isImageFile(filePath);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签行
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                if (exists)
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 20),
                    tooltip: '查看文件',
                    onPressed: () => _viewFile(filePath),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 文件内容区域
          if (exists && isImage)
            // 有图片 → 显示缩略图
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: Image.file(
                    file!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildAddButton(
                      '图片加载失败，点击重新上传', onUpload,
                    ),
                  ),
                ),
                // 替换按钮（覆盖在右上角）
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onUpload,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (exists && !isImage)
            // 有文件但不是图片（如 PDF）
            _buildFileCard(filePath, onUpload)
          else
            // 没有文件 → 显示添加按钮
            _buildAddButton('点击上传$label', onUpload),
        ],
      ),
    );
  }

  /// PDF/其他文件卡片
  Widget _buildFileCard(String filePath, VoidCallback onUpload) {
    return InkWell(
      onTap: () => _viewFile(filePath),
      child: Container(
        height: 80,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          color: Colors.grey,
        ),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf, size: 32, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  const Text('点击查看文件'),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onUpload,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 添加按钮（无文件时显示）
  Widget _buildAddButton(String hint, VoidCallback onUpload) {
    return InkWell(
      onTap: onUpload,
      child: Container(
        height: 100,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          color: Colors.grey,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 36, color: Colors.grey.shade500),
              const SizedBox(height: 4),
              Text(
                hint,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
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
