import 'package:core_domain/core_domain.dart';
import 'package:spider_js/spider_js.dart';
import 'package:test/test.dart';

/// ROADMAP M4 出口标准里的三条资源约束：
///
/// - 脚本死循环被 interrupt 正确中断，**不影响同进程其它源**
/// - 脚本 OOM 被限制在 Context 级别，**进程存活**
/// - 脚本异常返回带堆栈的 `SCRIPT_RUNTIME_ERROR`
///
/// 这一组的真正断言点有两个：一是错误码分类对不对，二是**测试进程还活着**
/// ——失控脚本没被兜住的话，表现是整个 suite 崩掉或挂死，而不是某条用例红。
///
/// 死循环相关用例刻意用 [supportsDeadline] 而不是 [isQuickJSAvailable] 判跳过：
/// wrapper DLL 是本地构建、不入库的，一份没有 `qs_arm_deadline` 的旧产物会让
/// `while(true){}` 真的一直跑下去，把整个测试进程挂死。
final String? _skipNoNative = isQuickJSAvailable
    ? null
    : 'QuickJS native 不可用，跳过';

final String? _skipNoDeadline = !isQuickJSAvailable
    ? 'QuickJS native 不可用，跳过'
    : !supportsDeadline
    ? 'wrapper DLL 缺 qs_arm_deadline，请重跑 native/build.bat'
    : null;

