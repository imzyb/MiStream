import 'package:player_engine/player_engine.dart';
import 'package:test/test.dart';

void main() {
  group('HwdecChain 平台默认链', () {
    test('Windows 按 docs/04 §5 的顺序', () {
      final chain = HwdecChain.forPlatform(HwdecPlatform.windows);

      expect(chain.methods, [
        HwdecMethod.d3d11vaCopy,
        HwdecMethod.d3d11va,
        HwdecMethod.dxva2Copy,
        HwdecMethod.none,
      ]);
    });

    test('macOS 按 docs/04 §5 的顺序', () {
      final chain = HwdecChain.forPlatform(HwdecPlatform.macos);

      expect(chain.methods, [
        HwdecMethod.videotoolboxCopy,
        HwdecMethod.videotoolbox,
        HwdecMethod.none,
      ]);
    });

    test('Linux 按 docs/04 §5 的顺序', () {
      final chain = HwdecChain.forPlatform(HwdecPlatform.linux);

      expect(chain.methods, [
        HwdecMethod.nvdecCopy,
        HwdecMethod.vaapiCopy,
        HwdecMethod.vaapi,
        HwdecMethod.none,
      ]);
    });

    test('未知平台只剩软解', () {
      final chain = HwdecChain.forPlatform(HwdecPlatform.other);

      expect(chain.methods, [HwdecMethod.none]);
      expect(chain.isSoftwareOnly, isTrue);
    });

    test('每条链的末位恒为软解', () {
      for (final platform in HwdecPlatform.values) {
        final chain = HwdecChain.forPlatform(platform);
        expect(
          chain.methods.last,
          HwdecMethod.none,
          reason: '$platform 的链没有软解兜底',
        );
      }
    });

    test('手工构造时自动补上软解兜底', () {
      final chain = HwdecChain(const [HwdecMethod.vaapi]);

      expect(chain.methods, [HwdecMethod.vaapi, HwdecMethod.none]);
    });

    test('软解在中间时被挪到末位，不会重复', () {
      final chain = HwdecChain(const [
        HwdecMethod.d3d11va,
        HwdecMethod.none,
        HwdecMethod.dxva2Copy,
      ]);

      expect(chain.methods, [
        HwdecMethod.d3d11va,
        HwdecMethod.dxva2Copy,
        HwdecMethod.none,
      ]);
    });

    test('softwareOnly 只有一档', () {
      expect(HwdecChain.softwareOnly().methods, [HwdecMethod.none]);
    });
  });

  group('HwdecChain.next', () {
    final chain = HwdecChain.forPlatform(HwdecPlatform.windows);

    test('逐档降级', () {
      expect(chain.next(HwdecMethod.d3d11vaCopy), HwdecMethod.d3d11va);
      expect(chain.next(HwdecMethod.d3d11va), HwdecMethod.dxva2Copy);
      expect(chain.next(HwdecMethod.dxva2Copy), HwdecMethod.none);
    });

    test('已在末位则无路可走', () {
      expect(chain.next(HwdecMethod.none), isNull);
    });

    test('不在链上的档位直接落到软解', () {
      // 用户在设置里强制指定了某个硬解方式（§5 规则 3），它失败之后没有
      // 「链上的下一档」可谈。
      expect(chain.next(HwdecMethod.vaapi), HwdecMethod.none);
    });
  });

  group('HwdecMethod', () {
    test('mpv 取值可反查', () {
      expect(
        HwdecMethod.fromMpvValue('d3d11va-copy'),
        HwdecMethod.d3d11vaCopy,
      );
      expect(HwdecMethod.fromMpvValue('no'), HwdecMethod.none);
    });

    test('认不出的取值返回 null 而不是抛异常', () {
      expect(HwdecMethod.fromMpvValue('vulkan-copy'), isNull);
    });

    test('只有 none 是软解', () {
      final software = HwdecMethod.values.where((m) => m.isSoftware);
      expect(software, [HwdecMethod.none]);
    });

    test('mpv 取值互不重复', () {
      final values = HwdecMethod.values.map((m) => m.mpvValue).toSet();
      expect(values, hasLength(HwdecMethod.values.length));
    });
  });

  group('HwdecFallbackDetector', () {
    test('窗口内达到阈值才判定降级', () {
      final detector = HwdecFallbackDetector();

      expect(detector.recordDecodeError(const Duration(seconds: 1)), isFalse);
      expect(detector.recordDecodeError(const Duration(seconds: 1)), isFalse);
      expect(detector.recordDecodeError(const Duration(seconds: 2)), isTrue);
      expect(detector.hasTripped, isTrue);
    });

    test('只在越过阈值的那一次返回 true', () {
      final detector = HwdecFallbackDetector();
      for (var i = 0; i < 3; i++) {
        detector.recordDecodeError(const Duration(seconds: 1));
      }

      // 一段花屏会连报十几次错，不该刷出十几条「已降级」提示。
      expect(detector.recordDecodeError(const Duration(seconds: 2)), isFalse);
      expect(detector.errorCount, 3);
    });

    test('窗口之外的错误不计入', () {
      final detector = HwdecFallbackDetector();

      expect(detector.recordDecodeError(const Duration(seconds: 5)), isFalse);
      expect(detector.recordDecodeError(const Duration(seconds: 9)), isFalse);
      expect(detector.errorCount, 0);
      expect(detector.hasTripped, isFalse);
    });

    test('阈值可调', () {
      final detector = HwdecFallbackDetector(
        policy: const HwdecFallbackPolicy(errorThreshold: 1),
      );

      expect(detector.recordDecodeError(Duration.zero), isTrue);
    });

    test('reset 之后重新计数', () {
      final detector = HwdecFallbackDetector();
      for (var i = 0; i < 3; i++) {
        detector.recordDecodeError(const Duration(seconds: 1));
      }
      expect(detector.hasTripped, isTrue);

      detector.reset();
      expect(detector.hasTripped, isFalse);
      expect(detector.errorCount, 0);
      expect(detector.recordDecodeError(const Duration(seconds: 1)), isFalse);
    });

    test('阈值必须为正', () {
      // 用变量而不是字面量：写成 const 表达式会让断言在编译期就失败，
      // 那样测不到运行期的行为。
      var threshold = 1;
      threshold = 0;

      expect(
        () => HwdecFallbackPolicy(errorThreshold: threshold),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
