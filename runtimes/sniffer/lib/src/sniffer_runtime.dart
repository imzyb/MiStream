/// 嗅探运行时门面。
///
/// 把三层串起来：内核发现 → 进程启动 → CDP 连接 → 会话嗅探 → 用完即杀。
///
/// 为什么单开一个门面而不是让调用方自己串：**生命周期顺序是硬约束**。
/// 先杀进程还是先关连接、profile 什么时候删、异常路径下怎么保证都清干净——
/// 这些顺序错了会泄漏进程。全部收敛在一处，调用方只需 `sniff()`。
library;

import 'dart:async';

import 'package:media_sniffer/media_sniffer.dart';
import 'package:sniffer/src/cdp/cdp_client.dart';
import 'package:sniffer/src/cdp/cdp_transport.dart';
import 'package:sniffer/src/kernel/kernel_locator.dart';
import 'package:sniffer/src/kernel/kernel_process.dart';
import 'package:sniffer/src/session/sniff_session.dart';

/// 嗅探运行时。
class SnifferRuntime {
  /// 构造运行时。
  ///
  /// [kernelLocator] 可注入，便于在没有浏览器的环境里测试降级路径；
  /// [transportFactory] 可注入，便于脱离网络测试协议层。
  SnifferRuntime({
    SnifferKernelLocator? kernelLocator,
    this.kernel,
    CdpTransport Function(String wsUrl)? transportFactory,
    Duration totalTimeout = const Duration(seconds: 20),
    this.startupTimeout = const Duration(seconds: 20),
    this.proxyServer,
    List<SnifferRule>? rules,
  }) : _kernelLocator = kernelLocator ?? const SnifferKernelLocator(),
       _transportFactory = transportFactory ?? WebSocketCdpTransport.new,
       _session = SniffSession(totalTimeout: totalTimeout, rules: rules);

  final SnifferKernelLocator _kernelLocator;
  final CdpTransport Function(String wsUrl) _transportFactory;
  final SniffSession _session;

  /// 显式指定的内核，null 表示运行时探测。
  final SnifferKernel? kernel;

  /// 等待 CDP 端点就绪的超时。
  final Duration startupTimeout;

  /// 代理服务器（`host:port`），null 表示直连。
  final String? proxyServer;

  /// 嗅探 [url]，返回结果（含失败原因）。
  ///
  /// 无论成功失败，进程与 profile 都会被清理。
  Future<CdpSniffOutcome> sniff(
    String url, {
    Map<String, String>? headers,
  }) async {
    SnifferKernel? resolved;
    try {
      resolved = kernel ?? _kernelLocator.locate();
    } on Object {
      resolved = null;
    }
    if (resolved == null) {
      return CdpSniffOutcome.miss(
        CdpSniffFailure.unavailable,
        '未找到可用的浏览器内核。请安装 Microsoft Edge 或 Google Chrome，或在设置中指定内核路径。',
      );
    }

    SnifferKernelProcess? proc;
    CdpClient? client;
    try {
      proc = await SnifferKernelProcess.launch(
        kernel: resolved,
        startupTimeout: startupTimeout,
        proxyServer: proxyServer,
      );

      client = CdpClient(_transportFactory(proc.browserWebSocketUrl));
      await client.connect();

      return await _session.sniff(
        client,
        url,
        headers: headers,
        kernelLabel: resolved.kind.label,
      );
    } on SnifferUnavailableException catch (e) {
      return CdpSniffOutcome.miss(CdpSniffFailure.unavailable, e.toString());
    } on KernelLaunchException catch (e) {
      return CdpSniffOutcome.miss(CdpSniffFailure.unavailable, e.toString());
    } on Object catch (e) {
      return CdpSniffOutcome.miss(CdpSniffFailure.pageError, e.toString());
    } finally {
      // 顺序有讲究：先断 CDP 再杀进程。反过来内核会先死，CDP 侧收到一堆
      // 「连接已关闭」的错误事件，日志噪音大且可能掩盖真实原因。
      try {
        await client?.close();
      } on Object {
        // 忽略：连接可能已经被内核关闭。
      }
      try {
        await proc?.dispose();
      } on Object {
        // 忽略：清理失败不该盖住嗅探本身的结论。
      }
    }
  }

  /// 当前是否有可用内核。
  bool get isAvailable {
    try {
      return (kernel ?? _kernelLocator.locate()) != null;
    } on Object {
      return false;
    }
  }

  /// 实际会使用的内核（显式指定优先，否则现场探测），没有则 null。
  SnifferKernel? get resolvedKernel {
    try {
      return kernel ?? _kernelLocator.locate();
    } on Object {
      return null;
    }
  }
}
