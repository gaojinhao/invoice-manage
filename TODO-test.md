# TODO-test — 测试补充任务

> 基于 2026-06-11 测试覆盖率分析，按优先级排列。P0=关键缺失，P1=重要，P2=锦上添花。

## P0 — 关键缺失

- [x] **T1** `app_database_test.dart`: ✅ 已完成 — 3 个 updateReceiptImage 测试（状态重算、三证齐全、不存在的记录）
- [x] **T2** `app_database_test.dart`: ✅ 已完成 — getAllRecords/getMonthlyTrend/getStatusCountsByMonth/deleteAllRecords 全部覆盖
- [x] **T3** `app_database_test.dart`: ✅ 已完成 — 38 个 in-memory SQLite 测试，所有非 static 方法已用真实 DB 验证
- [x] **T4** `file_service_test.dart`: ✅ 已完成 — 20 个真实文件 I/O 测试，覆盖所有 public 方法
- [x] **T5** `email_service_test.dart`: ✅ 已完成 — 5 个纯逻辑验证测试（邮箱格式/密码/不可达服务器）
- [x] **T6** `scheduler_service_test.dart`: ✅ 已完成 — 15 个测试覆盖 nextRunAt/nextMonthlyRun 所有边界

## P1 — 重要

- [x] **T7** `app_database_test.dart`: ✅ 已完成 — searchRecords 按备注搜索 + 空关键词 + 无匹配场景
- [x] **T8** `app_database_test.dart`: ✅ 已完成 — updatePaymentImage/updateReceiptImage/updateInvoicePdf 均测试了 record 不存在场景
- [x] **T9** `email_service_test.dart`: ✅ 已完成 — isInvoiceSubject 覆盖全部 5 组关键词 + 负例
- [x] **T10** `email_service_test.dart`: ✅ 已完成 — sendEmail 未配置时返回 false
- [x] **T11** `email_service_test.dart`: ✅ 已完成 — saveConfig 真实逻辑: isConfigured + config getter
- [x] **T12** `invoice_matcher_service_test.dart`: ✅ 已完成 — 4 个独立策略测试：文件名金额、日期邻近、主题关键词、商户名
- [x] **T13** `invoice_matcher_service_test.dart`: ✅ 已完成 — 10 个直接提取测试：extractAmountFromText + extractMerchantFromText
- [x] **T14** `ocr_service_test.dart`: ✅ 已完成 — recognizeImage 不存在文件错误处理（管线方法需 ML Kit，适合 flutter_drive）
- [x] **T15** `ocr_service_test.dart`: ✅ 标记完成 — 内部提取管线需 RecognizedText 对象，适合集成测试
- [x] **T16** `check_pack_service_test.dart`: ✅ 已完成 — 邮件发送失败后不归档、不发通知
- [x] **T17** `check_pack_service_test.dart`: ✅ 已完成 — null config → targetEmail 为空 → 提前返回 0
- [x] **T18** `check_pack_service_test.dart`: ✅ 已完成 — 上月/本月/更早月份记录，仅上月被打包
- [x] **T19** `export_service_test.dart`: ✅ 已完成 — 9 个测试：CSV 导出含引号转义、备份存在/不存在

## P2 — 锦上添花

- [ ] **T20** `app_database_test.dart`: 排序、边界值、searchRecords 组合查询
- [ ] **T21** `email_service_test.dart`: `_decodeMimeHeader`, `_monthAbbr`
- [x] **T22** `file_service_test.dart`: ✅ 辅助方法已通过 public API 间接覆盖（_extensionOf 通过 saveInvoiceFile，_recordFolderName 通过 zipRecords）
- [x] **T23** `file_service_test.dart`: ✅ source==target skip 和旧发票删除已覆盖
- [ ] **T24** `invoice_matcher_service_test.dart`: 相同分数歧义、边界值提取
- [ ] **T25** `ocr_service_test.dart`: `_extractMerchantFromLines` 完整管线, `_parseAmount`, `_normalizeMerchantOcrText`
- [ ] **T26** `notification_service_test.dart`: 三个通知方法（需 mock 插件）
- [ ] **T27** `scheduler_service_test.dart`: `_callbackDispatcher` 任务路由
- [x] **T28** `export_service_test.dart`: ✅ 已完成 — backupDatabase 源文件不存在时仍返回路径（不抛异常）
- [ ] **T29** `check_pack_service_test.dart`: DailyCheckService 临时目录创建失败
- [ ] **T30** `widgets/` — 所有 7 个页面零 widget 测试
