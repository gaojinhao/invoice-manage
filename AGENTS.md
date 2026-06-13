# AGENTS.md

本文件适用于所有 AI 编程助手（Codex 等）在本仓库工作。

> **Claude Code 用户**：另请参阅 [`CLAUDE.md`](./CLAUDE.md)，包含分支管理规范和 Claude Code 专属指引。

## 项目概览

这是一个个人报销文件管理 Flutter App，面向中文使用场景。核心流程是：

1. 拍照或从相册选择结账单。
2. 使用 Google ML Kit 中文 OCR 提取商户名、金额、日期。
3. 创建消费记录并保存结账单图片。
4. 后续补充支付记录截图和发票文件。
5. 按月打包本地文件，支持分享或后续邮件发送。

当前主技术栈：

- Flutter / Dart，Material 3 UI。
- Drift + SQLite 本地数据库。
- Google ML Kit 离线中文 OCR。
- `image_picker` 拍照/选图。
- `workmanager` 后台定时任务。
- `flutter_local_notifications` 本地通知。
- `flutter_secure_storage` 保存邮箱授权码。
- `archive` + `share_plus` 做 ZIP 打包和系统分享。

## 目录导览

- `lib/main.dart`：应用启动、全局错误兜底、Provider 注入、主题和本地化。
- `lib/database/tables.dart`：Drift 表和 `RecordStatus` 枚举。
- `lib/database/app_database.dart`：数据库 API、查询和状态更新。
- `lib/database/app_database.g.dart`：Drift 生成文件，不要手工改。
- `lib/screens/`：页面级 Widget。
  - `home_screen.dart`：首页、月度汇总、状态卡片、记录列表、打包导出入口。
  - `camera_screen.dart`：拍照/选图、OCR、创建消费记录。
  - `record_detail_screen.dart`：三证文件管理、查看/替换文件、删除记录。
  - `email_config_screen.dart`、`settings_screen.dart`、`search_screen.dart`、`charts_screen.dart`：配置、设置、搜索、统计。
- `lib/services/`：业务服务层。
  - `ocr_service.dart`：ML Kit 识别和商户/金额/日期提取规则。
  - `file_service.dart`：本地目录、图片/PDF 保存、月度 ZIP。
  - `email_service.dart`：SMTP 发件和简易 IMAP 收件。
  - `invoice_matcher_service.dart`：邮箱发票和待开发票记录匹配。
  - `check_pack_service.dart`：每日检查和月初打包流程。
  - `scheduler_service.dart`：Workmanager 任务注册和后台 isolate 回调。
  - `notification_service.dart`：本地通知。
- `test/`：以服务层测试为主，`test/helpers/mocks.dart` 提供 mock 和 stub factory。
- `openspec/`：需求/设计历史，不一定完全等同当前实现，改动前以代码为准。
- `.github/workflows/ci.yaml`、`lefthook.yml`、`CODE_REVIEW.md`：CI、提交钩子、review 清单。

## 业务模型

消费记录只有一张核心表 `ConsumptionRecords`：

- `date`：消费日期。
- `merchant`：商户名。
- `amount`：金额。
- `month`：月份索引，格式 `YYYY-MM`。
- `status`：`pendingPayment`、`pendingInvoice`、`complete`、`archived`。
- `receiptImg`：结账单图片路径。
- `paymentImg`：支付记录截图路径。
- `invoicePdf`：发票文件路径。
- `notes`：备注。

文件默认存放在应用文档目录下：

```text
records/YYYY-MM/YYYY-MM-DD_商户名/
  结账单.jpg
  支付记录.jpg
  发票.pdf
```

商户名用于目录名时会替换 `\ / : * ? " < > |` 为 `_`。修改文件命名或目录结构时，要同步检查打包、删除、查看和测试。

## OCR 约定

当前 OCR 正式实现只使用 Google ML Kit 中文识别，不依赖 Paddle/ONNX 模型。不要重新引入未跟踪的大模型文件或实验性原生 OCR 插件，除非用户明确要求。

`OcrService` 的提取策略：

