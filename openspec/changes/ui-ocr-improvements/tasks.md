# Tasks: 消费记录 UI 优化 + OCR 提取精度提升

## 状态：✅ 全部完成（2026-06-09）

---

## Phase 1: OCR 提取精度改进

- [x] 1.1 商户名正则升级（连锁品牌、行业后缀、前缀标记、智能兜底）
- [x] 1.2 金额正则升级（多前缀、符号前缀、等号分隔符、兜底取最大）
- [x] 1.3 日期正则升级（多格式支持、MM月DD日补年）
- [x] 1.4 测试验证：`flutter test` 100/100 ✅
- [x] 1.5 PaddleOCR 方案调研+文档备忘（paddle_ocr_flutter 插件）

## Phase 2: 首页记录卡片颜色编码

- [x] 2.1 实现 `_cardColor()` 逻辑（红/橘/绿判断）
- [x] 2.2 实现 `_cardStatusText()` 状态标签
- [x] 2.3 重构 `_buildRecordCard()` UI（左侧色条、金额着色、状态标签）
- [x] 2.4 移除旧的 statusColors/statusLabels map

## Phase 3: 详情页三证文件管理

- [x] 3.1 实现 3 个文件区域布局（结账单/支付记录/发票）
- [x] 3.2 实现已有文件→缩略图+替换按钮
- [x] 3.3 实现无文件→加号上传区域
- [x] 3.4 实现替换逻辑（覆盖保存+刷新）
- [x] 3.5 数据库新增 `updateReceiptImage()` 方法
- [x] 3.6 补充 camera_screen.dart 导入

## Phase 4: 手动打包导出

- [x] 4.1 首页添加 `_buildActionBar()` 按钮
- [x] 4.2 实现 `_packAndExport()` 方法（ZIP→选项弹窗）
- [x] 4.3 实现下载/分享选项（复用 ExportService.shareFile）
- [x] 4.4 实现邮箱发送选项（配置检查+引导）
- [x] 4.5 空记录提示

## Phase 5: 构建交付

- [x] 5.1 `flutter test` 全部通过（100/100 ✅）
- [x] 5.2 `flutter build apk --debug --target-platform android-arm64` ✅
- [x] 5.3 ADB 安装到手机并测试 ✅
- [x] 5.4 Git 提交（commit: 44f8e4b）
