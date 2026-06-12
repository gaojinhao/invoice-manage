import 'dart:io';

import 'package:flutter/services.dart';

class PdfRenderService {
  static const _channel = MethodChannel('invoice_app/pdf_renderer');

  const PdfRenderService();

  Future<List<String>> renderPdfToImages({
    required String pdfPath,
    required String outputDir,
  }) async {
    if (!Platform.isAndroid) return [];

    final paths = await _channel.invokeListMethod<String>('renderPdf', {
      'pdfPath': pdfPath,
      'outputDir': outputDir,
    });
    return paths ?? [];
  }
}
