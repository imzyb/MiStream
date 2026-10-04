import 'package:spider_js/spider_js.dart';
import 'package:test/test.dart';

/// wrapper DLL 由 `runtimes/spider_js/native/build.bat` 本地构建，不入库
/// （见 .gitignore）。CI 上不存在，正向用例整体跳过。
///
/// 刻意用 [isQuickJSAvailable] 而不是「DLL 文件在不在」来判定：文件存在但加载
/// 失败时，跳过条件必须跟着一起失效，否则又回到「断言恒真」的老路。
final String? _skipUnavailable = isQuickJSAvailable
    ? null
    : 'QuickJS native 不可用，跳过正向用例';

void main() {
  group('QuickJS 绑定', () {
    test(
      'native 不可用时 isQuickJSAvailable 为 false',
      () {
        expect(isQuickJSAvailable, isFalse);
      },
      skip: isQuickJSAvailable ? 'native 在场，此用例不适用' : null,
    );
  });

  group('JsRuntime 降级路径', () {
    test('创建后未 init 即为 unavailable', () {
      final runtime = JsRuntime();
      expect(runtime.status, JsRuntimeStatus.unavailable);
      expect(runtime.isAvailable, isFalse);
    });

    test(
      'native 不可用时 init 返回 false 并给出原因',
      () {
        final runtime = JsRuntime();
        expect(runtime.init(), isFalse);
        expect(runtime.status, JsRuntimeStatus.unavailable);
        // 失败必须可诊断——不能只是「返回 false」。
        expect(runtime.lastError, isNotNull);
      },
      skip: isQuickJSAvailable ? 'native 在场，此降级用例不适用' : null,
    );

    test(
      'native 不可用时 eval 返回 null',
      () {
        final runtime = JsRuntime()..init();
        expect(runtime.eval('1+2'), isNull);
      },
      skip: isQuickJSAvailable ? 'native 在场，此降级用例不适用' : null,
    );

    test('dispose 可重复调用且不抛异常', () {
      final runtime = JsRuntime()
        ..dispose()
        ..dispose();
      expect(runtime.status, JsRuntimeStatus.unavailable);
    });
  });

  group('JsRuntime 正向执行', () {
    late JsRuntime runtime;

    setUp(() {
      runtime = JsRuntime();
    });

    tearDown(() {
      runtime.dispose();
    });

    test('init 成功后状态为 available 且无错误', () {
      expect(runtime.init(), isTrue, reason: runtime.lastError);
      expect(runtime.status, JsRuntimeStatus.available);
      expect(runtime.lastError, isNull);
    });

    // 这条是整组的核心：引擎曾经 init 返回 true、status 报 available，而
    // eval 恒返回 null（qs_init 从未被调用 + 空指针判断写成了 `== null`）。
    // 只断言降级路径的话，这种「假装可用」永远没人发现。
    test('求值算术表达式', () {
      runtime.init();
      expect(runtime.eval('1+2'), '3');
    });

    test('求值对象与数组，结果可 JSON 序列化', () {
      runtime.init();
      expect(
        runtime.eval('JSON.stringify({a:[1,2,3].map(x => x * 2)})'),
        '{"a":[2,4,6]}',
      );
    });

    test('闭包与函数定义跨语句可见', () {
      runtime
        ..init()
        ..eval('function twice(x) { return x * 2 }');
      expect(runtime.eval('twice(21)'), '42');
    });

    test('非 ASCII 源码按 UTF-8 字节长度传入，不被截断', () {
      runtime.init();
      // 按 UTF-16 码元数传 length 的话，中文会被截在半个字符上。
      expect(runtime.eval("'中文测试'.length"), '4');
      expect(runtime.eval("'中文' + '测试'"), '中文测试');
    });

    test('脚本抛异常时返回 null 并记录原因', () {
      runtime.init();
      expect(runtime.eval('throw new Error("boom")'), isNull);
      expect(runtime.lastError, isNotNull);
    });

    test('语法错误不会打崩进程，后续求值仍正常', () {
      runtime.init();
      expect(runtime.eval('function ('), isNull);
      expect(runtime.lastError, isNotNull);
      expect(runtime.eval('1+1'), '2');
    });

    // 这几条守的是「JSValue 永不以 object 形态跨 FFI 边界」的约定
    // （见 JsRuntime._wrap 与 native/quickjs_wrapper.c 标注的待修复问题）。约定一旦
    // 破掉，object 会被我们持有却无法释放，dispose 时 libquickjs 直接断言
    // `list_empty(&rt->gc_obj_list)` 打崩进程——tearDown 里的 dispose 就是
    // 这几条的真正断言点。
    test('对象结果不跨界，dispose 不崩', () {
      runtime.init();
      expect(runtime.eval('({a:1})'), '[object Object]');
    });

    test('数组结果不跨界，dispose 不崩', () {
      runtime.init();
      expect(runtime.eval('[1,2,3]'), '1,2,3');
    });

    test('函数对象结果不跨界，dispose 不崩', () {
      runtime.init();
      expect(runtime.eval('(function f(){})'), isNotNull);
    });

    test('异常对象不跨界，dispose 不崩', () {
      runtime.init();
      expect(runtime.eval('new Error("held")'), 'Error: held');
    });

    test('undefined 结果有别于失败', () {
      runtime.init();
      expect(runtime.eval('undefined'), 'undefined');
      expect(runtime.lastError, isNull);
    });

    test('多实例互不干扰', () {
      runtime.init();
      final other = JsRuntime()..init();
      addTearDown(other.dispose);

      runtime.eval('var marker = "A"');
      other.eval('var marker = "B"');

      expect(runtime.eval('marker'), 'A');
      expect(other.eval('marker'), 'B');
    });
  }, skip: _skipUnavailable);
}