- 使用 ML Kit 的 `RecognizedText.blocks/lines`，保留 `boundingBox` 做空间排序和评分。
- 商户名优先从文本头部、靠上行、含店名/餐饮/品牌关键字的候选里提取。
- 金额优先从尾部和最终金额标签附近提取，例如 `应付金额`、`实付金额`、`餐饮消费金额`。
- 明确压低中间金额和干扰值，例如 `原单金额`、`菜品金额`、`优惠金额`、日期时间、电话、单号。
- 针对真实票据 OCR 错字做少量归一化，例如海底捞/摩尔城店相关误识别。

改 OCR 时必须补充或更新：

- `test/services/ocr_extraction_test.dart`
- 必要时补充真实 OCR 文本样例，尤其是金额标签和值分行、尾部打印时间、负数优惠、商户名误识别。

常用验证：

```bash
dart format lib/services/ocr_service.dart test/services/ocr_extraction_test.dart
dart analyze lib/services/ocr_service.dart test/services/ocr_extraction_test.dart
flutter test test/services/ocr_extraction_test.dart
```

## 数据库和生成文件

- 表结构在 `lib/database/tables.dart`。
- 数据库 API 在 `lib/database/app_database.dart`。
- `lib/database/app_database.g.dart` 是 Drift 生成文件，不要手工编辑。
- 改表结构或 Drift 查询后运行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

当前 `schemaVersion` 是 1。任何真实迁移都要添加 `MigrationStrategy`，不要直接破坏用户已有数据。

## 运行和构建

常用本地命令：

```bash
flutter pub get
dart format lib test
flutter test
flutter analyze
flutter build apk --debug
```

Android 构建注意事项：

- `android/app/build.gradle.kts` 使用 Java 17 兼容配置。
- 如果本机 Android 构建找不到 JDK，可显式设置 `JAVA_HOME` 到 JDK 17。
- App ID 是 `com.example.invoice_app`。
- `minSdk = 26`。
- ML Kit 中文识别依赖在 Android app module 显式添加：`com.google.mlkit:text-recognition-chinese:16.0.1`。
- `release` 当前仍使用 debug signing config 且开启 minify，这是项目现状，改签名策略前先确认交付方式。

真机调试经验：

```bash
flutter build apk --debug
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.example.invoice_app/.MainActivity
adb logcat --pid=$(adb shell pidof com.example.invoice_app)
```

如果 `flutter run` 在 vivo 等设备安装阶段表现不稳定，优先使用上面的 build + `adb install -r -t` 流程。

## 测试现状

服务层测试覆盖了 OCR、邮箱配置、文件路径、发票匹配、每日检查/月初打包和数据库 mock 行为。大量测试使用 `mocktail` mock，不都是真实 SQLite 集成测试。

推荐按改动范围跑测试：

- OCR：`flutter test test/services/ocr_extraction_test.dart`
- 文件服务：`flutter test test/services/file_service_test.dart`
- 邮件服务：`flutter test test/services/email_service_test.dart test/services/email_server_config_test.dart`
- 匹配/打包：`flutter test test/services/invoice_matcher_service_test.dart test/services/check_pack_service_test.dart`
- 数据库 API：`flutter test test/database/app_database_test.dart`

当前项目级 `flutter analyze` 可能报告既有未使用 import/变量和 lint 信息。做局部修复时，至少保证触碰文件的 `dart analyze <files>` 通过；做提交前整理或 CI 修复时再清理全项目 analyzer。

## 修改边界

- 优先保持 UI / Service / Data 三层清晰。页面可以调用 service 和 database provider，但复杂业务逻辑应放到 `lib/services/`。
- 不要手工编辑 Flutter/Drift 生成文件，除非是在明确处理生成产物。
- 不要提交本地构建产物、大模型文件、临时 UUID 文件、`.flutter-plugins-dependencies` 副本、APK、数据库文件或设备日志。
- 新依赖要确认必要性，避免为单点修复引入重型包。
- 涉及邮箱授权码、密码、IMAP/SMTP 配置时，继续使用 `flutter_secure_storage`，不要硬编码敏感信息。
- 涉及文件路径时，注意当前代码保存的是绝对路径；`CODE_REVIEW.md` 中“存相对路径”是目标规范，不是当前实现事实。迁移前需要设计兼容方案。

## 分支管理

本项目采用类 GitFlow 分支模型。AI 助手开始改动前必须先确认当前分支和工作区状态：

