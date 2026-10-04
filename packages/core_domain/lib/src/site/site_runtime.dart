/// TVBox `sites[].type` 与 `sites[].api` 共同决定的**运行时类型**。
///
/// 为什么要有这个东西：`type` 单独不足以判断一个站点能不能跑。
/// `type=3` 既可能是「JS 脚本源」（`api` 指向 `.js`），也可能是
/// 「蜘蛛 jar 源」（`api` 形如 `csp_Xxx`，需要 JVM 运行时）。而 JVM 运行时
/// 按 [ADR-006](../../../docs/adr/006-jar-运行时降级为可选.md) 是**可选组件**，
/// 未安装时这一类站点全部不可用。
///
/// 实测（2026-09-25）：`qist/tvbox` 的 `xiaosa/api.json` 有 105 个站点，
/// **全部是 `type=3` + `csp_`**。如果只看 `type` 就会认为它们都可用，
/// 首页会挨个去试然后全军覆没——UI 必须能一眼看出这类源缺运行时。
library;

/// 站点运行时类型。
enum SiteRuntimeKind {
  /// JSON API（`type=1` / `type=4`）。宿主直接发 HTTP，零脚本，最稳。
  http('http'),

  /// JS 运行时。`type=0` 用内置通用脚本（由 `ext` 驱动），
  /// `type=3` 且 `api` 非 `csp_` 的走脚本文件。
  js('js'),

  /// TVBox 蜘蛛 jar（`type=3` 且 `api` 以 `csp_` 开头），需要 JVM 运行时。
  jvm('jvm'),

  /// 当前实现不支持的类型。
  unsupported('unsupported');

  const SiteRuntimeKind(this.wireName);

  /// 落库用的稳定字符串。
  ///
  /// **刻意不用 `name`**：枚举改名会静默改变库里已有数据的含义，
  /// 而 `wireName` 是显式契约，改名时会被迫面对。
  final String wireName;

  /// 从落库值还原；无法识别时返回 `null`（调用方决定是报错还是回退）。
  static SiteRuntimeKind? fromWireName(String? value) {
    if (value == null) return null;
    for (final kind in SiteRuntimeKind.values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// `type=3` 且 `api` 以此开头的站点，是 TVBox 蜘蛛 jar 类（JVM 运行时）。
const String kCspApiPrefix = 'csp_';

/// 按 `type` 与 `api` 判定站点该走哪个运行时。
///
/// 映射依据 `docs/05-Spider引擎.md` §5.4：
///
/// | type | 语义 | 运行时 |
/// | --- | --- | --- |
/// | 0 | XPath / CSP 网页解析（`ext` 驱动） | JS（内置通用脚本） |
/// | 1 | JSON API（苹果 CMS 风格） | HTTP |
/// | 3 | `api` 以 `csp_` 开头 → jar 类名；否则 → JS 脚本 | JVM / JS |
/// | 4 | JSON API 变体 | HTTP |
/// | 其它 | 未知 | 不支持 |
///
/// 纯函数，不碰 IO——这样 `spider_host`（分发）、`search_engine`（灰显）、
/// `apps/mistream`（落库）三处可以用同一把尺子，不会各写一份然后漂移。
SiteRuntimeKind classifySiteRuntime({
  required int typeCode,
  required String api,
}) {
  switch (typeCode) {
    case 0:
      return SiteRuntimeKind.js;
    case 1:
    case 4:
      return SiteRuntimeKind.http;
    case 3:
      return api.startsWith(kCspApiPrefix)
          ? SiteRuntimeKind.jvm
          : SiteRuntimeKind.js;
    default:
      return SiteRuntimeKind.unsupported;
  }
}
