# core_logging

结构化日志。字段与落盘格式见 `docs/10-开发规范.md` §9。

## 脱敏是结构性的，不是自觉

`LogRecord` **没有**无参 `toJson()`。想把一条日志变成字节，必须交出一个
`Redactor`：

```dart
Map<String, Object?> toJson(Redactor redactor)
```

而 `Redactor` 也没有「关掉」的模式。于是「忘了脱敏」这件事在类型层面就写不
出来——不需要靠 code review 或 CI grep 去抓。

`docs/10` §10 把日志脱敏列为硬要求，因为泄漏路径太顺手了：源返回的播放地址
常常带 `?token=`，而排错时第一反应就是把整条 URL 打进日志、再连同诊断信息贴
进 issue。

### 两套敏感词表

URL query 里的 `key` 几乎一定是 API key，要打码；但 TVBox 配置里的 `key` 是
站点标识（`{"key":"csp_XXX"}`），打掉它诊断信息就没法看了。所以
`Redactor` 分开维护 `urlSensitiveKeys` 与 `fieldSensitiveKeys`。

## 用法

```dart
final logger = Logger(
  scope: 'spider',
  sink: await JsonlFileSink.open(directory: logDir),
);

logger.info('起播', detail: {'url': playUrl});   // url 中的 token 自动打码
logger.error('解析失败', code: ErrorCode.scriptTimeout, siteId: 'site-12');
```

## 单独测试

```bash
dart test packages/core_logging
```
