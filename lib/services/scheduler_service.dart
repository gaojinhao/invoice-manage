import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';

/// 后台定时任务名称常量
class SchedulerTasks {
  static const dailyCheck = 'dailyCheck';
  static const monthlyPack = 'monthlyPack';
}

/// 定时任务调度服务
class SchedulerService {
  /// 注册定时任务
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
      existingWorkPolicy: ExistingWorkPolicy.replace,
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
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// 计算到下一个指定时间的延迟
  Duration _nextRunAt(int hour, int minute) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next.difference(now);
  }

  /// 计算到下个月 1 号的延迟
  Duration _nextMonthlyRun() {
    final now = DateTime.now();
    var nextMonth = DateTime(now.year, now.month + 1, 1, 8, 0);
    // 如果本月还没到 1 号
    if (now.day == 1 && now.hour < 8) {
      nextMonth = DateTime(now.year, now.month, 1, 8, 0);
    }
    return nextMonth.difference(now);
  }
}

/// WorkManager 回调调度器（顶级函数）
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final notifier = NotificationService();

    switch (task) {
      case SchedulerTasks.dailyCheck:
        // 每日检查：由主应用在启动时同步执行
        // 后台只发通知提醒
        break;

      case SchedulerTasks.monthlyPack:
        // 月初打包：实际逻辑在 App 启动时处理
        // 此处仅为兜底提醒
        break;
    }

    return Future.value(true);
  });
}
