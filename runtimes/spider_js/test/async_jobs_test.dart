import 'package:core_domain/core_domain.dart';
import 'package:spider_js/spider_js.dart';
import 'package:test/test.dart';

/// JS 微任务（Promise job）必须被泵，否则 async 入口的源静默拿到空值。
///
/// 背景：`JS_Eval` 只跑脚本的同步部分。Promise 回调是挂在 runtime 队列上的
/// *job*，C API 不会自己跑它——`qs_eval` 里没有 `JS_ExecutePendingJob` 时，
/// `p.then(cb)` 永远不调 cb，`async function f(){ return 1 }` 的返回值永远不
/// 落地，`JSON.stringify(f())` 得到 `"{}"`。
///
/// 这类缺陷的可怕之处在于**不报错**：源能加载、能调用、返回空对象，界面上
/// 表现成「这个源没数据」，从错误日志里什么都看不出来。所以下面每条都断言
/// 具体值，而不是只断言「没抛异常」。
///
/// 跳过的判据用 [supportsJobPump]：wrapper DLL 是本地构建、不入库的，一份
/// 没有 `qs_drain_jobs` 的旧产物会让这些用例红得莫名其妙，明确跳过更好。
final String? _skipNoPump = !isQuickJSAvailable
    ? 'QuickJS native 不可用，跳过'
    : !supportsJobPump
    ? 'wrapper DLL 缺 qs_drain_jobs，请重跑 native/build.sh'
    : null;

void main() {
  group('Promise 微任务', () {
    late JsRuntime rt;

    setUp(() {
      rt = JsRuntime();
      if (!rt.init()) {
        fail('JS 运行时初始化失败: ${rt.lastError}');
      }
    });

    tearDown(() => rt.dispose());

    test('async 函数的返回值能落地', () {
      expect(
        rt.eval(
          '(async function () { '
          'return JSON.stringify({ list: [{ vod_id: "1" }] }); '
          '})()',
        ),
        '{"list":[{"vod_id":"1"}]}',
      );
      expect(rt.lastFailure, isNull);
    });

    test('async 函数里 await 能拿到值', () {
      expect(
        rt.eval(
          '(async function () { '
          'var v = await Promise.resolve(1); '
          'return String(v + 1); '
          '})()',
        ),
        '2',
      );
    });

    test('多级 then 链会被全部泵完', () {
      expect(
        rt.eval(
          '(async function () { '
          'var v = await Promise.resolve(1) '
          '.then(function (x) { return x + 1; }) '
          '.then(function (x) { return x * 10; }); '
          'return String(v); '
          '})()',
        ),
        '20',
      );
    });

    test('.then 回调在同一次求值内被泵到，跨求值可见', () {
      // 第一次求值只注册回调；回调若不被泵，第二次求值读到的就是初值。
      expect(
        rt.eval(
          '(function () { '
          'globalThis.__seen = "not-run"; '
          'Promise.resolve(42).then(function () { globalThis.__seen = "ran"; }); '
          'return "ok"; '
          '})()',
        ),
        'ok',
      );
      expect(rt.eval('globalThis.__seen'), 'ran');
    });

    test('async 函数抛异常上抛成 SCRIPT_RUNTIME_ERROR', () {
      expect(
        rt.eval('(async function () { throw new Error("boom"); })()'),
        isNull,
      );
      expect(rt.lastFailure?.code, ErrorCode.scriptRuntimeError);
      expect(rt.lastFailure?.message, contains('boom'));
    });

    test('Promise 被 reject 时上抛成 SCRIPT_RUNTIME_ERROR', () {
      expect(
        rt.eval('(async function () { await Promise.reject("nope"); })()'),
        isNull,
      );
      expect(rt.lastFailure?.code, ErrorCode.scriptRuntimeError);
      expect(rt.lastFailure?.message, contains('nope'));
    });

    test('永远不落定的 Promise 如实报错，不静默返回空值', () {
      // 这类源会一直等一个不会到来的事件。把空值当成功交出去的话，表现是
      // 「源能打开但没数据」；这里要求明确报错。
      expect(rt.eval('new Promise(function () {})'), isNull);
      expect(rt.lastFailure?.code, ErrorCode.scriptRuntimeError);
      expect(rt.lastFailure?.message, contains('未落定'));
    });

    test('async 函数里调宿主风格的同步函数仍走 await 正常返回', () {
      expect(
        rt.eval(
          '(async function () { '
          'function req() { return JSON.stringify({ a: 1 }); } '
          'var raw = await req(); '
          'return String(JSON.parse(raw).a); '
          '})()',
        ),
        '1',
      );
    });

    test('同步返回值不受影响（回归）', () {
      expect(rt.eval('1 + 2'), '3');
      expect(rt.eval('"abc"'), 'abc');
      expect(rt.eval('undefined'), 'undefined');
      expect(rt.lastFailure, isNull);
    });

    test('泵过微任务后同一实例仍可继续求值', () {
      expect(rt.eval('(async function () { return "a"; })()'), 'a');
      expect(rt.eval('(async function () { return "b"; })()'), 'b');
      expect(rt.lastFailure, isNull);
    });

    test('多个实例各自独立泵自己的队列', () {
      final other = JsRuntime();
      if (!other.init()) {
        fail('JS 运行时初始化失败: ${other.lastError}');
      }
      addTearDown(other.dispose);

      expect(rt.eval('(async function () { return "one"; })()'), 'one');
      expect(other.eval('(async function () { return "two"; })()'), 'two');
    });
  }, skip: _skipNoPump);
}
