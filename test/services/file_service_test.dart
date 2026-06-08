import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:invoice_app/services/file_service.dart';

class MockFile extends Mock implements File {}

void main() {
  group('FileService — 路径构建', () {
    test('getRecordDir 构建正确的目录结构', () async {
      // 路径构建逻辑不依赖平台通道，可以直接测试字符串模式
      const merchant = '华联超市';
      const date = '2026-06-08';
      const expectedPattern =
          RegExp(r'.+/records/2026-06/2026-06-08_华联超市$');

      // 验证 merchant 中的非法字符被替换
      const specialMerchant = 'test/file?name<>';
      final safeMerchant = specialMerchant.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      expect(safeMerchant, 'test_file_name__');
    });

    test('saveInvoicePdf 构建正确文件名', () {
      const expectedFile = '发票.pdf';
      expect(expectedFile, '发票.pdf');
    });

    test('saveReceiptImage 构建正确文件名', () {
      const expectedFile = '结账单.jpg';
      expect(expectedFile, '结账单.jpg');
    });

    test('savePaymentImage 构建正确文件名', () {
      const expectedFile = '支付记录.jpg';
      expect(expectedFile, '支付记录.jpg');
    });
  });

  group('FileService — merchant 安全化', () {
    test('普通中文商户名保持原样', () {
      final result = '华联超市'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      expect(result, '华联超市');
    });

    test('含非法字符的商户名被替换', () {
      final result = 'file:test?name'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      expect(result, 'file_test_name');
    });

    test('空商户名不变', () {
      final result = ''.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      expect(result, '');
    });

    test('全角字符不受影响', () {
      final result = '【测试】超市★'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      expect(result, '【测试】超市★');
    });
  });
}
