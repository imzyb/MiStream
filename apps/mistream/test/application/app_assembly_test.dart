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

import 'package:download/download.dart';
import 'package:mistream/application/app_assembly.dart';
import 'package:path/path.dart' as p;
import 'package:storage/storage.dart';
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

  group('下载路径与恢复', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.inMemory());
    tearDown(() => db.close());

    AppAssembly assemble({String? downloadsRoot}) =>
        AppAssembly(db, Repositories(db), downloadsRoot: downloadsRoot);

    test('downloadSavePathFor 拼在下载根目录之下', () {
      final assembly = assemble(downloadsRoot: p.join('root', 'downloads'));
      expect(
        assembly.downloadSavePathFor('庆余年 第二季'),
        p.join('root', 'downloads', '庆余年 第二季'),
      );
    });

    test('downloadSavePathFor 清理掉标题里的非法字符', () {
      // 旧实现在 UI 里直接写 `/downloads/<标题>`：Windows 上既会落到**当前盘
      // 根目录**，又会被标题里的 `:` `/` 直接搞坏。
      final assembly = assemble(downloadsRoot: p.join('root', 'downloads'));
      expect(
        assembly.downloadSavePathFor(r'第1集/上: 下'),
        p.join('root', 'downloads', '第1集_上_ 下'),
      );
    });

    test('未配置根目录时只返回清理后的名字', () {
      expect(assemble().downloadSavePathFor('甲'), '甲');
    });

    test('同一部剧的每一集各占一个目录', () {
      // HLS 下载把分片写成 `segment_000000.ts` 这种固定名字。多集共用一个目录
      // 时，第二集会直接覆盖第一集的分片 —— 两份任务各自以为自己下完了，合出来
      // 的文件是两集混在一起。
      final assembly = assemble(downloadsRoot: p.join('root', 'downloads'));
      expect(
        assembly.downloadSavePathFor('庆余年', '第 03 集'),
        p.join('root', 'downloads', '庆余年', '第 03 集'),
      );
      expect(
        assembly.downloadSavePathFor('庆余年', '第 03 集'),
        isNot(assembly.downloadSavePathFor('庆余年', '第 04 集')),
      );
    });

    test('集名为空时退回影片名那一层', () {
      final assembly = assemble(downloadsRoot: p.join('root', 'downloads'));
      expect(
        assembly.downloadSavePathFor('独行月球', ''),
        p.join('root', 'downloads', '独行月球'),
      );
    });

    test('restoreDownloads 走的是数据库仓储，不是内存', () async {
      // 装配层最容易出的错是「建了仓储但管理器还在用默认的内存实现」——
      // 那样用例全绿，而杀进程重启后任务全没了。这条用例钉的就是它。
      final repository = DriftDownloadRepository(db);
      final id = await repository.insertTask(
        DownloadTask(
          id: 0,
          title: '上次没下完的',
          url: 'https://a.com/v.m3u8',
          savePath: p.join('root', 'downloads', '上次没下完的'),
          status: DownloadStatus.downloading,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );

      final assembly = assemble(downloadsRoot: p.join('root', 'downloads'));
      await assembly.restoreDownloads();

      expect(assembly.downloadManager.tasks, hasLength(1));
      expect(
        assembly.downloadManager.taskById(id)!.status,
        DownloadStatus.paused,
        reason: '上次残留的「下载中」重启后要降级成「已暂停」',
      );
      // 降级结果也写回了库。
      expect(
        (await repository.listTasks()).single.status,
        DownloadStatus.paused,
      );
    });
  });
}
