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

  OcrService({String? language, TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(
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

      final merchant = extractMerchant(text);
      final amount = extractAmount(text);
      final date = extractDate(text);

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

  /// 从 OCR 文本中提取商户名
  /// 包内公开以支持单元测试
  String? extractMerchant(String text) {
    final patterns = <RegExp>[
      // ← 常见前缀标记
      RegExp(r'(?:商户|商家|店名|名称|单位名称)[：:\s]*([^\n]{2,18})'),
      RegExp(r'(?:欢迎光临|感谢光临|欢迎惠顾)\s*([^\n]{2,15})'),
      RegExp(r'(?:美团|饿了么|大众点评)\s*[·•]?\s*([^\n]{2,15})'),
      // ← 以常见行业后缀结尾的行
      RegExp(r'^([^\n]{2,12}(?:超市|便利店|餐厅|酒店|药店|商店|专卖店|公司|小店|食堂|饭馆|饭店|酒楼|火锅|烧烤|奶茶))'),
      RegExp(r'^([^\n]{2,12}(?:药房|大药房|门诊|医院|诊所|学校|学院|大学|中学|小学|幼儿园))'),
      RegExp(r'^([^\n]{2,12}(?:加油站|停车场|物业|水电|燃气|通信|移动|联通|电信))'),
      // ← "XX公司/XX企业/XX店"
      RegExp(r'^([^\n]{2,15}(?:公司|企业|集团|中心|广场|大厦))'),
      // ← 常见连锁品牌（覆盖更多）
      RegExp(r'((?:肯德基|麦当劳|必胜客|星巴克|瑞幸|蜜雪冰城|喜茶|奈雪|一点点|coco|沪上阿姨|古茗|茶百道))'),
      RegExp(r'((?:沃尔玛|永辉|大润发|华润万家|盒马|山姆|家乐福|罗森|全家|7-?11|美宜佳|红旗连锁))'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }

    // 取第1-2行非空文本作为备选
    final lines = text.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 2)
        .toList();
    if (lines.isNotEmpty) {
      // 跳过明显是公司抬头/地址的行
      for (final line in lines.take(4)) {
        if (line.contains(RegExp(r'(?:电话|地址|日期|时间|单号|订单号|流水号|收银员|操作员|交易)'))) {
          continue;
        }
        return line;
      }
      return lines.first;
    }

    return null;
  }

  /// 从 OCR 文本中提取金额
  double? extractAmount(String text) {
    final patterns = <RegExp>[
      // ← 常见前缀 + 金额
      RegExp(r'(?:合计|总计|实收|应付|支付|付款|消费|小计|金额|收款|实付)[：:\s=]*[¥￥]?\s*(\d+\.?\d*)'),
      RegExp(r'(?:合计|总计|实收|实付|应付)[：:\s=]*[¥￥]?\s*(\d+\.\d{2})'),
      // ← "¥" 或 "￥" 开头
      RegExp(r'[¥￥]\s*(\d+\.\d{2})'),
      RegExp(r'[¥￥]\s*(\d+)'),
      // ← "XX元" 模式（金额在前）
      RegExp(r'(\d+\.\d{2})\s*元'),
      RegExp(r'(\d+)\s*元'),
      // ← 找一行只有数字且包含小数点的
      RegExp(r'^[^\d]*(\d+\.\d{2})\s*$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final parsed = double.tryParse(match.group(1)!);
        if (parsed != null && parsed > 0 && parsed < 9999999) {
          return parsed;
        }
      }
    }

    // 兜底：找文本中所有小数点后两位的数字，取最大的（通常是总额）
    final allAmounts = RegExp(r'(\d+\.\d{2})').allMatches(text);
    if (allAmounts.isNotEmpty) {
      final amounts = allAmounts
          .map((m) => double.tryParse(m.group(1)!))
          .whereType<double>()
          .where((a) => a > 0 && a < 9999999)
          .toList();
      if (amounts.isNotEmpty) {
        amounts.sort();
        return amounts.last; // 通常是最大的那个（总额）
      }
    }

    return null;
  }

  /// 从 OCR 文本中提取日期
  DateTime? extractDate(String text) {
    final patterns = <List<Pattern>>[
      // YYYY年MM月DD日
      [RegExp(r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?')],
      // YYYY-MM-DD / YYYY/MM/DD / YYYY.MM.DD
      [RegExp(r'(\d{4})\s*[-/.]\s*(\d{1,2})\s*[-/.]\s*(\d{1,2})')],
      // YYYYMMDD 紧凑格式
      [RegExp(r'(\d{4})(\d{2})(\d{2})')],
      // MM月DD日（补当前年份）
      [RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*日')],
    ];

    for (final group in patterns) {
      for (final pattern in group) {
        final match = pattern.allMatches(text);
        // 找第一个看起来合理的日期
        for (final m in match) {
          final groups = m.groups(List.generate(m.groupCount + 1, (i) => i));
          if (groups.length >= 4) {
            final year = int.tryParse(groups[1] ?? '');
            final month = int.tryParse(groups[2] ?? '');
            final day = int.tryParse(groups[3] ?? '');
            if (year != null && month != null && day != null) {
              if (year >= 2020 && year <= 2099 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
                return DateTime(year, month, day);
              }
            }
          } else if (groups.length >= 3 && pattern is RegExp) {
            // MM月DD日
            final month = int.tryParse(groups[1] ?? '');
            final day = int.tryParse(groups[2] ?? '');
            if (month != null && day != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
              return DateTime(DateTime.now().year, month, day);
            }
          }
        }
      }
    }

    return null;
  }

  void dispose() {
    _recognizer.close();
  }
}
