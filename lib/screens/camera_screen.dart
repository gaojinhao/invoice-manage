import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../services/ocr_service.dart';
import '../services/file_service.dart';

/// 拍照上传 + OCR 识别页
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _picker = ImagePicker();
  File? _image;
  bool _processing = false;
  bool _manualMode = false;
  int _ocrRunId = 0;

  // OCR 结果
  final _merchantCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _ocrRawText;

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('需要相机权限才能拍照')));
      }
      return;
    }
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
    );
    if (file == null) return;
    setState(() {
      _image = File(file.path);
      _manualMode = false;
      _clearExtractedFields();
    });
    _recognize();
  }

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
    );
    if (file == null) return;
    setState(() {
      _image = File(file.path);
      _manualMode = false;
      _clearExtractedFields();
    });
    _recognize();
  }

  void _startManualEntry({bool keepImage = false}) {
    _ocrRunId++;
    setState(() {
      if (!keepImage) {
        _image = null;
      }
      _processing = false;
      _manualMode = true;
      _ocrRawText = null;
    });
  }

  void _clearExtractedFields() {
    _merchantCtrl.clear();
    _amountCtrl.clear();
    _dateCtrl.clear();
    _ocrRawText = null;
  }

  Future<void> _recognize() async {
    final image = _image;
    if (image == null) return;
    final runId = ++_ocrRunId;

    setState(() => _processing = true);
    final ocr = OcrService();

    try {
      final result = await ocr
          .recognizeImage(image)
          .timeout(const Duration(seconds: 25));
      if (!mounted || runId != _ocrRunId) return;

      _ocrRawText = result.rawText;

      if (result.merchant != null) _merchantCtrl.text = result.merchant!;
      if (result.amount != null) {
        _amountCtrl.text = result.amount!.toStringAsFixed(2);
      }
      if (result.date != null) {
        _dateCtrl.text =
            '${result.date!.year}-${result.date!.month.toString().padLeft(2, '0')}-${result.date!.day.toString().padLeft(2, '0')}';
      }
    } on TimeoutException {
      if (mounted && runId == _ocrRunId) {
        setState(() => _manualMode = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('识别超时，已切换到手动录入')));
      }
    } catch (e) {
      if (mounted && runId == _ocrRunId) {
        setState(() => _manualMode = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('识别失败，已切换到手动录入: $e')));
      }
    } finally {
      ocr.dispose();
      if (mounted && runId == _ocrRunId) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _save() async {
    if (_merchantCtrl.text.isEmpty ||
        _amountCtrl.text.isEmpty ||
        _dateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写商户名、金额和日期')));
      return;
    }

    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('金额格式不正确')));
      return;
    }

    DateTime? date;
    try {
      final parts = _dateCtrl.text.split('-');
      date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日期格式不正确（请使用 YYYY-MM-DD）')));
      return;
    }

    setState(() => _processing = true);

    try {
      final db = context.read<AppDatabase>();
      final fileService = FileService();

      // 保存结账单照片
      String? receiptPath;
      if (_image != null) {
        receiptPath = await fileService.saveReceiptImage(
          _image!,
          date,
          _merchantCtrl.text,
        );
      }

      // 创建消费记录
      await db.createRecord(
        date: date,
        merchant: _merchantCtrl.text,
        amount: amount,
        receiptImg: receiptPath,
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      );

      if (mounted) {
        Navigator.pop(context, true); // 返回 true 表示创建成功
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }

    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('上传结账单')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 图片预览 + 拍照按钮
            if (_image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_image!, height: 250, fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              if (_processing)
                const Center(child: CircularProgressIndicator())
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新识别'),
                      onPressed: _recognize,
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.edit_note),
                      label: const Text('手动录入'),
                      onPressed: () => _startManualEntry(keepImage: true),
                    ),
                  ],
                ),
              ],
            ] else ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withAlpha(50)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filled(
                            onPressed: _processing ? null : _takePhoto,
                            icon: const Icon(Icons.camera_alt),
                            tooltip: '拍照',
                          ),
                          const SizedBox(width: 24),
                          IconButton.filled(
                            onPressed: _processing ? null : _pickFromGallery,
                            icon: const Icon(Icons.photo_library),
                            tooltip: '从相册选择',
                          ),
                          const SizedBox(width: 24),
                          IconButton.filledTonal(
                            onPressed:
                                _processing ? null : () => _startManualEntry(),
                            icon: const Icon(Icons.edit_note),
                            tooltip: '手动录入',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('拍照、选择照片或手动录入'),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 识别结果 / 手动录入表单
            Text(
              _manualMode ? '手动录入' : '确认识别结果',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _merchantCtrl,
              decoration: const InputDecoration(
                labelText: '商户名 *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: '金额 *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
                suffixText: '元',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _dateCtrl,
              decoration: const InputDecoration(
                labelText: '日期 *',
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(now.year, now.month, now.day),
                  firstDate: DateTime(2020),
                  lastDate: now,
                  locale: const Locale('zh'),
                );
                if (picked != null) {
                  _dateCtrl.text =
                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                }
              },
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),

            if (_ocrRawText != null && _ocrRawText!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('原始 OCR 文本'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _ocrRawText!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _processing ? null : _save,
              icon:
                  _processing
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save),
              label: Text(_processing ? '保存中...' : '保存消费记录'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