void main() {
  group('时限与中断', () {
    test('死循环被超时中断，报 SCRIPT_TIMEOUT', () {
      final rt = JsRuntime(
        limits: const JsRuntimeLimits(evalTimeout: Duration(milliseconds: 200)),
      )..init();
      addTearDown(rt.dispose);

      final sw = Stopwatch()..start();
      expect(rt.eval('while(true){}'), isNull);
      sw.stop();

      expect(rt.lastFailure?.code, ErrorCode.scriptTimeout);
      // 真的被掐了，而不是碰巧跑完——留足余量避免 CI 抖动误报。
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    });

    test('超时后同一实例仍可继续求值', () {
      final rt = JsRuntime(
        limits: const JsRuntimeLimits(evalTimeout: Duration(milliseconds: 200)),
      )..init();
      addTearDown(rt.dispose);

      expect(rt.eval('while(true){}'), isNull);
      // deadline 必须在求值后撤掉，否则下一次求值第一条字节码就被过期时限掐死。
      expect(rt.eval('1+2'), '3');
      expect(rt.lastFailure, isNull);
    });

    test('一个源超时不影响同进程其它源', () {
      final slow = JsRuntime(
        limits: const JsRuntimeLimits(evalTimeout: Duration(milliseconds: 200)),
      )..init();
      final fast = JsRuntime()..init();
      addTearDown(slow.dispose);
      addTearDown(fast.dispose);

      expect(slow.eval('while(true){}'), isNull);
      expect(slow.lastFailure?.code, ErrorCode.scriptTimeout);

      // 另一个 runtime 的时限是独立的——deadline 若是进程全局的，这里会被
      // 上面那条已过期的时限连坐。
      expect(
        fast.eval('var n=0; for(var i=0;i<100000;i++){n+=i}; n'),
        '4999950000',
      );
      expect(fast.lastFailure, isNull);
    });

    test('深递归超时也能被掐断', () {
      final rt = JsRuntime(
        limits: const JsRuntimeLimits(evalTimeout: Duration(milliseconds: 300)),
      )..init();
      addTearDown(rt.dispose);

      expect(rt.eval('var i=0; while(true){ i = (i + 1) % 1000000 }'), isNull);
      expect(rt.lastFailure?.code, ErrorCode.scriptTimeout);
    });
  }, skip: _skipNoDeadline);

  group('正常路径不被上限误伤', () {
    test('正常脚本在时限内跑完', () {
      final rt = JsRuntime(
        limits: const JsRuntimeLimits(evalTimeout: Duration(seconds: 5)),
      )..init();
      addTearDown(rt.dispose);

      expect(rt.eval('JSON.stringify([1,2,3].map(x => x * 2))'), '[2,4,6]');
      expect(rt.lastFailure, isNull);
    });

    test('unlimited 不施加任何上限', () {
      final rt = JsRuntime(limits: const JsRuntimeLimits.unlimited())..init();
      addTearDown(rt.dispose);

      expect(rt.isMemoryLimited, isFalse);
      expect(rt.isStackLimited, isFalse);
      expect(rt.eval('1+1'), '2');
    });
  }, skip: _skipNoNative);

  group('内存与栈', () {
    test('内存超限被限制在实例级别，进程存活', () {
      final hungry = JsRuntime(
        limits: const JsRuntimeLimits(
          memoryBytes: 4 * 1024 * 1024,
          evalTimeout: Duration(seconds: 30),
        ),
      )..init();
      addTearDown(hungry.dispose);

      if (!hungry.isMemoryLimited) {
        markTestSkipped('这份 libquickjs 没导出 JS_SetMemoryLimit');
        return;
      }

      // 循环有界：限制万一没生效，这里也只是多分配一阵子，不会永远跑下去。
      final got = hungry.eval(
        'var a=[]; for(var i=0;i<100000;i++){ '
        'a.push(new Array(1000).join("x")) } a.length',
      );
      expect(got, isNull);
      expect(hungry.lastFailure?.code, ErrorCode.memoryLimitExceeded);

      // 同进程另起一个仍然好用——这条要是挂了，说明限制是进程级而非实例级。
      final other = JsRuntime()..init();
      addTearDown(other.dispose);
      expect(other.eval('1+1'), '2');
    });

    test('栈溢出被拦下，不打崩进程', () {
      final rt = JsRuntime(
        limits: const JsRuntimeLimits(stackBytes: 256 * 1024),
      )..init();
      addTearDown(rt.dispose);

      if (!rt.isStackLimited) {
        // 实测过：没有 JS_SetMaxStackSize 时这段递归会砸穿 native 栈，
        // 整个测试进程以 0xC0000005 结束——不是一条红用例，是 suite 没了。
        markTestSkipped('这份 libquickjs 没导出 JS_SetMaxStackSize');
        return;
      }

      expect(rt.eval('function f(){ return f() } f()'), isNull);
      expect(rt.lastFailure, isNotNull);
      // 还能接着跑，就证明只是抛了个异常而不是把栈砸了。
      expect(rt.eval('1+1'), '2');
    });
  }, skip: _skipNoNative);

  group('异常诊断', () {
    test('脚本异常报 SCRIPT_RUNTIME_ERROR 并带堆栈', () {
      final rt = JsRuntime()..init();
      addTearDown(rt.dispose);

      expect(
        rt.eval('function boom(){ throw new Error("炸了") } boom()'),
        isNull,
      );

      final failure = rt.lastFailure;
      expect(failure, isNotNull);
      expect(failure!.code, ErrorCode.scriptRuntimeError);
      expect(failure.message, contains('炸了'));
      // 诊断面板要能看到函数名，否则堆栈没有价值。
      expect(failure.stack, contains('boom'));
      expect(failure.display, contains('炸了'));
    });

    test('非 Error 抛出物没有堆栈但仍归类为运行时错误', () {
      final rt = JsRuntime()..init();
      addTearDown(rt.dispose);

      expect(rt.eval('throw "纯字符串"'), isNull);
      expect(rt.lastFailure?.code, ErrorCode.scriptRuntimeError);
      expect(rt.lastFailure?.message, contains('纯字符串'));
    });

    test('成功求值会清掉上一次的失败', () {
      final rt = JsRuntime()..init();
      addTearDown(rt.dispose);

      expect(rt.eval('throw new Error("x")'), isNull);
      expect(rt.lastFailure, isNotNull);
      expect(rt.eval('1'), '1');
      expect(rt.lastFailure, isNull);
      expect(rt.lastError, isNull);
    });
  }, skip: _skipNoNative);

  // ---- 不需要 native，CI 上照跑 ----
  group('上限配置与错误对象', () {
    test('默认上限取值合理', () {
      const l = JsRuntimeLimits();
      expect(l.evalTimeout, const Duration(seconds: 10));
      expect(l.memoryBytes, 64 * 1024 * 1024);
      expect(l.stackBytes, 1024 * 1024);
    });

    test('unlimited 三项全为零值', () {
      const l = JsRuntimeLimits.unlimited();
      expect(l.evalTimeout, Duration.zero);
      expect(l.memoryBytes, 0);
      expect(l.stackBytes, 0);
    });

    test('JsEvalError 的 display 在无堆栈时就是消息本身', () {
      const e = JsEvalError(
        code: ErrorCode.scriptRuntimeError,
        message: 'boom',
      );
      expect(e.display, 'boom');
      expect(e.toString(), contains('SCRIPT_RUNTIME_ERROR'));
    });

    test('JsEvalError 的 display 会附上堆栈', () {
      const e = JsEvalError(
        code: ErrorCode.scriptTimeout,
        message: 'boom',
        stack: '  at f',
      );
      expect(e.display, 'boom\n  at f');
    });
  });
}
