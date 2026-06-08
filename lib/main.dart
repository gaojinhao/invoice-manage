import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'database/app_database.dart';
import 'database/tables.dart';
import 'screens/home_screen.dart';
import 'screens/email_config_screen.dart';
import 'services/notification_service.dart';
import 'services/scheduler_service.dart';
import 'services/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知
  await NotificationService().initialize();

  // 初始化定时任务
  final scheduler = SchedulerService();
  await scheduler.initialize();
  await scheduler.scheduleDailyCheck();
  await scheduler.scheduleMonthlyPack();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const InvoiceApp(),
    ),
  );
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return DatabaseProvider(
      child: MaterialApp(
        title: '报销文件管理',
        debugShowCheckedModeBanner: false,
        themeMode: themeProvider.mode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('zh', 'CN'),
          const Locale('en', 'US'),
        ],
        locale: const Locale('zh', 'CN'),
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
