# TODO — 已完成任务记录

> 基于 openspec `ui-ocr-improvements` spec 对照代码审查，于 2026-06-11 全部修复完成。
> 原始缺口在 HEAD: `2506610` 中确认存在。

## ✅ Task 1: 手动打包后"发送到邮箱"没有真正发送
- **Commit**: `f98acee`
- **修复**: 替换占位 SnackBar，实现完整邮件发送流程：读取配置 → 配置 EmailService → sendEmail() 发送 ZIP 附件 → 显示结果

## ✅ Task 2: 邮箱测试连接没有按 spec 用 IMAP 验证
- **Commit**: `684b7a4` + test `4fd5e1a`
- **修复**: 新增 `verifyConnectionDetailed()` 用 `_ImapClient` 走 IMAP connect→login→selectInbox，每步返回具体失败原因；修复 `$TAG`→`$tag` bug

## ✅ Task 3: "手动录入"缺少主动入口
- **Commit**: `2bb0d76` + test `3eb11ac`
- **修复**: 初始状态和拍照后均添加显式"手动录入"按钮

## ✅ Task 4: 发票 PDF 上传逻辑不对
- **Commit**: `403858a` + tests `6445137`, `002eec6`
- **修复**: `_pickInvoiceFile()` 支持 PDF/图片双选；`saveInvoiceFile()` 按实际扩展名保存；新增 `file_picker` 依赖

## ✅ Task 5: 设置页"清除所有数据"是空实现
- **Commit**: `1b0c2a9`
- **修复**: 实现 `db.deleteAllRecords()` + `fileService.deleteAllRecordFiles()` + 清除 SecureStorage

## ✅ Task 6: 首页"本月各状态数量"是全局统计
- **Commit**: `3e12349`
- **修复**: 新增 `getStatusCountsByMonth()`；首页改为当月筛选统计

## ✅ Task 7: 状态流转不是按三证完整性综合计算
- **Commit**: `e32d0fb` + test `cccd8ae`
- **修复**: `statusForFiles()` 综合三证推导状态；所有 update 方法均重新计算

## ✅ Task 8: 月初自动打包 ZIP 只打包筛选记录
- **Commit**: `ada41b1` + test `f2b8523`
- **修复**: 新增 `zipRecords()` 仅打包传入记录的文件；`MonthlyPackService` 改用之

## ✅ Task 9: 月初定时任务严格每月 1 日执行
- **Commit**: `705f856`
- **修复**: `Duration(hours: 24)` 每天检查 + `day != 1` 守卫

## ✅ Task 10: 详情页灰色虚线占位 + 图片缓存刷新
- **Commit**: `f66874e`
- **修复**: `_DashedBorderPainter` 虚线边框；`_fileCacheKey` 时间戳缓存破坏

---

# TODO — 待实现任务

> 基于 openspec `amount-validation-word-export` change 新增，于 2026-06-12 记录。

## ⏳ Task 11: 上传支付记录时校验金额一致性
- **Spec**: `openspec/changes/amount-validation-word-export/specs/consumption/spec.md`
- **需求**: 上传支付记录截图后识别支付金额，与消费记录结账单金额比对
- **提示**: 金额不一致时显示“支付记录与结账单金额不一致”，但仍保存文件
- **测试**: 覆盖金额一致、金额不一致、无法识别金额

## ⏳ Task 12: 上传发票时校验金额一致性
- **Spec**: `openspec/changes/amount-validation-word-export/specs/consumption/spec.md`
- **需求**: 上传发票 PDF 或发票图片后识别发票金额，与消费记录结账单金额比对
- **提示**: 金额不一致时显示“发票与结账单金额不一致”，但仍保存文件
- **测试**: 覆盖 PDF/图片发票、金额一致、金额不一致、无法识别金额

## ⏳ Task 13: 生成月度打印裁剪 Word 文件
- **Spec**: `openspec/changes/amount-validation-word-export/specs/consumption/spec.md`
- **需求**: 打包导出当月记录时，额外生成一个 Word 文件用于打印裁剪
- **发票排版**: 发票截图/渲染图宽度与 A4 纸可打印宽度一致，高度保留完整内容
- **支付记录排版**: 每张支付记录宽为 A4 纸宽度的 1/4，高为 A4 纸高度的 1/3，一行最多 3 张
- **导出**: Word 文件放入当月导出的 ZIP
- **测试**: 覆盖无发票、无支付记录、混合 PDF/图片发票、多支付记录换行/分页
