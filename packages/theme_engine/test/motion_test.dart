import 'package:test/test.dart';
import 'package:theme_engine/theme_engine.dart';

void main() {
  group('DesignMotion 默认值', () {
    test('逐条等于规范 §2.4 的表格', () {
      const m = DesignMotion.standard;

      expect(m.hover.duration, const Duration(milliseconds: 120));
      expect(m.hover.curve, MotionCurve.easeOut);

      expect(m.pageTransition.duration, const Duration(milliseconds: 240));
      expect(m.pageTransition.curve, MotionCurve.easeInOutCubic);

      expect(m.overlay.duration, const Duration(milliseconds: 200));
      expect(m.overlay.curve, MotionCurve.easeOutCubic);

      expect(m.playerControls.duration, const Duration(milliseconds: 180));
      expect(m.playerControls.curve, MotionCurve.easeInOut);
    });

    test('默认不开「减少动效」', () {
      expect(DesignMotion.standard.reduceMotion, isFalse);
    });

    test('默认值本身通过校验', () {
      expect(validateMotion(DesignMotion.standard), isEmpty);
    });

    test('场景键名与主题包 JSON 的写法一致', () {
      expect(DesignMotion.standard.scenes.keys, [
        'motion.hover',
        'motion.pageTransition',
        'motion.overlay',
        'motion.playerControls',
      ]);
    });
  });

  group('减少动效', () {
    test('关闭时原样返回', () {
      const m = DesignMotion.standard;
      expect(m.effectiveHover, m.hover);
      expect(m.effectivePlayerControls, m.playerControls);
    });

    test('开启后四个场景时长全部归零', () {
      final m = DesignMotion.standard.copyWith(reduceMotion: true);

      for (final entry in m.scenes.entries) {
        expect(
          m.resolve(entry.value).duration,
          Duration.zero,
          reason: '${entry.key} 没有归零',
        );
      }
      expect(m.effectiveHover.duration, Duration.zero);
      expect(m.effectivePageTransition.duration, Duration.zero);
      expect(m.effectiveOverlay.duration, Duration.zero);
      expect(m.effectivePlayerControls.duration, Duration.zero);
    });

    test('归零后曲线保留', () {
      // 0ms 下曲线没有实际作用，保留是为了让调用方少写一个分支。
      final m = DesignMotion.standard.copyWith(reduceMotion: true);
      expect(m.effectiveHover.curve, MotionCurve.easeOut);
      expect(m.effectiveOverlay.curve, MotionCurve.easeOutCubic);
    });

    test('reduceMotion 会影响 validateMotion 的 0ms 判断', () {
      const zero = DesignMotion(
        hover: MotionSpec(duration: Duration.zero, curve: MotionCurve.easeOut),
      );
      // 没开减少动效却是 0ms → 多半是漏填
      expect(validateMotion(zero), isNotEmpty);
      // 开了减少动效 → 0ms 是正常状态
      expect(validateMotion(zero.copyWith(reduceMotion: true)), isEmpty);
    });
  });

  group('MotionCurve', () {
    test('四个枚举名就是主题包里的写法', () {
      expect(MotionCurve.values.map((c) => c.name).toList(), [
        'easeOut',
        'easeInOutCubic',
        'easeOutCubic',
        'easeInOut',
      ]);
    });

    test('fromName 认得全部四个', () {
      for (final curve in MotionCurve.values) {
        expect(MotionCurve.fromName(curve.name), curve);
      }
    });

    test('fromName 容忍首尾空白', () {
      expect(MotionCurve.fromName('  easeOutCubic '), MotionCurve.easeOutCubic);
    });

    test('fromName 不认识时返回 null 而不是默认值', () {
      // 返回默认值会让作者以为自己写的曲线生效了。
      expect(MotionCurve.fromName('easeInOutSine'), isNull);
      expect(MotionCurve.fromName('EASEOUT'), isNull);
      expect(MotionCurve.fromName(''), isNull);
    });
  });

  group('MotionSpec', () {
    test('milliseconds 与 duration 一致', () {
      const spec = MotionSpec(
        duration: Duration(milliseconds: 120),
        curve: MotionCurve.easeOut,
      );
      expect(spec.milliseconds, 120);
    });

    test('亚毫秒精度不丢', () {
      const spec = MotionSpec(
        duration: Duration(microseconds: 1500),
        curve: MotionCurve.easeOut,
      );
      expect(spec.milliseconds, 1.5);
    });

    test('相等性按值与曲线', () {
      const a = MotionSpec(
        duration: Duration(milliseconds: 120),
        curve: MotionCurve.easeOut,
      );
      const b = MotionSpec(
        duration: Duration(milliseconds: 120),
        curve: MotionCurve.easeOut,
      );
      const c = MotionSpec(
        duration: Duration(milliseconds: 120),
        curve: MotionCurve.easeInOut,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('validateMotion', () {
    test('负时长要报出来', () {
      const m = DesignMotion(
        overlay: MotionSpec(
          duration: Duration(milliseconds: -50),
          curve: MotionCurve.easeOutCubic,
        ),
      );
      expect(validateMotion(m).join(), contains('motion.overlay'));
      expect(validateMotion(m).join(), contains('不能为负'));
    });

    test('超过一秒要报出来', () {
      final m = DesignMotion.standard.copyWith(
        hover: const MotionSpec(
          duration: Duration(milliseconds: 1500),
          curve: MotionCurve.easeOut,
        ),
      );
      expect(validateMotion(m).join(), contains('超过 1000ms'));
    });

    test('刚好在上限上不算超', () {
      final m = DesignMotion.standard.copyWith(
        hover: const MotionSpec(
          duration: Duration(milliseconds: 1000),
          curve: MotionCurve.easeOut,
        ),
      );
      expect(validateMotion(m), isEmpty);
    });

    test('问题里带的是场景名而不是字段名', () {
      // 作者看到的是 `motion.hover`，不是 `hover`。
      const m = DesignMotion(
        hover: MotionSpec(
          duration: Duration(milliseconds: -1),
          curve: MotionCurve.easeOut,
        ),
      );
      final text = validateMotion(m).join();
      expect(text, contains('motion.hover'));
      expect(text, isNot(contains(' hover ')));
    });
  });

  group('toMap 与主题包往返', () {
    test('键名覆盖四个场景的时长与曲线', () {
      final map = DesignMotion.standard.toMap();
      expect(
        map.keys,
        containsAll(<String>[
          'motion.hover',
          'motion.hover.curve',
          'motion.pageTransition',
          'motion.pageTransition.curve',
          'motion.overlay',
          'motion.overlay.curve',
          'motion.playerControls',
          'motion.playerControls.curve',
        ]),
      );
      expect(map['motion.hover'], 120);
      expect(map['motion.hover.curve'], 'easeOut');
    });

    test('toMap 的每个键都被主题包解析器认得', () {
      // 这条是防漂移的核心：`toMap` 少写一个键、解析器少认一个键，任何一边
      // 改错了，这里就会红。否则「主题包能覆盖动效」会在某次改名后静默失效。
      final warnings = <String>[];
      final pkg = ThemePackage.fromJson({
        'id': 'com.example.roundtrip',
        'type': 'theme',
        'theme': {
          'brightness': 'dark',
          'tokens': DesignMotion.standard.toMap(),
        },
      }, onWarn: warnings.add);

      expect(warnings, isEmpty, reason: warnings.join('\n'));
      expect(pkg.motionDurations, hasLength(4));
      expect(pkg.motionCurves, hasLength(4));
    });

    test('原样叠回基准主题后与默认值相等', () {
      final pkg = ThemePackage.fromJson({
        'id': 'com.example.roundtrip',
        'theme': {
          'brightness': 'dark',
          'tokens': DesignMotion.standard.toMap(),
        },
      });

      final merged = pkg.applyTo(AppTheme.dark);

      expect(merged.motion.hover, DesignMotion.standard.hover);
      expect(
        merged.motion.pageTransition,
        DesignMotion.standard.pageTransition,
      );
      expect(merged.motion.overlay, DesignMotion.standard.overlay);
      expect(
        merged.motion.playerControls,
        DesignMotion.standard.playerControls,
      );
    });
  });
}
