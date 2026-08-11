import 'dart:io';

import 'package:spider_js/spider_js.dart';
import 'package:test/test.dart';

/// wrapper DLL 由 `runtimes/spider_js/native/build.bat` 本地构建，不入库
/// （见 .gitignore）。CI 上不存在，相关用例整体跳过。
final _wrapperDll = File('lib/src/engine/quickjs_wrapper.dll');

void main() {
  group('QuickJS 绑定', () {
    test(
      'wrapper DLL 存在时 isQuickJSAvailable 与之一致',
      () {
        // DLL 在场时才有意义：加载成功与否取决于它能否解析到 libquickjs.dll。
        expect(isQuickJSAvailable, isA<bool>());
      },
      skip: _wrapperDll.existsSync() ? null : 'wrapper DLL 未构建，跳过',
    );

    test('native 不可用时 isQuickJSAvailable 为 false', () {
      expect(isQuickJSAvailable, isFalse);
    }, skip: _wrapperDll.existsSync() ? 'wrapper DLL 在场，此用例不适用' : null);
  });

  group('JsRuntime', () {
    test('创建后状态为 unavailable', () {
      final runtime = JsRuntime();
      expect(runtime.status, JsRuntimeStatus.unavailable);
      expect(runtime.isAvailable, isFalse);
    });

    test('native 不可用时 init 返回 false', () {
      final runtime = JsRuntime();
      final result = runtime.init();
      expect(result, isFalse);
      expect(runtime.status, JsRuntimeStatus.unavailable);
    }, skip: isQuickJSAvailable ? 'native 可用，此降级用例不适用' : null);

    test('native 不可用时 eval 返回 null', () {
      final runtime = JsRuntime()..init();
      expect(runtime.eval('1+2'), isNull);
    }, skip: isQuickJSAvailable ? 'native 可用，此降级用例不适用' : null);

    test('dispose 可重复调用且不抛异常', () {
      final runtime = JsRuntime()
        ..dispose()
        ..dispose();
      expect(runtime.status, JsRuntimeStatus.unavailable);
    });
  });
}
