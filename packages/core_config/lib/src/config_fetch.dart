/// TVBox 配置的 HTTP 拉取：UA 选择、重定向跟随与失败诊断。
///
/// 单独成文件的原因：**拉配置和拉媒体对 UA 的要求是相反的**。媒体与封面要
/// 装成浏览器（躲防盗链白名单），而 TVBox 配置要装成 TVBox 客户端（订阅站
/// 按 UA 分流）。共用一个常量必然错一半。
library;

import 'dart:async';
import 'dart:io';

import 'package:core_config/src/config_decoder.dart';
import 'package:core_domain/core_domain.dart';

/// 拉取 TVBox 配置时使用的 `User-Agent`。
///
/// **必须是 okhttp 形态，不能用浏览器 UA。** TVBox 客户端跑在 Android 的
/// OkHttp 栈上，默认就标识为 `okhttp/3.x`；而相当一部分订阅站按 UA 分流：
/// 认 okhttp 才给配置，其它一律 302 到首页。用浏览器 UA 会稳定拿到首页
/// HTML，最后报「返回的是网页（HTML）」，把「UA 不对」误诊成「地址失效」。
///
/// 实测（2026-09-25，`http://www.饭太硬.cc/tv`）：
///
/// | UA | 结果 |
/// | --- | --- |
/// | `okhttp/3.15.0` / `4.9.0` / `4.12.0` / `2.7.5` | `200` |
/// | Chrome / Dalvik / `TVBox` / curl / 空 | `302` → 首页 HTML |
///
/// 判据是「UA 里含 `okhttp`」，版本号不参与。
const String kConfigFetchUserAgent = 'okhttp/3.15.0';

/// 兜底用的浏览器 UA。
///
/// 也有站点的策略与上面相反（只认浏览器 UA、对 okhttp 返回占位图）。单靠
/// 一个 UA 覆盖不了两类站点，所以 [ConfigFetcher.fetch] 会在首选 UA 拿到
/// 非配置内容时用它重试一次。
const String kConfigFetchBrowserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// 状态码是否为重定向。
bool isRedirectStatus(int statusCode) =>
    statusCode == 301 ||
    statusCode == 302 ||
    statusCode == 303 ||
    statusCode == 307 ||
    statusCode == 308;

/// 把响应的 `Location` 解析成下一个要请求的绝对 URL。
///
/// 返回 `null` 表示**不该跟随**：`Location` 缺失/为空，或解析结果已经在
/// [visited] 里（重定向成环）。
///
/// 抽成纯函数是因为这三件事都不该让调用方自己拼：`Location` 常常是相对
/// 地址（`/`、`../x`），直接拿去 `getUrl` 会炸；成环则会让循环空转到上限。
String? resolveRedirectUrl({
  required Uri current,
  required String? location,
  required List<String> visited,
}) {
  if (location == null || location.isEmpty) return null;
  final next = current.resolve(location).toString();
  if (visited.contains(next)) return null;
  return next;
}

/// 一次拉取的诊断信息。
///
/// 存在的理由：`HttpClient` 默认**静默跟随**重定向，于是「302 到首页」这件事
/// 在结果里完全看不出来——最终只表现为「拿到一段 HTML」，看起来像地址填错。
/// 把状态码、重定向链、content-type、字节数和实际使用的 UA 一起带出来，
/// 这类问题才能一眼定位。
class ConfigFetchDiagnostics {
  /// 构造诊断信息。
  const ConfigFetchDiagnostics({
    required this.requestedUrl,
    required this.userAgent,
    this.statusCode = 0,
    this.contentType = '',
    this.byteLength = 0,
    this.redirectChain = const <String>[],
    this.note = '',
  });

  /// 用户填写的地址。
  final String requestedUrl;

  /// 本次实际使用的 `User-Agent`。
  final String userAgent;

  /// 最后一次响应的状态码；`0` 表示压根没拿到响应（连接失败/超时）。
  final int statusCode;

  /// 最后一次响应的 `content-type`。
  final String contentType;

