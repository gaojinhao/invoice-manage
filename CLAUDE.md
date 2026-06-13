# CLAUDE.md

本文件是 Claude Code 在此仓库的**主工作指引**，会话启动时自动读取。`AGENTS.md` 是面向其他 AI 工具的精简版，内容以此文件为准。

---

## 项目概览

个人报销文件管理 Flutter App，面向中文使用场景。核心流程：

1. 拍照或从相册选择结账单
2. 使用 Google ML Kit 中文 OCR 提取商户名、金额、日期
3. 创建消费记录并保存结账单图片
4. 后续补充支付记录截图和发票文件
5. 按月打包本地文件，支持分享或邮件发送

### 技术栈

| 层 | 技术 |
|----|------|
| 框架 | Flutter / Dart，Material 3 UI |
| 数据库 | Drift + SQLite（本地） |
| OCR | Google ML Kit 离线中文识别 |
| 图片 | `image_picker` 拍照/选图 |
| 文件 | `file_picker` PDF 选择，`archive` ZIP 打包，`share_plus` 系统分享 |
| 后台 | `workmanager` 定时任务 |
| 通知 | `flutter_local_notifications` 本地通知 |
| 安全 | `flutter_secure_storage` 邮箱授权码 |

## 目录导览

```text
lib/
├── main.dart                         # 入口、错误兜底、Provider、主题、本地化
├── database/
│   ├── tables.dart                   # Drift 表定义 + RecordStatus 枚举
│   ├── app_database.dart             # 数据库 API、查询、状态更新
│   └── app_database.g.dart           # Drift 生成（勿手工编辑）
├── screens/
│   ├── home_screen.dart              # 首页、月度汇总、状态卡片、打包导出
│   ├── camera_screen.dart            # 拍照/选图、OCR、创建消费记录
│   ├── record_detail_screen.dart     # 三证文件管理、查看/替换、删除
│   ├── email_config_screen.dart      # 邮箱配置（SMTP/IMAP）
│   ├── settings_screen.dart          # 设置（清除数据、备份）
│   ├── search_screen.dart            # 搜索
│   └── charts_screen.dart            # 消费统计图表
├── services/
│   ├── ocr_service.dart              # ML Kit 识别 + 金额/商户/日期提取规则
│   ├── file_service.dart             # 本地目录、图片/PDF 保存、月度 ZIP
│   ├── email_service.dart            # SMTP 发件 + 简易 IMAP 收件
│   ├── invoice_matcher_service.dart  # 邮箱发票与待开发票记录自动匹配
│   ├── check_pack_service.dart       # 每日检查 + 月初打包流程
│   ├── scheduler_service.dart        # Workmanager 注册 + 后台 isolate 回调
│   ├── notification_service.dart     # 本地通知
│   ├── export_service.dart           # CSV 导出 + 数据库备份
│   ├── print_word_service.dart       # 月度打印裁剪 Word 生成
│   └── amount_validation_service.dart # 上传文件金额 OCR 校验
test/
├── database/app_database_test.dart   # in-memory SQLite 集成测试
├── services/                         # 服务层测试
│   ├── ocr_extraction_test.dart      # OCR 商户/金额/日期提取
│   ├── file_service_test.dart        # 文件 I/O
│   ├── email_service_test.dart       # 邮件逻辑
│   ├── invoice_matcher_service_test.dart
│   ├── check_pack_service_test.dart
│   ├── scheduler_service_test.dart
│   ├── export_service_test.dart
│   └── ...
└── helpers/mocks.dart                # mocktail Mock + stub 工厂
```

## 业务模型

核心表 `ConsumptionRecords`（Drift）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `date` | DateTime | 消费日期 |
| `merchant` | String | 商户名 |
| `amount` | double | 金额 |
| `month` | String | 月份索引 `YYYY-MM`，自动生成 |
| `status` | enum | `pendingPayment` → `pendingInvoice` → `complete` → `archived` |
| `receiptImg` | String? | 结账单图片路径 |
| `paymentImg` | String? | 支付记录截图路径 |
| `invoicePdf` | String? | 发票文件路径 |
| `notes` | String? | 备注 |

文件存放结构（应用文档目录下）：

```text
records/YYYY-MM/YYYY-MM-DD_商户名/
  结账单.jpg
  支付记录.jpg
  发票.<ext>               ← 按实际扩展名（pdf/jpg/png）
```

商户名用于目录名时替换 `\ / : * ? " < > |` 为 `_`。文件路径当前存**绝对路径**。

状态推导（`AppDatabase.statusForFiles`）：

- 三证齐全 → `complete`
- 有支付记录无发票 → `pendingInvoice`
- 其他 → `pendingPayment`
- 已归档 → 始终 `archived`

## OCR 约定

- 当前只使用 Google ML Kit 中文识别，不依赖 Paddle/ONNX
- `OcrService` 提取策略：
  - 商户名：优先从文本头部、靠上行、含店名/餐饮/品牌关键字的候选提取
  - 金额：优先从尾部和 `应付金额`/`实付金额`/`餐饮消费金额` 标签附近提取
  - 压低中间金额（`原单金额`、`优惠金额`、日期时间、电话、单号）
  - 少量 OCR 错字归一化（海底捞/摩尔城店相关）
- 改 OCR 必须同步更新 `test/services/ocr_extraction_test.dart`
- 当前 OCR 不保证 100% 准确，降级时会自动切到手动录入模式

## 数据库 & 生成文件

- 表结构 → `lib/database/tables.dart`
- API → `lib/database/app_database.dart`
- 生成文件 → `lib/database/app_database.g.dart`（**禁止手工编辑**）
- 测试用 in-memory DB → `AppDatabase.test()`
- `schemaVersion = 1`，迁移必须加 `MigrationStrategy`
- 改表结构后运行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 运行 & 构建

```bash
# 日常
flutter pub get
dart format lib test
flutter analyze
flutter test

# 指定测试
flutter test test/database/app_database_test.dart
flutter test test/services/ocr_extraction_test.dart

# 构建 APK
flutter build apk --debug

# 真机部署（推荐，比 flutter run 稳定）
flutter build apk --debug
adb install -r -g build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.example.invoice_app/.MainActivity
```

Android 构建注意事项：
- `JAVA_HOME` 需指向 JDK 21（开发机路径 `/opt/homebrew/opt/openjdk@21`）
- App ID：`com.example.invoice_app`，`minSdk = 26`
- ML Kit 中文识别需在 app module 显式依赖 `com.google.mlkit:text-recognition-chinese:16.0.1`
- `compileSdk = 36`（手动指定，高于 Flutter 默认值）
- `file_picker` 使用 11.x（Kotlin-only），Gradle 有预编译 hook 处理 registrant 兼容
