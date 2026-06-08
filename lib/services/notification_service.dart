import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 本地通知服务
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// 初始化通知通道
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  /// 发送通知（提醒补充文件）
  Future<void> showPaymentReminder(int count) async {
    const androidDetails = AndroidNotificationDetails(
      'payment_reminder',
      '支付记录提醒',
      channelDescription: '提醒用户补充支付记录截图',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      1001,
      '缺少支付记录',
      '您有 $count 条消费记录缺少支付记录截图，请及时补充',
      details,
    );
  }

  /// 发送通知（发票已下载）
  Future<void> showInvoiceDownloaded(String merchant, double amount) async {
    const androidDetails = AndroidNotificationDetails(
      'invoice_downloaded',
      '发票下载',
      channelDescription: '发票已自动下载',
      importance: Importance.defaultImportance,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      1002,
      '发票已下载',
      '$merchant ($amount元) 的发票已自动下载',
      details,
    );
  }

  /// 发送通知（月度报告已发送）
  Future<void> showMonthlyReportSent(String month) async {
    const androidDetails = AndroidNotificationDetails(
      'monthly_report',
      '月度报告',
      channelDescription: '月度报销文件已打包发送',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      1003,
      '月度报销文件已发送',
      '$month 的报销文件已打包发送到您的邮箱',
      details,
    );
  }
}
