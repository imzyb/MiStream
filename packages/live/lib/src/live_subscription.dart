import 'package:live/src/live_parser.dart';

/// 一条直播订阅源 —— TVBox 配置 `lives[]` 里的一项。
///
/// 刻意**不复用** `core_config` 的 `LiveConfig`：`live` 包不依赖
/// `core_config`，保持自成一体；app 层做一次字段映射即可（少一个依赖，
/// 也少一次「改 core_config 就牵连 live 测试」）。
class LiveSubscription {
  /// 构造订阅。
  const LiveSubscription({
    required this.url,
    this.name,
    this.type,
    this.userAgent,
    this.epgTemplate,
    this.logoTemplate,
  });

  /// 订阅地址。
  ///
  /// ⚠️ **可能是相对路径**（实测真实配置里就有 `./list.txt`）。用
  /// [resolveLiveUrl] 相对配置自身的 URL 解析后再拉取。
  final String url;

  /// 订阅名（显示用）。
  final String? name;

  /// TVBox 约定的格式标记：0 = M3U，1 = TXT。
  ///
  /// ⚠️ **不作为格式判据**。实测 `{"type": 0, "url": "./list.txt"}` 拉回来
  /// 的是纯 txt，与约定相反。导入一律按内容嗅探，这个字段只用于诊断与兜底。
  final int? type;

  /// 拉取时使用的 User-Agent（真实配置里出现过 `okhttp/3.15`）。
  final String? userAgent;

  /// EPG 接口模板，含 `{name}` / `{date}` 占位符。
  final String? epgTemplate;

  /// 频道图标模板，含 `{name}` 占位符。
  final String? logoTemplate;

  /// 展开 [logoTemplate]，把 `{name}` 换成频道名。
  ///
  /// 没有模板或频道名为空时返回 `null` —— 模板本身不是 URL，直接拿去当图标
  /// 地址会请求到一个 404 的模板串。
  String? logoFor(String channelName) {
    final template = logoTemplate?.trim() ?? '';
    if (template.isEmpty || channelName.isEmpty) return null;
    return template.replaceAll('{name}', Uri.encodeComponent(channelName));
  }

  @override
  String toString() => 'LiveSubscription(${name ?? ''} → $url)';
}

/// 把订阅里的地址解析成绝对 URL。
///
/// 真实配置里 `lives[].url` 可能是相对路径（实测 `./list.txt`），语义是
/// **相对配置文件自身的 URL**。直接当绝对地址请求会 404，而错误信息会是
/// 「导入 0 个频道」，完全指不到原因。
///
/// 已经是绝对 URL 的原样返回；[baseUrl] 缺失或不合法时也返回原值 —— 这里
/// 不吞掉问题，让传输层拿到原文去报错，比悄悄拼出一个奇怪地址好排查。
String resolveLiveUrl(String url, {String? baseUrl}) {
  final value = url.trim();
  if (value.isEmpty || hasUrlScheme(value)) return value;

  final base = baseUrl?.trim() ?? '';
  if (base.isEmpty) return value;
  final parsedBase = Uri.tryParse(base);
  if (parsedBase == null ||
      parsedBase.scheme.isEmpty ||
      parsedBase.host.isEmpty) {
    return value;
  }
  return parsedBase.resolve(value).toString();
}