  /// 最终拿到的字节数。
  final int byteLength;

  /// 重定向链：从第一个 `Location` 起，末尾是最终 URL。没有跳转则为空。
  final List<String> redirectChain;

  /// 额外说明（如「响应过大已中止」）。
  final String note;

  /// 最终生效的 URL。没有发生重定向时等于 [requestedUrl]。
  String get effectiveUrl =>
      redirectChain.isEmpty ? requestedUrl : redirectChain.last;

  /// 是否发生过重定向。
  bool get wasRedirected => redirectChain.isNotEmpty;

  /// 人类可读的一行摘要，直接拼进错误信息。
  ///
  /// 刻意把重定向链整条打出来：这正是「地址没错但拿到 HTML」的关键证据。
  String describe() {
    final head = <String>['HTTP $statusCode'];
    if (contentType.isNotEmpty) head.add(contentType);
    head.add('$byteLength 字节');
    final buffer = StringBuffer(head.join(' · '));
    if (note.isNotEmpty) buffer.write('（$note）');
    if (wasRedirected) {
      buffer.write('；重定向 ${redirectChain.join(' → ')}');
    }
    return buffer.toString();
  }

  /// 转成可放进 [AppError.detail] 的结构化形式。
  Map<String, Object?> toDetail() => <String, Object?>{
    'url': requestedUrl,
    'userAgent': userAgent,
    'status': statusCode,
    'contentType': contentType,
    'bytes': byteLength,
    if (redirectChain.isNotEmpty) 'redirects': redirectChain,
    if (note.isNotEmpty) 'note': note,
  };
}

/// 一次拉取的结果：字节 + 诊断。
class ConfigFetchOutcome {
  /// 构造结果。
  const ConfigFetchOutcome({required this.diagnostics, this.bytes, this.error});

  /// 成功时的响应字节。
  final List<int>? bytes;

  /// 失败原因；成功时为 `null`。
  final AppError? error;

  /// 诊断信息，成功失败都带着。
  final ConfigFetchDiagnostics diagnostics;

  /// 是否成功。
  bool get isOk => error == null;
}

/// 判断响应体能否当作配置。
///
/// 返回 `null` 表示可以接受；返回一段**内容类别文案**（如 `'网页（HTML）'`）
/// 表示不能，且这段文案会拼进错误信息——用户看到的就不只是「失败」，而是
/// 「返回的是网页（HTML），不是 TVBox JSON 配置」。
///
/// 做成「返回原因」而不是「返回 bool」，是因为失败时调用方手里已经没有
/// 响应体了，事后再想描述内容类别就无从下手。
typedef ConfigBodyVerdict =
    String? Function(List<int> bytes, ConfigFetchDiagnostics diagnostics);

/// 默认判据：排除网页/图片这类「明显不是配置」的内容。
///
/// 判据只能是**否定式**的——配置本身可能是 Base64 或 AES 密文，不是可读
/// JSON，所以不能反过来要求「必须能 jsonDecode」。真正能确定的就是
/// 「这是网页 / 这是图片」这两种。
///
/// 就是 [ConfigDecoder.probeNonJson]，套一层是为了对上 [ConfigBodyVerdict]
/// 的入参形状（多一个 diagnostics）。
String? defaultConfigVerdict(List<int> bytes, ConfigFetchDiagnostics _) {
  if (bytes.isEmpty) return '空响应';
  return ConfigDecoder.probeNonJson(bytes);
}

/// 配置拉取器。
///
/// 手动跟随重定向（而不是把 `followRedirects` 交给 `HttpClient`），为的是
/// 能记下整条跳转链——这是诊断「地址正确但被踢到首页」的唯一线索。
class ConfigFetcher {
  /// 构造。[client] 可注入，便于测试替换传输层。
  ConfigFetcher({
    HttpClient? client,
    this.maxRedirects = 5,
    this.timeout = const Duration(seconds: 20),
    this.maxBytes = 16 * 1024 * 1024,
  }) : _client = client ?? HttpClient();

