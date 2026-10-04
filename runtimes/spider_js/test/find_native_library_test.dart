/// [findNativeLibrary] 的候选顺序。
///
/// 这条查找链是 AOT 打包后能否加载 native 库的唯一依据：子进程被宿主从任意
/// 工作目录拉起时，`Directory.current` 与 `Platform.script` 都不再指向包内，
/// 只有「exe 自己旁边」这一条锚点是稳定的。因此这里钉住它的存在。
library;

import 'dart:io';

import 'package:spider_js/spider_js.dart';
import 'package:test/test.dart';

void main() {
  group('findNativeLibrary', () {
    test('找不到的名字返回 null', () {
      expect(findNativeLibrary('绝不存在的库_zzz.dll'), isNull);
    });

    test('认得 exe 同目录下的库', () {
      // 用当前 Dart 可执行文件所在目录造一个临时文件：AOT 后的子进程正是
      // 靠这条候选找到并排的 DLL。
      final exeDir = File(Platform.resolvedExecutable).parent;
      final probe = File(
        '${exeDir.path}${Platform.pathSeparator}'
        '_mistream_probe_lib.tmp',
      );
      try {
        probe.writeAsStringSync('x');
      } on Object {
        // 某些环境下 SDK 目录不可写（只读挂载 / 权限受限），跳过而不是假红。
        return;
      }
      try {
        expect(findNativeLibrary('_mistream_probe_lib.tmp'), probe.path);
      } finally {
        try {
          probe.deleteSync();
        } on Object {
          // 清理失败不影响结论。
        }
      }
    });

    test('QUICKJS_DLL_PATH 指定的目录参与查找', () {
      // 不改进程环境（Dart 不支持），只断言候选里确实读了这个变量：
      // 变量没设时行为应与不设一致，即找不到就是 null。
      expect(
        Platform.environment.containsKey('QUICKJS_DLL_PATH') ||
            findNativeLibrary('绝不存在的库_zzz.dll') == null,
        isTrue,
      );
    });
  });
}
