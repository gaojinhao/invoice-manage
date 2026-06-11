# 待实现任务列表

> 基于 openspec 中 `ui-ocr-improvements` spec 对照代码审查，识别出的缺口。
> 所有任务在 committed code (HEAD: 2506610) 中确认存在，工作区中已有修复代码。

## Task 1: 手动打包后"发送到邮箱"没有真正发送

**问题**: 首页打包后点击"发送到邮箱"，只弹出 SnackBar 提示"邮箱发送功能即将实现（当前可通过分享手动发送）"，然后退回系统分享，未真正调用邮件发送。

**涉及文件**:
- `lib/screens/home_screen.dart` (line ~358-364)

**修复要点**: 读取邮箱配置 → 调用 `EmailService.sendEmail()` 发送 ZIP 附件 → 显示发送结果。

---

## Task 2: 邮箱测试连接没有按 spec 用 IMAP 验证

**问题**: Spec 要求用 IMAP 验证连接并提示具体失败原因。原代码 `verifyConnection()` 内部调用 `checkCredentials(smtpServer)` 使用 SMTP 验证，失败只返回泛化的成功/失败布尔值。

**涉及文件**:
- `lib/services/email_service.dart` — 新增 `verifyConnectionDetailed()` 使用 `_ImapClient` 逐步骤验证
- `lib/screens/email_config_screen.dart` — 调用新方法，展示具体错误原因

**修复要点**: IMAP connect → login → selectInbox 逐步骤验证，每步失败返回具体原因（如 "IMAP SSL 连接失败，请确认端口为 993"）。

---

## Task 3: "手动录入"缺少主动入口

**问题**: Spec 要求用户可以主动点击"手动录入"跳过 OCR。原代码只在 OCR 异常 catch 块中设置 `_manualMode = true`，页面没有明确的手动录入按钮。

**涉及文件**:
- `lib/screens/camera_screen.dart`

**修复要点**: 在初始状态（无图片时）和拍照后均添加"手动录入"按钮，点击后直接进入手动录入表单。

---

## Task 4: 发票 PDF 上传逻辑不对

**问题**: 详情页发票区域只支持 `pickImage`（图库选图），但保存时固定调 `saveInvoicePdf()` 存为 `发票.pdf`，导致 JPG 图片内容套了 `.pdf` 扩展名。同时缺少真正的 PDF 文件选择能力。

**涉及文件**:
- `lib/screens/record_detail_screen.dart` — 新增 `_pickInvoiceFile()` 支持 PDF/图片双选
- `lib/services/file_service.dart` — `saveInvoiceFile()` 根据实际扩展名保存
- `pubspec.yaml` — 新增 `file_picker` 依赖
- `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
- `macos/Flutter/GeneratedPluginRegistrant.swift`

**修复要点**: 底部弹窗让用户选择"PDF 文件"或"从相册选图片"；保存时根据实际文件扩展名命名。

---

## Task 5: 设置页"清除所有数据"是空实现

**问题**: UI 有清除入口和确认对话框，但确认后只弹 SnackBar "已清除所有数据（需要在代码中实现）"，未执行实际删除。

**涉及文件**:
- `lib/screens/settings_screen.dart`

**修复要点**: 确认后执行 `db.deleteAllRecords()` + `fileService.deleteAllRecordFiles()` + 清除 SecureStorage 中的邮箱配置。

---

## Task 6: 首页"本月各状态数量"是全局统计

**问题**: 首页顶部卡片显示当月总金额和记录数，但状态数量（待补支付/待开发票/三证齐全）调用的是 `getStatusCounts()`（全库统计），而非当月筛选。

**涉及文件**:
- `lib/screens/home_screen.dart` — 改用 `getStatusCountsByMonth()`
- `lib/database/app_database.dart` — 新增 `getStatusCountsByMonth()` 方法

**修复要点**: 新增按月份筛选的状态统计方法，首页调用之。

---

## Task 7: 状态流转不是按三证完整性综合计算

**问题**: 原 `updatePaymentImage` 硬编码将状态设为 `pendingInvoice`，`updateInvoicePdf` 硬编码设为 `complete`，未根据三证（结账单 + 支付记录 + 发票）的实际存在情况综合推导状态。

**涉及文件**:
- `lib/database/app_database.dart` — 新增 `statusForFiles()` 和 `effectiveStatusForRecord()`

**修复要点**: 三证齐全 → complete；有支付记录无发票 → pendingInvoice；否则 → pendingPayment。所有 update 方法均通过 `statusForFiles()` 重新计算状态。

---

## Task 8: 月初自动打包 ZIP 实际打包整个月目录

**问题**: `MonthlyPackService.run()` 虽然筛选了"三证齐全"的记录，但 ZIP 打包调用的是 `zipMonthRecords()` 将整个月份目录下所有文件打包，未完成记录的文件也会被压入。

**涉及文件**:
- `lib/services/check_pack_service.dart` — 改用 `zipRecords()`
- `lib/services/file_service.dart` — 新增 `zipRecords()` 仅打包指定记录的文件

**修复要点**: `zipRecords()` 只遍历传入记录列表中的文件路径，每个记录以商户名建文件夹，文件命名为"结账单.jpg"/"支付记录.jpg"/"发票.pdf"。

---

## Task 9: 月初定时任务不是严格"每月 1 日"

**问题**: WorkManager 周期任务使用 `Duration(days: 30)`，首次能算到下月 1 日，但后续执行会漂移。且 `_runMonthlyPack()` 没有日期守卫。

**涉及文件**:
- `lib/services/scheduler_service.dart`

**修复要点**: 改为 `Duration(hours: 24)` 每天检查，在 `_runMonthlyPack()` 开头加 `if (DateTime.now().day != 1) return;` 守卫。

---

## Task 10: 详情页无文件占位不是灰色虚线占位区域

**问题**: Spec 要求"灰色虚线占位区域"，原 `_buildAddButton` 使用纯灰色背景 `Colors.grey`，无虚线边框。且替换同路径图片后受图片缓存影响不立即刷新。

**涉及文件**:
- `lib/screens/record_detail_screen.dart` — 新增 `_DashedBorderPainter`，新增 `_fileCacheKey`

**修复要点**: 使用 `CustomPaint` + `_DashedBorderPainter` 绘制虚线边框；`_fileCacheKey` 拼接文件修改时间戳以破坏图片缓存。