  final HttpClient _client;

  /// 最多跟随几次重定向。
  final int maxRedirects;

  /// 单次请求的超时。
  final Duration timeout;

  /// 响应体上限。配置只有几百 KB，超过这个数说明拉到的不是配置
  /// （常见于源站把请求导向一个视频/图片），没必要读完。
  final int maxBytes;

  /// 拉取 [url]。
  ///
  /// [userAgent] 为 `null` 时先试 [kConfigFetchUserAgent]，若拿到的内容不像
  /// 配置（HTML/图片/空）再退到 [kConfigFetchBrowserUserAgent] 重试一次。
  /// 两次都失败时返回**第一次**的错误，[ConfigFetchOutcome.diagnostics] 的
  /// `note` 里记下两次的结果对比。
  ///
  /// [verdict] 判断响应体能否当作配置；默认 [defaultConfigVerdict]。
  Future<ConfigFetchOutcome> fetch(
    String url, {
    String? userAgent,
    ConfigBodyVerdict? verdict,
  }) async {
    final check = verdict ?? defaultConfigVerdict;

    if (userAgent != null) {
      return _fetchOnce(url, userAgent, check);
    }

    final primary = await _fetchOnce(url, kConfigFetchUserAgent, check);
    if (primary.isOk) return primary;

    // 首选 UA 失败（含「拿到了 HTML/图片」这种 200 也算失败的情形），
    // 用浏览器 UA 再试一次——两类站点都覆盖到。
    final fallback = await _fetchOnce(
      url,
      kConfigFetchBrowserUserAgent,
      check,
    );
    if (fallback.isOk) return fallback;

    final combined = ConfigFetchDiagnostics(
      requestedUrl: primary.diagnostics.requestedUrl,
      userAgent: primary.diagnostics.userAgent,
      statusCode: primary.diagnostics.statusCode,
      contentType: primary.diagnostics.contentType,
      byteLength: primary.diagnostics.byteLength,
      redirectChain: primary.diagnostics.redirectChain,
      note:
          '${primary.diagnostics.note.isEmpty ? '' : '${primary.diagnostics.note}；'}'
          'okhttp UA: ${primary.diagnostics.describe()}'
          '；浏览器 UA: ${fallback.diagnostics.describe()}',
    );
    // 首选 UA 与浏览器 UA 的结果都要进 **message**，不能只放进 diagnostics：
    // `Err` 之后没人会再去翻 diagnostics，用户和日志看到的只有 message。
    // 首次尝试的结果已经在 `primary.error.message` 里了，这里只补「换过 UA」
    // 与第二次的结果，避免同一段话出现两遍。
    return ConfigFetchOutcome(
      error: _withNote(
        primary.error!,
        '两次 UA 都试过；浏览器 UA 的结果：${fallback.diagnostics.describe()}',
      ),
      diagnostics: combined,
    );
  }

