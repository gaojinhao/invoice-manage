import 'package:mocktail/mocktail.dart';
import 'package:invoice_app/database/app_database.dart';
import 'package:invoice_app/database/tables.dart';
import 'package:invoice_app/services/email_service.dart';
import 'package:invoice_app/services/file_service.dart';
import 'package:invoice_app/services/notification_service.dart';

/// AppDatabase mock
class MockAppDatabase extends Mock implements AppDatabase {}

/// EmailService mock
class MockEmailService extends Mock implements EmailService {}

/// FileService mock
class MockFileService extends Mock implements FileService {}

/// NotificationService mock
class MockNotificationService extends Mock implements NotificationService {}

/// OcrResult stub 工厂
OcrResult makeOcrResult({
  String? merchant,
  double? amount,
  DateTime? date,
  String rawText = '',
  double confidence = 0.85,
}) {
  return OcrResult(
    merchant: merchant,
    amount: amount,
    date: date,
    rawText: rawText,
    confidence: confidence,
  );
}

/// ConsumptionRecord stub 工厂
ConsumptionRecord makeRecord({
  String id = 'rec_001',
  DateTime? date,
  String merchant = '测试超市',
  double amount = 42.5,
  RecordStatus status = RecordStatus.pendingPayment,
  String? receiptImg,
  String? paymentImg,
  String? invoicePdf,
  String? notes,
}) {
  final now = DateTime.now();
  return ConsumptionRecord(
    id: id,
    date: date ?? DateTime(2026, 6, 8),
    merchant: merchant,
    amount: amount,
    status: status,
    month: '2026-06',
    receiptImg: receiptImg,
    paymentImg: paymentImg,
    invoicePdf: invoicePdf,
    notes: notes,
    createdAt: now,
    updatedAt: now,
  );
}

/// DownloadedInvoice stub 工厂
DownloadedInvoice makeInvoice({
  String fileName = 'invoice.pdf',
  String localPath = '/tmp/invoice.pdf',
  String subject = '电子发票_测试超市',
  DateTime? date,
  double? matchedAmount,
}) {
  return DownloadedInvoice(
    fileName: fileName,
    localPath: localPath,
    subject: subject,
    date: date ?? DateTime(2026, 6, 8),
    matchedAmount: matchedAmount,
  );
}
