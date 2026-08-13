/// 走宿主 RPC 的 drpy 函数：`req` 与 `local.*`。
///
/// 与 `host_bridge.dart` 里那批纯 Dart 实现（`pdfh`、`md5`…）分开放，因为它们
/// 的性质不同：那些是本地计算，这些**必须过宿主**。按 ADR-001 与 docs/08 §4，
/// 运行时子进程不发网络、不碰数据库——网络收敛到 `host.fetch` 才能统一施加
/// 白名单、SSRF 拦截、代理与限速，存储收敛到 `host.storage.*` 才能保证命名
/// 空间隔离不被脚本伪造。
///
/// 每条调用都是**阻塞**的（[RuntimeChild.callHost]），原因见 `sync_frame_io.dart`。
library;

import 'package:spider_js/src/child/runtime_child.dart';
import 'package:spider_js/src/engine/js_runtime.dart';

/// 把 `req` / `local.*` 注册到 [runtime] 的桥上，绑定到 [instanceId]。
///
/// owner 用 instanceId，由宿主在 `spider.create` 时给定——脚本拿不到也改不了，
/// 这是存储隔离不能交给子进程自报的原因。
void installDrpyHostFunctions(
  JsRuntime runtime,
  String instanceId,
  RuntimeChild child,
) {
  runtime.bridge
    ..register('req', (args) => _req(child, instanceId, args))
    ..register(
      'local.get',
      (args) => _storage(child, 'get', instanceId, <String, Object?>{
        'key': _str(args, 0),
      })?['value'],
    )
    ..register('local.set', (args) {
      _storage(child, 'set', instanceId, <String, Object?>{
        'key': _str(args, 0),
        'value': _str(args, 1),
      });
      return null;
    })
    ..register('local.delete', (args) {
      _storage(child, 'delete', instanceId, <String, Object?>{
        'key': _str(args, 0),
      });
      return null;
    });
}

/// `req(url, options)` → `host.fetch`，返回 drpy 形态的响应。
///
/// drpy 源读的是 `.content`；`.headers` / `.code` / `.url` 一并给出，真实源里
/// 三个都有人用（取 cookie、判 302、拼相对地址）。
Map<String, Object?> _req(
  RuntimeChild child,
  String instanceId,
  List<Object?> args,
) {
  final options = args.length > 1 && args[1] is Map
      ? (args[1]! as Map).cast<String, Object?>()
      : const <String, Object?>{};

  final outcome = child.callHost('host.fetch', <String, Object?>{
    'instanceId': instanceId,
    'url': _str(args, 0),
    'method': (options['method'] ?? 'GET').toString().toUpperCase(),
    'headers': options['headers'] ?? const <String, Object?>{},
    'body': options['body'],
    'timeoutMs': options['timeout'] ?? options['timeoutMs'],
    'redirect': options['redirect'] ?? true,
    'responseType': options['buffer'] == true ? 'buffer' : 'text',
  });

  final result = _unwrap(outcome, 'req');
  return <String, Object?>{
    'content': result['body'] ?? '',
    'headers': result['headers'] ?? const <String, Object?>{},
    'code': result['status'] ?? 0,
    'url': result['finalUrl'] ?? _str(args, 0),
  };
}

Map<String, Object?>? _storage(
  RuntimeChild child,
  String op,
  String instanceId,
  Map<String, Object?> params,
) {
  final outcome = child.callHost('host.storage.$op', <String, Object?>{
    'instanceId': instanceId,
    ...params,
  });
  return _unwrap(outcome, 'local.$op');
}

/// 把宿主回话拆成结果，失败就抛——抛出去会被 `HostBridge.invoke` 收成
/// `{'e': …}`，再由 JS 前导变回一个脚本能 try/catch 的异常。
Map<String, Object?> _unwrap(HostCallOutcome outcome, String what) {
  final error = outcome.error;
  if (error != null) {
    final message = error is Map && error['message'] != null
        ? error['message']
        : error;
    throw StateError('$what 失败: $message');
  }
  final result = outcome.result;
  return result is Map
      ? result.cast<String, Object?>()
      : const <String, Object?>{};
}

String _str(List<Object?> args, int index) =>
    index < args.length && args[index] != null ? args[index].toString() : '';
