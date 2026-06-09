# Design: 消费记录 UI 优化 + OCR 提取精度提升

## 文件结构变更

```
lib/
├── screens/
│   ├── home_screen.dart           ← 改造：卡片颜色 + 打包导出按钮
│   ├── record_detail_screen.dart  ← 重写：三区域文件管理
│   └── camera_screen.dart         ← 微调：去掉多余权限请求
├── services/
│   └── ocr_service.dart           ← 改造：正则模式全面升级
└── database/
    └── app_database.dart          ← 新增：updateReceiptImage 方法
```

## 首页卡片颜色逻辑

```
CardColor(record):
  if receipt!=null AND payment!=null AND invoice!=null → GREEN  (三证齐全)
  if payment!=null OR invoice!=null                    → ORANGE (部分完成)
  else                                                  → RED    (待补充)
```

- 不依赖 `RecordStatus` 枚举，直接判断 3 个文件字段的 null 状态
- 颜色体现在：左侧 4px 色条 + 金额数字 + 状态标签背景色 + 卡片边框色

## 详情页三区域架构

```
RecordDetailScreen
├── 基本信息卡片 (商户/日期/金额)
└── 3 个文件区域 (独立管理)
    ├── 结账单 (receiptImg)
    │   ├── 有文件 → Image.file 缩略图 + ⊕替换(右上角) + 👁查看(标签行)
    │   └── 无文件 → 灰色占位区域 + 中央⊕ + "点击上传结账单"
    ├── 支付记录 (paymentImg)
    │   └── (同上结构)
    └── 发票 (invoicePdf)
        └── (同上结构)
```

每个区域的上传/替换逻辑：
1. 点击⊕ → `ImagePicker.pickImage()` → `FileService.saveXXX()` → `AppDatabase.updateXXX()`
2. 替换时覆盖保存到同一目录，更新数据库中路径
3. 替换后自动 `_refreshRecord()` 刷新页面

## OCR 正则模式升级对照

| 提取项 | 旧模式（规则数） | 新模式（规则数） | 新增关键模式 |
|--------|-----------------|-----------------|-------------|
| 商户名 | 4 条 + 取第一行 | 9 条 + 智能兜底 | 连锁品牌、行业后缀、前缀标记、欢迎光临、美团/饿了么 |
| 金额 | 4 条 | 7 条 + 兜底取最大 | 付款、消费、小计、收款、实付等前缀；等号分隔符；纯数字行 |
| 日期 | 2 种格式 | 4 组格式 | YYYY.MM.DD、MM月DD日；多匹配选第一个合理值 |

## 打包导出流程

```
HomeScreen
└── _buildActionBar()
    └── OutlinedButton "打包导出当前月所有记录"
        └── _packAndExport()
            ├── FileService.zipMonthRecords(year, month) → ZIP
            ├── ShowModalBottomSheet (2 options)：
            │   ├── "下载/分享文件" → ExportService.shareFile(zipPath)
            │   └── "发送到邮箱" → 检查邮箱配置
            │       ├── 未配置 → AlertDialog → EmailConfigScreen
            │       └── 已配置 → 发送（当前 fallback 到分享）
            └── catch → SnackBar 错误提示
```

## 数据变更

### AppDatabase 新增方法

```dart
Future<void> updateReceiptImage(String id, String imagePath)
```
- 更新 `consumption_records` 表中指定 id 的 `receipt_img` 字段
- 更新 `updated_at` 时间戳
