import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/services/pdf_render_service.dart';
import 'package:invoice_app/services/print_word_service.dart';

import '../helpers/mocks.dart';

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lXW8CgAAAABJRU5ErkJggg==';

Future<File> _png(Directory dir, String name) async {
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(base64Decode(_onePixelPng));
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrintWordService', () {
    test('生成包含发票和支付记录图片的 Word 文件', () async {
      final base = await Directory.systemTemp.createTemp('print_word_test_');
      addTearDown(() => base.delete(recursive: true));
      final invoice = await _png(base, 'invoice.png');
      final payment = await _png(base, 'payment.png');
      final service = PrintWordService()..baseDirectory = () async => base;

      final path = await service.createMonthPrintDoc(
        year: 2026,
        month: 6,
        records: [
          makeRecord(invoicePdf: invoice.path, paymentImg: payment.path),
        ],
      );

      expect(path, isNotNull);
      final bytes = await File(path!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile('word/document.xml'), isNotNull);
      expect(
        archive.files.where((f) => f.name.startsWith('word/media/')),
        hasLength(2),
      );
    });

    test('PDF 发票通过 renderer 转为图片后写入 Word', () async {
      final base = await Directory.systemTemp.createTemp(
        'print_word_pdf_test_',
      );
      addTearDown(() => base.delete(recursive: true));
      final pdf = File('${base.path}/invoice.pdf');
      await pdf.writeAsString('fake pdf');
      final rendered = await _png(base, 'rendered.png');
      final service = PrintWordService(
        pdfRenderService: _FakePdfRenderService([rendered.path]),
      )..baseDirectory = () async => base;

      final path = await service.createMonthPrintDoc(
        year: 2026,
        month: 6,
        records: [makeRecord(invoicePdf: pdf.path)],
      );

      expect(path, isNotNull);
      final archive = ZipDecoder().decodeBytes(await File(path!).readAsBytes());
      expect(
        archive.files.where((f) => f.name.startsWith('word/media/')),
        hasLength(1),
      );
    });
  });
}

class _FakePdfRenderService extends PdfRenderService {
  final List<String> paths;

  const _FakePdfRenderService(this.paths);

  @override
  Future<List<String>> renderPdfToImages({
    required String pdfPath,
    required String outputDir,
  }) async {
    return paths;
  }
}
