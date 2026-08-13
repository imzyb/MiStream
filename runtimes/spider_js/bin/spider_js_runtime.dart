/// Spider JS 运行时子进程的入口。
///
/// 由 `SpiderHost` 用 `Process.start` 拉起，经 stdin/stdout 说 JSON-RPC
/// （`docs/08-RPC协议.md`）。stderr 留给致命错误，不参与协议。
///
/// 这里刻意什么都不做——所有逻辑在 [RuntimeChild]，这样主循环可以在测试里被
/// 注入的字节流驱动，不必真起进程。
library;

import 'dart:io';

import 'package:spider_js/src/child/runtime_child.dart';

void main(List<String> args) {
  final child = RuntimeChild();
  try {
    child.run();
  } on Object catch (e, st) {
    // 进程即将退出，宿主靠 runtime.fatal 提前失败在途请求（docs/08 §5.1）。
    stderr.writeln('spider_js 子进程致命错误: $e\n$st');
    child.dispose();
    exitCode = 1;
    return;
  }
  child.dispose();
}
