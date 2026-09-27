import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

void main() {
  group('PluginManifest', () {
    test('toJson/fromJson roundtrip', () {
      const manifest = PluginManifest(
        id: 'test.plugin',
        name: 'Test Plugin',
        version: '1.0.0',
        type: PluginType.source,
        description: 'A test plugin',
        author: 'Tester',
        permissions: [PluginPermission.network, PluginPermission.storage],
      );

      final json = manifest.toJson();
      final restored = PluginManifest.fromJson(json);

      expect(restored.id, manifest.id);
      expect(restored.name, manifest.name);
      expect(restored.version, manifest.version);
      expect(restored.type, manifest.type);
      expect(restored.description, manifest.description);
      expect(restored.author, manifest.author);
      expect(restored.permissions.length, manifest.permissions.length);
    });

    test('equality by id and version', () {
      const a = PluginManifest(
        id: 'test.plugin',
        name: 'Test',
        version: '1.0.0',
        type: PluginType.source,
      );
      const b = PluginManifest(
        id: 'test.plugin',
        name: 'Test',
        version: '1.0.0',
        type: PluginType.source,
      );
      const c = PluginManifest(
        id: 'other.plugin',
        name: 'Other',
        version: '1.0.0',
        type: PluginType.source,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('PluginType', () {
    test('fromString returns correct type', () {
      expect(PluginType.fromString('source'), PluginType.source);
      expect(PluginType.fromString('parser'), PluginType.parser);
      expect(PluginType.fromString('sniffer'), PluginType.sniffer);
      expect(PluginType.fromString('unknown_type'), PluginType.unknown);
    });
  });

  group('PluginPermission', () {
    test('static constants', () {
      expect(PluginPermission.network.value, 'network');
      expect(PluginPermission.storage.value, 'storage');
      expect(PluginPermission.webview.value, 'webview');
    });

    test('equality', () {
      expect(PluginPermission.network, PluginPermission.network);
      expect(PluginPermission.network == PluginPermission.storage, isFalse);
    });
  });

  group('PluginState 迁移规则', () {
    test('canEnable 只排除已启用', () {
      expect(PluginState.installed.canEnable, isTrue);
      expect(PluginState.disabled.canEnable, isTrue);
      // error 允许再次启用 = 「重试激活」。若这里为 false，故障插件就只能
      // 卸载重装，用户没有任何恢复手段。
      expect(PluginState.error.canEnable, isTrue);
      expect(PluginState.enabled.canEnable, isFalse);
    });

    test('canDisable 只允许已启用', () {
      expect(PluginState.enabled.canDisable, isTrue);
      expect(PluginState.installed.canDisable, isFalse);
      expect(PluginState.disabled.canDisable, isFalse);
      expect(PluginState.error.canDisable, isFalse);
    });

    test('isFailed 只认 error', () {
      expect(PluginState.error.isFailed, isTrue);
      for (final state in [
        PluginState.installed,
        PluginState.enabled,
        PluginState.disabled,
      ]) {
        expect(state.isFailed, isFalse);
      }
    });
  });

  group('PluginManager', () {
    late PluginManager manager;

    setUp(() {
      manager = PluginManager();
    });

    tearDown(() async {
      await manager.disposeAll();
    });

    test('install adds plugin and emits events', () async {
      final events = <PluginEvent>[];
      final sub = manager.events.listen(events.add);

      const manifest = PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        type: PluginType.source,
      );
      final api = _FakePluginApi(manifest);

      await manager.install(manifest, api);
      await Future<void>.delayed(Duration.zero);

      expect(manager.getState('test'), PluginState.enabled);
      expect(manager.getApi('test'), api);
      expect(events.length, 1);
      expect(events.first.newState, PluginState.enabled);
      expect(api.activated, isTrue);
      await sub.cancel();
    });

    test('install duplicate throws', () async {
      const manifest = PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        type: PluginType.source,
      );

      await manager.install(manifest, _FakePluginApi(manifest));
      // 用 `expectLater` 而不是 `expect(() => ...)`：`install` 是 async 函数，
      // 异常进的是 Future 而不是同步抛出，闭包形式断言不到。
      await expectLater(
        manager.install(manifest, _FakePluginApi(manifest)),
        throwsA(isA<StateError>()),
      );
      // 重复安装失败不该破坏已装好的那个
      expect(manager.getState('test'), PluginState.enabled);
    });

    test('enable/disable toggles state', () async {
      const manifest = PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        type: PluginType.source,
      );
      final api = _FakePluginApi(manifest);

      await manager.install(manifest, api);
      expect(manager.getState('test'), PluginState.enabled);

      await manager.disable('test');
      expect(manager.getState('test'), PluginState.disabled);
      expect(api.deactivated, isTrue);

      await manager.enable('test');
      expect(manager.getState('test'), PluginState.enabled);
      expect(api.activated, isTrue);
    });

    test('uninstall removes plugin and calls dispose', () async {
      const manifest = PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        type: PluginType.source,
      );
      final api = _FakePluginApi(manifest);

      await manager.install(manifest, api);
      await manager.uninstall('test');

      expect(manager.getState('test'), isNull);
      expect(api.disposed, isTrue);
    });

    test('getByType returns correct plugins', () async {
      const source = PluginManifest(
        id: 's1',
        name: 'Source',
        version: '1.0.0',
        type: PluginType.source,
      );
      const sniffer = PluginManifest(
        id: 'n1',
        name: 'Sniffer',
        version: '1.0.0',
        type: PluginType.sniffer,
      );

      await manager.install(source, _FakePluginApi(source));
      await manager.install(sniffer, _FakePluginApi(sniffer));

      expect(manager.getByType(PluginType.source).length, 1);
      expect(manager.getByType(PluginType.sniffer).length, 1);
      expect(manager.getByType(PluginType.player).length, 0);
    });

    test('getEnabled returns only enabled plugins', () async {
      const m1 = PluginManifest(
        id: 'p1',
        name: 'P1',
        version: '1.0.0',
        type: PluginType.source,
      );
      const m2 = PluginManifest(
        id: 'p2',
        name: 'P2',
        version: '1.0.0',
        type: PluginType.source,
      );

      await manager.install(m1, _FakePluginApi(m1));
      await manager.install(m2, _FakePluginApi(m2));
      await manager.disable('p1');

      expect(manager.getEnabled().length, 1);
      expect(manager.getEnabled().first.id, 'p2');
    });
  });

  group('PluginManager 生命周期状态机', () {
    late PluginManager manager;

    setUp(() {
      manager = PluginManager();
    });

    tearDown(() async {
      await manager.disposeAll();
    });

    PluginManifest manifestOf(String id) => PluginManifest(
      id: id,
      name: id,
      version: '1.0.0',
      type: PluginType.source,
    );

    test('激活失败时进入 error 态，不是无痕失败', () async {
      final manifest = manifestOf('broken');
      final api = _FakePluginApi(manifest, failActivate: true);
      final events = <PluginEvent>[];
      final sub = manager.events.listen(events.add);

      await expectLater(
        manager.install(manifest, api),
        throwsA(isA<StateError>()),
      );
      await Future<void>.delayed(Duration.zero);

      // 关键：异常照旧抛出，但插件必须留在管理器里且状态是 error ——
      // 否则用户既看不到它、也无从卸载。
      expect(manager.getState('broken'), PluginState.error);
      expect(manager.getApi('broken'), api);
      expect(events, hasLength(1));
      expect(events.single.oldState, PluginState.installed);
      expect(events.single.newState, PluginState.error);
      // error 不是 enabled，不该出现在可用列表里
      expect(manager.getEnabled(), isEmpty);

      await sub.cancel();
    });

    test('error 态插件可以重试启用', () async {
      final manifest = manifestOf('flaky');
      final api = _FakePluginApi(manifest, failActivate: true);

      await expectLater(
        manager.install(manifest, api),
        throwsA(isA<StateError>()),
      );
      expect(manager.getState('flaky'), PluginState.error);

      // 外部条件修好（例如补授权限）后重试
      api.failActivate = false;
      await manager.enable('flaky');

      expect(manager.getState('flaky'), PluginState.enabled);
      expect(api.activated, isTrue);
      expect(manager.getEnabled().single.id, 'flaky');
    });

    test('error 态插件可以卸载', () async {
      final manifest = manifestOf('stuck');
      final api = _FakePluginApi(manifest, failActivate: true);

      await expectLater(
        manager.install(manifest, api),
        throwsA(isA<StateError>()),
      );

      await manager.uninstall('stuck');

      expect(manager.getState('stuck'), isNull);
      expect(api.disposed, isTrue);
    });

    test('enable 对已启用的插件抛异常', () async {
      final manifest = manifestOf('on');
      await manager.install(manifest, _FakePluginApi(manifest));

      await expectLater(manager.enable('on'), throwsA(isA<StateError>()));
      expect(manager.getState('on'), PluginState.enabled);
    });

    test('enable/disable/uninstall 对不存在的插件抛异常', () async {
      await expectLater(manager.enable('ghost'), throwsA(isA<StateError>()));
      await expectLater(manager.disable('ghost'), throwsA(isA<StateError>()));
      await expectLater(manager.uninstall('ghost'), throwsA(isA<StateError>()));
    });

    test('disable 对已停用的插件抛异常', () async {
      final manifest = manifestOf('off');
      await manager.install(manifest, _FakePluginApi(manifest));
      await manager.disable('off');

      await expectLater(manager.disable('off'), throwsA(isA<StateError>()));
      expect(manager.getState('off'), PluginState.disabled);
    });

    test('停用失败时状态保持 enabled（插件其实还在跑）', () async {
      final manifest = manifestOf('sticky');
      final api = _FakePluginApi(manifest, failDeactivate: true);
      await manager.install(manifest, api);

      await expectLater(manager.disable('sticky'), throwsA(isA<StateError>()));

      // 没停成就不该标成已停用或故障 —— 它仍在运行
      expect(manager.getState('sticky'), PluginState.enabled);
      expect(manager.getEnabled().single.id, 'sticky');
    });

    test('单个插件清理失败不阻断其余，且异常不静默', () async {
      // 故意把坏插件排在前：它抛异常时，排在后面的好插件仍必须被清理。
      final bad = manifestOf('bad');
      final good = manifestOf('good');
      final badApi = _FakePluginApi(bad, failDispose: true);
      final goodApi = _FakePluginApi(good);

      await manager.install(bad, badApi);
      await manager.install(good, goodApi);

      await expectLater(manager.disposeAll(), throwsA(isA<StateError>()));

      expect(goodApi.disposed, isTrue);
      // 清理完照样要清空并关掉事件流，否则调用方永远等不到流结束
      expect(manager.manifests, isEmpty);
    });
  });

  group('PermissionChecker', () {
    test('hasAllPermissions returns true when all granted', () {
      const manifest = PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        type: PluginType.source,
        permissions: [PluginPermission.network, PluginPermission.storage],
      );

      final checker = PermissionChecker({
        'test': [PluginPermission.network, PluginPermission.storage],
      });

      expect(checker.hasAllPermissions(manifest), isTrue);
    });

    test('hasAllPermissions returns false when missing', () {
      const manifest = PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        type: PluginType.source,
        permissions: [PluginPermission.network, PluginPermission.webview],
      );

      final checker = PermissionChecker({
        'test': [PluginPermission.network],
      });

      expect(checker.hasAllPermissions(manifest), isFalse);
    });

    test('getMissingPermissions returns missing ones', () {
      const manifest = PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        type: PluginType.source,
        permissions: [
          PluginPermission.network,
          PluginPermission.storage,
          PluginPermission.webview,
        ],
      );

      final checker = PermissionChecker({
        'test': [PluginPermission.network],
      });

      final missing = checker.getMissingPermissions(manifest);
      expect(missing.length, 2);
      expect(missing, contains(PluginPermission.storage));
      expect(missing, contains(PluginPermission.webview));
    });

    test('grant and revoke', () {
      final checker = PermissionChecker({});

      checker.grant('test', PluginPermission.network);
      expect(checker.getGranted('test'), [PluginPermission.network]);

      checker.revoke('test', PluginPermission.network);
      expect(checker.getGranted('test'), isEmpty);
    });
  });
}

