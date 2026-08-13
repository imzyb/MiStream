/// 子进程侧的**同步**分帧读写。
///
/// 为什么不复用宿主侧的 `LspFrameParser`：那是个**增量**解析器，每次 `add` 都要
/// `_buffer.toBytes()` 把全量缓冲拷一遍。宿主按 socket chunk 喂它，一条消息只
/// add 几次，代价可以忽略；子进程这边只有 `stdin.readByteSync()` 这一个阻塞读
/// 原语，逐字节喂进去就退化成 O(n²)——一条 1MB 的响应体要拷约 10^12 字节。
///
/// 所以这里自己来：header 逐字节读到 `\r\n\r\n`（只有几十字节，无所谓），拿到
/// `Content-Length` 后按精确长度读 body。整体 O(n)。
///
/// **实测吞吐（2026-08-13，Windows）**：真 stdin 上 1MB 逐字节 `readByteSync`
/// 耗时 **668ms**（约 1.5MB/s）。对照实验里 `readLineSync`（一次 native 调用读
/// 整行）反而更慢，**748ms**——换读法没有出路，Dart 的同步 stdin 就是这个量级。
/// 典型 search 响应体 50–300KB，折合 30–200ms，3s 预算扛得住。
///
/// 真要提速只有一条路：大 payload 走临时文件，控制消息仍走 stdin（小，逐字节
/// 无所谓），`host.fetch` 的 body 由宿主落盘、子进程 `File.readAsBytesSync`
/// 批量读。等 search P50 基准真的顶不住了再做，别提前优化。
///
/// 为什么非同步不可：JS 求值期间 C 栈停在 `JS_Eval` 里回调 Dart，此时 Dart 事件
/// 循环不转，异步 I/O 的响应永远送不到。详见 ADR-001 与 `runtime_child.dart`。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:spider_host/spider_host.dart'
    show kMaxHeaderBytes, kMaxMessageBytes;

/// 分帧层的输入非法：畸形 header、超长、非法 UTF-8。
///
/// 与「流正常结束」区分开——后者是 [SyncFrameCodec.readFrame] 返回 null。
class FrameFormatException implements Exception {
  /// 以原因 [reason] 构造。
  const FrameFormatException(this.reason);

  /// 出错原因。
  final String reason;

  @override
  String toString() => 'FrameFormatException: $reason';
}

/// 阻塞式的 LSP 分帧读写。
///
/// 默认接在真实 stdin/stdout 上；测试可注入 `readByte` 与 `write`。
class SyncFrameCodec {
  /// 构造编解码器。
  ///
  /// [readByte] 返回下一个字节，流结束返回负数（`stdin.readByteSync` 的语义）。
  SyncFrameCodec({
    int Function()? readByte,
    void Function(List<int> bytes)? write,
  }) : _readByte = readByte ?? stdin.readByteSync,
       _write = write ?? _writeStdout;

  final int Function() _readByte;
  final void Function(List<int> bytes) _write;

  /// dart:io 的 stdout 默认是**阻塞**的（区别于 `Stdout.nonBlocking`），所以
  /// 同步循环里 add 完不必也没法 await flush。`test/sync_frame_io_test.dart`
  /// 里有一条真起子进程的用例钉住这个语义——它要是变了，子进程会直接死锁。
  static void _writeStdout(List<int> bytes) => stdout.add(bytes);

  /// 阻塞读出下一条消息的 JSON 文本。
  ///
  /// 流正常结束返回 null；输入非法抛 [FrameFormatException]。
  String? readFrame() {
    final header = _readHeader();
    if (header == null) return null;

    final length = _parseContentLength(header);
    if (length == null) {
      throw const FrameFormatException('畸形 Content-Length');
    }
    if (length > kMaxMessageBytes) {
      throw FrameFormatException('消息体 $length 字节，超过上限 $kMaxMessageBytes');
    }

    final body = Uint8List(length);
    for (var i = 0; i < length; i++) {
      final b = _readByte();
      if (b < 0) {
        throw FrameFormatException('body 读到一半流就断了（$i/$length 字节）');
      }
      body[i] = b;
    }

    try {
      return utf8.decode(body);
    } on FormatException {
      throw const FrameFormatException('非法 UTF-8 消息体');
    }
  }

  /// 写出一条消息。[json] 是消息体文本。
  void writeFrame(String json) {
    final body = utf8.encode(json);
    _write(utf8.encode('Content-Length: ${body.length}\r\n\r\n'));
    _write(body);
  }

  /// 逐字节读到 `\r\n\r\n`，返回 header 文本（不含结尾的两个 CRLF）。
  ///
  /// 一个字节都没读到就遇上流结束，说明对端正常关了管道，返回 null。
  String? _readHeader() {
    final buf = <int>[];
    for (;;) {
      final b = _readByte();
      if (b < 0) {
        if (buf.isEmpty) return null;
        throw FrameFormatException('header 读到一半流就断了（${buf.length} 字节）');
      }
      buf.add(b);

      final n = buf.length;
      if (n >= 4 &&
          buf[n - 4] == 13 &&
          buf[n - 3] == 10 &&
          buf[n - 2] == 13 &&
          buf[n - 1] == 10) {
        try {
          return utf8.decode(buf.sublist(0, n - 4));
        } on FormatException {
          throw const FrameFormatException('非法 UTF-8 header');
        }
      }

      if (n > kMaxHeaderBytes) {
        throw const FrameFormatException('header 超过上限 $kMaxHeaderBytes 字节');
      }
    }
  }

  static int? _parseContentLength(String header) {
    for (final rawLine in header.split('\r\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final colon = line.indexOf(':');
      if (colon <= 0) return null;
      if (line.substring(0, colon).trim().toLowerCase() != 'content-length') {
        continue;
      }
      final parsed = int.tryParse(line.substring(colon + 1).trim());
      if (parsed != null && parsed >= 0) return parsed;
    }
    return null;
  }
}
