import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('classifySiteRuntime 按 docs/05 §5.4 的映射', () {
    test('type=1 是 HTTP（JSON API）', () {
      expect(
        classifySiteRuntime(typeCode: 1, api: 'https://api.example.com/vod'),
        SiteRuntimeKind.http,
      );
    });

    test('type=4 也是 HTTP（JSON API 变体）', () {
      expect(
        classifySiteRuntime(typeCode: 4, api: 'https://api.example.com/vod'),
        SiteRuntimeKind.http,
      );
    });

    test('type=0 走 JS（内置通用脚本，api 是站点地址不是脚本）', () {
      expect(
        classifySiteRuntime(typeCode: 0, api: 'https://www.example.com/'),
        SiteRuntimeKind.js,
      );
    });

    test('type=3 且 api 是 csp_ 前缀 → JVM（蜘蛛 jar）', () {
      expect(
        classifySiteRuntime(typeCode: 3, api: 'csp_Fan'),
        SiteRuntimeKind.jvm,
      );
    });

    test('type=3 且 api 是 .js 脚本 → JS', () {
      expect(
        classifySiteRuntime(typeCode: 3, api: 'https://x/a.js'),
        SiteRuntimeKind.js,
      );
    });

    test('type=3 且 api 是相对脚本路径 → JS', () {
      expect(
        classifySiteRuntime(typeCode: 3, api: './js/360影视.js'),
        SiteRuntimeKind.js,
      );
    });

    test('未知 type 归为 unsupported', () {
      for (final code in <int>[2, 5, 99, -1]) {
        expect(
          classifySiteRuntime(typeCode: code, api: 'csp_X'),
          SiteRuntimeKind.unsupported,
          reason: 'type=$code',
        );
      }
    });

    test('type=3 看的是 api 前缀，不看大小写以外的东西', () {
      // `csp_` 必须是开头，`xcsp_Foo` 不算。
      expect(
        classifySiteRuntime(typeCode: 3, api: 'xcsp_Foo'),
        SiteRuntimeKind.js,
      );
      // 空 api 的 type=3 只能当脚本处理（后续加载会失败并给出明确错误）。
      expect(classifySiteRuntime(typeCode: 3, api: ''), SiteRuntimeKind.js);
    });
  });

  group('SiteRuntimeKind 落库值', () {
    test('wireName 与枚举一一对应', () {
      expect(SiteRuntimeKind.http.wireName, 'http');
      expect(SiteRuntimeKind.js.wireName, 'js');
      expect(SiteRuntimeKind.jvm.wireName, 'jvm');
      expect(SiteRuntimeKind.unsupported.wireName, 'unsupported');
    });

    test('fromWireName 能还原', () {
      for (final kind in SiteRuntimeKind.values) {
        expect(SiteRuntimeKind.fromWireName(kind.wireName), kind);
      }
    });

    test('fromWireName 对未知值与 null 返回 null，不静默回退', () {
      expect(SiteRuntimeKind.fromWireName(null), isNull);
      expect(SiteRuntimeKind.fromWireName(''), isNull);
      expect(SiteRuntimeKind.fromWireName('HTTP'), isNull);
      expect(SiteRuntimeKind.fromWireName('wasm'), isNull);
    });

    test('wireName 不随枚举名变化（改名的护栏）', () {
      // 枚举改名不该改变库里已有数据的含义——这条断言会在改名时失败，
      // 强制作者面对迁移。
      expect(
        SiteRuntimeKind.values.map((k) => k.wireName).toList(),
        <String>['http', 'js', 'jvm', 'unsupported'],
      );
    });
  });

  group('kCspApiPrefix', () {
    test('是 csp_（jar 类名前缀，也是 jvmClassName 的输入约定）', () {
      expect(kCspApiPrefix, 'csp_');
    });
  });
}
