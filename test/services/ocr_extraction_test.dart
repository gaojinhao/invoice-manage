import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/services/ocr_service.dart';

void main() {
  group('OcrService.extractMerchant', () {
    late OcrService service;

    setUp(() => service = OcrService());
    tearDown(() => service.dispose());

    test('商户: 前缀匹配', () {
      expect(service.extractMerchant('商户：华联超市'), '华联超市');
    });

    test('商家: 前缀匹配', () {
      expect(service.extractMerchant('商家: 永辉超市'), '永辉超市');
    });

    test('店名: 前缀匹配', () {
      expect(service.extractMerchant('店名: 好再来餐厅'), '好再来餐厅');
    });

    test('名称: 前缀匹配', () {
      expect(service.extractMerchant('名称：海底捞火锅'), '海底捞火锅');
    });

    test('第一行超市/便利店后缀', () {
      expect(service.extractMerchant('美宜佳便利店\n地址：xxx'), '美宜佳便利店');
    });

    test('第一行餐厅/酒店后缀', () {
      expect(service.extractMerchant('肯德基餐厅\n合计：80.00'), '肯德基餐厅');
    });

    test('欢迎光临前缀', () {
      expect(service.extractMerchant('欢迎光临 沃尔玛购物广场'), '沃尔玛购物广场');
    });

    test('感谢光临前缀', () {
      expect(service.extractMerchant('感谢光临 星巴克咖啡'), '星巴克咖啡');
    });

    test('无匹配时取第一行', () {
      expect(
        service.extractMerchant('这是一张小票\n地址：xxx\n合计：100.00'),
        '这是一张小票',
      );
    });

    test('空文本返回 null', () {
      expect(service.extractMerchant(''), null);
    });
  });

  group('OcrService.extractAmount', () {
    late OcrService service;

    setUp(() => service = OcrService());
    tearDown(() => service.dispose());

    test('合计：金额', () {
      expect(service.extractAmount('合计：128.00'), closeTo(128.00, 0.001));
    });

    test('合计:金额（无空格冒号）', () {
      expect(service.extractAmount('合计:99.90'), closeTo(99.90, 0.001));
    });

    test('总计=金额', () {
      expect(service.extractAmount('总计=256.50'), closeTo(256.50, 0.001));
    });

    test('实收 ¥ 开头', () {
      expect(service.extractAmount('实收 ¥128.00'), closeTo(128.00, 0.001));
    });

    test('应付 ￥ 开头', () {
      expect(service.extractAmount('应付 ￥88.00'), closeTo(88.00, 0.001));
    });

    test('支付金额: 前缀', () {
      expect(service.extractAmount('支付金额: 45.50'), closeTo(45.50, 0.001));
    });

    test('金额: 前缀', () {
      expect(service.extractAmount('金额：200.00'), closeTo(200.00, 0.001));
    });

    test('纯 ¥ 符号在前', () {
      expect(service.extractAmount('¥68.00'), closeTo(68.00, 0.001));
    });

    test('金额后接 元', () {
      expect(service.extractAmount('35.50元'), closeTo(35.50, 0.001));
    });

    test('无金额文本返回 null', () {
      expect(service.extractAmount('这是一张没有金额的小票'), null);
    });

    test('空文本返回 null', () {
      expect(service.extractAmount(''), null);
    });
  });

  group('OcrService.extractDate', () {
    late OcrService service;

    setUp(() => service = OcrService());
    tearDown(() => service.dispose());

    test('YYYY-MM-DD 格式', () {
      final date = service.extractDate('2026-06-08');
      expect(date, isNotNull);
      expect(date!.year, 2026);
      expect(date.month, 6);
      expect(date.day, 8);
    });

    test('YYYY年MM月DD日 格式', () {
      final date = service.extractDate('2026年06月08日');
      expect(date, isNotNull);
      expect(date!.year, 2026);
      expect(date.month, 6);
      expect(date.day, 8);
    });

    test('YYYY/MM/DD 格式', () {
      final date = service.extractDate('2026/6/8');
      expect(date, isNotNull);
      expect(date!.year, 2026);
      expect(date.month, 6);
      expect(date.day, 8);
    });

    test('YYYYMMDD 紧凑格式', () {
      final date = service.extractDate('20260608');
      expect(date, isNotNull);
      expect(date!.year, 2026);
      expect(date.month, 6);
      expect(date.day, 8);
    });

    test('日期在文本中间', () {
      final date = service.extractDate('交易时间：2026-06-08 14:30:00');
      expect(date, isNotNull);
      expect(date!.year, 2026);
      expect(date.month, 6);
      expect(date.day, 8);
    });

    test('无日期文本返回 null', () {
      expect(service.extractDate('没有任何日期的小票文本'), null);
    });

    test('空文本返回 null', () {
      expect(service.extractDate(''), null);
    });
  });

  group('OcrResult', () {
    test('isSuccessful — 全为空时返回 false', () {
      final result = OcrResult(rawText: '');
      expect(result.isSuccessful, false);
    });

    test('isSuccessful — 有金额时返回 true', () {
      final result = OcrResult(amount: 42.5, rawText: '合计：42.50');
      expect(result.isSuccessful, true);
    });

    test('isSuccessful — 有商户名时返回 true', () {
      final result = OcrResult(merchant: '永辉超市', rawText: '永辉超市');
      expect(result.isSuccessful, true);
    });

    test('isSuccessful — 有日期时返回 true', () {
      final result = OcrResult(date: DateTime(2026, 6, 8), rawText: '2026-06-08');
      expect(result.isSuccessful, true);
    });
  });
}
