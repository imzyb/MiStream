/// 起播编排器：回退链（解析器→嗅探→换线路→报错）。
///
/// docs/04-播放器设计.md §7。
library;

import 'package:core_domain/core_domain.dart';
import 'package:play_engine/src/models.dart';

/// 解析器成功解析出的结果。
class _ResolvedPlay {
  final String url;
  final String parserName;
  const _ResolvedPlay(this.url, this.parserName);
}

/// 起播编排器。
class PlayCoordinator {
  final SpiderPlayerApi spiderApi;
  final ParserResolver parserResolver;
  final SnifferLauncher sniffer;
  final PlayExecutor executor;
  final Duration playTimeout;

  /// 构造编排器。
  PlayCoordinator({
    required this.spiderApi,
    required this.parserResolver,
    required this.sniffer,
    required this.executor,
    this.playTimeout = const Duration(seconds: 8),
  });

  /// 执行起播编排，返回结果或结构化的失败信息。
  Future<Result<PlayResult, PlayFailure>> play({
    required String sourceName,
    required String ids,
    required List<PlaybackFlag> flags,
    required List<ParserRule> parsers,
  }) async {
    final stopwatch = Stopwatch()..start();
    final failures = <PlayFailure>[];

    for (final flag in flags) {
      // 1. 调用 spider.playerContent
      final content = await spiderApi.playerContent(
        flag: flag.name,
        ids: ids,
      );

      final baseUrl = content.url;
      if (baseUrl.isEmpty) {
        failures.add(
          PlayFailure(
            sourceName: sourceName,
            flag: flag.name,
            code: ErrorCode.playerOpenFailed.value,
            message: '源返回空地址',
          ),
        );
        continue;
      }

      final headers = Map<String, String>.from(content.header);

      // 2. 直链：直接试播
      if (content.isDirect) {
        final candidate = PlayCandidate(
          url: baseUrl,
          flag: flag.name,
          headers: headers,
          isDirect: true,
        );
        final error = await executor.tryPlay(candidate);
        if (error == null) {
          return Ok(
            PlayResult(
              url: baseUrl,
              headers: headers,
              sourceName: sourceName,
              flag: flag.name,
              elapsed: stopwatch.elapsed,
            ),
          );
        }
        failures.add(
          PlayFailure(
            sourceName: sourceName,
            flag: flag.name,
            code: ErrorCode.playerOpenFailed.value,
            message: error,
          ),
        );
        continue;
      }

      // 3. 需解析：走解析器链
      final resolved = await _tryParsers(baseUrl, headers, parsers, flag.name);
      if (resolved != null) {
        final candidate = PlayCandidate(
          url: resolved.url,
          flag: flag.name,
          headers: headers,
          isDirect: true,
        );
        final error = await executor.tryPlay(candidate);
        if (error == null) {
          return Ok(
            PlayResult(
              url: resolved.url,
              headers: headers,
              sourceName: sourceName,
              flag: flag.name,
              parserName: resolved.parserName,
              elapsed: stopwatch.elapsed,
            ),
          );
        }
        failures.add(
          PlayFailure(
            sourceName: sourceName,
            flag: flag.name,
            parserName: resolved.parserName,
            code: ErrorCode.playerOpenFailed.value,
            message: error,
          ),
        );
        continue;
      }

      // 4. 解析器全部失败 → 尝试嗅探
      final sniffedUrl = await sniffer.sniff(baseUrl, headers);
      if (sniffedUrl != null) {
        final candidate = PlayCandidate(
          url: sniffedUrl,
          flag: flag.name,
          headers: headers,
          isDirect: true,
        );
        final error = await executor.tryPlay(candidate);
        if (error == null) {
          return Ok(
            PlayResult(
              url: sniffedUrl,
              headers: headers,
              sourceName: sourceName,
              flag: flag.name,
              parserName: 'sniffer',
              elapsed: stopwatch.elapsed,
            ),
          );
        }
        failures.add(
          PlayFailure(
            sourceName: sourceName,
            flag: flag.name,
            parserName: 'sniffer',
            code: ErrorCode.playerOpenFailed.value,
            message: error,
          ),
        );
      } else {
        failures.add(
          PlayFailure(
            sourceName: sourceName,
            flag: flag.name,
            code: ErrorCode.sniffNoMatch.value,
            message: '嗅探未命中媒体流',
          ),
        );
      }
    }

    // 全部失败：返回最后一个失败或通用错误
    return Err(
      failures.isNotEmpty
          ? failures.last
          : PlayFailure(
              sourceName: sourceName,
              flag: flags.isNotEmpty ? flags.first.name : '',
              code: ErrorCode.playerNoPlayableSource.value,
              message: '没有可用的播放线路',
            ),
    );
  }

  /// 尝试解析器链，返回第一个成功解析的直链。
  Future<_ResolvedPlay?> _tryParsers(
    String url,
    Map<String, String> headers,
    List<ParserRule> parsers,
    String flag,
  ) async {
    for (final parser in parsers) {
      if (parser.flags.isNotEmpty && !parser.flags.contains(flag)) {
        continue;
      }
      final resolvedUrl = await parserResolver.resolve(parser, url);
      if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
        return _ResolvedPlay(resolvedUrl, parser.name);
      }
    }
    return null;
  }
}
