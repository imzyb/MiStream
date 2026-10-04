/// `play_engine` 的 SnifferLauncher 实现。
///
/// `play_engine` 只认 `Future<String?> sniff(url, headers)` 这一个签名
/// （`packages/play_engine/lib/src/models.dart`），所以这里做一层适配：
/// 把结构化的 [CdpSniffOutcome] 压成「命中的地址或 null」。
///
/// 错误信息不在这里吞掉——它通过 [SnifferRuntime] 与 [SniffSession] 的
/// `CdpSniffOutcome.detail` 暴露。播放链路要的只是一个「能不能播」的答案，
/// 而诊断链路要的是原因，两者取值路径不同，不该让播放链路被迫接收
/// 一个它不关心的错误对象。
library;

import 'package:play_engine/play_engine.dart';
import 'package:sniffer/src/session/sniff_session.dart';
import 'package:sniffer/src/sniffer_runtime.dart';

/// 用 CDP 嗅探的 [SnifferLauncher] 实现。
class CdpSnifferLauncher implements SnifferLauncher {
  /// 构造。
  ///
  /// 默认惰性创建 [SnifferRuntime]：构造时不探测内核，避免在应用启动
  /// 阶段做无谓的文件系统扫描。
  // ignore: prefer_initializing_formals — _runtime 要可变（惰性赋值），不能用 final 初始化形参。
  CdpSnifferLauncher({SnifferRuntime? runtime}) : _runtime = runtime;

  SnifferRuntime? _runtime;

  /// 取运行时（首次访问时创建）。
  SnifferRuntime get runtime => _runtime ??= SnifferRuntime();

  /// 最近一次嗅探的完整结果，供诊断面板读取。
  CdpSniffOutcome? get lastOutcome => _lastOutcome;
  CdpSniffOutcome? _lastOutcome;

  @override
  Future<String?> sniff(String url, Map<String, String> headers) async {
    final outcome = await runtime.sniff(url, headers: headers);
    _lastOutcome = outcome;
    return outcome.url;
  }
}
