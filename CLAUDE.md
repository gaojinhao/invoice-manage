# CLAUDE.md

本文件是 Claude Code 在此仓库的工作指引。详细项目说明（技术栈、业务模型、目录导览）见 [`AGENTS.md`](./AGENTS.md)，Claude Code 会在会话启动时同时读取两份文件。

## 分支管理

本项目采用类 GitFlow 分支模型，参考 Flutter、Kubernetes 等大型开源项目的分支管理实践。

### 分支结构

```text
main          ← 生产就绪代码，每次提交可独立发布
  │
  ├── develop ← 集成分支，feature/fix 分支合入此处
  │     │
  │     ├── feature/<name>   ← 新功能开发
  │     ├── fix/<name>       ← Bug 修复（非紧急）
  │     └── refactor/<name>  ← 重构（不改功能）
  │
  ├── release/<version> ← 发布准备（冻结特性，只修 bug）
  │
  └── hotfix/<name>     ← 紧急修复（从 main 分出，合回 main + develop）
```

### 分支命名

| 类型 | 格式 | 示例 |
|------|------|------|
| 功能 | `feature/<kebab-case>` | `feature/ocr-batch-scan` |
| 修复 | `fix/<kebab-case>` | `fix/zip-encoding-error` |
| 重构 | `refactor/<kebab-case>` | `refactor/db-migration-v2` |
| 发布 | `release/<semver>` | `release/1.2.0` |
| 热修复 | `hotfix/<kebab-case>` | `hotfix/crash-on-startup` |

### 工作流程

**新功能开发：**

```bash
git checkout develop
git pull origin develop
git checkout -b feature/<name>
# … 开发、测试 …
git checkout develop
git merge --no-ff feature/<name>
git push origin develop
```

**发布流程：**

```bash
git checkout develop
git checkout -b release/1.0.0
# 仅修 bug，版本号提升
git checkout main
git merge --no-ff release/1.0.0
git tag v1.0.0
git checkout develop
git merge --no-ff release/1.0.0
git branch -d release/1.0.0
git push origin main develop --tags
```

**紧急修复：**

```bash
git checkout main
git checkout -b hotfix/<name>
# … 修复、测试 …
git checkout main
git merge --no-ff hotfix/<name>
git tag v1.0.1
git checkout develop
git merge --no-ff hotfix/<name>
git branch -d hotfix/<name>
```

### 分支保护规则（GitHub 推荐配置）

| 分支 | 要求 |
|------|------|
| `main` | PR review 必须、CI 通过必须、禁止 force push、禁止直接 push |
| `develop` | PR review 推荐、CI 通过必须、禁止 force push |
| `feature/*` | 自由 push，合入 develop 时走 PR |
| `release/*` | 禁止 force push，合入 main 时走 PR |

### 当前项目简化

由于当前只有单人开发，不必严格走 Pull Request 流程，但**分支命名和合并方向必须遵循上述规则**：

- 所有新工作从 `develop` 分出
- 完成并验证后合回 `develop`
- `main` 只从 `release/*` 或 `hotfix/*` 合入
- 禁止直接在 `main` 上提交

当前仓库已有 `main` 分支。如尚未创建 `develop`，执行：

```bash
git checkout -b develop main
git push -u invoice-manage develop
```

## 常用命令

```bash
# 代码质量
dart format lib test
flutter analyze
flutter test

# 运行指定测试组
flutter test test/database/app_database_test.dart
flutter test test/services/file_service_test.dart
flutter test test/services/ocr_extraction_test.dart

# 构建与部署
flutter build apk --debug
adb install -r -g build/app/outputs/flutter-apk/app-debug.apk

# Drift 生成
dart run build_runner build --delete-conflicting-outputs
```

## Claude Code 特定指引

### 提交前检查清单

每次提交前必须通过以下检查：

```bash
git diff --cached --shortstat          # 确认 diff ≤ 200 行
dart format <changed files>            # 格式化
dart analyze <changed files>           # 静态分析
flutter test <relevant test files>     # 相关测试
```

### 提交格式

```
<type>(<scope>): <subject>

Co-Authored-By: Claude <noreply@anthropic.com>
```

类型：`feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` / `chore` / `ci` / `build`

### 代码修改原则

- 改动前先读 `AGENTS.md` 了解上下文
- 保持 UI / Service / Data 三层分离
- 复杂业务逻辑放 `lib/services/`
- 不改动生成文件（`*.g.dart`、`GeneratedPluginRegistrant.java` 等）
- 不提交构建产物、APK、数据库文件、大模型文件
- 涉及敏感信息（密码、授权码）继续使用 `flutter_secure_storage`
- 新增依赖需确认必要性

### 测试策略

- 新建 service 文件时同步创建 `test/services/<name>_test.dart`
- 涉及数据库查询时优先用 `AppDatabase.test()` 做 in-memory 测试
- 涉及文件 I/O 时注入 `baseDirectory` 可测接口
- 涉及纯逻辑方法时暴露为 `static` + `@visibleForTesting`

### Git Worktree 隔离

复杂任务可使用 worktree 隔离：

```bash
git worktree add -b feature/<name> ../app-invoice-<name> develop
```

Claude Code 中可使用 `EnterWorktree` 工具自动创建隔离环境。
