import 'dart:ui' as ui;

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

  // 初始化各项服务，失败不阻塞 App 启动
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService 初始化失败: $e');
  }

  try {
    final scheduler = SchedulerService();
    await scheduler.initialize();
    await scheduler.scheduleDailyCheck();
    await scheduler.scheduleMonthlyPack();
  } catch (e) {
    debugPrint('SchedulerService 初始化失败: $e');
  }

  runApp(
    _ErrorHandler(
      child: ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const InvoiceApp(),
      ),
    ),
  );
}

/// 全局错误兜底 — 捕获 Flutter 框架层未处理异常
class _ErrorHandler extends StatefulWidget {
  final Widget child;
  const _ErrorHandler({required this.child});

  @override
  State<_ErrorHandler> createState() => _ErrorHandlerState();
}

class _ErrorHandlerState extends State<_ErrorHandler> {
  String? _error;

  @override
  void initState() {
    super.initState();
    // 捕获 Flutter 框架错误
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      setState(() => _error = details.exceptionAsString());
    };
    // 捕获未处理的异步异常
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      setState(() => _error = error.toString());
      return true;
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('App 启动出错', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
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
