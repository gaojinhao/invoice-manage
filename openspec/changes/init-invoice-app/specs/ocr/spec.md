# Delta for OCR识别 (OCR)

## ADDED Requirements

### Requirement: 结账单 OCR 识别
使用 Google ML Kit（离线、本机运行）识别中文结账单/小票照片中的关键信息。

#### Scenario: 拍照识别成功
- GIVEN 用户拍摄了一张结账单照片
- WHEN 系统调用 ML Kit 文字识别
- THEN 提取图片中所有文字
- AND 通过正则/规则解析提取以下信息
  - 商户名称（如"永辉超市"、"美团外卖"）
  - 消费日期
  - 消费金额（含小数点，找"合计/实付/¥"后的数字）
- AND 在 UI 上展示解析结果供确认

#### Scenario: 从相册选择
- GIVEN 用户已有结账单照片
- WHEN 用户从相册选择图片
- THEN 同拍照流程执行 OCR

#### Scenario: 识别结果修正
- GIVEN OCR 识别结果已展示
- WHEN 用户发现金额/日期/商户名有误
- THEN 用户可点击编辑对应字段
- AND 修改后保存

#### Scenario: 手动录入（OCR 备用路径）
- GIVEN 用户上传了一张模糊/反光/歪斜的照片
- WHEN 用户点击"手动录入"
- THEN 跳过 OCR 直接进入编辑页
- AND 用户手动填写金额、日期、商户名
