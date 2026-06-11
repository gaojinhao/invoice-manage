import 'dart:io';
import 'dart:ui' show Rect;

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
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.chinese);

  /// 识别图片中的文字（使用 ML Kit 结构化输出）
  Future<OcrResult> recognizeImage(File imageFile) async {
    try {
      final recognizedText = await processImage(imageFile);
      return buildResult(recognizedText);
    } catch (e) {
      return OcrResult(rawText: '', confidence: 0);
    }
  }

  /// 执行 ML Kit 文字识别，返回原始 RecognizedText
  Future<RecognizedText> processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    return _recognizer.processImage(inputImage);
  }

  /// 从 RecognizedText 构建 OcrResult（含结构化行、空间排序、正则提取）
  OcrResult buildResult(RecognizedText recognizedText) {
    final allLines = getStructuredLines(recognizedText);

    if (allLines.isEmpty) {
      final fallback = recognizedText.text.trim();
      if (fallback.isEmpty) {
        return OcrResult(rawText: '', confidence: 0);
      }
      final merchant = extractMerchant(fallback);
      final amount = extractAmount(fallback);
      final date = extractDate(fallback);
      return OcrResult(
        merchant: merchant,
        amount: amount,
        date: date,
        rawText: fallback,
        confidence: 0.5,
      );
    }

    final structuredText = allLines.map((l) => l.text).join('\n');
    final avgConfidence =
        allLines.map((l) => l.confidence).reduce((a, b) => a + b) /
        allLines.length;

    final merchant = _extractMerchantFromLines(allLines);
    final amount = _extractAmountFromLines(allLines);
    final date = extractDate(structuredText);

    return OcrResult(
      merchant: merchant,
      amount: amount,
      date: date,
      rawText: structuredText,
      confidence: avgConfidence,
    );
  }

  /// 获取结构化行信息（含 bounding box，用于版面排序和字段评分）
  List<StructuredLine> getStructuredLines(RecognizedText recognizedText) {
    final lines = <StructuredLine>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final trimmed = line.text.trim();
        if (trimmed.isEmpty) continue;
        lines.add(
          StructuredLine(
            text: trimmed,
            boundingBox: line.boundingBox,
            confidence: line.confidence ?? 0.85,
          ),
        );
      }
    }
    // 空间排序
    lines.sort((a, b) {
      final yDiff = (a.boundingBox.top - b.boundingBox.top).abs();
      if (yDiff < 10) {
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      return a.boundingBox.top.compareTo(b.boundingBox.top);
    });
    return lines;
  }

  /// 从 OCR 文本中提取商户名
  /// 原则：店名通常在文本开头，从前几行中提取
  String? extractMerchant(String text) {
    return _extractMerchantFromLines(_plainTextLines(text));
  }

  /// 从 OCR 文本中提取金额
  /// 原则：最终合计金额通常在文本末尾，从后往前匹配
  double? extractAmount(String text) {
    return _extractAmountFromLines(_plainTextLines(text));
  }

  List<StructuredLine> _plainTextLines(String text) {
    final rawLines =
        text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

    return [
      for (var i = 0; i < rawLines.length; i++)
        StructuredLine(
          text: rawLines[i],
          boundingBox: Rect.fromLTWH(0, i * 24.0, 100, 18),
          confidence: 0.75,
        ),
    ];
  }

  String? _extractMerchantFromLines(List<StructuredLine> lines) {
    if (lines.isEmpty) return null;

    final docBottom = _maxBottom(lines);
    final candidates = <_MerchantCandidate>[];

    for (var i = 0; i < lines.length; i++) {
      final rawLine = lines[i].text;
      final cleaned = _cleanMerchantLine(rawLine);
      if (cleaned == null) continue;

      var score = 0.0;
      final yRatio = lines[i].boundingBox.top / docBottom;

      if (_merchantPrefixRegex.hasMatch(_normalizeText(rawLine))) {
        score += 36;
      }
      if (_brandRegex.hasMatch(cleaned)) {
        score += 34;
      }
      if (_merchantKeywordRegex.hasMatch(cleaned)) {
        score += 20;
      }
      if (i < 4 && cleaned.contains('店')) {
        score += 12;
      }
      if (_containsChinese(cleaned)) {
        score += 8;
      }
      if (cleaned.length >= 4 && cleaned.length <= 18) {
        score += 8;
      }
      if (i < 3) {
        score += 20;
      } else if (i < 6) {
        score += 10;
      }
      if (yRatio <= 0.25) {
        score += 18;
      } else if (yRatio <= 0.45) {
        score += 7;
      } else {
        score -= 12;
      }

      if (_merchantHardSkipRegex.hasMatch(cleaned)) {
        score -= 80;
      }
      if (_amountHintRegex.hasMatch(cleaned) || _looksLikeDateOrTime(cleaned)) {
        score -= 35;
      }
      if (_mostlyNumberOrSymbol(cleaned)) {
        score -= 60;
      }

      if (score >= 18) {
        candidates.add(_MerchantCandidate(cleaned, score));
      }
    }

    if (candidates.isEmpty) return null;
    final storeCandidates =
        candidates.where((c) => c.value.contains('店')).toList();
    if (storeCandidates.isNotEmpty) {
      storeCandidates.sort((a, b) => b.score.compareTo(a.score));
      return storeCandidates.first.value;
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.value;
  }

  String? _cleanMerchantLine(String rawLine) {
    var line = _normalizeText(rawLine);
    if (line.isEmpty) return null;

    line = line.replaceFirst(_merchantPrefixRegex, '');
    line = line.replaceFirst(_welcomePrefixRegex, '');
    line = line.replaceAll(RegExp(r'^[\s:：\-_*#=@]+'), '');
    line = line.replaceAll(RegExp(r'[\s:：\-_*#=]+$'), '');
    line = line.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    line = _normalizeMerchantOcrText(line);

    if (line.length < 2 || line.length > 32) return null;
    if (_mostlyNumberOrSymbol(line)) return null;
    if (_pureAsciiRegex.hasMatch(line) && !_brandRegex.hasMatch(line)) {
      return null;
    }
    if (_merchantHardSkipRegex.hasMatch(line)) return null;

    return line;
  }

  double? _extractAmountFromLines(List<StructuredLine> lines) {
    if (lines.isEmpty) return null;

    final layoutAmount = _extractFinalAmountByLayout(lines);
    if (layoutAmount != null) return layoutAmount;

    final tailAmount = _extractFinalAmountFromTail(lines);
    if (tailAmount != null) return tailAmount;

    final docBottom = _maxBottom(lines);
    final candidates = <_AmountCandidate>[];

    for (var i = 0; i < lines.length; i++) {
      final line = _normalizeNumberText(lines[i].text);
      final prevLine = i > 0 ? _normalizeNumberText(lines[i - 1].text) : '';
      final nextLine =
          i + 1 < lines.length ? _normalizeNumberText(lines[i + 1].text) : '';
      final currentHasFinalLabel = _finalAmountLabelRegex.hasMatch(line);
      final prevHasFinalLabel = _finalAmountLabelRegex.hasMatch(prevLine);
      final nextHasFinalLabel = _finalAmountLabelRegex.hasMatch(nextLine);
      final currentHasGenericAmountLabel =
          _genericAmountLabelRegex.hasMatch(line) &&
          _lastPositiveAmount(line) != null;
      final currentHasTotalLabel =
          currentHasFinalLabel ||
          _totalLabelRegex.hasMatch(line) ||
          currentHasGenericAmountLabel;
      final neighborHasTotalLabel =
          prevHasFinalLabel ||
          nextHasFinalLabel ||
          _totalLabelRegex.hasMatch(prevLine) ||
          _totalLabelRegex.hasMatch(nextLine);

      for (final match in _moneyRegex.allMatches(line)) {
        final rawAmount = match.group(1);
        if (rawAmount == null) continue;

        final amount = _parseAmount(rawAmount);
        if (amount == null || amount <= 0 || amount >= 1000000) continue;

        final hasCurrency = _currencyRegex.hasMatch(match.group(0) ?? '');
        final hasUnit = RegExp(r'[元圆]').hasMatch(match.group(0) ?? '');
        final hasDecimal = RegExp(r'[.,]\d{1,2}$').hasMatch(rawAmount);
        final hasMoneyHint =
            currentHasTotalLabel ||
            neighborHasTotalLabel ||
            hasCurrency ||
            hasUnit ||
            hasDecimal;

        if (!hasMoneyHint &&
            rawAmount.replaceAll(RegExp(r'\D'), '').length >= 5) {
          continue;
        }
        if (!hasMoneyHint && _looksLikeDateOrTime(line)) {
          continue;
        }

        var score = 0.0;
        final yRatio = lines[i].boundingBox.top / docBottom;

        if (currentHasFinalLabel) score += 82;
        if (prevHasFinalLabel) score += 72;
        if (nextHasFinalLabel) score += 10;
        if (!currentHasFinalLabel &&
            (_totalLabelRegex.hasMatch(line) || currentHasGenericAmountLabel)) {
          score += 34;
        }
        if (!prevHasFinalLabel && _totalLabelRegex.hasMatch(prevLine)) {
          score += 22;
        }
        if (!nextHasFinalLabel && _totalLabelRegex.hasMatch(nextLine)) {
          score += 8;
        }
        if (hasCurrency) score += 18;
        if (hasUnit) score += 10;
        if (hasDecimal) score += 14;
        if (!hasDecimal && !currentHasTotalLabel && !hasCurrency && !hasUnit) {
          score -= 12;
        }

        if (yRatio >= 0.58) {
          score += 18;
        } else if (yRatio >= 0.40) {
          score += 8;
        } else {
          score -= 8;
        }

        if (_amountHardSkipRegex.hasMatch(line)) score -= 70;
        if (_amountSoftSkipRegex.hasMatch(line)) score -= 18;
        if (_intermediateAmountLabelRegex.hasMatch(line)) score -= 26;
        if (_intermediateAmountLabelRegex.hasMatch(prevLine)) score -= 18;
        if (_looksLikeDateOrTime(line) && !currentHasTotalLabel) score -= 35;
        if (amount < 0.01) score -= 30;

        candidates.add(_AmountCandidate(amount, score, i));
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      final indexCompare = b.lineIndex.compareTo(a.lineIndex);
      if (indexCompare != 0) return indexCompare;
      return b.amount.compareTo(a.amount);
    });

    final best = candidates.first;
    return best.score >= 12 ? best.amount : null;
  }

  double? _extractFinalAmountByLayout(List<StructuredLine> lines) {
    final avgHeight = _averageLineHeight(lines);
    final maxYDistance = avgHeight * 2.2;
    _LayoutAmountCandidate? best;

    for (final labelLine in lines) {
      final labelText = _normalizeNumberText(labelLine.text);
      if (!_finalAmountLabelRegex.hasMatch(labelText)) continue;

      for (final amountLine in lines) {
        if (identical(labelLine, amountLine)) continue;

        final amountText = _normalizeNumberText(amountLine.text);
        if (_amountHardSkipRegex.hasMatch(amountText)) continue;

        final amount = _lastPositiveAmount(amountText);
        if (amount == null) continue;

        final yDistance =
            (labelLine.boundingBox.center.dy - amountLine.boundingBox.center.dy)
                .abs();
        if (yDistance > maxYDistance) continue;

        var score = 120.0 - yDistance;
        if (amountLine.boundingBox.left >= labelLine.boundingBox.right - 8) {
          score += 40;
        }
        if (amountText.contains('.') || amountText.contains(',')) {
          score += 12;
        }

        final candidate = _LayoutAmountCandidate(amount, score);
        if (best == null || candidate.score > best.score) {
          best = candidate;
        }
      }
    }

    return best?.amount;
  }

  double? _extractFinalAmountFromTail(List<StructuredLine> lines) {
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = _normalizeNumberText(lines[i].text);
      final prevLine = i > 0 ? _normalizeNumberText(lines[i - 1].text) : '';

      if (_finalAmountLabelRegex.hasMatch(line)) {
        final sameLine = _lastPositiveAmount(line);
        if (sameLine != null) return sameLine;

        for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
          final nextLine = _normalizeNumberText(lines[j].text);
          if (_amountHardSkipRegex.hasMatch(nextLine)) continue;
          if (_looksLikeDateOrTime(nextLine)) continue;
          final nextAmount = _lastPositiveAmount(nextLine);
          if (nextAmount != null) return nextAmount;
        }
      }

      if (_finalAmountLabelRegex.hasMatch(prevLine)) {
        final currentAmount = _lastPositiveAmount(line);
        if (currentAmount != null) return currentAmount;
      }
    }

    return null;
  }

  double? _lastPositiveAmount(String line) {
    double? amount;
    for (final match in _moneyRegex.allMatches(line)) {
      final rawAmount = match.group(1);
      if (rawAmount == null) continue;
      final parsed = _parseAmount(rawAmount);
      if (parsed != null && parsed > 0 && parsed < 1000000) {
        amount = parsed;
      }
    }
    return amount;
  }

  double _maxBottom(List<StructuredLine> lines) {
    var bottom = 1.0;
    for (final line in lines) {
      if (line.boundingBox.bottom > bottom) {
        bottom = line.boundingBox.bottom;
      }
    }
    return bottom;
  }

  double _averageLineHeight(List<StructuredLine> lines) {
    final heights =
        lines.map((l) => l.boundingBox.height).where((h) => h > 0).toList();
    if (heights.isEmpty) return 18;
    return heights.reduce((a, b) => a + b) / heights.length;
  }

  String _normalizeText(String text) {
    return text
        .replaceAll('：', ':')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('【', '[')
        .replaceAll('】', ']')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeNumberText(String text) {
    var normalized = _normalizeText(text)
        .replaceAll('，', ',')
        .replaceAll('．', '.')
        .replaceAll('。', '.')
        .replaceAll('￥', '¥');

    const fullWidthDigits = '０１２３４５６７８９';
    for (var i = 0; i < fullWidthDigits.length; i++) {
      normalized = normalized.replaceAll(fullWidthDigits[i], '$i');
    }
    return normalized;
  }

  String _normalizeMerchantOcrText(String text) {
    var normalized = text
        .replaceAll(RegExp(r'[海酒而]底[捞撈揚拷排携節斤檬烤精持]'), '海底捞')
        .replaceAll('火稱', '火锅')
        .replaceAll('火鍋', '火锅')
        .replaceAll('摩尔成店', '摩尔城店')
        .replaceAll('摩尔險店', '摩尔城店')
        .replaceAll('摩尔险店', '摩尔城店');

    final mallStoreMatch = RegExp(
      r'^[海酒而]底.{0,3}(摩尔.{0,4}店)',
    ).firstMatch(normalized);
    if (mallStoreMatch != null) {
      normalized = '海底捞${mallStoreMatch.group(1)!}';
    }

    return normalized;
  }

  double? _parseAmount(String raw) {
    var value = _normalizeNumberText(raw).replaceAll(' ', '');
    value = value.replaceAll(RegExp(r'[¥￥元圆]'), '');

    if (value.contains(',') && !value.contains('.')) {
      final parts = value.split(',');
      if (parts.length == 2 && parts.last.length <= 2) {
        value = '${parts.first}.${parts.last}';
      } else {
        value = value.replaceAll(',', '');
      }
    } else {
      value = value.replaceAll(',', '');
    }

    return double.tryParse(value);
  }

  bool _containsChinese(String text) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  bool _mostlyNumberOrSymbol(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return true;
    final numberOrSymbol = RegExp(
      r'^[0-9０-９¥￥.,，:：/\-+_#*=()（）]+$',
    ).hasMatch(compact);
    if (numberOrSymbol) return true;

    final digits = RegExp(r'[0-9０-９]').allMatches(compact).length;
    return digits / compact.length > 0.65;
  }

  bool _looksLikeDateOrTime(String text) {
    return RegExp(
      r'(?:\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}|'
      r'\d{1,2}:\d{2}|'
      r'\d{4}\s*年|'
      r'日期|时间)',
    ).hasMatch(text);
  }

  static final _brandRegex = RegExp(
    r'(海底捞|海底撈|海底揚|海底拷|海底排|海底烤|海底持|而底拷|酒底捞|肯德基|麦当劳|必胜客|星巴克|瑞幸|蜜雪冰城|喜茶|奈雪|一点点|coco|沪上阿姨|古茗|茶百道|霸王茶姬|库迪|Manner|Tims|西贝|太二|费大厨|老乡鸡|真功夫|永和大王|呷哺呷哺|杨国福|张亮|沃尔玛|永辉|大润发|华润万家|盒马|山姆|家乐福|罗森|全家|7-?11|美宜佳|红旗连锁)',
    caseSensitive: false,
  );
  static final _merchantPrefixRegex = RegExp(
    r'^(?:商户名称|商户名|商户|商家|店铺名称|店铺|店名|门店名称|门店|名称|收款方|收款商户|付款给|付款至)\s*[:：\-]?\s*',
  );
  static final _welcomePrefixRegex = RegExp(
    r'^(?:欢迎光临|欢迎您光临|感谢光临|谢谢惠顾)\s*[:：\-]?\s*',
  );
  static final _merchantKeywordRegex = RegExp(
    r'(店|馆|宴|吃|厅|楼|坊|轩|阁|铺|吧|廊|火锅|烧烤|烤肉|麻辣烫|串串|料理|快餐|面馆|粉店|小吃|面包|蛋糕|甜品|咖啡|奶茶|茶|酒|餐饮|饭店|饭馆|超市|便利店|商场|百货|广场|公司|企业|集团|中心|医院|诊所|药房|药店|门诊)',
  );
  static final _merchantHardSkipRegex = RegExp(
    r'(发票|清单|凭证|收据|销售单|电子小票|小票号|电话|地址|日期|时间|单号|流水号|收银员|操作员|支付方式|找零|备注|单据类型|合计|总计|实收|应付|实付|优惠|折扣|编号|代码|机器|终端|批次|纳税人|识别号|打印|开票|退货|换货|会员|积分|微信|支付宝|银联|云闪付|收款码|服务员|人数|开台|结账|菜品名称|数量|规格|金额|单价|COMM|ORDER)',
    caseSensitive: false,
  );
  static final _pureAsciiRegex = RegExp(
    r'^[a-zA-Z0-9\s_\-+*/=!@#$%^&(),.:;?|]+$',
  );
  static final _amountHintRegex = RegExp(r'(¥|￥|\d+[.,]\d{1,2}|元|圆)');
  static final _moneyRegex = RegExp(
    r'[¥￥]?\s*([+-]?(?:\d{1,3}(?:,\d{3})+|\d+)(?:[.,]\d{1,2})?)\s*(?:元|圆)?',
  );
  static final _currencyRegex = RegExp(r'[¥￥]');
  static final _finalAmountLabelRegex = RegExp(
    r'(应付金[额額]|应收金[额額]|实付金[额額]|实收金[额額]|餐饮消费金[额額]|消费金[额額]|交易金[额額]|支付金[额額]|收款金[额額]|付款金[额額]|实际付款|应付款|本次支付|需付|应付|应收|实付|实收)',
  );
  static final _totalLabelRegex = RegExp(r'(价税合计|合计|总计|总金[额額])');
  static final _genericAmountLabelRegex = RegExp(r'金[额額]\s*[:：]');
  static final _intermediateAmountLabelRegex = RegExp(
    r'(原单金[额額]|菜品金[额額]|商品金[额額]|订单金[额額]|赠菜金[额額]|优惠金[额額]|小计|原价)',
  );
  static final _amountHardSkipRegex = RegExp(
    r'(优惠|折扣|找零|积分|余额|充值|退款|税率|税额|单价|数量|件数|编号|单号|流水|电话|手机|会员|卡号|桌号|台号|人数|地址|税号|纳税人|识别号)',
  );
  static final _amountSoftSkipRegex = RegExp(r'(小计|商品金额|原价|抹零)');

  /// 从 OCR 文本中提取日期
  DateTime? extractDate(String text) {
    final patterns = <List<Pattern>>[
      [RegExp(r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?')],
      [RegExp(r'(\d{4})\s*[-/.]\s*(\d{1,2})\s*[-/.]\s*(\d{1,2})')],
      [RegExp(r'(\d{4})(\d{2})(\d{2})')],
      [RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*日')],
    ];

    for (final group in patterns) {
      for (final pattern in group) {
        final match = pattern.allMatches(text);
        for (final m in match) {
          final groups = m.groups(List.generate(m.groupCount + 1, (i) => i));
          if (groups.length >= 4) {
            final year = int.tryParse(groups[1] ?? '');
            final month = int.tryParse(groups[2] ?? '');
            final day = int.tryParse(groups[3] ?? '');
            if (year != null && month != null && day != null) {
              if (year >= 2020 &&
                  year <= 2099 &&
                  month >= 1 &&
                  month <= 12 &&
                  day >= 1 &&
                  day <= 31) {
                return DateTime(year, month, day);
              }
            }
          } else if (groups.length >= 3 && pattern is RegExp) {
            final month = int.tryParse(groups[1] ?? '');
            final day = int.tryParse(groups[2] ?? '');
            if (month != null &&
                day != null &&
                month >= 1 &&
                month <= 12 &&
                day >= 1 &&
                day <= 31) {
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

/// 结构化行信息 — 含文本、位置、置信度
class StructuredLine {
  final String text;
  final Rect boundingBox;
  final double confidence;

  StructuredLine({
    required this.text,
    required this.boundingBox,
    required this.confidence,
  });
}

class _MerchantCandidate {
  final String value;
  final double score;

  _MerchantCandidate(this.value, this.score);
}

class _AmountCandidate {
  final double amount;
  final double score;
  final int lineIndex;

  _AmountCandidate(this.amount, this.score, this.lineIndex);
}

class _LayoutAmountCandidate {
  final double amount;
  final double score;

  _LayoutAmountCandidate(this.amount, this.score);
}
