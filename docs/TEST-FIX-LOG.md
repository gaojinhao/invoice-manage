# 测试修复日志

修复日期: 2026-06-09

## 目标

`flutter test` 编译通过，验证测试审查系统有效性。

---

## 修复过程

### 第一轮 — 编译错误修复（Hermes Agent）

**修复前**: +9 通过 / -35 失败（全部编译错误）

| # | 问题 | 文件 | 修复 |
|---|------|------|------|
| 1 | `SMTP()` 不存在 | `lib/services/email_service.dart` | mailer 6.6.0 改用 `SmtpServer(host, username:, password:, port:, ssl:)` |
| 2 | `SMTPConnection()` 不存在 | `lib/services/email_service.dart` | `verifyConnection` 重写，去掉不存在的类 |
| 3 | `line.startsWith()` on `String?` | `lib/services/email_service.dart` | `_readResponse` 改用局部变量类型提升 + while(true) 模式 |
| 4 | `bytes.take(size)` 返回 `Iterable` | `lib/services/email_service.dart` | 加 `.toList()` |
| 5 | `_socket?.transform(utf8.decoder)` 类型不匹配 | `lib/services/email_service.dart` | 局部变量 + `.cast<List<int>>()` |
| 6 | `whereType<Directory>()` 不可用 | `lib/services/file_service.dart` | 先 `await .toList()` 再 filter |
| 7 | 缺 `import 'dart:io'` | `lib/services/invoice_matcher_service.dart` | 补上 |
| 8 | `verify(()=>..., never).called(0)` 语法错误 | `test/services/invoice_matcher_service_test.dart` | 换 `verifyNever()` |
| 9 | 同上 | `test/services/check_pack_service_test.dart` | 3 处换 `verifyNever()` |
| 10 | `const` 不能用于 `RegExp` | `test/services/file_service_test.dart` | `const` → `final` |
| 11 | 缺 `EmailConfig` 导入 | `test/services/check_pack_service_test.dart` | 补上 |
| 12 | 缺 `OcrResult` 导入 | `test/helpers/mocks.dart` | 补上 |
| 13 | drift 生成代码缺 `_uuid` | `lib/database/tables.dart` | `_uuid` → `uuid`，`_uuidCounter` → `uuidCounter` |
| 14 | drift `textEnum` 映射为 `String` | `lib/database/app_database.dart` | `equals(RecordStatus.xxx)` → `equals(RecordStatus.xxx.name)` |
| 15 | `write()`/`go()` 返回 `Future<int>` | `lib/database/app_database.dart` | `return` → `await` |
| 16 | `where()` 闭包用 `\|\|` 不合法 | `lib/database/app_database.dart` | 改用 `conditions.reduce((a,b) => a \| b)` |
| 17 | 缺 `import 'package:flutter/widgets.dart'` | `lib/database/app_database.dart` | 补上 |

**修复后**: +66 通过 / -34 失败（全部运行时错误，不再有编译错误）

### 第二轮 — 运行时错误修复（Hermes Agent）

| # | 问题 | 文件 | 修复 |
|---|------|------|------|
| 18 | google_mlkit 缺 Flutter binding | `test/services/ocr_service_test.dart` | `main()` 首行加 `TestWidgetsFlutterBinding.ensureInitialized()` |
| 19 | mocktail 缺 `File` fallback | `test/services/invoice_matcher_service_test.dart` | `main()` 首行加 `registerFallbackValue(File(''))` |

**修复后**: +70 通过 / -30 失败

---

## 第三轮 — 剩余运行时错误修复（Hermes Agent）

**修复前**: +70 ✅ / -30 ❌

| # | 问题 | 文件 | 修复 |
|---|------|------|------|
| 20 | MissingPluginException: vision#closeTextRecognizer | `test/services/ocr_extraction_test.dart` | 注入 mock TextRecognizer（所有 3 个 group） |
| 21 | MissingPluginException: vision#closeTextRecognizer | `test/services/ocr_service_test.dart` | 注入 mock TextRecognizer |
| 22 | mocktail 缺 `File` fallback | `test/services/check_pack_service_test.dart` | `main()` 内加 `registerFallbackValue(File(''))` + 补 `import 'dart:io'` |
| 23 | `extractAmount('总计=256.50')` 返回 null | `lib/services/ocr_service.dart` | 正则 `[：:\s]*` → `[：:\s=]*`（两行均更新） |

