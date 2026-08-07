import 'package:core_domain/core_domain.dart';
import 'package:play_engine/src/models.dart';
import 'package:play_engine/src/play_coordinator.dart';
import 'package:test/test.dart';

class _MockSpiderApi implements SpiderPlayerApi {
  final Map<String, PlayerContentResult> _results = {};
  int calls = 0;

  void setResult(String flag, PlayerContentResult result) {
    _results[flag] = result;
  }

  @override
  Future<PlayerContentResult> playerContent({
    required String flag,
    required String ids,
    List<String> vipFlags = const [],
  }) async {
    calls++;
    return _results[flag] ?? const PlayerContentResult(url: '');
  }
}

class _MockParser implements ParserResolver {
  final Map<String, String?> _results = {};
  int calls = 0;

  void setResult(String name, String? url) => _results[name] = url;

  @override
  Future<String?> resolve(ParserRule rule, String url) async {
    calls++;
    return _results[rule.name];
  }
}

class _MockSniffer implements SnifferLauncher {
  String? result;
  int calls = 0;

  @override
  Future<String?> sniff(String url, Map<String, String> headers) async {
    calls++;
    return result;
  }
}

class _MockExecutor implements PlayExecutor {
  String? failReason;
  String? lastUrl;
  int calls = 0;

  @override
  Future<String?> tryPlay(PlayCandidate candidate) async {
    calls++;
    lastUrl = candidate.url;
    return failReason;
  }
}

void main() {
  const flags = [
    PlaybackFlag(name: 'qiyi', priority: 2),
    PlaybackFlag(name: 'youku', priority: 1),
  ];
  const parsers = [
    ParserRule(name: '官解', type: 1, flags: ['qiyi']),
  ];

  group('PlayCoordinator', () {
    test('直链直接播放成功', () async {
      final api = _MockSpiderApi();
      api.setResult(
        'qiyi',
        const PlayerContentResult(parse: 0, url: 'https://direct.m3u8'),
      );
      final executor = _MockExecutor();

      final coordinator = PlayCoordinator(
        spiderApi: api,
        parserResolver: _MockParser(),
        sniffer: _MockSniffer(),
        executor: executor,
      );

      final result = await coordinator.play(
        sourceName: '源A',
        ids: '1',
        flags: flags,
        parsers: parsers,
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.url, 'https://direct.m3u8');
      expect(executor.lastUrl, 'https://direct.m3u8');
    });

    test('直链失败后换下一个 flag', () async {
      final api = _MockSpiderApi();
      api.setResult(
        'qiyi',
        const PlayerContentResult(parse: 0, url: 'https://bad1.m3u8'),
      );
      api.setResult(
        'youku',
        const PlayerContentResult(parse: 0, url: 'https://good2.m3u8'),
      );
      final executor = _MockExecutor()..failReason = '403';

      final coordinator = PlayCoordinator(
        spiderApi: api,
        parserResolver: _MockParser(),
        sniffer: _MockSniffer(),
        executor: executor,
      );

      // 全失败
      final result = await coordinator.play(
        sourceName: '源A',
        ids: '1',
        flags: flags,
        parsers: parsers,
      );
      expect(result.isErr, isTrue);
      expect(api.calls, 2);
    });

    test('需解析走解析器链成功', () async {
      final api = _MockSpiderApi();
      api.setResult(
        'qiyi',
        const PlayerContentResult(parse: 1, url: 'https://page.html'),
      );
      final parser = _MockParser()..setResult('官解', 'https://resolved.m3u8');
      final executor = _MockExecutor();

      final coordinator = PlayCoordinator(
        spiderApi: api,
        parserResolver: parser,
        sniffer: _MockSniffer(),
        executor: executor,
      );

      final result = await coordinator.play(
        sourceName: '源A',
        ids: '1',
        flags: flags,
        parsers: parsers,
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.url, 'https://resolved.m3u8');
      expect(result.valueOrNull!.parserName, '官解');
    });

    test('解析器失败后嗅探', () async {
      final api = _MockSpiderApi();
      api.setResult(
        'qiyi',
        const PlayerContentResult(parse: 1, url: 'https://page.html'),
      );
      final parser = _MockParser(); // 不返回结果
      final sniffer = _MockSniffer()..result = 'https://sniffed.m3u8';
      final executor = _MockExecutor();

      final coordinator = PlayCoordinator(
        spiderApi: api,
        parserResolver: parser,
        sniffer: sniffer,
        executor: executor,
      );

      final result = await coordinator.play(
        sourceName: '源A',
        ids: '1',
        flags: flags,
        parsers: parsers,
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.url, 'https://sniffed.m3u8');
      expect(result.valueOrNull!.parserName, 'sniffer');
      expect(sniffer.calls, 1);
    });

    test('全部失败返回结构化错误', () async {
      final api = _MockSpiderApi();
      api.setResult('qiyi', const PlayerContentResult(parse: 0, url: ''));
      api.setResult('youku', const PlayerContentResult(parse: 0, url: ''));
      final coordinator = PlayCoordinator(
        spiderApi: api,
        parserResolver: _MockParser(),
        sniffer: _MockSniffer(),
        executor: _MockExecutor(),
      );

      final result = await coordinator.play(
        sourceName: '源A',
        ids: '1',
        flags: flags,
        parsers: parsers,
      );
      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.message, '源返回空地址');
      expect(result.errorOrNull!.code, ErrorCode.playerOpenFailed.value);
    });

    test('解析器按 flag 过滤', () async {
      final api = _MockSpiderApi();
      api.setResult(
        'youku',
        const PlayerContentResult(parse: 1, url: 'https://page.html'),
      );
      // 官解只适用于 qiyi，不适用于 youku
      final parser = _MockParser()..setResult('官解', 'https://resolved.m3u8');
      final sniffer = _MockSniffer()..result = null;
      final executor = _MockExecutor();

      final coordinator = PlayCoordinator(
        spiderApi: api,
        parserResolver: parser,
        sniffer: sniffer,
        executor: executor,
      );

      final result = await coordinator.play(
        sourceName: '源A',
        ids: '1',
        flags: [flags[1]], // 只用 youku
        parsers: parsers,
      );
      // 解析器被过滤，走嗅探但嗅探失败
      expect(result.isErr, isTrue);
      expect(parser.calls, 0);
    });
  });
}
