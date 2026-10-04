// 实测真实 stdin 上 readByteSync 的吞吐，被 test/sync_frame_io_test.dart 起起来。
//
// 方案里的头号风险：子进程只有 readByteSync 这一个阻塞读原语，逐字节读大响应体
// 会不会慢到吃掉 search 的 3s 预算。注入闭包测不出这个——那是普通 Dart 调用，
// 真实的是 VM native 调用，量级不同。所以这里必须走真 stdin。
import 'package:spider_js/src/child/sync_frame_io.dart';

void main() {
  final codec = SyncFrameCodec();

  final sw = Stopwatch()..start();
  final body = codec.readFrame();
  sw.stop();

  codec.writeFrame(
    '{"bytes":${body?.length ?? -1},"elapsedMs":${sw.elapsedMilliseconds}}',
  );
}