```bash
git status --short --branch
git branch --show-current
git remote -v
```

分支结构：

```text
main          # 生产就绪代码，每次提交应可独立发布
develop       # 集成分支，feature/fix/refactor 分支合入此处
feature/*     # 新功能或文档规范补充
fix/*         # 非紧急 bug 修复
refactor/*    # 不改变行为的重构
release/*     # 发布准备，只修发布阻塞问题
hotfix/*      # 从 main 分出的紧急修复
```

分支命名使用 kebab-case：

- `feature/<name>`，例如 `feature/ocr-batch-scan`。
- `fix/<name>`，例如 `fix/zip-encoding-error`。
- `refactor/<name>`，例如 `refactor/db-migration-v2`。
- `release/<semver>`，例如 `release/1.2.0`。
- `hotfix/<name>`，例如 `hotfix/crash-on-startup`。

工作流约束：

- 所有新工作从 `develop` 分出；如果当前在 `main`，先切到 `develop` 并同步后再建分支。
- 功能、文档规范和常规改动使用 `feature/*`；普通缺陷修复使用 `fix/*`；纯重构使用 `refactor/*`。
- 完成验证后，`feature/*`、`fix/*`、`refactor/*` 合回 `develop`。
- `main` 只接受 `release/*` 或 `hotfix/*` 合入，禁止直接在 `main` 上提交。
- `hotfix/*` 必须从 `main` 分出，修复后合回 `main` 和 `develop`。
- 单人开发不强制 PR，但必须遵循分支命名、合并方向和验证要求。

远程推送：

- 推送到当前工作分支对应的远程同名分支，例如 `git push -u <remote> feature/<name>`。
- 若仓库远程名不是 `origin`，以 `git remote -v` 的结果为准，不要硬编码远程名。
- 不要未经用户明确要求执行 `--force`、`--force-with-lease`、删除远程分支或改写已推送历史。

## 多 Agent 协作

本仓库支持 OpenClaw + Codex + Claude Code 的多 agent 工作流。`CLAUDE.md` 是完整规则，本节是所有 AI 助手必须遵守的执行摘要。

角色边界：

- OpenClaw：需求入口、任务拆解、状态流转、分派、飞书通知、测试审查和合入 gate。
- Codex：默认开发 agent，负责实现、验证、提交和推送。
- Claude Code：备用/接力开发 agent，Codex 额度耗尽、阻塞或长时间无进展时接手。

协作原则：

- 不要让多个 agent 同时修改同一个工作区；使用独立 worktree 或独立 clone。
- 不要用聊天上下文替代任务状态；任务必须记录在 `TODO-task.md`、OpenSpec change 或 GitHub Issue 中。
- 同一任务同一时刻只能有一个 owner，推荐字段：`Owner: codex` 或 `Owner: claude`。
- 接力必须记录 `Last agent`、`Last commit`、`Known blocker`，后续 agent 先读现有分支和失败日志。

推荐任务状态：

```text
drafted -> ready -> assigned -> in_progress -> pushed -> reviewing -> ci_passed -> merged -> done
```

阻塞和接力使用：

```text
blocked
handoff_requested
```

开发 agent 完成标准：

- 推送前完成相关验证；至少执行 `git diff --check` 和与改动相关的 analyze/test。
- 推送到远程同名分支后，把任务状态改为 `pushed`，并记录分支、提交和验证结果。
- OpenClaw 审查通过和 CI 通过前，不要自行合入 `develop` 或 `main`。
- 涉及数据库迁移、文件删除、权限、构建配置、发布配置或敏感信息时，必须等待人工确认后合入。

## 提交规范

提交信息遵循：

```text
<type>(<scope>): <subject>
```

常见类型：`feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test`、`chore`、`ci`、`build`。

单次提交的 diff 规模必须控制在 200 行以内（插入行 + 删除行）。如果一个需求超过 200 行，按 task、行为或测试/实现边界拆成多个提交；提交前用 `git diff --cached --shortstat` 复核。

示例：

```text
fix(ocr): improve final amount extraction
docs(codex): add repository guidance
```

提交前建议：

```bash
git status --short
git diff --check
dart format <changed dart files>
dart analyze <changed dart files>
flutter test <relevant test files>
```
