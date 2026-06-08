import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/app_database.dart';
import 'database/tables.dart';
import 'screens/home_screen.dart';
import 'screens/email_config_screen.dart';
import 'services/notification_service.dart';
import 'services/scheduler_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知
  await NotificationService().initialize();

  // 初始化定时任务
  final scheduler = SchedulerService();
  await scheduler.initialize();
  await scheduler.scheduleDailyCheck();
  await scheduler.scheduleMonthlyPack();

  runApp(const InvoiceApp());
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DatabaseProvider(
      child: MaterialApp(
        title: '报销文件管理',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
