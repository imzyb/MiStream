import 'dart:io';

import 'package:spider_host/spider_host.dart';
import 'package:test/test.dart';

/// 造一个工厂。`jvm` 传 null 即「未安装 JVM 运行时」（ADR-006 的默认形态）。
SpiderRuntimeFactory _factory({SpiderJvmConfig? jvm}) => SpiderRuntimeFactory(
  spiderJsPath: 'unused-in-these-tests',
  hostApi: HostApi(),
  jvm: jvm,
);

SpiderJvmConfig _jvmConfig() => SpiderJvmConfig(
  javaPath: 'java',
  runtimeJarPath: 'runtime.jar',
  libsDirPath: 'libs',
  jarCacheDir: Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'runtime_capability_test',
  ),
);

void main() {
  group('supports：按站点判定运行时可用性', () {
    test('type=1 / type=4 走 HTTP，永远可用（不需要运行时工厂）', () {
      final factory = _factory();
      addTearDown(factory.dispose);

      expect(factory.supports(typeCode: 1, api: 'https://api.x/vod'), isTrue);
      expect(factory.supports(typeCode: 4, api: 'https://api.x/vod'), isTrue);
    });

    test('type=0 走 JS 内置脚本，可用', () {
      final factory = _factory();
      addTearDown(factory.dispose);

      expect(factory.supports(typeCode: 0, api: 'https://www.x.com/'), isTrue);
    });

    test('type=3 的脚本源走 JS，可用', () {
      final factory = _factory();
      addTearDown(factory.dispose);

      expect(
        factory.supports(typeCode: 3, api: 'https://x/a.js'),
        isTrue,
      );
    });

    test('type=3 的 csp_ 源在没装 JVM 时不可用——真实配置的主力形态', () {
      final factory = _factory();
      addTearDown(factory.dispose);

      expect(factory.supports(typeCode: 3, api: 'csp_Fan'), isFalse);
    });

    test('装了 JVM 后 csp_ 源变为可用', () {
      final factory = _factory(jvm: _jvmConfig());
      addTearDown(factory.dispose);

      expect(factory.supports(typeCode: 3, api: 'csp_Fan'), isTrue);
      // 同一个工厂里脚本源照样可用。
      expect(factory.supports(typeCode: 3, api: 'https://x/a.js'), isTrue);
    });

    test('未知 type 不可用', () {
      final factory = _factory(jvm: _jvmConfig());
      addTearDown(factory.dispose);

      expect(factory.supports(typeCode: 99, api: 'csp_X'), isFalse);
      expect(factory.supports(typeCode: 2, api: 'csp_X'), isFalse);
    });

    test('supports 是同步纯判定：不会起子进程、不下载脚本', () {
      final factory = _factory();
      addTearDown(factory.dispose);

      // 直接调用即可返回；若它内部真去 create，这里会因为
      // spiderJsPath 无效而抛错或挂住。
      expect(factory.supports(typeCode: 3, api: './js/x.js'), isTrue);
    });
  });

  group('create 与 supports 用同一把尺子', () {
    test('type=1 直接给出 HTTP 运行时（零脚本、无子进程）', () async {
      final factory = _factory();
      addTearDown(factory.dispose);

      final runtime = await factory.create(
        typeCode: 1,
        api: 'https://api.x/vod',
      );

      expect(runtime, isA<HttpRuntimeAdapter>());
      await runtime.dispose();
    });

    test('type=4 也走 HTTP——以前这里会抛「不支持的站点类型」', () async {
      final factory = _factory();
      addTearDown(factory.dispose);

      final runtime = await factory.create(
        typeCode: 4,
        api: 'https://api.x/vod',
      );

      expect(runtime, isA<HttpRuntimeAdapter>());
      await runtime.dispose();
    });

    test('未知 type 抛 ArgumentError（与 supports 返回 false 一致）', () async {
      final factory = _factory();
      addTearDown(factory.dispose);

      await expectLater(
        factory.create(typeCode: 99, api: 'csp_X'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('csp_ 源在没装 JVM 时明确报「未配置」，而不是静默走错分支', () async {
      final factory = _factory();
      addTearDown(factory.dispose);

      await expectLater(
        factory.create(typeCode: 3, api: 'csp_Fan'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('JVM 运行时未配置'),
          ),
        ),
      );
    });
  });
}
