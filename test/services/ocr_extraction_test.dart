import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mocktail/mocktail.dart';
import 'package:invoice_app/services/ocr_service.dart';

class MockTextRecognizer extends Mock implements TextRecognizer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OcrService.extractMerchant', () {
    late OcrService service;
    late MockTextRecognizer mockRecognizer;

    setUp(() {
      mockRecognizer = MockTextRecognizer();
      when(() => mockRecognizer.close()).thenAnswer((_) async {});
      service = OcrService(recognizer: mockRecognizer);
    });
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
      expect(service.extractMerchant('这是一张小票\n地址：xxx\n合计：100.00'), '这是一张小票');
    });

    test('空文本返回 null', () {
      expect(service.extractMerchant(''), null);
    });

    test('真实小票标题在前时选择门店名称', () {
      expect(
        service.extractMerchant('销售小票\n门店名称：喜茶深圳万象天地店\n地址：深圳市南山区\n合计：39.00'),
        '喜茶深圳万象天地店',
      );
    });

    test('支付截图优先选择收款商户', () {
      expect(
        service.extractMerchant('支付成功\n收款商户：麦当劳前海壹方汇店\n订单金额 ¥45.00'),
        '麦当劳前海壹方汇店',
      );
    });

    test('海底捞 OCR 错字归一并优先提取头部店名', () {
      expect(
        service.extractMerchant('@海底火祸\n而底排摩尔城店\n单据类型:预打单\n应付金额:\n193.00'),
        '海底捞摩尔城店',
      );
    });
  });

  group('OcrService.extractAmount', () {
    late OcrService service;
    late MockTextRecognizer mockRecognizer;

    setUp(() {
      mockRecognizer = MockTextRecognizer();
      when(() => mockRecognizer.close()).thenAnswer((_) async {});
      service = OcrService(recognizer: mockRecognizer);
    });
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

    test('真实小票排除电话优惠并选择实收金额', () {
      expect(
        service.extractAmount(
          '电话：13800138000\n商品A 68.00\n优惠：10.00\n合计：58.00\n实收 ¥58.00',
        ),
        closeTo(58.00, 0.001),
      );
    });

    test('金额标签与金额分行时提取下一行金额', () {
      expect(
        service.extractAmount('应付金额\n￥88.50\n支付方式：微信支付'),
        closeTo(88.50, 0.001),
      );
    });

    test('支付截图优先选择实付而非订单金额', () {
      expect(
        service.extractAmount(
          '支付成功\n商户名称：麦当劳\n订单金额 ¥45.00\n优惠 ¥5.00\n实付金额 ¥40.00',
        ),
        closeTo(40.00, 0.001),
      );
    });

    test('海底捞小票从末尾最终金额提取而非原单金额', () {
      expect(
        service.extractAmount(
          '原单金額:\n215.00\n菜品金额:\n215.00\n优惠金额:\n-22.00\n赠菜金额\n-22.00\n应付金額:\n193.00\n餐饮消費金額:\n193.00\n打印:2026-05-23 22:22:25',
        ),
        closeTo(193.00, 0.001),
      );
    });

    test('最终金额标签后方是打印时间时不提取秒数', () {
      expect(
        service.extractAmount(
          '原单金额:\n215.00\n优惠金额:\n-22.00\n193.00\n应付金額:\n193.00\n餐饮消费金額:\n打印:2026-05-23 22:22:25',
        ),
        closeTo(193.00, 0.001),
      );
    });
  });

  group('OcrService.extractDate', () {
    late OcrService service;
    late MockTextRecognizer mockRecognizer;

    setUp(() {
      mockRecognizer = MockTextRecognizer();
      when(() => mockRecognizer.close()).thenAnswer((_) async {});
      service = OcrService(recognizer: mockRecognizer);
    });
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
      final result = OcrResult(
        date: DateTime(2026, 6, 8),
        rawText: '2026-06-08',
      );
      expect(result.isSuccessful, true);
    });
  });
}
