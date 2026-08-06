/// LSP 风格分帧的增量解析器。
///
/// 解析 `Content-Length: N\r\n\r\n` header + UTF-8 JSON body 的字节流，吐出完整的
/// JSON 字符串。**必须扛住**：半包、粘包、超大包、畸形 header、非法 UTF-8，且
/// 不因任何畸形输入而死循环或抛未捕获异常——这是 M3 出口标准之一
/// （`docs/08-RPC协议.md` §10 分帧）。
library;

import 'dart:convert';
import 'dart:typed_data';

/// 单条消息体上限（字节）。超出直接判错并建议断开——`docs/08 §1`。
const int kMaxMessageBytes = 32 * 1024 * 1024;

/// 单条消息 header 上限（字节），防止畸形 header 无限增长。
const int kMaxHeaderBytes = 16 * 1024;

/// 解析结果：要么产出一条完整 JSON 字符串，要么告知还需要更多数据/已出错。
sealed class FrameResult {
  /// 基类，不可直接实例化。
  const FrameResult();
}

/// 完整解析出的一条消息（其 JSON 文本）。
class FrameComplete extends FrameResult {
  const FrameComplete(this.body);

  /// 消息体 JSON 文本。
  final String body;
}

/// 还需要更多字节才能凑齐一条消息。
class FrameNeedMore extends FrameResult {
  /// 等待更多数据。
  const FrameNeedMore();
}

/// 输入非法（畸形 header / 超大包 / 非法 UTF-8），流已不可用。
class FrameError extends FrameResult {
  const FrameError(this.reason);

  /// 错误原因。
  final String reason;
}

/// 增量流式分帧解析器。
///
/// 用法：把收到的字节块不断喂给 [add]，它会返回可能的结果。若 [add] 返回
/// [FrameError]，该解析器实例已损坏，应丢弃并重建。
class LspFrameParser {
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  /// 当前等待的帧总长度（header + body）。null 表示还没解析出 header。
  int? _frameLength;

  /// 喂入一块字节，返回解析结果。
  ///
  /// 可能产出零到一个 [FrameComplete]。若返回 [FrameError]，流已损坏。
  FrameResult add(List<int> chunk) {
    _buffer.add(chunk);

    for (;;) {
      if (_frameLength == null) {
        final header = _tryReadHeader();
        if (header is FrameError) {
          return header;
        }
        if (header is String) {
          final contentLength = _parseContentLength(header);
          if (contentLength == null) {
            return const FrameError('畸形 Content-Length');
          }
          if (contentLength > kMaxMessageBytes) {
            return FrameError('消息体超过上限 $kMaxMessageBytes 字节');
          }
          _frameLength = _headerEnd() + contentLength;
        } else {
          return const FrameNeedMore();
        }
      }

      final bytes = _buffer.toBytes();
      if (bytes.length < _frameLength!) {
        return const FrameNeedMore();
      }

      final frame = bytes.sublist(0, _frameLength!);
      // 记住 header 结束位置，buffer 清空后再也找不到了。
      final headerEnd = _headerEnd();
      _buffer.clear();
      if (bytes.length > _frameLength!) {
        _buffer.add(bytes.sublist(_frameLength!));
      }
      _frameLength = null;

      final body = frame.sublist(headerEnd);
      final text = _decodeUtf8(body);
      if (text == null) {
        return const FrameError('非法 UTF-8 消息体');
      }
      return FrameComplete(text);
    }
  }

  /// 尝试从缓冲开头读取 header 文本；返回 null 表示还需更多数据。
  Object? _tryReadHeader() {
    final bytes = _buffer.toBytes();
    final end = _indexOfDoubleCrlf(bytes);
    if (end == -1) {
      if (bytes.length > kMaxHeaderBytes) {
        return const FrameError('header 超过上限 $kMaxHeaderBytes 字节');
      }
      return null;
    }
    final header = _decodeUtf8(bytes.sublist(0, end));
    if (header == null) {
      return const FrameError('非法 UTF-8 header');
    }
    return header;
  }

  /// 当前缓冲中 `\r\n\r\n` 结束位置（含两个 CRLF），作为 body 起点。
  int _headerEnd() {
    final bytes = _buffer.toBytes();
    final end = _indexOfDoubleCrlf(bytes);
    return end + 4;
  }

  static int? _parseContentLength(String header) {
    for (final rawLine in header.split('\r\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final colon = line.indexOf(':');
      if (colon <= 0) return null;
      final name = line.substring(0, colon).trim().toLowerCase();
      if (name != 'content-length') continue;
      final value = line.substring(colon + 1).trim();
      final parsed = int.tryParse(value);
      if (parsed != null && parsed >= 0) return parsed;
    }
    return null;
  }

  static int _indexOfDoubleCrlf(List<int> bytes) {
    for (var i = 0; i < bytes.length - 3; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  static String? _decodeUtf8(List<int> bytes) {
    try {
      return const Utf8Codec().decode(bytes, allowMalformed: false);
    } on FormatException {
      return null;
    }
  }
}
