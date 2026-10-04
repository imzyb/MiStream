/// Verifies a packaged Spider JVM runtime layout.
///
/// 与 `check_spider_js_bundle.dart` 对称，但断言的是 **JVM** 运行时的包内布局。
/// 只做「文件在不在、是不是空壳」的检查，不启动 JVM —— 启动冒烟需要 JDK，
/// 见 `tools/jvm_smoke_test.ps1`。
///
/// ## 为什么需要这条门禁
///
/// `runtimes/spider_jvm/build/` 与 `libs/` 都不入库（根 `.gitignore` 的 `build/`
/// 命中前者），jar 由 `melos run jvm:build` 现场编译。于是「发布链忘了构建它」
/// 与「构建了但 CMake 忘了拷进产物」这两种失败**都不会报错**，只会让产物里少
/// 一个目录。0.1.0 的便携包正是这样出厂的：用户装上后 105 个 csp_ 站点全部
/// 显示「(暂不支持)」，而 CI 全绿。
///
/// 所以这条断言的意义不在「检查一个文件」，而在于把「静默降级」变成
/// 「发布链红」。
library;

import 'dart:io';

/// 包内运行时 jar 的相对路径（`AppAssembly._resolveJvmConfig()` 找的就是它）。
const _runtimeJarRelative = 'runtimes/spider_jvm/build/spider_jvm_runtime.jar';

/// 包内依赖目录的相对路径（`java -cp <jar>;<libs>/*` 的第二段）。
const _libsRelative = 'runtimes/spider_jvm/libs';

/// 修复指引。失败时原样打出来 —— 门禁只说「不合格」而不说「怎么修」，
/// 下一个人还得重新推一遍因果链。
const _howToFix =
    '修法：先运行 `melos run jvm:build`（需 JDK 17）再构建，'
    '或确认 CMakeLists.txt 里 runtimes/spider_jvm 的 install 规则还在。';

Future<void> main(List<String> args) async {
  final bundleIndex = args.indexOf('--bundle');
  if (bundleIndex == -1 || bundleIndex + 1 >= args.length) {
    stderr.writeln(
      'Usage: dart run tools/check_jvm_runtime_bundle.dart '
      '--bundle <directory>',
    );
    exitCode = 64;
    return;
  }

  final root = Directory(args[bundleIndex + 1]).absolute;
  if (!root.existsSync()) {
    stderr.writeln('JVM 运行时门禁失败：产物目录不存在（${root.path}）。');
    exitCode = 1;
    return;
  }

  final sep = Platform.pathSeparator;
  final problems = <String>[];

  final jar = File(
    '${root.path}$sep${_runtimeJarRelative.replaceAll('/', sep)}',
  );
  if (!jar.existsSync()) {
    problems.add('缺少运行时 jar：${jar.path}');
  } else if (jar.lengthSync() == 0) {
    problems.add('运行时 jar 是 0 字节空壳：${jar.path}');
  }

  final libs = Directory(
    '${root.path}$sep${_libsRelative.replaceAll('/', sep)}',
  );
  if (!libs.existsSync()) {
    problems.add('缺少依赖目录：${libs.path}');
  } else {
    final jars = libs
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jar'))
        .toList();
    if (jars.isEmpty) {
      // 空目录也算失败：`java -cp ...;libs/*` 会在启动时找不到依赖，
      // 表现成运行时报错而不是「少个可选功能」。
      problems.add('依赖目录里没有任何 .jar：${libs.path}');
    } else {
      final empties = jars.where((f) => f.lengthSync() == 0).toList();
      if (empties.isNotEmpty) {
        problems.add(
          '依赖目录里有 0 字节的 jar：'
          '${empties.map((f) => f.path).join(', ')}',
        );
      } else {
        stdout.writeln('Spider JVM 依赖：${jars.length} 个 jar');
      }
    }
  }

  if (problems.isNotEmpty) {
    stderr.writeln('JVM 运行时门禁失败：产物 ${root.path} 不含可用的 Spider JVM 运行时。');
    for (final problem in problems) {
      stderr.writeln('  - $problem');
    }
    stderr.writeln('影响：所有 csp_ 站点在界面上会显示「(暂不支持)」，整份配置不可用。');
    stderr.writeln(_howToFix);
    exitCode = 1;
    return;
  }

  stdout.writeln('Spider JVM runtime verified: ${root.path}');
}
