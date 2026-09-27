/// [AppAssembly] 里 java 运行时探测的单测。
///
/// 覆盖「`JAVA_HOME` 优先 → `PATH` 回退」这条链：它决定 `classifySiteRuntime`
/// 判为 jvm 的站点（`api` 以 `csp_` 开头）会不会被整体当成「无运行时」。真实
/// 配置里这类站点常常占绝大多数，漏掉 `PATH` 回退等于整份配置都点不动。
///
/// 用例用真实临时目录 + 真实文件，因为被测函数本体就是靠 `existsSync` 判断的；
/// 换成 mock 就测不到「目录存在但没有该文件」这类真实分支。
library;

import 'dart:io';

import 'package:mistream/application/app_assembly.dart';
import 'package:test/test.dart';

void main() {
  /// `PATH` 的分隔符随平台变化，用例里手工拼 `PATH` 值时要跟着走。
  final pathSep = Platform.isWindows ? ';' : ':';

  /// 可执行文件名；与实现同一套规则（Windows 带 `.exe`）。
  final javaName = Platform.isWindows ? 'java.exe' : 'java';

  /// 与实现同一套规则，用来构造「名字不对」的反例。
  final otherName = Platform.isWindows ? 'java' : 'java.exe';

  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mistream-path-probe');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  String sub(String name) => '${root.path}${Platform.pathSeparator}$name';

  /// 造一个 `PATH` 形态的目录：`<name>/<java>`，返回该目录路径。
  String pathDirWithJava(String name) {
    final dir = Directory(sub(name))..createSync(recursive: true);
    File(
      '${dir.path}${Platform.pathSeparator}$javaName',
    ).writeAsStringSync('placeholder');
    return dir.path;
  }

  /// 造一个存在但**不含** java 的目录。
  String pathDirWithoutJava(String name) {
    Directory(sub(name)).createSync(recursive: true);
    return sub(name);
  }

  /// 造一个 `JAVA_HOME` 形态的目录：`<name>/bin/<java>`，返回 `<name>`。
  String javaHomeWithJava(String name) {
    final bin = Directory('${sub(name)}${Platform.pathSeparator}bin')
      ..createSync(recursive: true);
    File(
      '${bin.path}${Platform.pathSeparator}$javaName',
    ).writeAsStringSync('placeholder');
    return sub(name);
  }

  /// 造一个 `JAVA_HOME` 形态但 `bin/` 下没有 java 的目录。
  String javaHomeWithoutJava(String name) {
    Directory(
      '${sub(name)}${Platform.pathSeparator}bin',
    ).createSync(recursive: true);
    return sub(name);
  }

  group('resolveJavaPath', () {
    test('JAVA_HOME 可用时优先用它', () {
      final home = javaHomeWithJava('jdk');
      final onPath = pathDirWithJava('path-jdk');
      expect(
        AppAssembly.resolveJavaPath(javaHome: home, pathValue: onPath),
        '${home}${Platform.pathSeparator}bin'
        '${Platform.pathSeparator}$javaName',
      );
    });

    test('JAVA_HOME 没设时回退到 PATH', () {
      // 本次修复的核心：原来这里直接返回 null，于是整份 csp_ 配置被判成
      // 「无运行时」——片源列表灰显、探测阶段直接跳过。
      final onPath = pathDirWithJava('path-jdk');
      expect(
        AppAssembly.resolveJavaPath(javaHome: null, pathValue: onPath),
        '${onPath}${Platform.pathSeparator}$javaName',
      );
    });

    test('JAVA_HOME 是空串时视作没设', () {
      final onPath = pathDirWithJava('path-jdk');
      expect(
        AppAssembly.resolveJavaPath(javaHome: '', pathValue: onPath),
        '${onPath}${Platform.pathSeparator}$javaName',
      );
    });

    test('JAVA_HOME 指向的目录里没有 java 时回退到 PATH', () {
      final broken = javaHomeWithoutJava('broken-jdk');
      final onPath = pathDirWithJava('path-jdk');
      expect(
        AppAssembly.resolveJavaPath(javaHome: broken, pathValue: onPath),
        '${onPath}${Platform.pathSeparator}$javaName',
      );
    });

    test('两处都没有时返回 null', () {
      expect(
        AppAssembly.resolveJavaPath(
          javaHome: javaHomeWithoutJava('broken-jdk'),
          pathValue: pathDirWithoutJava('empty-path-dir'),
        ),
        isNull,
      );
    });
  });

  group('findExecutableOnPath', () {
    test('PATH 缺失或为空时返回 null', () {
      expect(AppAssembly.findExecutableOnPath(null, javaName), isNull);
      expect(AppAssembly.findExecutableOnPath('', javaName), isNull);
    });

    test('命中单段 PATH', () {
      final dir = pathDirWithJava('jdk');
      expect(
        AppAssembly.findExecutableOnPath(dir, javaName),
        '${dir}${Platform.pathSeparator}$javaName',
      );
    });

    test('前段没有时继续往后找', () {
      final missing = sub('nope');
      final hit = pathDirWithJava('jdk');
      expect(
        AppAssembly.findExecutableOnPath('$missing$pathSep$hit', javaName),
        '${hit}${Platform.pathSeparator}$javaName',
      );
    });

    test('命中第一段后不再往后找', () {
      final first = pathDirWithJava('first');
      final second = pathDirWithJava('second');
      expect(
        AppAssembly.findExecutableOnPath('$first$pathSep$second', javaName),
        '${first}${Platform.pathSeparator}$javaName',
      );
    });

    test('跳过空段与空白段', () {
      final hit = pathDirWithJava('jdk');
      expect(
        AppAssembly.findExecutableOnPath(
          '$pathSep  $pathSep$hit$pathSep',
          javaName,
        ),
        '${hit}${Platform.pathSeparator}$javaName',
      );
    });

    test('目录存在但没有该可执行文件时不算命中', () {
      expect(
        AppAssembly.findExecutableOnPath(
          pathDirWithoutJava('jdk-empty'),
          javaName,
        ),
        isNull,
      );
    });

    test('全都不存在时返回 null', () {
      expect(
        AppAssembly.findExecutableOnPath(
          '${sub('a')}$pathSep${sub('b')}',
          javaName,
        ),
        isNull,
      );
    });

    test('可执行文件名不做后缀兼容', () {
      // 找另一个名字不该被同目录下的 java 满足，否则会拿到一个非可执行的
      // 同名文件交给子进程。
      final dir = pathDirWithJava('jdk');
      expect(AppAssembly.findExecutableOnPath(dir, otherName), isNull);
    });
  });
}
