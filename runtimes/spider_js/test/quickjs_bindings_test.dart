import 'package:spider_js/src/engine/js_runtime.dart';
import 'package:spider_js/src/engine/quickjs_bindings.dart';
import 'package:test/test.dart';

void main() {
  group('QuickJS 绑定', () {
    test('native 库不可用时优雅降级', () {
      // 当前环境没有 QuickJS 库，应返回 false
      expect(isQuickJSAvailable, isFalse);
    });

    test('loadQuickJS 返回 null', () {
      expect(loadQuickJS(), isNull);
    });
  });

  group('JsRuntime', () {
    test('创建后状态为 unavailable', () {
      final runtime = JsRuntime();
      expect(runtime.status, JsRuntimeStatus.unavailable);
      expect(runtime.isAvailable, isFalse);
    });

    test('init 返回 false（native 库不可用）', () {
      final runtime = JsRuntime();
      final result = runtime.init();
      expect(result, isFalse);
      expect(runtime.status, JsRuntimeStatus.unavailable);
    });

    test('eval 返回 null（native 库不可用）', () {
      final runtime = JsRuntime();
      runtime.init();
      expect(runtime.eval('1+2'), isNull);
    });

    test('dispose 不会崩溃', () {
      final runtime = JsRuntime();
      runtime.dispose();
      // 双重 dispose 也不会崩溃
      runtime.dispose();
    });
  });
}
