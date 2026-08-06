/// `MediaKitEngine` 的契约入口。
///
/// 与 `FakePlayerEngine` 跑的是同一套 [runPlayerEngineContract]，这是
/// [ADR-004] 里「抽象层没有泄漏」的核心证据：真实实现复用同一份用例，而不是
/// 对着接口再抄一遍测试。
///
/// ## 为什么这里可能跳过
///
/// 契约里 `createSource` 必须返回一个「确实能打开」的媒体，`MediaKitEngine`
/// 于是需要两样本环境没有的东西：**libmpv 运行库**与**一个本地样本媒体文件**。
/// 两者都由运行时环境变量给出，缺了任何一样就整组跳过（并用 `markTestSkipped`
/// 说明缺了什么）——`dart test` 就能在没有 libmpv 的开发机与 CI 上照常跑：
///
/// - `LIBMPV_LIBRARY_PATH`：libmpv 库路径，交给 [MediaKitEngine]。
/// - `MISTREAM_SAMPLE_MEDIA`：一个本地可播文件路径，如 `file:///tmp/sample.mkv`。
///
/// 这属于「需要真实媒体才能验」的部分，与 `docs/04-播放器设计.md` §2 的划分
/// 一致：真真能不能起播由 M1 出口标准的手工验收把关，不由本套件保证。
///
/// 运行（`LIBMPV_LIBRARY_PATH` 与 `MISTREAM_SAMPLE_MEDIA` 也可以直接作为
/// 进程环境变量，不用 `--define`）：
/// ```bash
/// $env:LIBMPV_LIBRARY_PATH = "build\\libmpv\\libmpv-2.dll"
/// $env:MISTREAM_SAMPLE_MEDIA = "file:///C:/samples/sample.mkv"
/// dart test test/contract/media_kit_engine_contract_test.dart
/// ```
///
/// [ADR-004]: ../../../../docs/adr/004-播放器分两期实现.md
library;

import 'dart:io';

import 'package:player_engine/player_engine.dart';
import 'package:test/test.dart';

import 'player_engine_contract.dart';

void main() {
  final libmpvPath = Platform.environment['LIBMPV_LIBRARY_PATH'] ?? '';
  final sampleMedia = Platform.environment['MISTREAM_SAMPLE_MEDIA'] ?? '';

  final sampleUri = Uri.tryParse(sampleMedia);
  if (sampleUri == null || !sampleUri.hasScheme) {
    test('MediaKitEngine 契约（跳过：未配置样本媒体）', () {
      markTestSkipped('需要 MISTREAM_SAMPLE_MEDIA 指定一个本地样本媒体');
    });
    return;
  }

  final runtime = MediaKitRuntime.ensureInitialized(
    libmpv: libmpvPath.isEmpty ? null : libmpvPath,
  );
  if (runtime.isErr) {
    test('MediaKitEngine 契约（跳过：libmpv 不可用）', () {
      markTestSkipped('找不到 libmpv：${runtime.errorOrNull?.message}');
    });
    return;
  }

  runPlayerEngineContract(
    label: 'MediaKitEngine',
    createEngine: () =>
        MediaKitEngine(libmpv: libmpvPath.isEmpty ? null : libmpvPath),
    createSource: () => MediaSource(uri: sampleUri),
  );
}
