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
│   ├── ocr_service_test.dart         # OCR 基础
│   ├── ocr_extraction_test.dart      # OCR 商户/金额/日期提取
│   ├── file_service_test.dart        # 文件 I/O
│   ├── email_service_test.dart       # 邮件逻辑
│   ├── email_server_config_test.dart # 邮件服务器配置
│   ├── invoice_matcher_service_test.dart
│   ├── check_pack_service_test.dart
│   ├── scheduler_service_test.dart
│   ├── export_service_test.dart
│   ├── print_word_service_test.dart
│   ├── amount_validation_service_test.dart
│   └── notification_service_test.dart
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
  发票.pdf         ← 实为发票.<ext>，按实际扩展名（pdf/jpg/png）
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
- `JAVA_HOME` 需指向 JDK 21（本机路径 `/opt/homebrew/opt/openjdk@21`）
- App ID：`com.example.invoice_app`，`minSdk = 26`
- ML Kit 中文识别需在 app module 显式依赖 `com.google.mlkit:text-recognition-chinese:16.0.1`
- `compileSdk = 36`（手动指定，高于 Flutter 默认值）
- `file_picker` 使用 11.x（Kotlin-only），Gradle 有预编译 hook 处理 registrant 兼容

## 测试策略

- 服务层优先，使用 in-memory SQLite / 真实文件 I/O + 依赖注入，减少纯 mock 测试
- 新建 service 必须同步创建 `test/services/<name>_test.dart`
- 文件 I/O 测试：注入 `baseDirectory`，使用 `Directory.systemTemp.createTemp()`
- 数据库测试：使用 `AppDatabase.test()`（`NativeDatabase.memory()`）
- 纯逻辑方法：暴露为 `static` 并标注 `// Visible for testing`
- 当前 229 tests，`flutter test` 全部通过

常用测试命令：

```bash
flutter test test/services/ocr_extraction_test.dart                                  # OCR 提取
flutter test test/services/file_service_test.dart                                    # 文件服务
flutter test test/services/email_service_test.dart test/services/email_server_config_test.dart  # 邮件
flutter test test/services/invoice_matcher_service_test.dart test/services/check_pack_service_test.dart  # 匹配/打包
flutter test test/database/app_database_test.dart                                    # 数据库
```

## 分支管理

本项目采用类 GitFlow 分支模型，参考 Flutter、Kubernetes 等大型开源项目实践。

### 分支结构

```text
main          ← 生产就绪代码，每次提交可独立发布
  │
  ├── develop ← 集成分支，feature/fix 分支合入此处
  │     │
  │     ├── feature/<name>   ← 新功能开发
  │     ├── fix/<name>       ← Bug 修复（非紧急）
  │     └── refactor/<name>  ← 重构（不改功能）
  │
  ├── release/<version> ← 发布准备（冻结特性，只修 bug）
  │
  └── hotfix/<name>     ← 紧急修复（从 main 分出，合回 main + develop）
```

### 分支命名

| 类型 | 格式 | 示例 |
|------|------|------|
| 功能 | `feature/<kebab-case>` | `feature/ocr-batch-scan` |
| 修复 | `fix/<kebab-case>` | `fix/zip-encoding-error` |
| 重构 | `refactor/<kebab-case>` | `refactor/db-migration-v2` |
| 发布 | `release/<semver>` | `release/1.2.0` |
| 热修复 | `hotfix/<kebab-case>` | `hotfix/crash-on-startup` |

### 工作流程

```bash
# 新功能：从 develop 分出，合回 develop
git checkout develop && git pull
git checkout -b feature/<name>
# … 开发、测试 …
git checkout develop && git merge --no-ff feature/<name>
git push origin develop

# 发布：从 develop 分出，合到 main 并打 tag，再合回 develop
git checkout develop && git checkout -b release/1.0.0
# … 修 bug、提升版本号 …
git checkout main && git merge --no-ff release/1.0.0 && git tag v1.0.0
git checkout develop && git merge --no-ff release/1.0.0
git push origin main develop --tags

# 紧急修复：从 main 分出，合回 main + develop
git checkout main && git checkout -b hotfix/<name>
# … 修复、测试 …
git checkout main && git merge --no-ff hotfix/<name> && git tag v1.0.1
git checkout develop && git merge --no-ff hotfix/<name>
```

### 当前简化

单人开发不强制 PR，但**必须遵循分支命名和合并方向**：
- 所有新工作从 `develop` 分出
- 完成验证后合回 `develop`
- `main` 只从 `release/*` 或 `hotfix/*` 合入
- **禁止直接在 `main` 上提交**

## 提交规范

格式：

```text
<type>(<scope>): <subject>

Co-Authored-By: Claude <noreply@anthropic.com>
```

类型：`feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` / `chore` / `ci` / `build`

**单次提交 diff ≤ 200 行**（插入 + 删除）。超过则按 task/行为/测试边界拆成多个提交。

提交前检查：

```bash
git diff --cached --shortstat          # 确认 ≤ 200 行
dart format <changed files>            # 格式化
dart analyze <changed files>           # 静态分析（至少触碰文件通过）
flutter test <relevant test files>     # 相关测试
```

## 修改边界

- 保持 UI / Service / Data 三层分离，复杂业务逻辑放 `lib/services/`
- **禁止手工编辑**：`*.g.dart`、`GeneratedPluginRegistrant.java`、`.flutter-plugins-dependencies`
- **禁止提交**：构建产物、APK、数据库文件、大模型文件、临时文件
- 敏感信息（密码、授权码）必须走 `flutter_secure_storage`，**禁止硬编码**
- 新依赖需确认必要性，避免为单点修复引入重型包
- 修改文件命名/目录结构时同步检查打包、删除、查看和测试

## Git Worktree 隔离

复杂任务可使用 worktree：

```bash
git worktree add -b feature/<name> ../app-invoice-<name> develop
```
