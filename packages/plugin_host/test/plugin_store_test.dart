import 'dart:io';

import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

import 'support/plugin_fixture.dart';

/// [PluginStore] 的磁盘行为：版本目录、指针、残留清理、幂等删除。
///
/// 这里刻意全部用**真实文件系统**（系统临时目录），不 mock。这个类的全部价值
/// 就在于「磁盘上到底留下了什么」，mock 掉 IO 等于什么都没测。
void main() {
  final sep = Platform.pathSeparator;
  late Directory root;
  late Directory srcRoot;
  late PluginStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('plugin_store_test_');
    srcRoot = Directory.systemTemp.createTempSync('plugin_store_src_');
    store = PluginStore(pluginsDirectory: root.path);
  });

  tearDown(() {
    for (final dir in [root, srcRoot]) {
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } on FileSystemException {
        // 临时目录清不掉不影响结论。
      }
    }
  });

  /// 拼插件库内的路径。
  String pathOf(String id, [String? a, String? b, String? c]) => [
    root.path,
    id,
    if (a != null) a,
    if (b != null) b,
    if (c != null) c,
  ].join(sep);

  /// 把 [version] 的产物写进版本库。
  Future<void> write(String id, String version, {String? marker}) async {
    final source = makeVersionSource(srcRoot.path, id, version, marker: marker);
    await store.writeVersion(
      DownloadedPlugin(
        manifest: manifestOf(id, version),
        versionDir: source.path,
      ),
    );
  }

  /// 直接往磁盘写指针，模拟「上一次运行留下的状态」。
  void writePointerRaw(String id, String content) {
    final dir = Directory(pathOf(id, 'files'))..createSync(recursive: true);
    File('${dir.path}${sep}current').writeAsStringSync(content);
  }

  String? readPointerRaw(String id) {
    final file = File(pathOf(id, 'files', 'current'));
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// 版本库目录下的条目名（含 `.staging_*` 这类残留），便于断言「清干净了」。
  ///
  /// 用 `path.split` 而不是 `uri.pathSegments.last`：目录的 URI 以 `/` 结尾，
  /// 最后一段永远是空字符串。
  List<String> versionsDirEntries(String id) {
    final dir = Directory(pathOf(id, 'versions'));
    if (!dir.existsSync()) return const [];
    return dir.listSync().map((e) => e.path.split(sep).last).toList()..sort();
  }

  group('init', () {
    test('空目录上不抛异常，也不产生任何状态', () async {
      await store.init();
      expect(store.currentVersionOf('app'), isNull);
      expect(store.previousVersionOf('app'), isNull);
      expect(store.availableVersionsOf('app'), isEmpty);
    });

    test('指针指向已不存在的版本时回退到最高版本，并把指针补回去', () async {
      await write('app', '1.0.0');
      await write('app', '2.0.0');
      writePointerRaw('app', '3.0.0'); // 指向一个从没下载过的版本

      await store.init();

      expect(store.currentVersionOf('app'), '2.0.0');
      expect(
        readPointerRaw('app'),
        '2.0.0',
        reason: '不补指针的话每次启动都会再回退一次，发布态无从判断',
      );
    });

    test('指针内容是空白时同样回退', () async {
      await write('app', '1.0.0');
      writePointerRaw('app', '   \n');

      await store.init();

      expect(store.currentVersionOf('app'), '1.0.0');
      expect(readPointerRaw('app'), '1.0.0');
    });

    test('指针丢失（整个 files 目录都没了）时回退到最高版本', () async {
      await write('app', '1.0.0');
      await write('app', '2.0.0');

      await store.init();

      expect(store.currentVersionOf('app'), '2.0.0');
      expect(readPointerRaw('app'), '2.0.0');
    });

    test('清掉上次没跑完留下的 staging/backup 残留，且不把它们当版本', () async {
      await write('app', '1.0.0');
      final versions = pathOf('app', 'versions');
      Directory('$versions${sep}.staging_2.0.0').createSync(recursive: true);
      Directory('$versions${sep}.backup_1.0.0').createSync(recursive: true);

      await store.init();

      expect(versionsDirEntries('app'), ['1.0.0']);
      expect(store.availableVersionsOf('app'), ['1.0.0']);
    });
  });

  group('writeVersion / installed', () {
    test('落盘后 installed 能读到 manifest', () async {
      await write('app', '1.0.0');

      final manifest = store.installed('app', '1.0.0');

      expect(manifest, isNotNull);
      expect(manifest!.version, '1.0.0');
      expect(manifest.id, 'app');
      expect(store.availableVersionsOf('app'), ['1.0.0']);
    });

    test('重复写同一版本会整体替换，不留 staging/backup 残留', () async {
      await write('app', '1.0.0', marker: 'old');
      await write('app', '1.0.0', marker: 'new');

      final index = File(pathOf('app', 'versions', '1.0.0', 'index.js'));
      expect(index.readAsStringSync(), 'new');
      expect(versionsDirEntries('app'), ['1.0.0']);
    });

    test('版本目录在但 manifest 坏了：installed 返回 null 而不是抛异常', () async {
      await write('app', '1.0.0');
      File(
        pathOf('app', 'versions', '1.0.0', 'manifest.json'),
      ).writeAsStringSync('{ 这不是 JSON');

      expect(store.installed('app', '1.0.0'), isNull);
    });

    test('未下载过的版本 installed 返回 null', () async {
      await write('app', '1.0.0');
      expect(store.installed('app', '9.9.9'), isNull);
    });
  });

  group('availableVersionsOf', () {
    test('按数字段排序，不是按字符串', () async {
      await write('app', '1.10.0');
      await write('app', '1.2.0');
      await write('app', '1.9.0');

      expect(
        store.availableVersionsOf('app'),
        ['1.2.0', '1.9.0', '1.10.0'],
        reason: '字符串排序会把 1.10.0 排到 1.9.0 前面，回退就会选错版本',
      );
    });
  });

  group('activeVersionOf', () {
    test('返回指针指向的版本，而不是最高版本', () async {
      await write('app', '1.0.0');
      await write('app', '2.0.0');
      writePointerRaw('app', '1.0.0');

      await store.init();

      expect(store.activeVersionOf('app')?.version, '1.0.0');
    });

    test('没发布过时返回 null', () async {
      await write('app', '1.0.0');
      expect(store.activeVersionOf('app'), isNull);
    });
  });

  group('pruneBrokenVersions', () {
    test('保留当前版本与可回滚版本，清掉其余', () async {
      await write('app', '1.0.0');
      await write('app', '2.0.0');
      await write('app', '3.0.0');
      writePointerRaw('app', '3.0.0');
      await store.init();
      expect(store.previousVersionOf('app'), '2.0.0');

      store.pruneBrokenVersions(manifestOf('app', '3.0.0'));

      expect(
        store.availableVersionsOf('app'),
        ['2.0.0', '3.0.0'],
        reason: '1.0.0 既不是当前也不是可回滚目标，应当清掉',
      );
    });

    test('从未发布过时跳过，不误删刚下载好的版本', () async {
      await write('app', '1.0.0');
      await write('app', '2.0.0');
      // 刻意不调 init：模拟「下载完但还没发布」的状态，此时没有指针。

      store.pruneBrokenVersions(manifestOf('app', '2.0.0'));

      expect(
        store.availableVersionsOf('app'),
        ['1.0.0', '2.0.0'],
        reason: '没有指针时「哪个是垃圾」无从判断，动手只会删掉用户的东西',
      );
    });
  });

  group('remove', () {
    test('删掉整个版本库，且重复删不抛异常', () async {
      await write('app', '1.0.0');
      writePointerRaw('app', '1.0.0');
      await store.init();

      store.remove('app');

      expect(Directory(pathOf('app')).existsSync(), isFalse);
      expect(store.currentVersionOf('app'), isNull);
      // 幂等：它跑在 uninstall 里，也会被每个测试的 tearDown 走到，
      // 一条删除失败就会让整个套件变红，而原因与被测行为无关。
      expect(() => store.remove('app'), returnsNormally);
      expect(() => store.remove('从没存在过'), returnsNormally);
    });
  });
}