  /// 用固定 [userAgent] 拉一次，不重试。
  Future<ConfigFetchOutcome> _fetchOnce(
    String url,
    String userAgent,
    ConfigBodyVerdict verdict,
  ) async {
    final chain = <String>[];
    var current = url;
    var status = 0;
    var contentType = '';
    var byteLength = 0;
    var note = '';

    ConfigFetchDiagnostics diag() => ConfigFetchDiagnostics(
      requestedUrl: url,
      userAgent: userAgent,
      statusCode: status,
      contentType: contentType,
      byteLength: byteLength,
      redirectChain: List<String>.unmodifiable(chain),
      note: note,
    );

    try {
      for (var hop = 0; hop <= maxRedirects; hop++) {
        final uri = Uri.tryParse(current);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          return ConfigFetchOutcome(
            diagnostics: diag(),
            error: LocalError(
              code: ErrorCode.invalidArgument,
              message: '配置地址无效，请输入完整的 HTTP/HTTPS 地址',
              detail: diag().toDetail(),
            ),
          );
        }

        final request = await _client.getUrl(uri).timeout(timeout);
        request
          ..followRedirects = false
          ..headers.set(HttpHeaders.userAgentHeader, userAgent)
          ..headers.set(HttpHeaders.acceptHeader, '*/*');
        final response = await request.close().timeout(timeout);

        status = response.statusCode;
        contentType =
            response.headers.value(HttpHeaders.contentTypeHeader) ?? '';

        if (isRedirectStatus(status)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          final next = resolveRedirectUrl(
            current: uri,
            location: location,
            visited: chain,
          );
          if (next == null) {
            final why = (location == null || location.isEmpty)
                ? 'HTTP $status 重定向但未给出 Location'
                : '重定向成环';
            return ConfigFetchOutcome(
              diagnostics: diag(),
              error: RemoteError(
                code: ErrorCode.configFetchFailed,
                message: '订阅拉取失败：$why',
                detail: diag().toDetail(),
              ),
            );
          }
          chain.add(next);
          current = next;
          continue;
        }

        if (status < 200 || status >= 300) {
          await response.drain<void>();
          return ConfigFetchOutcome(
            diagnostics: diag(),
            error: RemoteError(
              code: ErrorCode.configFetchFailed,
              message: '订阅拉取失败：${diag().describe()}',
              detail: diag().toDetail(),
            ),
          );
        }

        final bytes = <int>[];
        var tooLarge = false;
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > maxBytes) {
            tooLarge = true;
            // `break` 会取消这条流的订阅，剩下的响应体不再读——比读完再丢
            // 好得多（源站可能把请求导向一个几百 MB 的文件）。
            break;
          }
        }
        byteLength = bytes.length;

        if (tooLarge) {
          note = '响应超过 ${maxBytes ~/ (1024 * 1024)} MiB，已中止';
          return ConfigFetchOutcome(
            diagnostics: diag(),
            error: RemoteError(
              code: ErrorCode.configFetchFailed,
              message: '订阅拉取失败：${diag().describe()}',
              detail: diag().toDetail(),
            ),
          );
        }

        final why = verdict(bytes, diag());
        if (why != null) {
          return ConfigFetchOutcome(
            diagnostics: diag(),
            error: RemoteError(
              code: ErrorCode.configNotJson,
              message: '返回的是$why，不是 TVBox JSON 配置；${diag().describe()}',
              detail: diag().toDetail(),
            ),
          );
        }

        return ConfigFetchOutcome(bytes: bytes, diagnostics: diag());
      }

      return ConfigFetchOutcome(
        diagnostics: diag(),
        error: RemoteError(
          code: ErrorCode.configFetchFailed,
          message: '订阅拉取失败：重定向次数超过 $maxRedirects 次',
          detail: diag().toDetail(),
        ),
      );
    } on Object catch (e, st) {
      return ConfigFetchOutcome(
        diagnostics: diag(),
        error: RemoteError(
          code: ErrorCode.configFetchFailed,
          message: '订阅拉取失败：${diag().describe()}（$e）',
          detail: diag().toDetail(),
          cause: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// 释放底层连接池。
  void close() => _client.close(force: true);
}

/// 在**保留错误类型与错误码**的前提下，把 [note] 追加进 message。
///
/// 用 `switch` 重建而不是 `copyWith`，是因为 [AppError] 是 `sealed`，新增
/// 子类时这里会编译不过——正好提醒把新类型一起处理掉。
AppError _withNote(AppError base, String note) => switch (base) {
  final LocalError e => LocalError(
    code: e.code,
    message: '${e.message}（$note）',
    detail: e.detail,
    cause: e.cause,
    stackTrace: e.stackTrace,
  ),
  final RemoteError e => RemoteError(
    code: e.code,
    message: '${e.message}（$note）',
    instanceId: e.instanceId,
    method: e.method,
    remoteStack: e.remoteStack,
    elapsed: e.elapsed,
    detail: e.detail,
    cause: e.cause,
    stackTrace: e.stackTrace,
  ),
};
