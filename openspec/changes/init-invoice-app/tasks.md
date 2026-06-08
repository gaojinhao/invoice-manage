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

## Phase 4: 邮件服务

- [ ] 4.1 实现邮箱配置页
- [ ] 4.2 实现 IMAP 收件
- [ ] 4.3 实现发票自动匹配
- [ ] 4.4 实现月度 ZIP 打包
- [ ] 4.5 实现 SMTP 发送

## Phase 5: 定时任务与通知

- [ ] 5.1 集成 WorkManager
- [ ] 5.2 实现每日检查 + 通知
- [ ] 5.3 实现每日邮箱自动下载
- [ ] 5.4 实现月初打包发送
- [ ] 5.5 引导加入省电白名单

## Phase 6: UI 界面

- [ ] 6.1 首页仪表盘
- [ ] 6.2 消费记录列表
- [ ] 6.3 拍照/上传页
- [ ] 6.4 记录详情页
- [ ] 6.5 邮箱配置页
- [ ] 6.6 设置页
