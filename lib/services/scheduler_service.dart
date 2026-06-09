import 'package:workmanager/workmanager.dart';
import 'package:path_provider/path_provider.dart';
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
    await Workmanager().initialize(
      _callbackDispatcher,
      isInDebugMode: false,
    );
  }

  /// 注册每日检查任务（每天 10:00）
  Future<void> scheduleDailyCheck() async {
    await Workmanager().registerPeriodicTask(
      SchedulerTasks.dailyCheck,
      SchedulerTasks.dailyCheck,
      frequency: const Duration(hours: 24),
      initialDelay: _nextRunAt(10, 0),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  /// 注册月初打包任务（每月 1 日 08:00）
  Future<void> scheduleMonthlyPack() async {
    await Workmanager().registerPeriodicTask(
      SchedulerTasks.monthlyPack,
      SchedulerTasks.monthlyPack,
      frequency: const Duration(days: 30),
      initialDelay: _nextMonthlyRun(),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  Duration _nextRunAt(int hour, int minute) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));
    return next.difference(now);
  }

  Duration _nextMonthlyRun() {
    final now = DateTime.now();
    var nextMonth = DateTime(now.year, now.month + 1, 1, 8, 0);
    if (now.day == 1 && now.hour < 8) {
      nextMonth = DateTime(now.year, now.month, 1, 8, 0);
    }
    return nextMonth.difference(now);
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
    final storage = FlutterSecureStorage();
    final email = await storage.read(key: 'email_addr') ?? '';
    final password = await storage.read(key: 'email_pass') ?? '';
    if (email.isNotEmpty && password.isNotEmpty) {
      emailService.configure(EmailConfig(
        email: email,
        password: password,
        imapServer: emailService.getImapServer(email),
      ));
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
  final db = AppDatabase();
  final notifier = NotificationService();
  final fileService = FileService();
  final emailService = EmailService();

  // 从安全存储加载邮箱配置
  try {
    final storage = FlutterSecureStorage();
    final email = await storage.read(key: 'email_addr') ?? '';
    final password = await storage.read(key: 'email_pass') ?? '';
    final sendTo = await storage.read(key: 'send_to') ?? email;
    if (email.isNotEmpty && password.isNotEmpty) {
      emailService.configure(EmailConfig(
        email: email,
        password: password,
        imapServer: emailService.getImapServer(email),
        sendTo: sendTo,
      ));
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
