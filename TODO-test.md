# TODO-test.md — 测试体系搭建状态

## ✅ 已完成

### 基础设施
- ✅ `analysis_options.yaml` — 严格 Dart lint 规则
- ✅ `CODE_REVIEW.md` — 代码审核清单
- ✅ `.github/pull_request_template.md` — PR 模板
- ✅ `.github/workflows/ci.yaml` — CI 流水线（analyze → test → commitlint）
- ✅ `lefthook.yml` — 预提交钩子

### 测试依赖
- ✅ `pubspec.yaml` — 添加 mocktail + sqlite3

### 测试辅助
- ✅ `test/helpers/mocks.dart` — Mock 工厂 + Stub 工厂

### 服务层测试（7 文件，900 行）
- ✅ `test/services/ocr_service_test.dart` — OcrResult 模型 + 生命周期
- ✅ `test/services/email_service_test.dart` — EmailConfig + 配置管理 + 功能方法
- ✅ `test/services/file_service_test.dart` — 路径构建 + merchant 安全化
- ✅ `test/services/invoice_matcher_service_test.dart` — 匹配逻辑（金额/商户名/日期/阈值）
- ✅ `test/services/check_pack_service_test.dart` — 每日检查 + 月初打包全流程

### 数据库测试
- ✅ `test/database/app_database_test.dart` — 状态查询 + 状态更新 + CRUD

## ⏳ 待完成

### 等待 Flutter SDK 安装后验证
- [ ] 运行 `flutter pub get` 确认依赖解析
- [ ] 运行 `dart run build_runner build` 生成 drift 代码
- [ ] 运行 `flutter test` 确认所有测试通过
- [ ] 运行 `flutter analyze` 确认无 lint 错误

### 后续迭代
- [ ] Widget 测试（screen 级别）
- [ ] 集成测试（端到端流程）
- [ ] CI 中添加上限覆盖率阈值
