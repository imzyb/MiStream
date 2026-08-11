/// UseCase 与基础设施的适配器。
library;

import 'dart:convert';

import 'package:play_engine/play_engine.dart';
import 'package:spider_host/spider_host.dart';

/// 基于 [HttpRuntime] 的 [SpiderPlayerApi] 实现。
class HttpSpiderPlayerApi implements SpiderPlayerApi {
  /// 构造适配器。
  HttpSpiderPlayerApi(this.runtime);

  /// 底层 HTTP 运行时。
  final HttpRuntime runtime;

  @override
  Future<PlayerContentResult> playerContent({
    required String flag,
    required String ids,
    List<String> vipFlags = const [],
  }) async {
    final result = await runtime.play(flag: flag, ids: ids);
    return result.fold(
      (ok) {
        try {
          final json = jsonDecode(ok.body) as Map<String, Object?>;
          return PlayerContentResult(
            parse: (json['parse'] as num?)?.toInt() ?? 0,
            url: (json['url'] as String?) ?? '',
            jx: (json['jx'] as num?)?.toInt() ?? 0,
            header:
                (json['header'] as Map?)?.map(
                  (k, v) => MapEntry(k.toString(), v.toString()),
                ) ??
                {},
          );
        } on Object {
          return const PlayerContentResult();
        }
      },
      (_) => const PlayerContentResult(),
    );
  }
}