class _FakePluginApi implements SourcePluginApi {
  _FakePluginApi(
    this._manifest, {
    this.failActivate = false,
    this.failDeactivate = false,
    this.failDispose = false,
  });

  final PluginManifest _manifest;
  bool activated = false;
  bool deactivated = false;
  bool disposed = false;

  /// 置 `true` 后对应的生命周期回调抛异常。
  /// 用来驱动 [PluginState.error] 与「单个插件清理失败」这两条路径。
  bool failActivate;
  bool failDeactivate;
  bool failDispose;

  @override
  PluginManifest get manifest => _manifest;

  @override
  Future<void> onActivate() async {
    if (failActivate) throw StateError('${_manifest.id} 激活失败');
    activated = true;
  }

  @override
  Future<void> onDeactivate() async {
    if (failDeactivate) throw StateError('${_manifest.id} 停用失败');
    deactivated = true;
  }

  @override
  Future<void> onDispose() async {
    if (failDispose) throw StateError('${_manifest.id} 释放失败');
    disposed = true;
  }

  @override
  Future<List<Map<String, dynamic>>> getHome() async => [];

  @override
  Future<List<Map<String, dynamic>>> getCategories() async => [];

  @override
  Future<Map<String, dynamic>> getCategoryDetail({
    required String typeId,
    int page = 1,
  }) async => {};

  @override
  Future<List<Map<String, dynamic>>> search({
    required String keyword,
    int page = 1,
  }) async => [];

  @override
  Future<Map<String, dynamic>> getDetail({required String vodId}) async => {};

  @override
  Future<Map<String, dynamic>> getPlayUrl({
    required String vodId,
    required String flag,
    String? episodeId,
  }) async => {};
}
