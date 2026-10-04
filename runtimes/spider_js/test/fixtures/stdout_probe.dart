// 子进程侧 stdout 语义的探针，被 test/sync_frame_io_test.dart 起起来。
//
// 关键在于：写完**立刻退出**，不 await flush（同步主循环里也没法 await）。
// 父进程若能收全两条帧，就证明 dart:io 的 stdout 确实是阻塞写——这是整个
// 同步子进程能成立的前提，语义一变子进程会直接死锁。
import 'package:spider_js/src/child/sync_frame_io.dart';

void main() {
  SyncFrameCodec()
    ..writeFrame('{"jsonrpc":"2.0","id":1,"result":{"probe":"第一条"}}')
    ..writeFrame('{"jsonrpc":"2.0","id":2,"result":{"probe":"第二条"}}');
  // 刻意不 flush、不 sleep：这条路径要是不可靠，这个测试就该红。
}
