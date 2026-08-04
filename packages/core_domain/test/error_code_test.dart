import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('ErrorBand.of', () {
    test('按区段边界归类', () {
      expect(ErrorBand.of(-32700), ErrorBand.jsonRpc);
      expect(ErrorBand.of(-32600), ErrorBand.jsonRpc);
      expect(ErrorBand.of(-32000), ErrorBand.runtime);
      expect(ErrorBand.of(-32099), ErrorBand.runtime);
      expect(ErrorBand.of(-32100), ErrorBand.spider);
      expect(ErrorBand.of(-32199), ErrorBand.spider);
      expect(ErrorBand.of(-32200), ErrorBand.permissionNetwork);
      expect(ErrorBand.of(-32299), ErrorBand.permissionNetwork);
      expect(ErrorBand.of(-32300), ErrorBand.sniffer);
      expect(ErrorBand.of(-32399), ErrorBand.sniffer);
      expect(ErrorBand.of(1000), ErrorBand.config);
      expect(ErrorBand.of(1100), ErrorBand.storage);
      expect(ErrorBand.of(1200), ErrorBand.player);
      expect(ErrorBand.of(1300), ErrorBand.plugin);
      expect(ErrorBand.of(1400), ErrorBand.update);
      expect(ErrorBand.of(1900), ErrorBand.general);
    });

    test('区段之间的空隙归为 unknown', () {
      expect(ErrorBand.of(-32400), ErrorBand.unknown);
      expect(ErrorBand.of(0), ErrorBand.unknown);
      expect(ErrorBand.of(500), ErrorBand.unknown);
      expect(ErrorBand.of(1500), ErrorBand.unknown);
      expect(ErrorBand.of(9999), ErrorBand.unknown);
    });
  });

  group('ErrorCode', () {
    test('全部已知码取值唯一', () {
      final seen = <int, String>{};
      for (final code in ErrorCode.known) {
        expect(
          seen.containsKey(code.value),
          isFalse,
          reason: '${code.name} 与 ${seen[code.value]} 撞码 ${code.value}',
        );
        seen[code.value] = code.name;
      }
      expect(seen, hasLength(ErrorCode.known.length));
    });

    test('全部已知码常量名唯一', () {
      final names = ErrorCode.known.map((code) => code.name).toSet();
      expect(names, hasLength(ErrorCode.known.length));
    });

    test('没有一个已知码落进 unknown 区段', () {
      final strays = ErrorCode.known.where(
        (code) => code.band == ErrorBand.unknown,
      );
      expect(strays, isEmpty, reason: '越界的码：${strays.map((c) => c.name)}');
    });

    test('符号区分来源：负数来自 RPC，正数是本地', () {
      expect(ErrorCode.runtimeBusy.isRemote, isTrue);
      expect(ErrorCode.runtimeBusy.isLocal, isFalse);
      expect(ErrorCode.dbOpenFailed.isLocal, isTrue);
      expect(ErrorCode.dbOpenFailed.isRemote, isFalse);

      for (final code in ErrorCode.known) {
        expect(
          code.isRemote ^ code.isLocal,
          isTrue,
          reason: '${code.name} 既不是远端也不是本地',
        );
      }
    });

    test('lookup 命中已知码，未命中返回 null', () {
      expect(ErrorCode.lookup(-32001), ErrorCode.runtimeBusy);
      expect(ErrorCode.lookup(-32999), isNull);
    });

    test('resolve 对未知码合成占位码，保留原值且不可重试', () {
      final code = ErrorCode.resolve(-32150);

      expect(code.value, -32150);
      expect(code.name, 'UNKNOWN_SPIDER');
      expect(code.band, ErrorBand.spider);
      expect(code.retryable, isFalse);
    });

    test('相等性只看数值', () {
      expect(const ErrorCode(-32001, '别名'), ErrorCode.runtimeBusy);
      expect(
        const ErrorCode(-32001, '别名').hashCode,
        ErrorCode.runtimeBusy.hashCode,
      );
    });

    test('toString 同时给出名字与数值', () {
      expect(ErrorCode.runtimeBusy.toString(), 'RUNTIME_BUSY(-32001)');
    });

    test('文档承诺可重试的码确实标了 retryable', () {
      // docs/08 §7 的「建议动作」列写明要退避重试的几个。
      expect(ErrorCode.runtimeBusy.retryable, isTrue);
      expect(ErrorCode.runtimeCrashed.retryable, isTrue);
      expect(ErrorCode.rateLimited.retryable, isTrue);
      expect(ErrorCode.networkTimeout.retryable, isTrue);

      // 反过来，这几个重试没有意义。
      expect(ErrorCode.messageTooLarge.retryable, isFalse);
      expect(ErrorCode.hostNotAllowed.retryable, isFalse);
      expect(ErrorCode.protocolVersionMismatch.retryable, isFalse);
      expect(ErrorCode.networkTlsError.retryable, isFalse);
    });
  });
}
