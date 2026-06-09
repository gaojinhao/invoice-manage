# Delta for OCR识别 (OCR)

## MODIFIED Requirements

### Requirement: 结账单 OCR 识别（提取精度优化）
使用 Google ML Kit（离线、本机运行）识别中文结账单/小票照片中的关键信息，**正则提取模式全面升级以覆盖更多实际小票格式**。

#### Scenario: 商户名提取 — 连锁品牌匹配
- GIVEN 用户拍摄了一张连锁品牌小票（如肯德基、星巴克、瑞幸、蜜雪冰城等）
- WHEN 系统调用商户名提取逻辑
- THEN 应正确识别品牌名为商户名
- AND 不需要依赖前缀标记（如"商户："）

#### Scenario: 商户名提取 — 行业后缀匹配
- GIVEN 小票首行为"XX超市/餐厅/药店/加油站"等
- WHEN 系统提取商户名
- THEN 应取整行文本作为商户名

#### Scenario: 商户名提取 — 前缀标记匹配
- GIVEN 小票中包含"商户：XX"、"商家 XX"、"店名：XX"等标记
- WHEN 系统提取商户名
- THEN 应提取标记后的文本

#### Scenario: 商户名提取 — 智能兜底
- GIVEN 所有模式匹配均失败
- WHEN 系统进入兜底逻辑
- THEN 取前 4 行中不包含"电话/地址/日期/单号"的第一行文本
- AND 如果所有行都包含上述关键词，取第一行

#### Scenario: 金额提取 — 多前缀匹配
- GIVEN 小票中包含"合计/总计/实收/应付/付款/消费/小计/金额/收款"等前缀
- WHEN 系统提取金额
- THEN 应识别所有常见前缀后的数字
- AND 支持冒号/等号/空格等分隔符

#### Scenario: 金额提取 — 符号前缀匹配
- GIVEN 金额以"¥"或"￥"开头
- WHEN 系统提取金额
- THEN 应正确提取符号后的数字

#### Scenario: 金额提取 — 兜底逻辑
- GIVEN 所有前缀模式匹配均失败
- WHEN 系统进入兜底逻辑
- THEN 找出文本中所有格式为 NNNN.NN 的数字
- AND 取最大值（通常为总额）
- AND 过滤掉 0 和超过 9999999 的异常值

#### Scenario: 日期提取 — 多格式支持
- GIVEN 小票中包含日期信息
- WHEN 系统提取日期
- THEN 支持以下格式：
  - YYYY年MM月DD日、YYYY-MM-DD、YYYY/MM/DD、YYYY.MM.DD
  - YYYYMMDD 紧凑格式
  - MM月DD日（补当年年份）

## ADDED Requirements

### Requirement: PaddleOCR 替换方案（备选）
后续网络条件允许时，将 OCR 引擎从 Google ML Kit 替换为 PaddleOCR（PP-OCRv5），以提升中文识别准确率。

#### Scenario: PaddleOCR 集成
- GIVEN Flutter 项目已添加 `paddle_ocr_flutter` 依赖
- WHEN 系统初始化 OCR 引擎
- THEN 调用 `PaddleOcrFlutter().init()` 加载模型（约 21MB，首次 ~1-2s）
- AND 调用 `recognize(imagePath)` 返回 List<OcrResult>
- AND 复用现有正则提取逻辑解析结果

#### PaddleOCR 备忘
| 项目 | 值 |
|------|-----|
| 插件 | `paddle_ocr_flutter: ^0.0.3` |
| 引擎 | PP-OCRv5 + ONNX Runtime |
| 模型大小 | ~21MB（det 4.6MB + rec 16MB + cls 571KB）|
| 字库 | 18,383 汉字/英文/符号 |
| 平台 | Android arm64-v8a |
| 协议 | MIT |
| 发布 | 2026年4月，52 天前 |