**修复后**: +100 ✅ / -0 ❌ **全部通过！**

## 当前测试状态

```
flutter test  →  +100 ✅ / -0 ❌  全部通过！
```

### 已通过的测试模块（70 个）

| 模块 | 测试文件 | 状态 |
|------|----------|------|
| OcrResult 基础 | `ocr_service_test.dart` | ✅ 通过 |
| OcrService 创建销毁 | `ocr_service_test.dart` | ✅ 通过 |
| AppDatabase 查询 | `app_database_test.dart` | ✅ 通过 |
| AppDatabase 创建 | `app_database_test.dart` | ✅ 通过 |
| AppDatabase 更新 | `app_database_test.dart` | ✅ 通过 |
| AppDatabase 搜索 | `app_database_test.dart` | ✅ 通过 |
| FileService 路径 | `file_service_test.dart` | ✅ 通过 |
| EmailServerConfig | `email_server_config_test.dart` | ✅ 通过 |
| EmailService | `email_service_test.dart` | ✅ 通过 |
| InvoiceMatcherService | `invoice_matcher_service_test.dart` | ✅ 通过 |
| 其他基础测试 | - | ✅ 通过 |

### 剩余失败（30 个）

全部是运行时错误，类型清晰，修复方案明确。

#### 分类统计

| 错误类型 | 影响文件 | 数量 | 根因 | 修复方案 |
|----------|----------|------|------|----------|
| Flutter binding 未初始化 | `test/services/ocr_service_test.dart` | 1 | `OcrService.dispose()` 调用 `TextRecognizer.close()` 需 Flutter binding | `main()` 内加 `TestWidgetsFlutterBinding.ensureInitialized()` |
| Flutter binding 未初始化 | `test/services/ocr_extraction_test.dart` | 27 | 文本解析方法内部调用 `TextRecognizer` 时未初始化 binding | `main()` 内加 `TestWidgetsFlutterBinding.ensureInitialized()` |
| mocktail 缺 `File` fallback | `test/services/check_pack_service_test.dart` | 2 | `any()` 或 `when()` 匹配 `File` 类型参数时需注册 fallback | `main()` 内加 `registerFallbackValue(File(''))` |

#### 详细失败用例清单

**`test/services/ocr_service_test.dart`（1 个）**
- OcrService — 文本解析（通过 recognizeImage 间接测试）service 创建和销毁不抛异常

**`test/services/ocr_extraction_test.dart`（27 个）**

- extractMerchant（8 个）
  - 商户: 前缀匹配 / 商家: 前缀匹配 / 店名: 前缀匹配 / 名称: 前缀匹配
  - 第一行超市/便利店后缀 / 第一行餐厅/酒店后缀
  - 欢迎光临前缀 / 感谢光临前缀 / 无匹配时取第一行 / 空文本返回 null
- extractAmount（10 个）
  - 合计：金额 / 合计:金额（无空格冒号）/ 总计=金额
  - 实收 ¥ 开头 / 应付 ￥ 开头 / 支付金额: 前缀 / 金额: 前缀
  - 纯 ¥ 符号在前 / 金额后接 元 / 无金额文本返回 null / 空文本返回 null
- extractDate（7 个）
  - YYYY-MM-DD 格式 / YYYY年MM月DD日 格式 / YYYY/MM/DD 格式
  - YYYYMMDD 紧凑格式 / 日期在文本中间 / 无日期文本返回 null / 空文本返回 null

**`test/services/check_pack_service_test.dart`（2 个）**
- DailyCheckService run — 邮箱已配置时执行发票下载
- MonthlyPackService run — ZIP 打包失败返回 0

---

## 执行命令速查

```bash
# 运行所有测试
flutter test

# 重新生成 drift 代码
dart run build_runner build --delete-conflicting-outputs
```
