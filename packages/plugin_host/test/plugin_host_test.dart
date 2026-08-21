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
      expect(
        () => manager.install(manifest, _FakePluginApi(manifest)),
        throwsA(isA<StateError>()),
      );
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
  _FakePluginApi(this._manifest);

  final PluginManifest _manifest;
  bool activated = false;
  bool deactivated = false;
  bool disposed = false;

  @override
  PluginManifest get manifest => _manifest;

  @override
  Future<void> onActivate() async => activated = true;

  @override
  Future<void> onDeactivate() async => deactivated = true;

  @override
  Future<void> onDispose() async => disposed = true;

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
