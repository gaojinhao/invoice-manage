# Tasks: 初始化报销文件管理 App（纯 Flutter 方案）

> 🟢 已完成 | 🟡 进行中 | ⚪ 待开始

## Phase 1: 项目初始化 ✅

- [x] 1.1 创建 Flutter 项目（Android + 鸿蒙配置）
- [x] 1.2 配置依赖（drift, image_picker, google_mlkit_text_recognition 等）
- [x] 1.3 搭建项目目录结构（models/services/screens/widgets）
- [x] 1.4 创建数据模型 + 数据库表（drift ORM）

## Phase 2: OCR 识别 ✅

- [x] 2.1 实现拍照/相册选择功能（camera_screen.dart）
- [x] 2.2 集成 Google ML Kit 文字识别（ocr_service.dart）
- [x] 2.3 解析识别结果：金额、日期、商户名（ocr_service.dart _extractMerchant/Amount/Date）
- [x] 2.4 实现识别结果预览与手动修正页（camera_screen.dart OCR预览 + 编辑表单）

## Phase 3: 消费记录管理 ✅

- [x] 3.1 实现消费记录增删改查（app_database.dart createRecord / deleteRecord）
- [x] 3.2 实现状态流转（updatePaymentImage → pendingInvoice → updateInvoicePdf → complete → markArchived）
- [x] 3.3 实现月份筛选与列表展示（getRecordsByMonth + HomeScreen 记录列表）
- [x] 3.4 实现本月消费总额统计 + 仪表盘（getMonthlyTotal + getStatusCounts + 首页卡片）

## Phase 4: 邮件服务 ✅

- [x] 4.1 实现邮箱配置页（email_config_screen.dart）
- [x] 4.2 实现 IMAP 收件（email_service.dart _ImapClient，基于 Socket 完整实现）
- [x] 4.3 实现发票自动匹配（invoice_matcher_service.dart，金额+商户+日期多策略打分）
- [x] 4.4 实现月度 ZIP 打包（file_service.dart zipMonthRecords）
- [x] 4.5 实现 SMTP 发送（email_service.dart sendEmail，支持 QQ/163/Outlook/Gmail）

## Phase 5: 定时任务与通知 ✅

- [x] 5.1 集成 WorkManager（scheduler_service.dart 注册+回调）
- [x] 5.2 实现每日检查 + 通知（DailyCheckService + NotificationService）
- [x] 5.3 实现每日邮箱自动下载（DailyCheckService._checkEmailInvoices）
- [x] 5.4 实现月初打包发送（MonthlyPackService -> ZIP -> SMTP -> 归档）
- [x] 5.5 引导加入省电白名单（settings_screen.dart 各品牌指南弹窗）

## Phase 6: UI 界面 ✅

- [x] 6.1 首页仪表盘（home_screen.dart 月度总额+状态统计卡片）
- [x] 6.2 消费记录列表（home_screen.dart 月份切换+状态颜色标识）
- [x] 6.3 拍照/上传页（camera_screen.dart 拍照→OCR→确认→保存）
- [x] 6.4 记录详情页（record_detail_screen.dart 文件清单+补充入口）
- [x] 6.5 邮箱配置页（email_config_screen.dart 授权码+测试连接）
- [x] 6.6 设置页（settings_screen.dart 含深色模式+省电白名单+数据库管理+导出）

## Phase 7: 平台构建 & 可运行 🟡

- [x] 7.1 跑 `flutter create .` 重新生成 Android 平台脚手架（build.gradle / settings.gradle / gradle-wrapper 等）
- [x] 7.2 恢复 AndroidManifest.xml 中的权限和 WorkManager 配置
- [x] 7.3 跑 `flutter build apk --debug` 验证构建成功（188MB debug APK）
- [x] 7.4 跑 `flutter analyze` 确保无新增错误（0 errors）
- [ ] 7.5 真机运行验证全流程
