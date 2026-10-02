import 'dart:io';

import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

import 'support/plugin_fixture.dart';

/// [PluginStore.upgrade] / [rollback] 的行为契约。
///
/// 核心不变量只有一条：**任何失败路径都不能让用户失去当前能用的版本**。
/// 指针、旧版本目录、可回滚目标，三者要么一起前进，要么原地不动。
void main() {
  final sep = Platform.pathSeparator;
  late Directory root;
  late Directory srcRoot;
  late PluginStore store;

  /// 每次成功发布时记一笔，用来断言「通知到了」/「没通知」。
  late List<String> published;

  /// 置 true 后发布通知抛异常，模拟「指针切好了但运行时没接上」。
  var failPublish = false;

  setUp(() {
    root = Directory.systemTemp.createTempSync('plugin_upgrade_test_');
    srcRoot = Directory.systemTemp.createTempSync('plugin_upgrade_src_');
    published = [];
    failPublish = false;
    store = PluginStore(
      pluginsDirectory: root.path,
      publishPointer: (id, version) async {
        published.add('$id@$version');
        if (failPublish) throw StateError('注入的发布失败');
      },
    );
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

  String pathOf(String id, [String? a, String? b, String? c]) => [
    root.path,
    id,
    ?a,
    ?b,
    ?c,
  ].join(sep);

  /// 把 [version] 的产物写进版本库。
  Future<void> write(String id, String version) async {
    final source = makeVersionSource(srcRoot.path, id, version);
    await store.writeVersion(
      DownloadedPlugin(
        manifest: manifestOf(id, version),
        versionDir: source.path,
      ),
    );
  }

  /// 手工发布 [version]：写指针 + init 重建内存状态。
  Future<void> publish(String id, String version) async {
    final dir = Directory(pathOf(id, 'files'))..createSync(recursive: true);
    File('${dir.path}${sep}current').writeAsStringSync(version);
    await store.init();
  }

  /// 造一个「已发布 1.0.0，磁盘上还有 2.0.0」的常见起点。
  Future<void> givenUpgradable() async {
    await write('app', '1.0.0');
    await write('app', '2.0.0');
    await publish('app', '1.0.0');
  }

  group('upgrade', () {
    test('正常升级：新版本先激活，指针再切，旧版本成为回滚目标', () async {
      await givenUpgradable();

      final api = RecordingPluginApi(manifestOf('app', '2.0.0'));
      final result = await store.upgrade(manifestOf('app', '2.0.0'), api);

      expect(result?.version, '2.0.0');
      expect(api.activateCount, 1, reason: '新版本必须先激活');
      expect(store.currentVersionOf('app'), '2.0.0');
      expect(store.previousVersionOf('app'), '1.0.0');
      expect(store.activeVersionOf('app')?.version, '2.0.0');
      expect(published, ['app@2.0.0']);
    });

    test('目标版本不在磁盘上：返回 null，且根本不去激活它', () async {
      await givenUpgradable();

      final api = RecordingPluginApi(manifestOf('app', '9.9.9'));
      final result = await store.upgrade(manifestOf('app', '9.9.9'), api);

      expect(result, isNull);
      expect(api.activateCount, 0, reason: '产物都没下载就先别激活');
      expect(store.currentVersionOf('app'), '1.0.0');
      expect(published, isEmpty);
    });

    test('已经是指针指向的版本：幂等短路，不重复激活', () async {
      await givenUpgradable();
      await store.upgrade(
        manifestOf('app', '2.0.0'),
        RecordingPluginApi(manifestOf('app', '2.0.0')),
      );
      published.clear();

      // 同一个升级包被投递第二次（下载器重试等）。
      final api = RecordingPluginApi(manifestOf('app', '2.0.0'));
      final result = await store.upgrade(manifestOf('app', '2.0.0'), api);

      expect(result, isNull);
      expect(api.activateCount, 0);
      expect(store.alreadyCurrent('app', '2.0.0'), isTrue);
      expect(published, isEmpty);
    });

    test('新版本激活失败：指针与旧版本一个字节都没动', () async {
      await givenUpgradable();

      final api = RecordingPluginApi(
        manifestOf('app', '2.0.0'),
        failActivate: true,
      );
      final result = await store.upgrade(manifestOf('app', '2.0.0'), api);

      expect(result, isNull);
      expect(api.activateCount, 1);
      expect(store.currentVersionOf('app'), '1.0.0');
      expect(store.activeVersionOf('app')?.version, '1.0.0');
      expect(published, isEmpty);
      // 新版本目录留着：用户能诊断它、也能修好外部条件后重试。
      expect(store.availableVersionsOf('app'), contains('2.0.0'));
    });

    test('指针切好了但发布通知失败：如实返回 null，但保留新指针', () async {
      await givenUpgradable();

      failPublish = true;
      final api = RecordingPluginApi(manifestOf('app', '2.0.0'));
      final result = await store.upgrade(manifestOf('app', '2.0.0'), api);

      expect(result, isNull, reason: '通知没成功就要如实返回失败');
      expect(
        store.currentVersionOf('app'),
        '2.0.0',
        reason: '磁盘上新版本才是真的；把指针写回旧版本会让它指向可能已删的目录',
      );
      expect(store.previousVersionOf('app'), '1.0.0');
    });

    test('允许降级：升级到一个更低的版本号也能成功', () async {
      await write('app', '1.0.0');
      await write('app', '2.0.0');
      await publish('app', '2.0.0');

      // 用户主动用升级通道装一个更低的版本号（修坏版本的常见手段）。
      final api = RecordingPluginApi(manifestOf('app', '1.0.0'));
      final result = await store.upgrade(manifestOf('app', '1.0.0'), api);

      expect(result?.version, '1.0.0');
      expect(store.currentVersionOf('app'), '1.0.0');
      expect(store.previousVersionOf('app'), '2.0.0');
    });
  });

  group('rollback', () {
    /// 起点：从 1.0.0 升到 2.0.0。
    Future<void> givenUpgraded() async {
      await givenUpgradable();
      await store.upgrade(
        manifestOf('app', '2.0.0'),
        RecordingPluginApi(manifestOf('app', '2.0.0')),
      );
      published.clear();
    }

    test('回到上一个版本，并把刚换下来的版本记为新的回滚目标', () async {
      await givenUpgraded();

      final api = RecordingPluginApi(manifestOf('app', '1.0.0'));
      final result = await store.rollback(manifestOf('app', '2.0.0'), api);

      expect(result?.version, '1.0.0');
      expect(api.activateCount, 1, reason: '回滚也要先激活旧版本');
      expect(store.currentVersionOf('app'), '1.0.0');
      expect(store.previousVersionOf('app'), '2.0.0');
      expect(published, ['app@1.0.0']);
    });

    test('只有一个版本时没有回滚目标，返回 null', () async {
      await write('app', '1.0.0');
      await publish('app', '1.0.0');

      final api = RecordingPluginApi(manifestOf('app', '1.0.0'));
      final result = await store.rollback(manifestOf('app', '1.0.0'), api);

      expect(result, isNull);
      expect(api.activateCount, 0);
    });

    test('回滚目标目录已被清理：返回 null，不假装成功', () async {
      await givenUpgraded();
      Directory(pathOf('app', 'versions', '1.0.0')).deleteSync(recursive: true);

      final api = RecordingPluginApi(manifestOf('app', '1.0.0'));
      final result = await store.rollback(manifestOf('app', '2.0.0'), api);

      expect(result, isNull);
      expect(api.activateCount, 0, reason: '目录都不在了，不该去激活');
      expect(store.currentVersionOf('app'), '2.0.0');
    });

    test('回滚时激活失败：返回 null，当前版本继续服务', () async {
      await givenUpgraded();

      final api = RecordingPluginApi(
        manifestOf('app', '1.0.0'),
        failActivate: true,
      );
      final result = await store.rollback(manifestOf('app', '2.0.0'), api);

      expect(result, isNull);
      expect(store.currentVersionOf('app'), '2.0.0');
      expect(store.activeVersionOf('app')?.version, '2.0.0');
      expect(published, isEmpty);
    });

    test('回滚后重放同一个升级包：判成已是最新，不重复动作', () async {
      await givenUpgraded();
      await store.rollback(
        manifestOf('app', '2.0.0'),
        RecordingPluginApi(manifestOf('app', '1.0.0')),
      );
      published.clear();

      // 升级通道又推了一次 2.0.0 —— 现在指针在 1.0.0，所以这是**正常的再升级**。
      final api = RecordingPluginApi(manifestOf('app', '2.0.0'));
      final result = await store.upgrade(manifestOf('app', '2.0.0'), api);

      expect(result?.version, '2.0.0');
      expect(api.activateCount, 1);
      expect(store.currentVersionOf('app'), '2.0.0');
      expect(store.previousVersionOf('app'), '1.0.0');
    });
  });
}
