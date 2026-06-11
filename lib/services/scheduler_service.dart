import 'package:workmanager/workmanager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'check_pack_service.dart';
import 'email_service.dart';
import 'file_service.dart';
import 'notification_service.dart';
import '../database/app_database.dart';

/// 后台定时任务名称常量
class SchedulerTasks {
  static const dailyCheck = 'dailyCheck';
  static const monthlyPack = 'monthlyPack';
}

/// 定时任务调度服务（前台注册用）
class SchedulerService {
  /// 注册所有定时任务
  Future<void> initialize() async {
    await Workmanager().initialize(_callbackDispatcher);
  }

  /// 注册每日检查任务（每天 10:00）
  Future<void> scheduleDailyCheck() async {
    await Workmanager().registerPeriodicTask(
      SchedulerTasks.dailyCheck,
      SchedulerTasks.dailyCheck,
      frequency: const Duration(hours: 24),
      initialDelay: nextRunAt(10, 0),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  /// 注册月初打包任务（每天检查，只有每月 1 日实际执行）
  Future<void> scheduleMonthlyPack() async {
    await Workmanager().registerPeriodicTask(
      SchedulerTasks.monthlyPack,
      SchedulerTasks.monthlyPack,
      frequency: const Duration(hours: 24),
      initialDelay: nextMonthlyRun(),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  /// Visible for testing — calculates the delay until [hour]:[minute] today
  /// (or tomorrow if the time has already passed).
  Duration nextRunAt(int hour, int minute, {DateTime? now}) {
    final n = now ?? DateTime.now();
    var next = DateTime(n.year, n.month, n.day, hour, minute);
    if (next.isBefore(n)) next = next.add(const Duration(days: 1));
    return next.difference(n);
  }

  /// Visible for testing — calculates the delay until the next 1st of month
  /// at 08:00 (or today at 08:00 if it's already the 1st before 8 AM).
  Duration nextMonthlyRun({DateTime? now}) {
    final n = now ?? DateTime.now();
    var nextMonth = DateTime(n.year, n.month + 1, 1, 8, 0);
    if (n.day == 1 && n.hour < 8) {
      nextMonth = DateTime(n.year, n.month, 1, 8, 0);
    }
    return nextMonth.difference(n);
  }
}

/// WorkManager 回调调度器（顶级函数，后台 isolate 运行）
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case SchedulerTasks.dailyCheck:
          await _runDailyCheck();
          break;
        case SchedulerTasks.monthlyPack:
          await _runMonthlyPack();
          break;
      }
      return Future.value(true);
    } catch (_) {
      return Future.value(false);
    }
  });
}

/// 执行每日检查（在后台 isolate 中运行）
Future<void> _runDailyCheck() async {
  final db = AppDatabase();
  final notifier = NotificationService();
  final fileService = FileService();
  final emailService = EmailService();

  // 从安全存储加载邮箱配置
  try {
    const storage = FlutterSecureStorage();
    final email = await storage.read(key: 'email_addr') ?? '';
    final password = await storage.read(key: 'email_pass') ?? '';
    if (email.isNotEmpty && password.isNotEmpty) {
      emailService.configure(
        EmailConfig(
          email: email,
          password: password,
          imapServer: emailService.getImapServer(email),
        ),
      );
    }
  } catch (_) {
    // 后台 isolate 可能无法访问 secure storage，静默跳过
  }

  await notifier.initialize();

  final service = DailyCheckService(
    db: db,
    emailService: emailService,
    notifier: notifier,
    fileService: fileService,
  );

  await service.run();
  await db.close();
}

/// 执行月初打包
Future<void> _runMonthlyPack() async {
  if (DateTime.now().day != 1) return;

  final db = AppDatabase();
  final notifier = NotificationService();
  final fileService = FileService();
  final emailService = EmailService();

  // 从安全存储加载邮箱配置
  try {
    const storage = FlutterSecureStorage();
    final email = await storage.read(key: 'email_addr') ?? '';
    final password = await storage.read(key: 'email_pass') ?? '';
    final sendTo = await storage.read(key: 'send_to') ?? email;
    if (email.isNotEmpty && password.isNotEmpty) {
      emailService.configure(
        EmailConfig(
          email: email,
          password: password,
          imapServer: emailService.getImapServer(email),
          sendTo: sendTo,
        ),
      );
    }
  } catch (_) {
    // 静默跳过
  }

  await notifier.initialize();

  final service = MonthlyPackService(
    db: db,
    emailService: emailService,
    notifier: notifier,
    fileService: fileService,
  );

  await service.run();
  await db.close();
}
