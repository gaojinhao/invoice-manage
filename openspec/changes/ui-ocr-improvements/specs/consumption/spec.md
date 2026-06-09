# Delta for 消费记录管理 (Consumption)

## MODIFIED Requirements

### Requirement: 消费记录列表卡片 — 颜色编码
首页消费记录列表中的每条记录以**长条形卡片**展示，颜色反映三证齐全程度。

#### Scenario: 红色卡片 — 支付记录和发票均缺失
- GIVEN 一条消费记录的 `paymentImg` 和 `invoicePdf` 均为 null
- WHEN 首页渲染该记录卡片
- THEN 卡片左侧色条为红色
- AND 状态标签显示"待补充"
- AND 金额数字显示为红色

#### Scenario: 橘色卡片 — 部分文件已上传
- GIVEN 一条消费记录的 `paymentImg` 或 `invoicePdf` 不为 null（至少一个已上传）
- WHEN 首页渲染该记录卡片
- THEN 卡片左侧色条为橘色
- AND 状态标签显示"部分完成"
- AND 金额数字显示为橘色

#### Scenario: 绿色卡片 — 三证齐全
- GIVEN 一条消费记录的 `receiptImg`、`paymentImg`、`invoicePdf` 均不为 null
- WHEN 首页渲染该记录卡片
- THEN 卡片左侧色条为绿色
- AND 状态标签显示"三证齐全"
- AND 金额数字显示为绿色

#### Scenario: 卡片信息布局
- GIVEN 任意一条消费记录
- WHEN 在首页展示
- THEN 卡片包含：左侧色条 | 商户名 + 日期 | 金额 | 状态标签 | 右箭头
- AND 商户名单行显示，超长截断
- AND 日期格式为 yyyy-MM-dd

### Requirement: 消费记录详情页 — 三证文件管理
点击记录卡片进入详情页，页面从上到下分布 3 个独立的文件管理区域，分别对应结账单、支付记录、发票。

#### Scenario: 三区域布局
- GIVEN 用户进入某条消费记录详情页
- WHEN 页面加载完成
- THEN 显示 3 个独立文件区域，从上到下依次为：
  1. **结账单**（图标=receipt_long，颜色=indigo）
  2. **支付记录**（图标=payment，颜色=orange）
  3. **发票**（图标=description，颜色=green）
- AND 每个区域有标签行（图标 + 名称）
- AND 底部为文件内容区域

#### Scenario: 已有文件 → 显示缩略图 + 替换按钮
- GIVEN 某区域已有文件（如结账单已上传）
- WHEN 页面渲染
- THEN 显示图片缩略图（高度 180px，宽度撑满）
- AND 缩略图右上角覆盖半透明圆形加号按钮（⊕）
- AND 标签行右侧有👁查看按钮
- AND 点击加号按钮 → 打开相册选择新图片 → 替换原文件
- AND 点击查看按钮 → 系统调用 `OpenFile.open()` 打开文件

#### Scenario: 无文件 → 显示加号上传区域
- GIVEN 某区域无文件（如支付记录未上传）
- WHEN 页面渲染
- THEN 显示灰色虚线占位区域
- AND 中央显示加号图标（add_circle_outline）
- AND 下方提示文字"点击上传XX"
- AND 点击 → 打开相册选择图片 → 上传

#### Scenario: 文件替换（覆盖式）
- GIVEN 某区域已有文件
- WHEN 用户点击加号按钮
- THEN 打开相册选择新图片
- AND 新图片覆盖保存到原文件路径
- AND 数据库中记录更新为新的文件路径
- AND 缩略图即时刷新为新图片

## ADDED Requirements

### Requirement: 手动打包导出
首页增设手动打包导出按钮，将当前月份所有记录的文件打包为 ZIP，可选择下载分享或发送到邮箱。

#### Scenario: 打包当前月记录为 ZIP
- GIVEN 用户在首页
- WHEN 用户点击"打包导出当前月所有记录"按钮
- THEN 调用 `FileService.zipMonthRecords(year, month)` 生成 ZIP
- AND 弹出操作选择 BottomSheet：
  - 📥 **下载/分享文件** — 通过系统分享菜单发送（微信/QQ等）
  - 📧 **发送到邮箱** — 若已配置邮箱则发送，未配置则引导到邮箱配置页

#### Scenario: 无记录可打包
- GIVEN 当前月没有任何消费记录
- WHEN 用户点击打包按钮
- THEN 显示提示"当前月暂无记录可打包"

#### Scenario: 未配置邮箱引导
- GIVEN 用户选择"发送到邮箱"但尚未配置邮箱
- WHEN 系统检查 `flutter_secure_storage` 中无 `email_addr`
- THEN 弹窗提示"请先配置邮箱"
- AND 提供"去配置"按钮跳转到邮箱配置页

### Requirement: 文件上传方式扩展
除结账单通过 CameraScreen 拍照上传外，详情页的 3 个文件区域均支持从相册选择图片上传/替换。

#### Scenario: 详情页相册上传
- GIVEN 用户在详情页的任一文件区域
- WHEN 用户点击加号按钮
- THEN 打开系统相册（`image_picker` pickImage 最大宽度 2048px）
- AND 选择图片后调用对应 FileService 方法保存
- AND 更新数据库中的文件路径
