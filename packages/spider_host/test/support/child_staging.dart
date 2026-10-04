// 把子进程桩复制到本机磁盘（C:）的临时目录再运行。
//
// 为什么不能就地跑：本仓库在 I: 盘，那是一块虚拟化文件系统。`dart run` 每轮
// 启动都要读 `<仓库根>/.dart_tool/package_config.json`，而 2 小时长跑跑到第
// 8660 轮时系统开始拒绝访问它：
//
//     Error: Error when reading '../../.dart_tool/package_config.json': 拒绝访问。
//
// 子进程因此起不来，宿主退避 5 次后按设计熔断，长跑判红。已排除资源耗尽：
// I: 盘还有 709G、`%TEMP%` 只有 44 个条目、`.dart_tool` 只有 64 个文件，
// 都不随轮数增长。所以是那块盘的文件系统语义，不是资源不够。
//
// 桩只用 dart:io / dart:convert，不依赖任何包，于是可以搬到一个**没有
// pubspec.yaml** 的目录里跑。dart 是按**脚本所在目录**向上找 pubspec 的
// （实测：cwd 留在 I: 盘、脚本放 C: 盘也能跑通，决定因素是脚本位置而非 cwd），
// 找不到就完全不走 pub 层，I: 盘 package_config 的读取次数从「每轮 1 次」降到 0。
//
// 只对**长时间运行**的用例有意义（长跑）。短用例撞上这个故障的概率极低，
// 就地跑还能少一层复制。
import 'dart:io';

Directory? _stagingDir;

/// 解析 `test/support/` 下某个桩文件的绝对路径。
///
/// ⚠️ **不能只用 `Platform.script.resolve(...)`** —— 它在两种跑法下含义不同：
///
/// | 跑法 | `Platform.script` | 相对解析 |
/// | --- | --- | --- |
/// | `dart run test/xxx_test.dart` | 测试文件的真实路径 | ✅ 正确 |
/// | **`dart test`** | **预编译产物** `<tmp>/dart_test.kernel.<hash>/xxx_test.dart` | ❌ 必然落空 |
///
/// CI 的 `melos run test` 走的是 `dart test`，于是 `real_process_host_test` 与
/// `host_soak_test` 这 8 条真子进程用例在三个平台上**全红**，报的是
/// `Could not find file .../dart_test.kernel.<hash>/support/rpc_child.dart`。
/// 本地用 `dart run` 跑却全绿 —— 这个差异藏了很久。
///
/// 兜底用 `Directory.current`：`dart test` 的 cwd 是**包目录**。再从 cwd 向上找
/// 几层，兼容 cwd 落在子目录的情况。
String resolveTestSupportFile(String name) {
  final beside = Platform.script.resolve('support/$name');
  if (File(beside.toFilePath()).existsSync()) return beside.toFilePath();

  final suffix = [
    'test',
    'support',
    name,
  ].join(Platform.pathSeparator);

  var dir = Directory.current;
  for (var depth = 0; depth < 4; depth++) {
    final candidate = File('${dir.path}${Platform.pathSeparator}$suffix');
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }

  // 用 join 而不是相邻字符串字面量：后者会被
  // `missing_whitespace_between_adjacent_strings` 判为疑似漏了空格的笔误
  // （CI 是 --fatal-infos，会直接红）。
  throw ArgumentError(
    [
      '找不到测试桩 $name：',
      'Platform.script=${Platform.script}',
      '（dart test 下指向预编译产物，不是源码目录）、',
      'cwd=${Directory.current.path}',
    ].join(),
  );
}

/// 把 [sources]（桩文件的绝对路径）复制到本机临时目录，返回该目录。
///
/// 同一进程内重复调用复用同一个目录，只在首次真正复制。返回目录里的文件名
/// 与源文件同名，直接拼 [Platform.pathSeparator] 就能用。
Directory stageChildStubs(List<String> sources) {
  final dir = _stagingDir ??= Directory.systemTemp.createTempSync(
    'mistream_child_',
  );
  for (final path in sources) {
    final source = File(path);
    if (!source.existsSync()) {
      throw ArgumentError('桩文件不存在: $path');
    }
    final name = source.uri.pathSegments.last;
    source.copySync('${dir.path}${Platform.pathSeparator}$name');
  }
  return dir;
}

/// 删掉暂存目录。清不掉不算失败——那是系统临时目录，交给系统回收。
void cleanChildStubs() {
  final dir = _stagingDir;
  if (dir == null) return;
  _stagingDir = null;
  try {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } on FileSystemException {
    // 文件可能仍被刚杀掉的子进程占着，忽略。
  }
}
