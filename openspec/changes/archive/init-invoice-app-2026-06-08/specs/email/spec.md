# Delta for 邮件处理 + 定时任务 (Email & Scheduler)

## ADDED Requirements

### Requirement: 邮箱配置
用户可在 App 内配置邮箱，用于接收发票和发送月度压缩包。所有操作在手机本地完成，不经过第三方服务器。

#### Scenario: 配置邮箱
- GIVEN 用户首次使用
- WHEN 用户在设置页填写邮箱和授权码
- THEN 系统使用 IMAP 协议验证连接
- AND 保存配置到本地安全存储（flutter_secure_storage）
- AND 提示配置成功

#### Scenario: 邮箱验证失败
- GIVEN 用户填写了邮箱信息
- WHEN App 连接邮箱失败
- THEN 提示具体原因（密码错误/IMAP未开启/需要授权码）
- AND 让用户重新配置

### Requirement: 每日检查邮箱下载发票
App 通过 WorkManager 定时任务，每天检查邮箱中是否有匹配的发票。

#### Scenario: 自动下载发票
- GIVEN WorkManager 触发每日邮箱检查任务
- WHEN 邮箱中有新邮件，金额+日期匹配某条消费记录
- THEN 下载邮件附件（发票 PDF/图片）到本地
- AND 关联到对应的消费记录
- AND 更新记录状态

#### Scenario: 无匹配发票
- GIVEN 每日检查执行
- WHEN 没有找到匹配的发票邮件
- THEN 跳过，等待下次检查

### Requirement: 每日检查缺文件并通知

#### Scenario: 提醒补充支付记录
- GIVEN WorkManager 触发每日检查
- WHEN 存在状态为"待补支付记录"的记录
- THEN 发送本地通知："您有 N 条记录缺少支付记录截图"

#### Scenario: 全部齐全
- GIVEN 每日检查执行
- WHEN 所有记录状态正常
- THEN 不做任何通知

### Requirement: 月初打包发送

#### Scenario: 自动打包归档
- GIVEN 时间是本月第 1 天
- WHEN WorkManager 触发月初打包任务
- THEN 扫描上个月所有"三证齐全"的记录
- AND 每条记录建一个文件夹（放 3 个文件）
- AND 打包为 ZIP
- AND 通过 SMTP 发送到配置的目标邮箱
- AND 更新记录状态为"已归档"
