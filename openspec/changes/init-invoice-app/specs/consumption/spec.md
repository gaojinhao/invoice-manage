# Delta for 消费记录管理 (Consumption)

## ADDED Requirements

### Requirement: 创建消费记录
用户拍照上传结账单后，App 本地 OCR 识别并创建一条消费记录。

#### Scenario: 拍照上传结账单
- GIVEN 用户完成了一次消费
- WHEN 用户对结账单拍照（或从相册选择）
- THEN App 本地调用 ML Kit 识别金额、日期、商户名
- AND 创建一条状态为"待补支付记录"的消费记录
- AND 显示识别结果供用户确认/修改

#### Scenario: 手动创建消费记录
- GIVEN 用户无法拍照（电子小票等）
- WHEN 用户选择手动录入
- THEN 用户手动输入金额、日期、商户名
- AND 创建一条消费记录

### Requirement: 消费记录状态管理

#### Scenario: 状态流转
- GIVEN 一条消费记录已创建 → 状态="待补支付记录"
- WHEN 用户上传了支付记录截图
- THEN 状态变更为"待开发票"
- WHEN 系统从邮箱下载了对应发票
- THEN 状态变更为"三证齐全"
- WHEN 月初打包发送后
- THEN 状态变更为"已归档"

#### Scenario: 状态查看
- GIVEN 用户在首页
- WHEN 页面加载
- THEN 展示所有消费记录列表
- AND 每条记录显示：日期、商户、金额、状态（带颜色标识）
- AND 可按月份筛选
- AND 首页顶部显示各状态的数量统计

### Requirement: 月度消费统计

#### Scenario: 本月消费总额
- GIVEN 用户打开首页
- WHEN 页面加载完成
- THEN 显示本月消费总额
- AND 显示本月各状态记录数量（待补支付记录/待开发票/三证齐全）

#### Scenario: 按月份查看
- GIVEN 用户在首页
- WHEN 用户切换月份
- THEN 显示该月所有消费记录
- AND 更新该月消费总额
