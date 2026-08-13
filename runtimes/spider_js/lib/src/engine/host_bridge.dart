/// drpy 宿主 API 桥 —— 把纯 Dart 实现暴露给 QuickJS 里跑的脚本。
///
/// JS 侧只看得见一个入口 `__qs_host(name, argsJson)`，友好的 `pdfh` / `md5` /
/// `console.log` 等由 `JsRuntime` 注入的 JS 前导脚本在其上层封装。这样设计是为
/// 了守住 `native/quickjs_wrapper.c` 上记的那条约束：**跨 FFI 的 JSValue 只能
/// 是字符串**，所以实参与返回值一律走 JSON。
///
/// 只登记**同步**函数。`req`（网络）与 `local.*`（落库）在 Dart 侧都是异步的，
/// 而 drpy 脚本按同步语义调用它们，需要 ADR-001 的子进程/隔离区加阻塞原语才能
/// 对上，不在本层解决。
library;

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:spider_js/src/drpy/crypto.dart' as drpy;
import 'package:spider_js/src/drpy/html_parser.dart' as drpy;
import 'package:spider_js/src/engine/quickjs_bindings.dart' as qjs;

/// 一个宿主函数：接 JSON 解出的实参表，返回可 JSON 序列化的结果。
typedef HostHandler = Object? Function(List<Object?> args);

/// 宿主函数分发表与 native 回调的持有者。
///
/// 与 `JsRuntime` 一一对应：每个实例持有自己的 [NativeCallable]，[dispose]
/// 必须调用，否则回调会一直把这个对象钉在内存里。
class HostBridge {
  /// 构造分发表。[extraHandlers] 可覆盖或追加内置函数，测试用。
  HostBridge({Map<String, HostHandler>? extraHandlers}) {
    _handlers = <String, HostHandler>{
      ..._builtinHandlers(),
      ...?extraHandlers,
    };
  }

  late final Map<String, HostHandler> _handlers;

  /// 脚本经 `console.*` 打出来的行，供源诊断面板展示。
  final List<String> consoleOutput = <String>[];

  NativeCallable<qjs.HostDispatchC>? _dispatch;
  NativeCallable<qjs.HostReleaseC>? _release;

  /// 已登记的宿主函数名，按字母序。
  Iterable<String> get handlerNames => _handlers.keys.toList()..sort();

  /// 把 `__qs_host` 装进 [ctx] 的全局对象。返回 false 表示 native 侧缺少
  /// 必要导出，此时 drpy API 在脚本里不可用（引擎本身仍可跑纯计算脚本）。
  bool install(Pointer<Void> ctx) {
    // 指针返回值不接受 exceptionalReturn（dart:ffi 只对数值类型要求它），
    // 所以 _onCall 内部必须自己兜住一切异常，绝不能让它逃出去。
    final dispatch = _dispatch ??=
        NativeCallable<qjs.HostDispatchC>.isolateLocal(_onCall);
    final release = _release ??= NativeCallable<qjs.HostReleaseC>.isolateLocal(
      _onRelease,
    );

    return qjs.registerHost(
      ctx,
      dispatch.nativeFunction,
      release.nativeFunction,
    );
  }

  /// 释放 native 回调。
  void dispose() {
    _dispatch?.close();
    _dispatch = null;
    _release?.close();
    _release = null;
  }

  /// 调用一个宿主函数，返回准备回给 JS 的 payload。
  ///
  /// 成功是 `{'v': 结果}`，失败是 `{'e': 消息}`——前导脚本按这两个键决定是
  /// 返回值还是抛 JS 异常。抽成公开方法是为了让分发表能在**没有 native 库**
  /// 的环境（CI 即是）里被完整测到。
  Map<String, Object?> invoke(String name, List<Object?> args) {
    final handler = _handlers[name];
    if (handler == null) {
      return <String, Object?>{'e': '未登记的宿主函数: $name'};
    }
    try {
      return <String, Object?>{'v': handler(args)};
    } on Object catch (e) {
      // 宿主函数抛错要变成脚本里的 JS 异常，而不是把整个引擎带崩。
      return <String, Object?>{'e': '$name: $e'};
    }
  }

  /// native 侧每次 `__qs_host(name, args)` 都打到这里。
  ///
  /// 返回的指针由 native 侧拷进 JS 字符串后立刻回调 [_onRelease] 归还，所以
  /// 这里可以放心 malloc。
  Pointer<Utf8> _onCall(Pointer<Utf8> namePtr, Pointer<Utf8> argsPtr) {
    try {
      final decoded = jsonDecode(argsPtr.toDartString());
      final args = decoded is List<Object?> ? decoded : <Object?>[decoded];
      return _encode(invoke(namePtr.toDartString(), args));
    } on Object catch (e) {
      return _encode(<String, Object?>{'e': '宿主调用解码失败: $e'});
    }
  }

  void _onRelease(Pointer<Utf8> ptr) {
    if (ptr != nullptr) malloc.free(ptr);
  }

  Pointer<Utf8> _encode(Map<String, Object?> payload) {
    try {
      return jsonEncode(payload).toNativeUtf8();
    } on Object catch (e) {
      return jsonEncode(<String, Object?>{'e': '返回值无法序列化: $e'}).toNativeUtf8();
    }
  }

  Map<String, HostHandler> _builtinHandlers() => <String, HostHandler>{
    // ---- HTML 解析（drpy 伪 XPath）----
    'pdfh': (a) => drpy.pdfh(_str(a, 0), _str(a, 1)),
    'pdfa': (a) => drpy.pdfa(_str(a, 0), _str(a, 1)),
    'pd': (a) => drpy.pd(_str(a, 0), _str(a, 1), _str(a, 2)),
    'pdfl': (a) => drpy.pdfl(_str(a, 0), _str(a, 1), _str(a, 2)),

    // ---- 摘要与编码 ----
    'md5': (a) => drpy.md5(_str(a, 0)),
    'sha1': (a) => drpy.sha1(_str(a, 0)),
    'sha256': (a) => drpy.sha256Drpy(_str(a, 0)),
    'hmac256': (a) => drpy.hmac256(_str(a, 0), _str(a, 1)),
    'urlencode': (a) => drpy.urlencode(_str(a, 0)),
    'urldecode': (a) => drpy.urldecode(_str(a, 0)),
    'base64Encode': (a) => base64Encode(utf8.encode(_str(a, 0))),
    'base64Decode': (a) => utf8.decode(base64Decode(_str(a, 0))),

    // ---- 工具 ----
    'joinUrl': (a) => drpy.joinUrl(_str(a, 0), _str(a, 1)),
    'aes': (a) => drpy.aes(
      encrypt: a.isNotEmpty && a[0] == true,
      input: _str(a, 1),
      key: _str(a, 2),
      iv: a.length > 3 && a[3] != null ? a[3].toString() : null,
      mode: a.length > 4 && a[4] != null
          ? a[4].toString()
          : 'AES/CBC/PKCS5Padding',
    ),
    'console.log': (a) {
      consoleOutput.add(a.map((e) => e?.toString() ?? 'null').join(' '));
      return null;
    },
  };

  static String _str(List<Object?> args, int index) =>
      index < args.length && args[index] != null ? args[index].toString() : '';
}
