/// 直播订阅源的 HTTP 拉取。
///
/// 刻意**不复用** `ConfigFetcher`：那一个是给 TVBox **配置**用的，会把
/// HTML/图片判成「不是配置」并换浏览器 UA 重试一次。直播源不一样 —— 它本来
/// 就是纯文本，源站返回 HTML 错误页时应当如实报错，换个 UA 再撞一次只会把
/// 「源挂了」拖成两倍等待时间。
library;

import 'dart:io';
// `BytesBuilder` 从 `dart:io` 拿是间接导入，已标记废弃 —— 显式写出来。
import 'dart:typed_data';

import 'package:core_config/core_config.dart';
import 'package:text_codec/text_codec.dart';

/// 从响应头与响应体解码出直播源文本。
///
/// 单独抽成函数是为了**可测**：真实 `HttpClient` 要起连接，而本项目的沙箱
/// 禁止本地回环，整条 [LiveSourceFetcher.call] 路径在测试里跑不到 —— 把
/// 「响应头 → 字符集 → 文本」这三步留在这个纯函数里，它才可能被盯住。
///
/// 优先级：响应头里明确的 charset > 内容嗅探（见 `decodeText`）。
/// **响应头优先**是刻意的 —— 源站说自己是 GBK 就按 GBK 解，不因为「这串字节
/// 恰好也能按 UTF-8 解通」就改口。
String decodeSourceBody({required List<int> bytes, String? contentType}) =>
    decodeText(bytes, charset: charsetFromContentType(contentType));

/// 直播源拉取器。
///
/// 持有复用的 [HttpClient]：一次导入会连着拉十几个源，每个源各建一个客户端
/// 会白白多出一堆握手。用完记得 [close]。
class LiveSourceFetcher {
  /// 构造。[client] 可注入，便于测试替换传输层。
  LiveSourceFetcher({
    HttpClient? client,
    this.timeout = const Duration(seconds: 15),
    this.maxBytes = 8 * 1024 * 1024,
  }) : _client = client ?? HttpClient();

  final HttpClient _client;

  /// 单次请求（连接 + 读完响应体）的超时。
  ///
  /// 比配置拉取的 20 秒短：一次导入会串行拉十几个源，任何一个卡住都会拖慢
  /// 整批。15 秒足够拉完一份几万行的直播表。
  final Duration timeout;

  /// 响应体上限。直播表通常是几十 KB 到几 MB；超过这个数说明拉到的不是表。
  final int maxBytes;

  /// 拉取 [url] 并解码为文本。
  ///
  /// [userAgent] 为空时用 [kConfigFetchUserAgent]（`okhttp/3.15.0`）—— 实测
  /// 直播源站与配置站点的 UA 策略一致，非 okhttp 的 UA 常被 302 踢到首页。
  ///
  /// 解码走 [decodeText]：响应头给了 charset 就按它，没给就按内容猜（UTF-8
  /// 严格解失败退回 GBK）。少数老直播源是 GBK，只按 UTF-8 解会整篇乱码，
  /// 而且**宽容模式也救不回来** —— GBK 汉字两字节都落在 `0x81`~`0xFE`，
  /// UTF-8 解码器会把它们判为非法起始字节。
  Future<String> call(String url, {String? userAgent}) async {
    final uri = Uri.parse(url);
    final override = userAgent?.trim() ?? '';

    final request = await _client.getUrl(uri).timeout(timeout);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      override.isEmpty ? kConfigFetchUserAgent : override,
    );

    final response = await request.close().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // 先把连接排空，否则 keep-alive 连接会留着不放。
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }

    final bytes = await _readCapped(response).timeout(timeout);
    return decodeSourceBody(
      bytes: bytes,
      contentType: response.headers.value(HttpHeaders.contentTypeHeader),
    );
  }

  /// 释放底层连接池。
  void close() => _client.close(force: true);

  /// 读响应体，累计超过 [maxBytes] 就中止。
  Future<List<int>> _readCapped(HttpClientResponse response) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw HttpException(
          '直播源超过 ${maxBytes ~/ (1024 * 1024)}MB，判定不是播放列表',
          uri: response.redirects.isEmpty
              ? null
              : response.redirects.last.location,
        );
      }
    }
    return builder.takeBytes();
  }
}
