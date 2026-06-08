# Design: 个人报销文件管理 App（纯手机端方案）

## 技术架构

```
┌───────────────────────────────────────────────────┐
│              Flutter App (Android + 鸿蒙)           │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │               UI Layer                       │   │
│  │  ┌────────────┐ ┌──────────┐ ┌───────────┐  │   │
│  │  │ 首页仪表盘  │ │ 消费记录  │ │ 设置页    │  │   │
│  │  │ 月度统计   │ │ 详情/编辑│ │ 邮箱配置  │  │   │
│  │  └────────────┘ └──────────┘ └───────────┘  │   │
│  └─────────────────────────────────────────────┘   │
│                         │                           │
│  ┌─────────────────────────────────────────────┐   │
│  │             Service Layer                    │   │
│  │  ┌──────────┐ ┌──────────┐ ┌────────────┐  │   │
│  │  │OCR Service│ │Email Svc│ │File Service│  │   │
│  │  │(ML Kit)  │ │(IMAP)   │ │(local FS)  │  │   │
│  │  └──────────┘ └──────────┘ └────────────┘  │   │
│  │  ┌──────────┐ ┌──────────┐ ┌────────────┐  │   │
│  │  │通知服务   │ │定时任务   │ │ZIP打包     │  │   │
│  │  │(local)   │ │(WorkMgr) │ │(archive)   │  │   │
│  │  └──────────┘ └──────────┘ └────────────┘  │   │
│  └─────────────────────────────────────────────┘   │
│                         │                           │
│  ┌─────────────────────────────────────────────┐   │
│  │             Data Layer                       │   │
│  │  ┌──────────┐ ┌──────────┐ ┌────────────┐  │   │
│  │  │SQLite DB │ │本地文件   │ │SharedPref  │  │   │
│  │  │(drift)   │ │存储      │ │(配置)      │  │   │
│  │  └──────────┘ └──────────┘ └────────────┘  │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
└───────────────────────────────────────────────────┘
```

### 关键依赖（Flutter packages）

| 功能 | 包 | 说明 |
|------|-----|------|
| 相机/相册 | `image_picker` | 拍照 + 选图 |
| OCR | `google_mlkit_text_recognition` | 离线中文 OCR，毫秒级 |
| 数据库 | `drift` (原 moor) | 类型安全 SQLite ORM |
| 邮件 IMAP | `mailer` + `dart:io` | 直接从手机连邮箱 |
| 定时任务 | `workmanager` | Android 后台任务 |
| 本地通知 | `flutter_local_notifications` | 离线推送 |
| ZIP 打包 | `archive` | 纯 Dart 压缩 |
| 图表 | `fl_chart` | 月度统计图表 |
| 文件管理 | `path_provider` | 获取存储路径 |

## 数据结构

### consumption_records（SQLite）
```
id          INTEGER PRIMARY KEY
date        TEXT (YYYY-MM-DD)
merchant    TEXT (商户名)
amount      REAL (金额)
status      TEXT:
              pending_payment  → 待补支付记录
              pending_invoice  → 待开发票
              complete         → 三证齐全
              archived         → 已归档
month       TEXT (YYYY-MM)
receipt_img TEXT (结账单照片路径, 本地)
payment_img TEXT (支付记录截图路径, 本地)
invoice_pdf TEXT (发票路径, 本地)
notes       TEXT (备注)
created_at  TEXT (ISO8601)
updated_at  TEXT (ISO8601)
```

### email_config（SharedPreferences）
```
email_addr    → 邮箱地址
email_pass    → 授权码
imap_server   → IMAP 服务器（如 imap.qq.com）
imap_port     → 993
send_to       → 月报发送目标邮箱
```

## 文件存储结构
```
<app_documents>/records/
└── YYYY-MM/
    └── YYYY-MM-DD_商户名/
        ├── 结账单.jpg
        ├── 支付记录.jpg
        └── 发票.pdf
```

## 定时任务（WorkManager）

| 任务 | 触发 | 操作 |
|------|------|------|
| 每日检查 | 每天 10:00（仅前台时） | 查缺支付记录 → 通知 |
| 每日邮箱检查 | 每天 10:30 | 查邮件下载发票 |
| 月初打包 | 每月 1 日 08:00 | 打包上月 → 发邮件 |

> 注意：Android 厂商省电策略可能延迟后台任务，需引导用户将 App 加入白名单。

## 数据安全
- 所有数据存储在手机本地
- 邮箱授权码加密存储（flutter_secure_storage）
- 不经过任何第三方服务器
- 用户可自行备份 db 文件
