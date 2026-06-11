# TODO-test — 测试补充任务

> 基于 2026-06-11 测试覆盖率分析，按优先级排列。P0=关键缺失，P1=重要，P2=锦上添花。

## P0 — 关键缺失

- [ ] **T1** `app_database_test.dart`: `updateReceiptImage()` 零覆盖 — 测试更新结账单后状态重新计算
- [ ] **T2** `app_database_test.dart`: `getAllRecords()`, `getMonthlyTrend()`, `getStatusCountsByMonth()`, `deleteAllRecords()` 零覆盖
- [ ] **T3** `app_database_test.dart`: 无 in-memory Drift 数据库测试 — 所有非 static 方法仅靠 mock
- [x] **T4** `file_service_test.dart`: ✅ 已完成 — 20 个真实文件 I/O 测试，覆盖所有 public 方法
- [x] **T5** `email_service_test.dart`: ✅ 已完成 — 5 个纯逻辑验证测试（邮箱格式/密码/不可达服务器）
- [x] **T6** `scheduler_service_test.dart`: ✅ 已完成 — 15 个测试覆盖 nextRunAt/nextMonthlyRun 所有边界

## P1 — 重要

- [ ] **T7** `app_database_test.dart`: `searchRecords` notes 字段匹配未测试；多条件 OR 逻辑未验证
- [ ] **T8** `app_database_test.dart`: `updatePaymentImage` / `updateReceiptImage` / `updateInvoicePdf` —— record 不存在时的 early return 均未测试
- [ ] **T9** `email_service_test.dart`: `checkAndDownloadInvoices` 主题关键词过滤（发票/invoice/电子票据/开票）未测
- [ ] **T10** `email_service_test.dart`: `sendEmail` 真实实现（Message 构建、附件、错误处理）未测
- [ ] **T11** `email_service_test.dart`: `saveConfig` 真实逻辑未测（仅 mock）
- [ ] **T12** `invoice_matcher_service_test.dart`: 金额-文件名匹配(80分)、商户名匹配(50分)、日期邻近3-7天(10分)、主题关键词匹配(20分)均未测
- [ ] **T13** `invoice_matcher_service_test.dart`: `_extractAmountFromText` / `_extractMerchantFromText` 未直接测
- [ ] **T14** `ocr_service_test.dart`: `buildResult`, `getStructuredLines`, `recognizeImage` 管线方法未测
- [ ] **T15** `ocr_service_test.dart`: `_extractAmountFromLines`, `_extractFinalAmountByLayout`, `_extractFinalAmountFromTail` 内部方法未测
- [ ] **T16** `check_pack_service_test.dart`: 邮件发送失败后 ZIP 成功——不应归档（可能丢数据）
- [ ] **T17** `check_pack_service_test.dart`: target email 为空（无 sendTo 且无 config email）early return 未测
- [ ] **T18** `check_pack_service_test.dart`: 其他月份的三证齐全记录应被排除
- [ ] **T19** `export_service_test.dart`: 整个文件零测试。CSV 中商户名/备注字段含逗号/引号时未转义（潜在 bug）

## P2 — 锦上添花

- [ ] **T20** `app_database_test.dart`: 排序、边界值、searchRecords 组合查询
- [ ] **T21** `email_service_test.dart`: `_decodeMimeHeader`, `_monthAbbr`
- [x] **T22** `file_service_test.dart`: ✅ 辅助方法已通过 public API 间接覆盖（_extensionOf 通过 saveInvoiceFile，_recordFolderName 通过 zipRecords）
- [x] **T23** `file_service_test.dart`: ✅ source==target skip 和旧发票删除已覆盖
- [ ] **T24** `invoice_matcher_service_test.dart`: 相同分数歧义、边界值提取
- [ ] **T25** `ocr_service_test.dart`: `_extractMerchantFromLines` 完整管线, `_parseAmount`, `_normalizeMerchantOcrText`
- [ ] **T26** `notification_service_test.dart`: 三个通知方法（需 mock 插件）
- [ ] **T27** `scheduler_service_test.dart`: `_callbackDispatcher` 任务路由
- [ ] **T28** `export_service_test.dart`: `backupDatabase` 源文件不存在场景
- [ ] **T29** `check_pack_service_test.dart`: DailyCheckService 临时目录创建失败
- [ ] **T30** `widgets/` — 所有 7 个页面零 widget 测试
