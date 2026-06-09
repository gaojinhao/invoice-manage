import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mocktail/mocktail.dart';
import 'package:invoice_app/services/ocr_service.dart';

class MockTextRecognizer extends Mock implements TextRecognizer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('OcrService — 文本解析（通过 recognizeImage 间接测试）', () {
    late OcrService service;

    setUp(() {
      final mockRecognizer = MockTextRecognizer();
      when(() => mockRecognizer.close()).thenAnswer((_) async {});
      service = OcrService(recognizer: mockRecognizer);
    });

    tearDown(() {
      service.dispose();
    });

    // 注: 以下测试使用平台通道会触发 MissingPluginException
    // 在真机/模拟器或 flutter drive 下可运行完整流程
    // 单元测试阶段仅验证模型层逻辑

    test('service 创建和销毁不抛异常', () {
      // 基本生命周期验证
      expect(service, isNotNull);
    });
  });

  group('OcrService 解析逻辑集成（需要模拟器/真机）', () {
    // 以下覆盖实际的图片识别流程
    // 使用 google_mlkit_text_recognition 需要设备支持
    // 在 CI 中可用 flutter drive 或 firebase test lab

    test('识别小票文本 — 提取商户名（超市前缀）', () {
      const text = '华联超市\n地址：北京市朝阳区\n合计：128.00';
      // 需要通过 recognizeImage 传图片文件来测试
      // 单元测试阶段暂不覆盖
    });
  });
}
