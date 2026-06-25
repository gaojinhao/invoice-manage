import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'pdf_render_service.dart';

class PrintWordService {
  Future<Directory> Function() baseDirectory = getApplicationDocumentsDirectory;
  final PdfRenderService pdfRenderService;

  PrintWordService({this.pdfRenderService = const PdfRenderService()});

  static const _emuPerTwip = 635;
  static const _pageWidthTwips = 11906;
  static const _pageHeightTwips = 16838;
  static const _pageMarginTwips = 360;
  static const _paymentsPerRow = 5;
  static const _contentWidthEmu =
      (_pageWidthTwips - _pageMarginTwips * 2) * _emuPerTwip;
  static const _contentHeightEmu =
      (_pageHeightTwips - _pageMarginTwips * 2) * _emuPerTwip;
  static const _paymentWidthEmu = _contentWidthEmu ~/ _paymentsPerRow;
  static const _paymentHeightEmu = _contentHeightEmu ~/ 4;

  Future<String?> createMonthPrintDoc({
    required int year,
    required int month,
    required List<ConsumptionRecord> records,
  }) async {
    final base = await baseDirectory();
    final monthStr =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final monthDir = Directory('${base.path}/records/$monthStr');
    await monthDir.create(recursive: true);

    final tempDir = await Directory.systemTemp.createTemp(
      'invoice_print_word_',
    );
    try {
      final images = <_DocImage>[];
      for (final record in records) {
        final invoice = record.invoicePdf;
        if (invoice != null) {
          for (final path in await _invoiceImagePaths(invoice, tempDir)) {
            images.add(_DocImage(path: path, kind: _ImageKind.invoice));
          }
        }
        final payment = record.paymentImg;
        if (payment != null && await File(payment).exists()) {
          images.add(_DocImage(path: payment, kind: _ImageKind.payment));
        }
      }

      if (images.isEmpty) return null;
      final bytes = await _buildDocx(images);
      final output = File('${monthDir.path}/打印裁剪.docx');
      await output.writeAsBytes(bytes);
      return output.path;
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<List<String>> _invoiceImagePaths(
    String path,
    Directory tempDir,
  ) async {
    final file = File(path);
    if (!await file.exists()) return [];
    if (_isPdf(path)) {
      try {
        return pdfRenderService.renderPdfToImages(
          pdfPath: path,
          outputDir: tempDir.path,
        );
      } catch (_) {
        return [];
      }
    }
    return _isImage(path) ? [path] : [];
  }

  Future<List<int>> _buildDocx(List<_DocImage> images) async {
    final archive = Archive();
    final mediaRels = <String>[];
    final body = StringBuffer();
    var index = 0;

    for (final image in images.where((i) => i.kind == _ImageKind.invoice)) {
      index++;
      final relId = 'rId$index';
      final mediaName = 'image$index.${_extension(image.path)}';
      final height = await _invoiceHeight(image.path);
      _addFile(
        archive,
        'word/media/$mediaName',
        await File(image.path).readAsBytes(),
      );
      mediaRels.add(_relationship(relId, mediaName));
      body.write(
        _paragraph([
          _drawing(relId, 'invoice_$index', _contentWidthEmu, height),
        ]),
      );
    }

    final payments = images.where((i) => i.kind == _ImageKind.payment).toList();
    for (var row = 0; row < payments.length; row += _paymentsPerRow) {
      final drawings = <String>[];
      for (final image in payments.skip(row).take(_paymentsPerRow)) {
        index++;
        final relId = 'rId$index';
        final mediaName = 'image$index.${_extension(image.path)}';
        _addFile(
          archive,
          'word/media/$mediaName',
          await File(image.path).readAsBytes(),
        );
        mediaRels.add(_relationship(relId, mediaName));
        drawings.add(
          _drawing(
            relId,
            'payment_$index',
            _paymentWidthEmu,
            _paymentHeightEmu,
          ),
        );
      }
      body.write(_paragraph(drawings));
    }

    _addText(archive, '[Content_Types].xml', _contentTypes());
    _addText(archive, '_rels/.rels', _rootRels());
    _addText(archive, 'word/document.xml', _document(body.toString()));
    _addText(
      archive,
      'word/_rels/document.xml.rels',
      _docRels(mediaRels.join()),
    );
    return ZipEncoder().encode(archive);
  }

  Future<int> _invoiceHeight(String path) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(path);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final height =
          (_contentWidthEmu / descriptor.width * descriptor.height).round();
      descriptor.dispose();
      buffer.dispose();
      return height;
    } catch (_) {
      return 9360000;
    }
  }

  void _addText(Archive archive, String path, String text) {
    _addFile(archive, path, utf8.encode(text));
  }

  void _addFile(Archive archive, String path, List<int> bytes) {
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  String _extension(String path) =>
      path.split('.').last.toLowerCase() == 'jpg'
          ? 'jpeg'
          : path.split('.').last.toLowerCase();
  bool _isPdf(String path) => path.toLowerCase().endsWith('.pdf');
  bool _isImage(String path) =>
      RegExp(r'\.(png|jpe?g)$', caseSensitive: false).hasMatch(path);

  String _paragraph(List<String> drawings) =>
      '<w:p><w:pPr><w:jc w:val="left"/></w:pPr><w:r>${drawings.join('</w:r><w:r>')}</w:r></w:p>';
  String _relationship(String id, String target) =>
      '<Relationship Id="$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$target"/>';
  String _docRels(String rels) =>
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">$rels</Relationships>';
  String _rootRels() =>
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>';
  String _contentTypes() =>
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="jpeg" ContentType="image/jpeg"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>';
  String _document(String body) =>
      '<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>$body<w:sectPr><w:pgSz w:w="$_pageWidthTwips" w:h="$_pageHeightTwips"/><w:pgMar w:top="$_pageMarginTwips" w:right="$_pageMarginTwips" w:bottom="$_pageMarginTwips" w:left="$_pageMarginTwips"/></w:sectPr></w:body></w:document>';
  String _drawing(String relId, String name, int cx, int cy) =>
      '<w:drawing><wp:inline><wp:extent cx="$cx" cy="$cy"/><wp:docPr id="${relId.substring(3)}" name="$name"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="$name"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="$relId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>';
}

enum _ImageKind { invoice, payment }

class _DocImage {
  final String path;
  final _ImageKind kind;

  const _DocImage({required this.path, required this.kind});
}
