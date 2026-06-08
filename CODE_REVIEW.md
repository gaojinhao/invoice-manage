# app-invoice 代码审核指南

> 基于项目 spec 和开发规范的审核清单。每次 PR 请逐项检查。

---

## 🔴 必查项（不通过则不能合并）

### 架构规范
- [ ] **分层清晰** — UI / Service / Data 三层职责分离，不跨层调用
  - UI 层不直接操作数据库或文件系统
  - Service 层不引用 Flutter widget
- [ ] **单一路径** — 同一个功能只有一种实现方式，没有重复的 Service
- [ ] **禁止 import 循环** — `dart analyze` 不应报告 circular dependency

### 数据库（drift）
- [ ] **迁移** — 表结构变更必须写 migration，不能直接删表重建
- [ ] **类型安全** — 所有查询使用 drift 的编译时检查，不写原始 SQL
- [ ] **文件路径存储** — 存相对路径（`records/YYYY-MM/...`），不存绝对路径

### 错误处理
- [ ] **所有 async 调用有 try-catch** — 特别是 OCR、IMAP、文件 I/O
- [ ] **用户可见的错误有中文提示** — 不向用户暴露原始异常堆栈
- [ ] **关键操作有日志** — 使用 `logger` 包，不直接用 `print`

### 安全
- [ ] **敏感信息加密** — 邮箱授权码使用 `flutter_secure_storage`
- [ ] **无硬编码密钥** — 没有 API key、密码硬编码在代码里
- [ ] **文件权限** — 不读写应用沙盒外的文件

---

## 🟡 建议项（根据场景决策）

### 性能
- [ ] 列表页使用了 `ListView.builder` 而不是 `ListView(children: ...)`
- [ ] OCR 识别在 isolate 中执行，不阻塞 UI 线程
- [ ] SQL 查询有索引支持（按月、按状态查询）
- [ ] 大文件（照片、PDF）预览使用缩略图或懒加载

### 代码质量
- [ ] Widget 拆分为合理粒度，单个 widget 不超过 200 行
- [ ] 重复逻辑抽取为复用方法或 mixin
- [ ] 状态管理方案一致（全项目用同一方案，不混用 setState + Bloc + riverpod）

### UI/UX
- [ ] 空状态有占位提示（无消费记录时显示引导文案）
- [ ] 加载中显示 loading indicator
- [ ] 错误状态有重试入口
- [ ] 遵循 Material Design 3 / Flutter 官方设计规范

---

## 📋 目录结构规范

```
lib/
├── main.dart
├── app.dart                    # App 入口 + 路由
├── models/                     # 数据模型（与 drift 表对应）
│   └── consumption_record.dart
├── database/                   # drift 数据库定义
│   ├── database.dart
│   └── tables.dart
├── services/                   # 业务逻辑层
│   ├── ocr_service.dart
│   ├── email_service.dart
│   ├── file_service.dart
│   └── notification_service.dart
├── screens/                    # 页面级 widget
│   ├── dashboard/
│   ├── records/
│   ├── upload/
│   └── settings/
├── widgets/                    # 可复用小组件
│   ├── status_badge.dart
│   ├── month_selector.dart
│   └── file_preview.dart
└── utils/                      # 工具函数
    ├── date_utils.dart
    └── logger.dart
```

---

## 📝 Commit 规范

```
<type>(<scope>): <subject>

<body>

<footer>
```

**type:**
- `feat` — 新功能
- `fix` — 修复 bug
- `refactor` — 重构
- `style` — 代码格式化（不影响功能）
- `test` — 添加/修改测试
- `docs` — 文档变更
- `chore` — 构建/依赖/配置
- `ci` — CI 配置变更

**scope（可选）:** `ocr`, `email`, `db`, `ui`, `notification`, `config` 等

**示例:**
```
feat(ocr): 添加 Google ML Kit 小票识别

集成 Google ML Kit 文字识别，拍照后自动提取金额、日期和商户名。
支持识别结果预览和手动修正。
```

---

## 🔍 Review 流程

1. **作者** `dart analyze` 通过 + `dart format` 格式化后提交 PR
2. **Reviewer** 按 🔴 必查项逐条检查
3. 发现问题→评论区指出（附代码行号 + 建议方案）
4. **作者** 修复后重新请求 review
5. ✅ 所有 🔴 必查项通过 → approve + merge
