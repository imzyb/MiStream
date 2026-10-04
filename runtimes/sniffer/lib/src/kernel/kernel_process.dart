/// 浏览器内核子进程管理。
///
/// 关键约束（来自 ADR-005）：
/// - **用完即杀**：不持久化 profile、不复用 cookie、不保留缓存
/// - 每次嗅探一个一次性 profile 目录，杀进程后删掉
///
/// 端点发现靠解析 stdout 里的 `DevTools listening on ws://...`。
/// 为什么不用 `--remote-debugging-port=<固定端口>` 再拼 URL：固定端口会撞车
/// （同时嗅多个源时必炸），而 `--remote-debugging-port=0` 让系统分配端口后，
/// 唯一能拿到真实端口的就是这行输出。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sniffer/src/kernel/kernel_locator.dart';

/// 内核进程启动失败。
class KernelLaunchException implements Exception {
  /// 构造错误。
  const KernelLaunchException(this.message);

  /// 原因。
  final String message;

  @override
  String toString() => 'KernelLaunchException: $message';
}

/// 一个正在运行的内核实例。
class SnifferKernelProcess {
  SnifferKernelProcess._({
    required this.kernel,
    required this.process,
    required this.browserWebSocketUrl,
    required this.profileDir,
    required this.httpEndpoint,
  });

  /// 使用的内核。
  final SnifferKernel kernel;

  /// 子进程句柄。
  final Process process;

  /// 浏览器级 CDP WebSocket 地址。
  final String browserWebSocketUrl;

  /// 一次性 profile 目录。
  final Directory profileDir;

  /// DevTools HTTP 端点基址，如 `http://127.0.0.1:12345`。
  final String httpEndpoint;

  /// 启动内核并等待 DevTools 端点就绪。
  ///
  /// [startupTimeout] 是「等端点出现」的上限；内核本身启动通常几百毫秒，
  /// 但冷启动 + 杀软扫描时可能到数秒。
  static Future<SnifferKernelProcess> launch({
    SnifferKernel? kernel,
    Duration startupTimeout = const Duration(seconds: 20),
    String? proxyServer,
    List<String> extraArgs = const [],
    void Function(String line)? onStderrLine,
  }) async {
    final resolved = kernel ?? const SnifferKernelLocator().locateOrThrow();

    final profileDir = await Directory.systemTemp.createTemp('mistream-sniff-');
    final args = <String>[
      // `--headless=new` 是当前 Chrome/Edge 的新无头模式；老无头（`--headless`）
      // 在部分版本上不支持完整 Network 域，嗅探会拿不到事件。
      '--headless=new',
      '--disable-gpu',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-extensions',
      '--disable-background-networking',
      '--disable-sync',
      '--disable-default-apps',
      '--mute-audio',
      // 让内核把 DevTools 地址打到 stdout，端口由系统分配避免撞车。
      '--remote-debugging-port=0',
      '--remote-allow-origins=*',
      '--user-data-dir=${profileDir.path}',
      if (proxyServer != null) '--proxy-server=$proxyServer',
      ...extraArgs,
      'about:blank',
    ];

    final proc = await Process.start(resolved.path, args);
    final stderrLines = <String>[];

    final endpointCompleter = Completer<String>();

    // 端点行由内核打在 **stderr** 上（`DevTools listening on ws://...`），
    // 不是 stdout。这一点很容易搞错——把两条流都重定向到同一个日志文件看
    // 是分不出来的，而只听 stdout 的后果是所有启动都等到超时。
    // 因此这里两条流都扫，谁先出现算谁的。
    void scanLine(String line) {
      if (endpointCompleter.isCompleted) return;
      final ws = parseDevToolsUrl(line);
      if (ws != null) endpointCompleter.complete(ws);
    }

    proc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      stderrLines.add(line);
      if (stderrLines.length > 200) stderrLines.removeAt(0);
      onStderrLine?.call(line);
      scanLine(line);
    });

    final stdoutSub = proc.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(scanLine);

    var exited = false;
    int? exitCode;
    unawaited(
      proc.exitCode.then((code) {
        exited = true;
        exitCode = code;
        if (!endpointCompleter.isCompleted) {
          endpointCompleter.completeError(
            KernelLaunchException(
              '内核在端点就绪前退出（code=$code）${stderrLines.isEmpty ? '' : '；stderr: ${stderrLines.take(3).join(' | ')}'}',
            ),
          );
        }
      }),
    );

    final String wsUrl;
    try {
      wsUrl = await endpointCompleter.future.timeout(
        startupTimeout,
        onTimeout: () {
          throw KernelLaunchException(
            '等待 CDP 端点超时（${startupTimeout.inSeconds}s）'
            '${exited ? '，进程已退出 code=$exitCode' : ''}'
            '${stderrLines.isEmpty ? '' : '；stderr: ${stderrLines.take(3).join(' | ')}'}',
          );
        },
      );
    } on Object {
      // 启动失败时进程可能已经在跑（端点没出现但进程活着，例如参数不被支持）。
      // 不在这里杀掉的话，调用方拿不到进程句柄，只能等它自己退出——那就是
      // 一个真泄漏。ADR-005 的「用完即杀」在这里同样适用。
      unawaited(stdoutSub.cancel());
      try {
        proc.kill(ProcessSignal.sigkill);
      } on Object {
        // 已经退出了。
      }
      try {
        await _cleanupProfile(profileDir);
      } on Object {
        // 清理失败不该改变抛出的异常。
      }
      rethrow;
    }
    // 成功路径：stdout 用完就收，stderr 留给诊断回调。
    unawaited(stdoutSub.cancel());

    return SnifferKernelProcess._(
      kernel: resolved,
      process: proc,
      browserWebSocketUrl: wsUrl,
      profileDir: profileDir,
      httpEndpoint: _httpEndpointOf(wsUrl),
    );
  }

  /// 杀掉内核并清理一次性 profile。
  ///
  /// 清理失败不抛异常：临时目录残留比让调用方在 finally 里炸掉更可接受。
  Future<void> dispose() async {
    try {
      process.kill(ProcessSignal.sigkill);
    } on Object {
      // 进程可能已经退出。
    }
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on Object {
      // 超时或已退出，继续清理。
    }
    await _cleanupProfile(profileDir);
  }

  /// 删掉一次性 profile 目录。
  ///
  /// 删除失败时**重试几次再放弃**：Windows 上内核刚被杀时文件句柄可能还没
  /// 释放，立即删会碰到占用错误。重试比直接放弃更可能真的清干净——而
  /// 「不持久化 cookie」这个承诺正是靠删掉 profile 兑现的。
  static Future<void> _cleanupProfile(Directory dir) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (!dir.existsSync()) return;
        await dir.delete(recursive: true);
        return;
      } on Object {
        await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
      }
    }
  }

  /// 从 `DevTools listening on ws://127.0.0.1:PORT/devtools/browser/ID` 提取地址。
  static String? parseDevToolsUrl(String line) {
    final idx = line.indexOf('ws://');
    if (idx < 0) return null;
    final tail = line.substring(idx).trim();
    // 行尾可能跟别的输出，按空白截断。
    final end = tail.indexOf(RegExp(r'\s'));
    final url = end < 0 ? tail : tail.substring(0, end);
    return url.startsWith('ws://') && url.contains('/devtools/') ? url : null;
  }

  static String _httpEndpointOf(String wsUrl) {
    final uri = Uri.parse(wsUrl);
    return 'http://${uri.host}:${uri.port}';
  }
}
