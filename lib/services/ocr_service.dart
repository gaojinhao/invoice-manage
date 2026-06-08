import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR 识别结果
class OcrResult {
  final String? merchant;
  final double? amount;
  final DateTime? date;
  final String rawText;
  final double confidence;

  OcrResult({
    this.merchant,
    this.amount,
    this.date,
    required this.rawText,
    this.confidence = 0.0,
  });

  bool get isSuccessful => merchant != null || amount != null || date != null;
}

/// OCR 服务 — 使用 Google ML Kit 本机识别
class OcrService {
  final TextRecognizer _recognizer;

  OcrService({String? language})
      : _recognizer = TextRecognizer(
          script: TextRecognitionScript.chinese,
        );

  /// 识别图片中的文字
  Future<OcrResult> recognizeImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _recognizer.processImage(inputImage);

      final text = recognizedText.text;
      if (text.isEmpty) {
        return OcrResult(rawText: '', confidence: 0);
      }

      final merchant = _extractMerchant(text);
      final amount = _extractAmount(text);
      final date = _extractDate(text);

      return OcrResult(
        merchant: merchant,
        amount: amount,
        date: date,
        rawText: text,
        confidence: 0.85,
      );
    } catch (e) {
      return OcrResult(rawText: '', confidence: 0);
    }
  }

  /// 从 OCR 文本中提取商户名（常见中文小票模式）
  String? _extractMerchant(String text) {
    final patterns = [
      RegExp(r'(?:商户|商家|店名|名称)[：:\s]*([^\n]{2,15})'),
      RegExp(r'^([^\n]{2,10}(?:超市|便利店|餐厅|酒店|药店|商店|专卖店|公司|小店|食堂|饭馆|饭店|酒楼))'),
      RegExp(r'(?:欢迎光临|感谢光临)\s*([^\n]{2,15})'),
      RegExp(r'^(.{2,15}(?:超市|便利店|餐厅|酒店|药店))'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }

    // 取第一行非空文本作为备选
    final lines = text.split('\n').where((l) => l.trim().length > 2).toList();
    if (lines.isNotEmpty) return lines.first.trim();

    return null;
  }

  /// 从 OCR 文本中提取金额
  double? _extractAmount(String text) {
    final patterns = [
      RegExp(r'(?:合计|总计|实收|应付|支付|金额|¥|￥)\s*[：:\s]*\s*(\d+\.?\d*)'),
      RegExp(r'(?:合计|总计|实收)[：:\s]*[¥￥]?\s*(\d+\.?\d*)'),
      RegExp(r'[¥￥]\s*(\d+\.\d{2})'),
      RegExp(r'(\d+\.\d{2})\s*元'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
    }

    return null;
  }

  /// 从 OCR 文本中提取日期
  DateTime? _extractDate(String text) {
    final patterns = [
      RegExp(r'(\d{4})[-年/](\d{1,2})[-月/](\d{1,2})'),
      RegExp(r'(\d{4})(\d{2})(\d{2})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final year = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        final day = int.tryParse(match.group(3)!);
        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
    }

    return null;
  }

  void dispose() {
    _recognizer.close();
  }
}
